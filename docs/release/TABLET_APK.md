# Android Tablet Deployment

For daily Android tablet testing, do **not** use `.github/workflows/release.yml`. That workflow is for store/distribution releases and intentionally requires a release keystore.

Use `.github/workflows/android_tablet_apk.yml` instead.

## Permanent flow

- Every relevant push to `main` automatically builds an installable Android APK.
- `NOT_SUPABASE_URL` and `NOT_SUPABASE_PUBLISHABLE_KEY` are injected with `--dart-define` during the build.
- Android release-keystore secrets are not required for this tablet-test APK.
- The workflow uploads the artifact as `not-android-tablet-apk` containing `not-tablet.apk` and its SHA-256 checksum.

## One-command installation

With the tablet connected and authorized through ADB:

```bash
bash tools/install_tablet_latest.sh
```

The script downloads the newest successful `Android tablet APK (Supabase)` artifact from GitHub Actions, verifies its checksum, and installs it with `adb install -r`.

Requirements on the development machine:

- GitHub CLI (`gh`) authenticated for GitHub Actions artifact access.
- Android Platform Tools (`adb`).
- An authorized Android device visible in `adb devices`.

## Store releases

`Signed release packaging` remains the official store/distribution workflow. Android AAB generation there requires:

- `NOT_ANDROID_KEYSTORE_B64`
- `NOT_RELEASE_STORE_PASSWORD`
- `NOT_RELEASE_KEY_ALIAS`
- `NOT_RELEASE_KEY_PASSWORD`

Those signing secrets are intentionally independent from Supabase client configuration.
