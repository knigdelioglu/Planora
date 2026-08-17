alter table public.entities
  drop constraint if exists entities_entity_type_check;

alter table public.entities
  add constraint entities_entity_type_check
  check (entity_type in (
    'note',
    'board',
    'column',
    'card',
    'card_note_link',
    'attachment',
    'reminder'
  ));

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
  if p_entity_type not in (
    'note',
    'board',
    'column',
    'card',
    'card_note_link',
    'attachment',
    'reminder'
  ) then
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

  insert into public.entities(
    user_id,
    entity_type,
    entity_id,
    version,
    updated_at,
    deleted_at,
    payload
  )
  values(
    uid,
    p_entity_type,
    p_entity_id,
    p_version,
    p_updated_at,
    p_deleted_at,
    coalesce(p_payload, '{}'::jsonb)
  )
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

revoke all on function public.apply_entity_change(
  text,
  text,
  bigint,
  bigint,
  timestamptz,
  timestamptz,
  jsonb
) from public;

grant execute on function public.apply_entity_change(
  text,
  text,
  bigint,
  bigint,
  timestamptz,
  timestamptz,
  jsonb
) to authenticated;
