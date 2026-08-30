# Third-party notices

Newbili is distributed under GPL-3.0-only. The following list records projects and services that informed or support this repository. Each third party retains its own copyright, trademark, license, database rights, and service terms.

## Primary upstream and lineage

- **PiliPlus** — <https://github.com/bggRGjQaUbCoE/PiliPlus> — GPL-3.0. Newbili Android is a modified derivative of upstream commit `44680b8a486a0518f366a2c9bff6242506cf8783` (2.1.2 series, imported 2026-08-30). PiliPlus is also the primary feature and behavior reference for Newbili iOS.
- **PiliPalaX** — <https://github.com/orz12/PiliPalaX> — GPL-3.0. Upstream lineage acknowledged by PiliPlus.
- **PiliPala** — <https://github.com/guozhigq/pilipala> — GPL-3.0. Original upstream lineage acknowledged by PiliPlus/PiliPalaX.

## Design and native-client references

- **AniShelf** — <https://github.com/samuelhe52/AniShelf> — Apache-2.0. Newbili's PGC browsing surfaces adapt its immersive artwork, soft color-orb background, rounded poster-card, and content-hierarchy ideas while retaining Newbili's own navigation and playback behavior.
- **MiniBili-WEB** — <https://github.com/ResistanceTo/MiniBili-WEB> — MIT. Apple-platform product presentation and interface reference.
- **PiliPod** — <https://github.com/BPTPW/PiliPod> — GPL-3.0. Swift-native client and player-interaction reference.
- **BiliBili-UWP** — <https://github.com/Richasy/BiliBili-UWP> — GPL-3.0. Fluent hierarchy, acrylic treatment, content organization, and wide-screen Master–Detail design reference. Newbili reimplements these ideas for touch-first phone and tablet layouts; it does not copy the Windows title bar or fixed desktop panes.
- **AndroidLiquidGlass / Backdrop** — <https://github.com/Kyant0/AndroidLiquidGlass> — Apache-2.0. Rendering-principle and capability-degradation reference. The current Flutter client uses its own `BackdropFilter`-based surfaces and does not directly link the Compose library.

## API documentation and community services

- **bilibili-API-collect** — <https://github.com/SocialSisterYi/bilibili-API-collect>. Public API documentation and field-semantics reference. The repository does not currently declare a standard SPDX license, so Newbili treats it as documentation to cite rather than a source package to copy.
- **BilibiliSponsorBlock** — <https://github.com/hanydd/BilibiliSponsorBlock> — GPL-3.0. Newbili talks to its public segment query/report API. API and community-database terms remain controlled by that project.
- **SponsorBlock** — <https://github.com/ajayyy/SponsorBlock> — GPL-3.0. Original SponsorBlock project and protocol lineage. Its database/API may be governed separately from source code.

## Optional tooling

- **Flutter / Dart** — <https://github.com/flutter/flutter> and <https://github.com/dart-lang/sdk> — BSD-3-Clause. The Android client is built with Flutter 3.47.2 and carries the generated package notices inside the APK.
- **media-kit / libmpv / FFmpeg** — <https://github.com/media-kit/media-kit>, <https://github.com/mpv-player/mpv>, and <https://github.com/FFmpeg/FFmpeg>. Android playback packages native libmpv/FFmpeg components supplied by PiliPlus's pinned media-kit toolchain. Their MIT/LGPL/GPL and optional-component terms remain applicable; inspect the build configuration before redistribution.
- **canvas_danmaku** — <https://github.com/bggRGjQaUbCoE/canvas_danmaku> — MIT. Flutter danmaku renderer used by the Android client.
- **Anime4K** — <https://github.com/bloc97/Anime4K> — MIT. Optional player shader assets included by the Android upstream.
- **Font Awesome / Material Design Icons** — <https://fontawesome.com/license/free> and <https://pictogrammers.com/docs/general/license/>. Icon font assets and packages used by the Android interface; their respective free-icon licenses apply.
- **FFmpeg (optional iOS research tooling)** — <https://github.com/FFmpeg/FFmpeg>. `Scripts/fetch-ffmpeg-av1-vt.sh` can separately fetch an iOS research build. FFmpeg licensing depends on its configuration and enabled components; consult <https://ffmpeg.org/legal.html> before redistribution.
- **actions/checkout** — <https://github.com/actions/checkout> — MIT. Used by the GitHub Actions unsigned-IPA workflow to check out this repository.
- **actions/upload-artifact** — <https://github.com/actions/upload-artifact> — MIT. Used by the GitHub Actions unsigned-IPA workflow to publish the generated artifact.

## Apple platform software

Newbili uses Apple-provided Swift, SwiftUI, UIKit, AVFoundation, AVKit, VideoToolbox, Metal, Network, WebKit, AuthenticationServices, PhotosUI, Compression, Xcode, and Icon Composer. These are platform frameworks and developer tools, not code relicensed by this repository.

If a required attribution is missing or inaccurate, please open an issue at <https://github.com/Rseam-07/Newbili/issues>.
