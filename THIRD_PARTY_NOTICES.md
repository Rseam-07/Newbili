# Third-party notices

Newbili is distributed under GPL-3.0-only. The following list records projects and services that informed or support this repository. Each third party retains its own copyright, trademark, license, database rights, and service terms.

## Primary upstream and lineage

- **PiliPlus** — <https://github.com/bggRGjQaUbCoE/PiliPlus> — GPL-3.0. Primary feature, API-parameter, model-field, and interaction-behavior reference for Newbili.
- **PiliPalaX** — <https://github.com/orz12/PiliPalaX> — GPL-3.0. Upstream lineage acknowledged by PiliPlus.
- **PiliPala** — <https://github.com/guozhigq/pilipala> — GPL-3.0. Original upstream lineage acknowledged by PiliPlus/PiliPalaX.

## Design and native-client references

- **MiniBili-WEB** — <https://github.com/ResistanceTo/MiniBili-WEB> — MIT. Apple-platform product presentation and interface reference.
- **PiliPod** — <https://github.com/BPTPW/PiliPod> — GPL-3.0. Swift-native client and player-interaction reference.

## API documentation and community services

- **bilibili-API-collect** — <https://github.com/SocialSisterYi/bilibili-API-collect>. Public API documentation and field-semantics reference. The repository does not currently declare a standard SPDX license, so Newbili treats it as documentation to cite rather than a source package to copy.
- **BilibiliSponsorBlock** — <https://github.com/hanydd/BilibiliSponsorBlock> — GPL-3.0. Newbili talks to its public segment query/report API. API and community-database terms remain controlled by that project.
- **SponsorBlock** — <https://github.com/ajayyy/SponsorBlock> — GPL-3.0. Original SponsorBlock project and protocol lineage. Its database/API may be governed separately from source code.

## Optional tooling

- **FFmpeg** — <https://github.com/FFmpeg/FFmpeg>. `Scripts/fetch-ffmpeg-av1-vt.sh` can fetch FFmpeg for separate AV1/VideoToolbox research. Newbili does not bundle an FFmpeg binary by default. FFmpeg licensing depends on the configuration and enabled components; consult <https://ffmpeg.org/legal.html> before redistribution.
- **actions/checkout** — <https://github.com/actions/checkout> — MIT. Used by the GitHub Actions unsigned-IPA workflow to check out this repository.
- **actions/upload-artifact** — <https://github.com/actions/upload-artifact> — MIT. Used by the GitHub Actions unsigned-IPA workflow to publish the generated artifact.

## Apple platform software

Newbili uses Apple-provided Swift, SwiftUI, UIKit, AVFoundation, AVKit, VideoToolbox, Metal, Network, WebKit, AuthenticationServices, PhotosUI, Compression, Xcode, and Icon Composer. These are platform frameworks and developer tools, not code relicensed by this repository.

If a required attribution is missing or inaccurate, please open an issue at <https://github.com/Rseam-07/Newbili/issues>.
