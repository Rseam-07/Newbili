#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_MODE="${1:-preview}"
case "$PREVIEW_MODE" in
  preview|--regression) ;;
  *) echo 'Usage: prepare-native-device-preview.sh [--regression]' >&2; exit 2 ;;
esac
if [[ "$PREVIEW_MODE" == "--regression" ]]; then
  PREVIEW_PROJECT="$ROOT_DIR/NativeDeviceRegression.xcodeproj"
else
  PREVIEW_PROJECT="$ROOT_DIR/NativeDevicePreview.xcodeproj"
fi
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
# Prepare a separate local target. Xcode writes Personal Team signing only to
# this ignored copy; the original app, account data and release project remain.
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$ROOT_DIR/Newbili.xcodeproj" "$PREVIEW_PROJECT"
python3 - "$ROOT_DIR" "$SDK_VERSION" "$PREVIEW_MODE" <<'PY'
from pathlib import Path
import plistlib
import sys
root=Path(sys.argv[1]); sdk=sys.argv[2]; regression=sys.argv[3]=='--regression'
deployment=sdk if tuple(map(int, sdk.split('.'))) < (26,4) else '26.4'
name='NativeDeviceRegression' if regression else 'NativeDevicePreview'
bundle='com.rseam07.newbili.nativeregression' if regression else 'com.rseam07.newbili.nativepreview'
info_name='.native-device-regression-Info.plist' if regression else '.native-device-preview-Info.plist'
project=root/(name+'.xcodeproj')
p=project/'project.pbxproj'
s=p.read_text().replace('IPHONEOS_DEPLOYMENT_TARGET = 26.4;', f'IPHONEOS_DEPLOYMENT_TARGET = {deployment};')
s=s.replace('com.rseam07.newbiliTests', bundle+'Tests')
s=s.replace('PRODUCT_BUNDLE_IDENTIFIER = com.rseam07.newbili;', 'PRODUCT_BUNDLE_IDENTIFIER = '+bundle+';')
s=s.replace('Config/Newbili-Info.plist', info_name)
p.write_text(s)
for scheme in (project/'xcshareddata/xcschemes').glob('*.xcscheme'):
    scheme.write_text(scheme.read_text().replace('container:Newbili.xcodeproj','container:'+name+'.xcodeproj'))
info=plistlib.loads((root/'Config/Newbili-Info.plist').read_bytes())
info['CFBundleDisplayName']='Newbili 自动回归' if regression else 'Newbili 原生预览'
(root/info_name).write_bytes(plistlib.dumps(info))
print(project)
PY
