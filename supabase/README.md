# Supabase setup

`0001_initial.sql` is the authoritative remote schema for the single-user-per-account sync backend.

Apply it with the Supabase CLI against the intended project. The Flutter client only receives the project URL and publishable/anon key. A `service_role` key must never be shipped in the application binary.

The schema intentionally stores syncable objects in one `entities` table so the client can pull an ordered delta stream by `sync_revision`. The `apply_entity_change` RPC performs optimistic version checking. Attachments are private Storage objects under `<auth.uid()>/<attachment-id>/<filename>` and are protected by RLS policies.
