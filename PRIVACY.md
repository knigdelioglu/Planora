# Privacy

Not is designed as a private, single-user personal workspace.

## Local data

Notes, boards, cards, reminder metadata and attachment metadata are stored in the application's local SQLite database. Attachment bytes are stored in the application's managed filesystem rather than in SQLite.

## Cloud synchronization

Cloud synchronization is optional and only activates when a Supabase project is configured and the user signs in. When enabled, syncable entity data and attachment files are sent to that configured Supabase project. Row-level security restricts remote records to the authenticated account.

## Logs

Production logging must not include note bodies, attachment contents, passwords, session tokens or privileged keys.

## Advertising and analytics

The product scope contains no advertising SDK and no behavioral analytics SDK.
