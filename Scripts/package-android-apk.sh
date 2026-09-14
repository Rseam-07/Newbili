#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/AndroidFlutter"
SOURCE_APK_DIR="${NEWBILI_APK_DIR:-$PROJECT_DIR/build/app/outputs/flutter-apk}"
ANDROID_SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
EXPECTED_SIGNER_SHA256="4876a7a04d24c8a89e82ca355a8f3fc404019d076af5aae2f5faaac32b5d6cdb"
LEGACY_TEST_KEYSTORE="${NEWBILI_LEGACY_ANDROID_KEYSTORE:-${HOME}/.android/debug.keystore}"

if [[ -z "$ANDROID_SDK_DIR" ]]; then
  echo "Set ANDROID_SDK_ROOT or ANDROID_HOME before packaging." >&2
  exit 1
fi

version="$(awk '/^version:/ { print $2 }' "$PROJECT_DIR/pubspec.yaml")"
version_name="${version%+*}"
version_code="${version##*+}"
apksigner="$(find "$ANDROID_SDK_DIR/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner | sort | tail -n 1)"
aapt2="$(find "$ANDROID_SDK_DIR/build-tools" -mindepth 2 -maxdepth 2 -type f -name aapt2 | sort | tail -n 1)"
if [[ -z "$apksigner" || -z "$aapt2" ]]; then
  echo "Android build-tools with apksigner and aapt2 are required." >&2
  exit 1
fi
zipalign="${aapt2%/*}/zipalign"
if [[ ! -x "$zipalign" || ! -f "$LEGACY_TEST_KEYSTORE" ]]; then
  echo "zipalign and the legacy Newbili Android test keystore are required." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/dist"

for abi in armeabi-v7a arm64-v8a x86_64; do
  source_apk="$SOURCE_APK_DIR/app-$abi-release.apk"
  output_apk="$ROOT_DIR/dist/Newbili-Android-$version_name-$version_code-$abi-test.apk"
  if [[ ! -f "$source_apk" ]]; then
    echo "Release APK was not produced for $abi." >&2
    exit 1
  fi

  # Reject stale/mislabeled CI artifacts before copying or signing anything.
  badging="$("$aapt2" dump badging "$source_apk")"
  printf '%s\n' "$badging" | sed -n '1,5p'
  if [[ "$badging" != *"package: name='com.rseam07.newbili'"* ||
        "$badging" != *"versionCode='$version_code'"* ||
        "$badging" != *"versionName='$version_name'"* ||
        "$badging" != *"minSdkVersion:'31'"* ||
        "$badging" != *"native-code: '$abi'"* ]]; then
    echo "APK identity, version, minimum SDK or ABI does not match this release." >&2
    exit 1
  fi

  "$zipalign" -f 4 "$source_apk" "$output_apk"
  "$apksigner" sign \
    --ks "$LEGACY_TEST_KEYSTORE" \
    --ks-key-alias androiddebugkey \
    --ks-pass pass:android \
    --key-pass pass:android \
    --v1-signing-enabled false \
    --v2-signing-enabled true \
    --v3-signing-enabled false \
    "$output_apk"

  "$apksigner" verify --verbose --print-certs "$output_apk"
  "$zipalign" -c 4 "$output_apk"
  # Merge stderr: some build-tools versions send certificate details there.
  signer_sha256="$("$apksigner" verify --print-certs "$output_apk" 2>&1 | sed -n 's/^.*certificate SHA-256 digest: //p' | head -n 1)"
  if [[ "$signer_sha256" != "$EXPECTED_SIGNER_SHA256" ]]; then
    echo "APK signer differs from the existing public Newbili Android test release." >&2
    exit 1
  fi

  echo "Android test-channel APK: $output_apk"
  shasum -a 256 "$output_apk"
done
