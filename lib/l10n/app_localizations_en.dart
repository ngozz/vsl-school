// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VSL School';

  @override
  String get appWindowTitle => 'VSL School — Vietnamese Sign Language Lessons';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String loadError(String error) {
    return 'Could not load data:\n$error';
  }

  @override
  String get cdnUnavailable =>
      'CDN unavailable — downloads and streaming are disabled.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeBlack => 'Black';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get rememberSpeed => 'Remember playback speed';

  @override
  String get rememberSpeedHint =>
      'Apply the last chosen speed to the next video';

  @override
  String get settingsDownloads => 'Downloads & updates';

  @override
  String downloadedSummary(
    int lessons,
    int lessonsTotal,
    int videos,
    String size,
  ) {
    final intl.NumberFormat lessonsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String lessonsString = lessonsNumberFormat.format(lessons);
    final intl.NumberFormat lessonsTotalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String lessonsTotalString = lessonsTotalNumberFormat.format(
      lessonsTotal,
    );
    final intl.NumberFormat videosNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String videosString = videosNumberFormat.format(videos);

    return 'Downloaded: $lessonsString/$lessonsTotalString lessons ($videosString videos, $size)';
  }

  @override
  String get checkUpdates => 'Check for updates on launch';

  @override
  String get checkUpdatesOff => 'Off = fully offline once downloaded';

  @override
  String get downloadAll => 'Download all content';

  @override
  String get checkNow => 'Check for updates';

  @override
  String get deleteDownloaded => 'Delete downloaded data';

  @override
  String get replayIntro => 'View the guide again';

  @override
  String lessonCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Lessons: $countString';
  }

  @override
  String get dataCredit =>
      'Lesson content from “App Khiem Thinh” (qipedc.moet.gov.vn).';

  @override
  String get allDownloaded => 'Everything is already downloaded.';

  @override
  String get downloadOnWifi => 'Will download on Wi-Fi (reopen this screen).';

  @override
  String downloadStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Started downloading $countString videos…';
  }

  @override
  String deletedVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Deleted $countString videos.';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Could not check: $error';
  }

  @override
  String get upToDate => 'Content is up to date.';

  @override
  String get subjectMath => 'Maths';

  @override
  String get subjectLiterature => 'Vietnamese';

  @override
  String get subjectMathShort => 'Num';

  @override
  String get subjectLiteratureShort => 'Viet';

  @override
  String gradeChip(int grade) {
    return 'Grade $grade';
  }

  @override
  String get hasUpdate => 'Update available';

  @override
  String get lessonDownloaded => 'This lesson is already downloaded.';

  @override
  String get lessonEmpty => 'This lesson has no content yet';

  @override
  String get downloadedBadge => 'Downloaded';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get downloadLesson => 'Download this lesson';

  @override
  String bannerDeleting(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Deleting $doneString/$totalString videos…';
  }

  @override
  String get bannerCanceling => 'Cancelling…';

  @override
  String bannerDownloading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Downloading $doneString/$totalString videos…';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteTitle => 'Delete downloaded data';

  @override
  String deleteBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Delete $countString downloaded videos (~$size)? Videos will stream from the CDN.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get batchTitle => 'Download content';

  @override
  String batchBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Will download $countString videos (~$size).\nWi-Fi recommended. Continue?';
  }

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get noWifiTitle => 'No Wi-Fi detected';

  @override
  String noWifiBody(String size) {
    return 'This device is on mobile data. Continue downloading (~$size)?';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get lessonDownloadTitle => 'Downloading lesson';

  @override
  String lessonProgress(
    int done,
    int total,
    String doneSize,
    String totalSize,
  ) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString/$totalString videos — $doneSize / $totalSize';
  }

  @override
  String get updateTitle => 'Content update available';

  @override
  String updateChanged(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString videos changed';
  }

  @override
  String updateRemoved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString videos removed';
  }

  @override
  String updateMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '… and $countString more lessons';
  }

  @override
  String updateLessonLine(String lesson, String detail) {
    return '$lesson: $detail';
  }

  @override
  String get updateOtherGroup => 'Other';

  @override
  String updateTotal(int files, String size) {
    final intl.NumberFormat filesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String filesString = filesNumberFormat.format(files);

    return 'Total: $filesString videos (~$size). Update to get the latest.';
  }

  @override
  String get update => 'Update';

  @override
  String updateStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Re-downloading $countString updated videos…';
  }

  @override
  String get replay => 'Replay';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get languageSubtitle => 'You can change this any time in Settings.';

  @override
  String get introWelcomeTitle => 'Welcome to VSL School';

  @override
  String get introWelcomeBody =>
      'Vietnamese Sign Language lessons for Maths and Vietnamese, grades 1–5 — watch online or download for offline study.';

  @override
  String get introOfflineTitle => 'Fully offline';

  @override
  String get introOfflineBody =>
      'Open Settings → “Download all content” (~2.9 GB) to save every lesson. Then turn off “Check for updates on launch” — the app needs no network after that.';

  @override
  String get introSourceTitle => 'Data source';

  @override
  String get introSourceBody =>
      'Content, videos and subtitles from Vietnam\'s national sign-language portal: “App Khiem Thinh” (qipedc.moet.gov.vn) — Vietnam Sign Language Centre / Ministry of Education and Training. This is a personal-use app, not the original work. Happy learning!';

  @override
  String get notifRunningTitle => 'Downloading in background';

  @override
  String notifRunningBody(int total, String size) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString videos (~$size)';
  }

  @override
  String get notifCompleteTitle => 'Download complete';

  @override
  String notifCompleteBody(String token) {
    return '$token videos downloaded';
  }

  @override
  String get notifErrorTitle => 'Lesson download failed';

  @override
  String notifErrorBody(String token) {
    return '$token failed';
  }
}
