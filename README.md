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
flutter build apk --release         # Android (CI release-signs; debug-signed locally)
flutter build web --release         # Web → build/web
flutter build ios --no-codesign     # iOS (needs Xcode + macOS)
```

### Android release signing

The keystore is created **once** and kept forever: Android refuses to update
an installed app whose signing key changed. Back it up (e.g. Google Drive) and
never commit it — `android/key.properties`, `*.jks` and `*.keystore` are
git-ignored.

```powershell
# from vsl-school/android/app
keytool -genkeypair -v -keystore vsl-school.jks -storetype PKCS12 `
  -keyalg RSA -keysize 2048 -validity 10000 -alias vsl-school
```

- Use the **same password** for the store and the key (PKCS12 requires it).
- Losing the keystore means every user has to uninstall before updating.

Add four repository secrets (**Settings → Secrets and variables → Actions**):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the PowerShell output below |
| `ANDROID_STORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `vsl-school` |
| `ANDROID_KEY_PASSWORD` | same as the store password |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("vsl-school.jks"))
```

CI decodes that into `android/app/vsl-school.jks` and writes
`android/key.properties` (`storeFile=vsl-school.jks`) before
`flutter build apk --release`; without the secret the APK stays debug-signed.

**One-time migration:** the previously published APK was debug-signed, so
Android refuses to install a release-signed build over it. Uninstall the old
app once (this also deletes downloaded videos and settings), then install the
new APK.

## CI/CD (GitHub Actions)

`.github/workflows/build.yml` builds and publishes automatically. Triggers:

| Trigger | Effect |
|---|---|
| Push commit whose **message contains `[build]`** | Full build: Android APK + Web + unsigned iOS IPA |
| **Manual** (`workflow_dispatch`) | Same, any time |
| Any other push | CI skipped on purpose |

Each build run **creates a GitHub Release** (`build<run-number>`) containing:

- `vsl-school-android.apk` — sideload-ready (release-signed in CI)
- `vsl-school-ios-unsigned.ipa` — not code-signed; resign or use a sideload
  tool (e.g. AltStore, Sideloadly) to install
- `vsl-school-web.zip` — static web build

The web artifact is also **deployed to GitHub Pages** automatically on each
`main` build (base path is baked at build time so it works under `/<repo>/`),
at `https://ngozz.github.io/vsl-school/`.

## iOS via SideStore / AltStore

The iOS build can be added to SideStore or AltStore using this source:

```
https://ngozz.github.io/vsl-school/altstore-source.json
```

It points at the latest unsigned IPA release; SideStore/AltStore signs it
during installation (same scheme as vsl-dictionary). The file lives in
`web/altstore-source.json` and ships to Pages with every web build — bump its
`version`/`date` when you want SideStore to see an update.

### Repo setup notes

1. Enable **Actions → Settings → Pages → GitHub Pages** with the workflow
   source set (the `deploy-pages` job configures this).
2. The Android APK is **release-signed** in CI from four repository secrets:
   `ANDROID_KEYSTORE_BASE64` (base64 of `vsl-school.jks`),
   `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`vsl-school`) and
   `ANDROID_KEY_PASSWORD`. Without them the build stays debug-signed, so
   forks and local runs still work. See
   [Android release signing](#android-release-signing).
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
