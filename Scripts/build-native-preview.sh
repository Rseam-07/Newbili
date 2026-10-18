#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_PROJECT="$ROOT_DIR/.native-preview.xcodeproj"
SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
# Local build copy only: the published project's minimum stays at iOS 26.4.
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$ROOT_DIR/Newbili.xcodeproj" "$PREVIEW_PROJECT"
python3 - "$PREVIEW_PROJECT" "$SDK_VERSION" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); sdk=sys.argv[2]
deployment=sdk if tuple(map(int, sdk.split('.'))) < (26,4) else '26.4'
p=root/'project.pbxproj'
p.write_text(p.read_text().replace('IPHONEOS_DEPLOYMENT_TARGET = 26.4;', f'IPHONEOS_DEPLOYMENT_TARGET = {deployment};'))
for scheme in (root/'xcshareddata/xcschemes').glob('*.xcscheme'):
    scheme.write_text(scheme.read_text().replace('container:Newbili.xcodeproj', 'container:.native-preview.xcodeproj'))
PY
if [[ $# -eq 0 ]]; then
  set -- build
fi
xcodebuild -project "$PREVIEW_PROJECT" -scheme Newbili -configuration Debug \
  -sdk iphonesimulator -destination "${NATIVE_PREVIEW_DESTINATION:-generic/platform=iOS Simulator}" \
  -derivedDataPath "${NATIVE_PREVIEW_DERIVED_DATA:-/private/tmp/newbili-native-derived}" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO "$@"
