#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/AndroidFlutter"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter)}"
ANDROID_SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

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

ANDROID_SDK_ROOT="$ANDROID_SDK_DIR" "$ROOT_DIR/Scripts/package-android-apk.sh"
