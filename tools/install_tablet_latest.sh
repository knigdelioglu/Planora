#!/usr/bin/env bash
set -euo pipefail

REPO="${NOT_GITHUB_REPO:-knigdelioglu/not}"
WORKFLOW="android_tablet_apk.yml"
ARTIFACT="not-android-tablet-apk"

for cmd in gh adb; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' is required" >&2
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "error: GitHub CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
  echo "error: no authorized Android device is connected" >&2
  adb devices >&2 || true
  exit 1
fi

run_id="$({
  gh run list \
    --repo "$REPO" \
    --workflow "$WORKFLOW" \
    --branch main \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId'
} 2>/dev/null || true)"

if [[ -z "$run_id" || "$run_id" == "null" ]]; then
  echo "error: no successful '$WORKFLOW' run exists yet" >&2
  echo "Push the current code to main or run the 'Android tablet APK (Supabase)' workflow once." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Downloading latest Supabase-enabled tablet APK (run $run_id)..."
gh run download "$run_id" \
  --repo "$REPO" \
  --name "$ARTIFACT" \
  --dir "$tmp_dir"

apk="$tmp_dir/not-tablet.apk"
checksum="$tmp_dir/not-tablet.apk.sha256"

test -f "$apk" || { echo "error: APK missing from artifact" >&2; exit 1; }

if [[ -f "$checksum" ]]; then
  (
    cd "$tmp_dir"
    sha256sum -c "$(basename "$checksum")"
  )
fi

echo "Installing APK on connected tablet..."
adb install -r "$apk"

echo "Tablet installation complete. Supabase configuration is embedded in this APK at build time."
