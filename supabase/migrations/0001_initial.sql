-- Not cloud schema: single-user-per-account, multi-device synchronization.
create extension if not exists pgcrypto;

create sequence if not exists public.sync_revision_seq;

create table if not exists public.entities (
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (entity_type in ('note','board','column','card','attachment','reminder')),
  entity_id text not null,
  version bigint not null check (version >= 1),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  sync_revision bigint not null default nextval('public.sync_revision_seq'),
  primary key (user_id, entity_type, entity_id)
);

create index if not exists entities_user_revision_idx
  on public.entities(user_id, sync_revision);
create index if not exists entities_user_type_idx
  on public.entities(user_id, entity_type, deleted_at);

create or replace function public.bump_sync_revision()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.sync_revision := nextval('public.sync_revision_seq');
  return new;
end;
$$;

drop trigger if exists entities_bump_sync_revision on public.entities;
create trigger entities_bump_sync_revision
before insert or update on public.entities
for each row execute function public.bump_sync_revision();

alter table public.entities enable row level security;

drop policy if exists "entities_select_own" on public.entities;
create policy "entities_select_own" on public.entities
for select using (auth.uid() = user_id);

drop policy if exists "entities_insert_own" on public.entities;
create policy "entities_insert_own" on public.entities
for insert with check (auth.uid() = user_id);

drop policy if exists "entities_update_own" on public.entities;
create policy "entities_update_own" on public.entities
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "entities_delete_own" on public.entities;
create policy "entities_delete_own" on public.entities
for delete using (auth.uid() = user_id);

create or replace function public.apply_entity_change(
  p_entity_type text,
  p_entity_id text,
  p_base_version bigint,
  p_version bigint,
  p_updated_at timestamptz,
  p_deleted_at timestamptz,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  current_row public.entities%rowtype;
  resulting_revision bigint;
begin
  if uid is null then
    raise exception 'authentication required';
  end if;
  if p_entity_type not in ('note','board','column','card','attachment','reminder') then
    raise exception 'unsupported entity type';
  end if;
  if p_version < 1 then
    raise exception 'version must be positive';
  end if;

  select * into current_row
  from public.entities
  where user_id = uid and entity_type = p_entity_type and entity_id = p_entity_id
  for update;

  if found and p_base_version is not null and current_row.version <> p_base_version then
    return jsonb_build_object(
      'status', 'conflict',
      'remote', jsonb_build_object(
        'entity_type', current_row.entity_type,
        'entity_id', current_row.entity_id,
        'version', current_row.version,
        'updated_at', current_row.updated_at,
        'deleted_at', current_row.deleted_at,
        'payload', current_row.payload,
        'sync_revision', current_row.sync_revision
      )
    );
  end if;

  insert into public.entities(user_id, entity_type, entity_id, version, updated_at, deleted_at, payload)
  values(uid, p_entity_type, p_entity_id, p_version, p_updated_at, p_deleted_at, coalesce(p_payload, '{}'::jsonb))
  on conflict(user_id, entity_type, entity_id)
  do update set
    version = excluded.version,
    updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at,
    payload = excluded.payload
  returning sync_revision into resulting_revision;

  return jsonb_build_object('status', 'ok', 'revision', resulting_revision);
end;
$$;

revoke all on function public.apply_entity_change(text,text,bigint,bigint,timestamptz,timestamptz,jsonb) from public;
grant execute on function public.apply_entity_change(text,text,bigint,bigint,timestamptz,timestamptz,jsonb) to authenticated;

insert into storage.buckets(id, name, public)
values ('attachments', 'attachments', false)
on conflict(id) do update set public = false;

-- Supabase manages RLS on storage.objects. Do not ALTER the Storage-owned table;
-- define only the application-specific access policies below.
drop policy if exists "attachments_select_own" on storage.objects;
create policy "attachments_select_own" on storage.objects
for select to authenticated
using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "attachments_insert_own" on storage.objects;
create policy "attachments_insert_own" on storage.objects
for insert to authenticated
with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "attachments_update_own" on storage.objects;
create policy "attachments_update_own" on storage.objects
for update to authenticated
using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "attachments_delete_own" on storage.objects;
create policy "attachments_delete_own" on storage.objects
for delete to authenticated
using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
