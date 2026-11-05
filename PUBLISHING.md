# Publishing checklist — vsl-school

## Release hygiene
- [x] `LICENSE` (MIT), `fastlane/metadata/android/` (en-US + vi-VN text, icon,
      4 phone screenshots, `changelogs/1.txt`).
- [ ] Tag the release commit — F-Droid reads these tags:
      `git tag v1.0.0 && git push origin v1.0.0`
- [ ] `pubspec.yaml` version is `1.0.0+1`. For every future store release the
      `+N` (versionCode) must strictly increase.
- [ ] CI publishes on a `[build]` commit marker and auto-attaches the APK/IPA
      to a GitHub Release. Edit the release text for v1.0.0 to be user-facing.

## Store listings
- Keep `short_description.txt` ≤ 80 chars (no trailing dot) and `title.txt`
  ≤ 30 chars.
- For every future release add `changelogs/<versionCode>.txt` (≤ 500 chars) in
  both locales — F-Droid reads them automatically.

## F-Droid
1. Repo requirements: FOSS license ✓, FOSS dependencies ✓, version tags,
   fastlane metadata ✓.
2. Open a submission: <https://gitlab.com/fdroid/rfp/issues> (or the forum
   submission queue).
3. Fork <https://gitlab.com/fdroid/fdroiddata> and add
   `metadata/com.ngozz.vsl_school.yml`. Copy the build block from an existing
   Flutter app in fdroiddata; point `UpdateCheckData` at `pubspec.yaml`.
4. Validate with `fdroid lint`, test the build via the fdroiddata CI, then
   open a merge request. Review takes days to weeks.

Before submitting, resolve two things reviewers will hit:

- **Repo size.** The repo currently tracks 772 lesson videos (~2.6 GiB).
  F-Droid's build server clones the whole repository; consider untracking the
  videos (they are already served by the CDN and are not needed to build the
  APK) and keeping them only in releases/CDN.
- **Content licensing.** Lesson videos/text come from "App Khiem Thinh"
  (qipedc.moet.gov.vn) and the app disclaims being the original work.
  Reviewers may tag NonFreeAssets; have the portal's terms (or permission)
  ready to point to. The APK itself bundles no videos — media is downloaded
  from the CDN at runtime.

Notes:
- F-Droid signs the APK with its own key; `vsl-school.jks` stays local and is
  never committed (CI signs GitHub releases from repo secrets).

## Play Store (optional)
- One-time $25 fee; reuse the fastlane text and screenshots for the listing.
- Build an AAB: `flutter build appbundle --release`.
- Data safety: the app collects no user data. Content rating: educational.

## Never commit
- `android/key.properties`, `*.jks` (gitignored; release signing uses GitHub
  secrets).
