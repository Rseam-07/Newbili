#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/AndroidFlutter"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter)}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)}"
PUB_CACHE_DIR="${PUB_CACHE:-${HOME}/.pub-cache}"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "Flutter executable not found: $FLUTTER_BIN" >&2
  exit 1
fi

if ! "$FLUTTER_BIN" --version | head -n 1 | grep -q 'Flutter 3.47.2'; then
  echo "Newbili Android requires Flutter 3.47.2." >&2
  exit 1
fi

apply_once() {
  local target_dir="$1"
  local patch_path="$2"
  local patch_name="${patch_path:t}"

  if (cd "$target_dir" && git apply --recount --ignore-space-change --whitespace=nowarn --reverse --check "$patch_path" >/dev/null 2>&1); then
    echo "Already applied: $patch_name"
  elif (cd "$target_dir" && git apply --recount --ignore-space-change --whitespace=nowarn --check "$patch_path"); then
    (cd "$target_dir" && git apply --recount --ignore-space-change --whitespace=nowarn "$patch_path")
    echo "Applied: $patch_name"
  else
    echo "Patch does not match Flutter 3.47.2: $patch_name" >&2
    exit 1
  fi
}

flutter_patches=(
  modal_barrier.patch
  text_selection.patch
  mouse_cursor.patch
  image_anim.patch
  layout_builder.patch
  navigation_drawer.patch
  popup_menu.patch
  fab.patch
  null_safety_for_selectable_region.patch
  selectable_region.patch
  editable_text.patch
  text_field.patch
  scroll_position.patch
  scrollable.patch
  scrollable_gesture.patch
  draggable_scrollable_sheet.patch
  scaffold.patch
  text.patch
  text_painter.patch
  sliver.patch
  refresh_indicator.patch
  bottom_sheet_android.patch
  scroll_view.patch
  navigator.patch
)

for patch_name in "${flutter_patches[@]}"; do
  apply_once "$FLUTTER_ROOT" "$PROJECT_DIR/lib/scripts/$patch_name"
done

pub_get_args=(pub get)
if [[ "${NEWBILI_OFFLINE:-0}" == "1" ]]; then
  pub_get_args+=(--offline)
fi
(cd "$PROJECT_DIR" && "$FLUTTER_BIN" "${pub_get_args[@]}")

material_ui_dir="$(find "$PUB_CACHE_DIR/hosted/pub.dev" -maxdepth 1 -type d -name 'material_ui-*' | sort | tail -n 1)"
if [[ -z "$material_ui_dir" ]]; then
  echo "material_ui was not found under $PUB_CACHE_DIR." >&2
  exit 1
fi

material_patches=(
  modal_barrier_material.patch
  navigation_drawer.patch
  popup_menu.patch
  fab.patch
  text_field.patch
  scaffold.patch
  refresh_indicator.patch
  tabs.patch
  bottom_sheet_android.patch
)

for patch_name in "${material_patches[@]}"; do
  apply_once "$material_ui_dir" "$PROJECT_DIR/lib/scripts/material/$patch_name"
done

echo "Android Flutter SDK and material_ui patches are ready."
