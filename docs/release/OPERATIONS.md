# Post-release operations

## Severity
- P0: data loss/corruption, security boundary failure, app cannot start, core offline flow is unusable.
- P1: major feature failure with no safe workaround.
- P2: degraded non-critical behavior or visual defect.

P0 releases are blocked. P1 issues require an explicit release decision and remediation plan.

## Database migrations
Every schema change after 1.0 must include an old-schema fixture, forward migration, data-preservation assertions and a recovery plan. Production code must never solve migration failure by silently deleting the database.

## Dependencies
Drift/sqlite, flutter_local_notifications/timezone, Supabase and Riverpod upgrades require changelog/API review before merging. Dependency upgrades are not bundled with unrelated feature work.

## Sync incidents
Investigate queue accumulation by operation status and safe error category without logging user content. Never reset synchronization by deleting local unsynced data. Recovery must preserve a local copy before any destructive repair.

## Backup and backend
Supabase project backup/retention should be configured at the infrastructure level. RLS changes are reviewed as security changes and must be tested with at least two distinct user identities.
