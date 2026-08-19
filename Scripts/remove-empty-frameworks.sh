#!/bin/zsh
set -euo pipefail

APP_PATH="${1:-}"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Usage: ${0:t} /path/to/App.app" >&2
  exit 1
fi

empty_frameworks=()
while IFS= read -r -d '' framework; do
  top_level_payload="$(find "$framework" -maxdepth 1 \( -type f -o -type l \) -print -quit)"
  if [[ -z "$top_level_payload" ]]; then
    empty_frameworks+=("$framework")
  fi
done < <(find "$APP_PATH" -type d -name '*.framework' -print0)

for framework in "${empty_frameworks[@]}"; do
  echo "Removing empty framework: ${framework#$APP_PATH/}"
  rm -rf "$framework"
done

echo "Removed ${#empty_frameworks[@]} empty framework(s) from ${APP_PATH:t}."
