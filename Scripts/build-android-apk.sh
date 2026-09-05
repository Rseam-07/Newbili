#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/AndroidFlutter"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter)}"
ANDROID_SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
EXPECTED_SIGNER_SHA256="4876a7a04d24c8a89e82ca355a8f3fc404019d076af5aae2f5faaac32b5d6cdb"
LEGACY_TEST_KEYSTORE="${NEWBILI_LEGACY_ANDROID_KEYSTORE:-${HOME}/.android/debug.keystore}"

if [[ -z "$ANDROID_SDK_DIR" ]]; then
  echo "Set ANDROID_SDK_ROOT or ANDROID_HOME before building." >&2
  exit 1
fi

if [[ -d "$ANDROID_SDK_DIR/platforms/android-37.0" && ! -e "$ANDROID_SDK_DIR/platforms/android-37" ]]; then
  ln -s android-37.0 "$ANDROID_SDK_DIR/platforms/android-37"
fi

FLUTTER_BIN="$FLUTTER_BIN" "$ROOT_DIR/Scripts/prepare-android-flutter.sh"

(cd "$PROJECT_DIR" && "$FLUTTER_BIN" analyze --no-pub --no-fatal-infos)
(cd "$PROJECT_DIR" && "$FLUTTER_BIN" test --no-pub)
version_line="$(grep -E '^version:' "$PROJECT_DIR/pubspec.yaml" | awk '{print $2}')"
version_name="${version_line%%+*}"
version_code="${version_line##*+}"
build_time="${NEWBILI_BUILD_TIME:-$(date +%s)}"
commit_hash="${NEWBILI_COMMIT_HASH:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"

(cd "$PROJECT_DIR" && \
  GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.project.newbiliDebugReleaseSigning=true" \
  "$FLUTTER_BIN" build apk \
    --release \
    --split-per-abi \
    --no-pub \
    --build-name "$version_name" \
    --build-number "$version_code" \
    --dart-define "pili.name=$version_name" \
    --dart-define "pili.code=$version_code" \
    --dart-define "pili.hash=$commit_hash" \
    --dart-define "pili.time=$build_time")

mkdir -p "$ROOT_DIR/dist"

apksigner="$(find "$ANDROID_SDK_DIR/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner | sort | tail -n 1)"
aapt2="$(find "$ANDROID_SDK_DIR/build-tools" -mindepth 2 -maxdepth 2 -type f -name aapt2 | sort | tail -n 1)"
if [[ -z "$apksigner" || -z "$aapt2" ]]; then
  echo "Android build-tools with apksigner and aapt2 are required." >&2
  exit 1
fi
zipalign="${aapt2:h}/zipalign"
if [[ ! -x "$zipalign" || ! -f "$LEGACY_TEST_KEYSTORE" ]]; then
  echo "zipalign and the legacy Newbili Android test keystore are required." >&2
  exit 1
fi

for abi in armeabi-v7a arm64-v8a x86_64; do
  source_apk="$PROJECT_DIR/build/app/outputs/flutter-apk/app-$abi-release.apk"
  output_apk="$ROOT_DIR/dist/Newbili-Android-$version_name-$version_code-$abi-test.apk"
  if [[ ! -f "$source_apk" ]]; then
    echo "Release APK was not produced for $abi." >&2
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
  # apksigner writes verification details to stderr on some build-tools
  # versions; merge both streams before extracting the certificate digest.
  signer_sha256="$("$apksigner" verify --print-certs "$output_apk" 2>&1 | sed -n 's/^.*certificate SHA-256 digest: //p' | head -n 1)"
  if [[ "$signer_sha256" != "$EXPECTED_SIGNER_SHA256" ]]; then
    echo "APK signer differs from the existing public Newbili Android test release." >&2
    exit 1
  fi

  badging="$("$aapt2" dump badging "$output_apk" | head -n 5)"
  echo "$badging"
  if ! echo "$badging" | grep -q "package: name='com.rseam07.newbili'"; then
    echo "Unexpected Android application id." >&2
    exit 1
  fi
  if ! echo "$badging" | grep -q "minSdkVersion:'31'"; then
    echo "Android 12 minimum SDK verification failed." >&2
    exit 1
  fi

  echo "Android test-channel APK: $output_apk"
  shasum -a 256 "$output_apk"
done
