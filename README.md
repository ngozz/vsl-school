# VSL School — Trường học Ký hiệu Việt Nam

An offline-first Flutter app of sign-language **video lessons** — Toán (math)
and Tiếng Việt (literature) for grades 1–5. Distilled from the "App Khiem Thinh"
lesson app into a lightweight, Vietnamese-interface reader with a custom video
player.

**Source data:** lesson content, videos and captions from the National Sign
Language portal of [qipedc.moet.gov.vn (App Khiem Thinh)](https://qipedc.moet.gov.vn/)
(Trung tâm Kỹ hiệu Việt Nam / Bộ Giáo dục và Đào tạo).

## What it does

- **Lesson browsing** — subject chips (Toán / Tiếng Việt) + grade chips
  (Lớp 1–5), lesson list with video thumbnails.
- **Lesson player** — segment outline synced to lesson videos; tap a segment to
  jump to it.
- **Custom player** (`lib/widgets/lesson_video_player.dart`, built on
  `video_player`) — H.264/AAC mp4 playback, SRT captions with a CC toggle,
  speed menu (0.25×–1.5×), tap-to-show auto-hiding controls, native-style
  fullscreen with portrait/landscape handling.
- **Personal touches** — remember-speed option, three themes (Tối / Đen / Sáng,
  green-seeded Material 3), interface in Vietnamese.

## Project layout

```
vsl-school/
├── data/
│   ├── json/            # title.json (lesson index) + translate.json, exercises/, interactive/ (future use)
│   │   └── tablecontent/  # 150 lesson outlines (segment + video mapping)
│   ├── videos/          # 772 re-encoded lesson videos (H.264 mp4 + AAC)
│   ├── srt/             # 753 Vietnamese caption files (SRT)
│   └── thumbs/          # 150 lesson thumbnails (WebP)
├── lib/
│   ├── main.dart        # app entry + Material You themes
│   ├── models/lesson.dart
│   ├── services/        # lesson catalogue, settings
│   ├── screens/         # home (browse) + lesson screen
│   └── widgets/lesson_video_player.dart
├── .github/workflows/   # build + release CI (see below)
└── icon.png             # launcher icon source
```

Data is mine: the original Unity-era media (.webm) was re-encoded to
H.264/AAC mp4 for broad platform support, captions exported to SRT.

## Building

```bash
flutter pub get
flutter run              # run on a device
flutter build apk --release         # Android (debug signing for now)
flutter build web --release         # Web → build/web
flutter build ios --no-codesign     # iOS (needs Xcode + macOS)
```

## CI/CD (GitHub Actions)

`.github/workflows/build.yml` builds and publishes automatically. Triggers:

| Trigger | Effect |
|---|---|
| Push commit whose **message contains `[build]`** | Full build: Android APK + Web + unsigned iOS IPA |
| **Manual** (`workflow_dispatch`) | Same, any time |
| Any other push | CI skipped on purpose |

Each build run **creates a GitHub Release** (`build<run-number>`) containing:

- `vsl-school-android.apk` — sideload-ready (debug-signed for now)
- `vsl-school-ios-unsigned.ipa` — not code-signed; resign or use a sideload
  tool (e.g. AltStore, Sideloadly) to install
- `vsl-school-web.zip` — static web build

The web artifact is also **deployed to GitHub Pages** automatically on each
`main` build (base path is baked at build time so it works under `/<repo>/`),
at `https://ngozz.github.io/vsl-school/`.

### Repo setup notes

1. Enable **Actions → Settings → Pages → GitHub Pages** with the workflow
   source set (the `deploy-pages` job configures this).
2. The Android APK is **debug-signed** for now — fine for personal sideloading.
   Replace the signing config in `android/app/build.gradle.kts` (and add CI
   keystore secrets) when a Play-Store-ready build is needed.
3. iOS builds need no extra setup (no signing config = unsigned IPA on a
   macOS runner).
4. Media (~2.7 GB) makes the repo big; consider
   [`git lfs`](https://git-lfs.com) for `data/videos/*` if you hit push limits
   — or keep media out of git and stream it from a CDN in a later iteration.

## Data attribution

Lesson content sourced from the national sign-language portal
[App Khiem Thinh (qipedc.moet.gov.vn)](https://qipedc.moet.gov.vn/)
(Trung tâm Kỹ hiệu Việt Nam / Bộ Giáo dục và Đào tạo). This project is a
personal-use reader, not the original work.
