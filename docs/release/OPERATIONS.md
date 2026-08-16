# Release Operations & Deployment Guide

This document outlines the operational procedures, security controls, and automated pipeline specifications for packaging, signing, notarizing, and distributing the application across Android, macOS, and iOS platforms.

---

## 1. Automated Release Pipeline

All official release builds are packaged and signed via the dedicated GitHub Actions workflow:
- **Workflow File:** `.github/workflows/release.yml`
- **Trigger:** Manual trigger via `workflow_dispatch` with target platform selection (`android`, `macos`, `ios`).
- **Flutter Version:** `3.44.8` (stable channel).

---

## 2. GitHub Secrets Specification

Zero sensitive credentials or keys are committed to source control. The workflow dynamically resolves all certificates, keys, and credentials from GitHub Repository Secrets.

| Secret Name | Platform | Description / Format |
| :--- | :--- | :--- |
| `NOT_SUPABASE_URL` | All | Supabase production backend URL |
| `NOT_SUPABASE_PUBLISHABLE_KEY` | All | Supabase anon/publishable client API key |
| `NOT_ANDROID_KEYSTORE_B64` | Android | Base64-encoded release Keystore (`.jks` / `.keystore`) |
| `NOT_RELEASE_STORE_PASSWORD` | Android | Release Keystore password |
| `NOT_RELEASE_KEY_ALIAS` | Android | Release key alias |
| `NOT_RELEASE_KEY_PASSWORD` | Android | Release key alias password |
| `NOT_MACOS_CERTIFICATE_B64` | macOS | Base64-encoded Developer ID Application certificate (`.p12`) |
| `NOT_MACOS_CERTIFICATE_PASSWORD` | macOS | Password for the Developer ID `.p12` certificate |
| `NOT_MACOS_SIGN_IDENTITY` | macOS | Codesign identity (e.g., `Developer ID Application: Team Name (TEAM_ID)`) |
| `NOT_APPLE_TEAM_ID` | macOS / iOS | Apple Developer 10-character Team ID |
| `NOT_APPLE_ID` | macOS / iOS | Apple ID email address for automated services |
| `NOT_APPLE_APP_SPECIFIC_PASSWORD` | macOS / iOS | App-specific password generated via appleid.apple.com |
| `NOT_APPLE_API_KEY_B64` | macOS / iOS | Base64-encoded App Store Connect API Key (`AuthKey_XXXXXXXXXX.p8`) |
| `NOT_APPLE_API_KEY_ID` | macOS / iOS | App Store Connect API Key ID (e.g., `2X9R4HXF34`) |
| `NOT_APPLE_API_ISSUER` | macOS / iOS | App Store Connect Issuer UUID |
| `NOT_IOS_CERTIFICATE_B64` | iOS | Base64-encoded Apple Distribution certificate (`.p12`) |
| `NOT_IOS_CERTIFICATE_PASSWORD` | iOS | Password for the Apple Distribution `.p12` certificate |
| `NOT_IOS_PROVISIONING_PROFILE_B64` | iOS | Base64-encoded App Store Distribution provisioning profile (`.mobileprovision`) |

### Encoding Signing Material for GitHub Secrets
To encode binary certificates and profiles for storage in GitHub Secrets:
```bash
base64 -i Certificate.p12 | tr -d '\n'
base64 -i Profile.mobileprovision | tr -d '\n'
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
base64 -i release.keystore | tr -d '\n'
```

---

## 3. macOS Packaging, Signing & Notarization

For macOS distribution outside the Mac App Store, Apple Gatekeeper requires Developer ID code signing, hardened runtime, and notarization with ticket stapling.

### Execution Steps
1. **Compilation:** `flutter build macos --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
2. **Keychain & Identity:** Creates ephemeral runner keychain, imports Developer ID Application certificate, and unlocks partition list for `/usr/bin/codesign`.
3. **Hardened Runtime Signing:**
   ```bash
   codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$APP_PATH"
   codesign --verify --deep --strict --verbose=2 "$APP_PATH"
   ```
4. **Notarization Submission (`xcrun notarytool`):**
   Submits zip archive to Apple Notary Service and waits synchronously for processing:
   ```bash
   # Using App Store Connect API Key (Preferred)
   xcrun notarytool submit not-macos-submission.zip \
     --key "$RUNNER_TEMP/AuthKey.p8" \
     --key-id "$APPLE_API_KEY_ID" \
     --issuer "$APPLE_API_ISSUER" \
     --wait

   # Or using Apple ID credentials
   xcrun notarytool submit not-macos-submission.zip \
     --apple-id "$APPLE_ID" \
     --password "$APPLE_APP_SPECIFIC_PASSWORD" \
     --team-id "$APPLE_TEAM_ID" \
     --wait
   ```
5. **Ticket Stapling (`xcrun stapler`):**
   Attaches the Apple notarization ticket directly to the `.app` bundle so Gatekeeper can verify it offline:
   ```bash
   xcrun stapler staple "$APP_PATH"
   xcrun stapler validate "$APP_PATH"
   ```
6. **Gatekeeper Assessment Verification (`spctl`):**
   Verifies that macOS Gatekeeper accepts the stapled application without warnings:
   ```bash
   spctl --assess --type execute --verbose "$APP_PATH"
   ```
7. **Distribution Archive:** Generates final `not-macos.zip` containing the notarized and stapled `.app` bundle and uploads as workflow artifact.

### Notarization Troubleshooting
If notarization status returns `Invalid`:
```bash
xcrun notarytool log <SUBMISSION_ID> --key "$KEY_PATH" --key-id "$KEY_ID" --issuer "$ISSUER_ID"
```

---

## 4. iOS Packaging & TestFlight Distribution

For iOS distribution via TestFlight and the App Store:

### Execution Steps
1. **Compilation:** `flutter build ipa --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
2. **Signing:** Code signed with Apple Distribution certificate and matching App Store Distribution provisioning profile.
3. **Pre-Upload Validation (`xcrun altool --validate-app`):**
   Validates the IPA bundle structure, entitlements, and metadata against App Store Connect requirements:
   ```bash
   xcrun altool --validate-app --type ios --file "$IPA_PATH" --apiKey "$APPLE_API_KEY_ID" --apiIssuer "$APPLE_API_ISSUER"
   ```
4. **App Store Connect / TestFlight Upload (`xcrun altool --upload-app`):**
   Uploads the validated IPA package to App Store Connect:
   ```bash
   xcrun altool --upload-app --type ios --file "$IPA_PATH" --apiKey "$APPLE_API_KEY_ID" --apiIssuer "$APPLE_API_ISSUER"
   ```
5. **Artifact Retention:** The signed `.ipa` is published to GitHub Actions artifacts (`not-ios-ipa`).

### Post-Upload TestFlight Flow
1. App Store Connect processes the build (~5-15 minutes).
2. Set "Export Compliance" (Encryption: None / Exempt).
3. Automatically distributed to Internal Testing groups; submitted for Beta App Review for External Testing groups.

---

## 5. Android Signed Release Packaging

For Android distribution via Google Play Store / Internal App Sharing:
1. **Compilation:** `flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
2. **Signing:** Built directly with release keystore and credentials specified via environment variables.
3. **Artifact Retention:** The signed `.aab` is uploaded as `not-android-aab`.

---

## 6. Incident Severity & Operational Procedures

### Severity Definitions
- **P0:** Data loss/corruption, security boundary failure, application crash on launch, core offline flows inoperable.
  - *Action:* Release immediately blocked or distribution halted.
- **P1:** Major feature failure with no safe workaround.
  - *Action:* Requires explicit release decision and immediate patch remediation plan.
- **P2:** Degraded non-critical behavior or visual defect.
  - *Action:* Scheduled for next standard release cycle.

### Database Migrations
Every schema change post-1.0 must include:
1. Old-schema fixture and forward migration test.
2. Data-preservation assertions.
3. Rollback / recovery plan.
*Production code must never resolve migration failures by silently dropping or resetting local databases.*

### Sync Incidents & Queue Accumulation
- Investigate sync queue accumulation by operation status and safe error category without logging user content or PII.
- Never reset synchronization by deleting local unsynced data.
- Recovery routines must preserve an exportable local copy prior to any destructive repair.

### Backup & Backend Infrastructure
- Supabase project backup retention is configured at infrastructure level.
- Row-Level Security (RLS) policies are treated as critical security boundaries and must be verified with at least two distinct authenticated identities.
