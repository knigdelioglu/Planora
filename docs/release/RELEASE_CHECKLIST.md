# Release Checklist

## 1. Code Quality & Data Integrity
- [ ] Phase 18 validation workflow (`phase18_validation.yml`) is green on target commit.
- [ ] Static analysis (`flutter analyze`) and formatting (`dart format`) pass without warnings.
- [ ] Unit, widget, and integration test suite passes with full assertions.
- [ ] No P0 data-loss, corruption, or security defect is open.
- [ ] Database migration fixtures pass from every supported previous schema version.
- [ ] Offline Notes, Kanban, attachments, and reminders are verified.
- [ ] Two-device sync and conflict flows are verified against production-like Supabase backend.

## 2. CI Secrets & Workflow Readiness
- [ ] Repository Secrets configured for Supabase (`NOT_SUPABASE_URL`, `NOT_SUPABASE_PUBLISHABLE_KEY`).
- [ ] Android signing secrets configured (`NOT_ANDROID_KEYSTORE_B64`, `NOT_RELEASE_STORE_PASSWORD`, `NOT_RELEASE_KEY_ALIAS`, `NOT_RELEASE_KEY_PASSWORD`).
- [ ] macOS Developer ID signing & notarization credentials configured (`NOT_MACOS_CERTIFICATE_B64`, `NOT_MACOS_CERTIFICATE_PASSWORD`, `NOT_MACOS_SIGN_IDENTITY`, `NOT_APPLE_TEAM_ID`, `NOT_APPLE_API_KEY_B64` or `NOT_APPLE_ID` / `NOT_APPLE_APP_SPECIFIC_PASSWORD`).
- [ ] iOS Distribution signing & App Store Connect upload credentials configured (`NOT_IOS_CERTIFICATE_B64`, `NOT_IOS_CERTIFICATE_PASSWORD`, `NOT_IOS_PROVISIONING_PROFILE_B64`, `NOT_APPLE_API_KEY_B64` or `NOT_APPLE_ID` / `NOT_APPLE_APP_SPECIFIC_PASSWORD`).

## 3. macOS Distribution & Notarization
- [ ] Developer ID Application certificate imported and verified in workflow.
- [ ] Release app bundle built and codesigned with hardened runtime (`--options runtime --timestamp`).
- [ ] `xcrun notarytool submit --wait` executes and returns `Accepted` status.
- [ ] `xcrun stapler staple` attaches the notarization ticket to the `.app` bundle.
- [ ] `spctl --assess --type execute --verbose` passes with Gatekeeper acceptance.
- [ ] Final `not-macos.zip` artifact verified on a clean macOS user account (no Gatekeeper quarantine popup).
- [ ] File pickers, SQLite access, and local notifications verified on physical Mac.

## 4. iOS & TestFlight Distribution
- [ ] Apple Distribution certificate and mobileprovision profile valid and imported.
- [ ] Release IPA archive generated via `flutter build ipa --release`.
- [ ] `xcrun altool --validate-app` passes without warnings or errors.
- [ ] `xcrun altool --upload-app` successfully uploads IPA to App Store Connect / TestFlight.
- [ ] TestFlight build completes processing and Export Compliance is configured.
- [ ] Internal/External tester groups receive build notifications.
- [ ] Exact notifications, background sync, and terminated-app reminder flows verified on physical iPhone/iPad.

## 5. Android Packaging & Distribution
- [ ] Release keystore available only in secure secret storage.
- [ ] Signed AAB bundle generated and signature verified.
- [ ] Exact alarm and notification permission strings reviewed.
- [ ] Fresh install, upgrade migration, and process-death flows checked on physical Android device.

## 6. Product Metadata & Release Tagging
- [ ] Version and build numbers in `pubspec.yaml` updated and match Git release tag.
- [ ] CHANGELOG.md updated with all user-facing changes and bug fixes.
- [ ] PRIVACY.md and THIRD_PARTY_NOTICES.md verified and current.
- [ ] Store descriptions, release notes, and screenshots updated for targeted distribution channels.
- [ ] Post-release telemetry, sync metrics, and error logs monitored during initial rollout window.
