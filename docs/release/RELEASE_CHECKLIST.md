# Release checklist

## Code and data
- [ ] Phase 18 validation workflow is green.
- [ ] No P0 data-loss, corruption or security defect is open.
- [ ] Database migration fixtures pass from every supported previous schema.
- [ ] Offline Notes, Kanban, attachments and reminders are verified.
- [ ] Two-device sync and conflict flows are verified against the production-like Supabase project.

## Android
- [ ] Release keystore is available only in secret storage.
- [ ] AAB release build is signed.
- [ ] Exact alarm and notification permission copy is reviewed.
- [ ] Fresh install, upgrade and process-death flows are checked on a physical device.

## iOS
- [ ] Distribution certificate/profile is configured outside source control.
- [ ] Archive is signed and validated.
- [ ] Notification permission and terminated-app reminder flow are checked on a physical iPhone/iPad.

## macOS
- [ ] Developer ID or App Store signing identity is configured outside source control.
- [ ] Signed archive is notarized when distributing outside the Mac App Store.
- [ ] Gatekeeper launch, file picker and notifications are checked on a clean user account.

## Product metadata
- [ ] Version/build numbers are final.
- [ ] CHANGELOG, privacy text and third-party notices are current.
- [ ] Store description/screenshots are current for selected distribution channels.
