# Supabase setup

`0001_initial.sql` is the authoritative remote schema for the single-user-per-account sync backend.

The Flutter client only receives the project URL and publishable/anon key. A `service_role` key must never be shipped in the application binary.

The schema intentionally stores syncable objects in one `entities` table so the client can pull an ordered delta stream by `sync_revision`. The `apply_entity_change` RPC performs optimistic version checking. Attachments are private Storage objects under `<auth.uid()>/<attachment-id>/<filename>` and are protected by RLS policies.

## GitHub integration

For a Supabase project connected directly to this repository:

- Repository: `knigdelioglu/not`
- Working directory: `.` because the `supabase/` directory is at repository root.
- Production branch: `main`.
- `Deploy to production` can stay enabled. New files under `supabase/migrations/` are then applied when they reach `main`.
- Supabase preview/automatic branching is not required for this project and can remain disabled on the Free plan.

The GitHub integration deploys the Supabase schema, but it does **not** configure the Flutter application's client credentials. Release builds still need these GitHub Actions repository secrets:

- `NOT_SUPABASE_URL` — Project URL from Supabase project API settings.
- `NOT_SUPABASE_PUBLISHABLE_KEY` — publishable/anon client key from Supabase project API settings.

Local builds can pass the same values without committing credentials:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never commit or ship a `service_role` key.

## Row Level Security (RLS) & Storage Policies

1. **Entities Isolation (`public.entities`)**:
   - `entities_select_own`: Users can only read rows where `auth.uid() = user_id`.
   - `entities_insert_own`: Users can only insert rows with `auth.uid() = user_id`.
   - `entities_update_own`: Users can only update their own rows and cannot change `user_id` to another user.
   - `entities_delete_own`: Users can only delete their own rows.

2. **Optimistic RPC (`apply_entity_change`)**:
   - Executes with `security invoker` privileges.
   - Requires valid `auth.uid()`; unauthenticated / anon callers are rejected.
   - Ensures all mutations occur within the authenticated caller's security boundary.

3. **Private Storage Isolation (`attachments` bucket)**:
   - Objects are stored under `<auth.uid()>/<attachment_id>/<filename>`.
   - `attachments_select_own`, `attachments_insert_own`, `attachments_update_own`, `attachments_delete_own` restrict access to authenticated users matching the first folder token `(storage.foldername(name))[1] = auth.uid()::text`.
   - Anonymous access is completely blocked.

## Synchronization behavior

The client is offline-first. Local mutations are written to SQLite and queued transactionally. While signed in and online, a non-empty sync queue now schedules a debounced sync instead of waiting for the periodic five-minute pass. Returning the app to the foreground also starts a sync immediately.

The local database is bound to the first cloud user that successfully enables synchronization. If a different Supabase account is later signed in on the same local database, synchronization is blocked before any upload or download so queued data cannot cross account boundaries.

## Running RLS Security Tests

An automated real PostgreSQL / Supabase security test suite is located at `test/core/remote/supabase_rls_security_test.dart`.

To run the targeted RLS security test suite:

```bash
flutter test test/core/remote/supabase_rls_security_test.dart
```

Optional environment variables:

- `PGHOST` (default: `localhost`)
- `PGPORT` (default: `5432`)
- `PGDATABASE` (default: `postgres`)
- `PGUSER` (default: `postgres` or current user)
- `PSQL_PATH` (explicit path to `psql` binary if not in default PATH)
