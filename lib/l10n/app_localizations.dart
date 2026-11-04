import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'VSL School'**
  String get appTitle;

  /// No description provided for @appWindowTitle.
  ///
  /// In vi, this message translates to:
  /// **'VSL School — Bài giảng Ký hiệu Việt Nam'**
  String get appWindowTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTooltip;

  /// Fatal error while loading the bundled lesson data.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi tải dữ liệu:\n{error}'**
  String loadError(String error);

  /// No description provided for @cdnUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'CDN không khả dụng — tải/phát trực tuyến bị tắt.'**
  String get cdnUnavailable;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsTheme;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @themeBlack.
  ///
  /// In vi, this message translates to:
  /// **'Đen'**
  String get themeBlack;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// Settings heading for the interface language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguage;

  /// Language name — never translated.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// Language name — never translated.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @rememberSpeed.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhớ tốc độ phát'**
  String get rememberSpeed;

  /// No description provided for @rememberSpeedHint.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng tốc độ đã chọn cho video kế tiếp'**
  String get rememberSpeedHint;

  /// No description provided for @settingsDownloads.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống & cập nhật'**
  String get settingsDownloads;

  /// How much of the catalogue is stored locally.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải: {lessons}/{lessonsTotal} bài ({videos} video, {size})'**
  String downloadedSummary(
    int lessons,
    int lessonsTotal,
    int videos,
    String size,
  );

  /// No description provided for @checkUpdates.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cập nhật khi mở ứng dụng'**
  String get checkUpdates;

  /// No description provided for @checkUpdatesOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải'**
  String get checkUpdatesOff;

  /// No description provided for @downloadAll.
  ///
  /// In vi, this message translates to:
  /// **'Tải toàn bộ nội dung'**
  String get downloadAll;

  /// No description provided for @checkNow.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cập nhật'**
  String get checkNow;

  /// No description provided for @deleteDownloaded.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dữ liệu đã tải'**
  String get deleteDownloaded;

  /// No description provided for @replayIntro.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại hướng dẫn'**
  String get replayIntro;

  /// No description provided for @lessonCount.
  ///
  /// In vi, this message translates to:
  /// **'Số bài học: {count}'**
  String lessonCount(int count);

  /// No description provided for @dataCredit.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung bài học từ “App Khiem Thinh” (qipedc.moet.gov.vn).'**
  String get dataCredit;

  /// No description provided for @allDownloaded.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ nội dung đã được tải về máy.'**
  String get allDownloaded;

  /// No description provided for @downloadOnWifi.
  ///
  /// In vi, this message translates to:
  /// **'Sẽ tải khi có Wi-Fi (mở lại màn hình này).'**
  String get downloadOnWifi;

  /// No description provided for @downloadStarted.
  ///
  /// In vi, this message translates to:
  /// **'Đã bắt đầu tải {count} video…'**
  String downloadStarted(int count);

  /// No description provided for @deletedVideos.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá {count} video.'**
  String deletedVideos(int count);

  /// No description provided for @updateCheckFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kiểm tra: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @upToDate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung đã là bản mới nhất.'**
  String get upToDate;

  /// No description provided for @subjectMath.
  ///
  /// In vi, this message translates to:
  /// **'Toán'**
  String get subjectMath;

  /// No description provided for @subjectLiterature.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get subjectLiterature;

  /// Two-or-three letter fallback shown when a Maths lesson thumbnail is missing.
  ///
  /// In vi, this message translates to:
  /// **'Số'**
  String get subjectMathShort;

  /// Short fallback shown when a Vietnamese-language lesson thumbnail is missing.
  ///
  /// In vi, this message translates to:
  /// **'TV'**
  String get subjectLiteratureShort;

  /// No description provided for @gradeChip.
  ///
  /// In vi, this message translates to:
  /// **'Lớp {grade}'**
  String gradeChip(int grade);

  /// No description provided for @hasUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Có bản cập nhật'**
  String get hasUpdate;

  /// No description provided for @lessonDownloaded.
  ///
  /// In vi, this message translates to:
  /// **'Bài học đã được tải về máy.'**
  String get lessonDownloaded;

  /// No description provided for @lessonEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bài học chưa có nội dung'**
  String get lessonEmpty;

  /// No description provided for @downloadedBadge.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải về máy'**
  String get downloadedBadge;

  /// No description provided for @cancelDownload.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ tải'**
  String get cancelDownload;

  /// No description provided for @downloadLesson.
  ///
  /// In vi, this message translates to:
  /// **'Tải bài này về máy'**
  String get downloadLesson;

  /// No description provided for @bannerDeleting.
  ///
  /// In vi, this message translates to:
  /// **'Đang xoá {done}/{total} video…'**
  String bannerDeleting(int done, int total);

  /// No description provided for @bannerCanceling.
  ///
  /// In vi, this message translates to:
  /// **'Đang huỷ tải…'**
  String get bannerCanceling;

  /// No description provided for @bannerDownloading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải {done}/{total} video…'**
  String bannerDownloading(int done, int total);

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get cancel;

  /// No description provided for @deleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dữ liệu đã tải'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Xoá {count} video đã tải (~{size})? Video sẽ phát trực tuyến từ CDN.'**
  String deleteBody(int count, String size);

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get delete;

  /// No description provided for @batchTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống nội dung'**
  String get batchTitle;

  /// No description provided for @batchBody.
  ///
  /// In vi, this message translates to:
  /// **'Sẽ tải {count} video (~{size}).\nNên dùng Wi-Fi. Tiếp tục?'**
  String batchBody(int count, String size);

  /// No description provided for @later.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get later;

  /// No description provided for @download.
  ///
  /// In vi, this message translates to:
  /// **'Tải'**
  String get download;

  /// No description provided for @noWifiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thấy Wi-Fi'**
  String get noWifiTitle;

  /// No description provided for @noWifiBody.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị đang dùng dữ liệu di động. Tiếp tục tải (~{size})?'**
  String noWifiBody(String size);

  /// No description provided for @continueLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get continueLabel;

  /// No description provided for @lessonDownloadTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải bài học'**
  String get lessonDownloadTitle;

  /// Live counters inside the iOS lesson-download dialog.
  ///
  /// In vi, this message translates to:
  /// **'{done}/{total} video — {doneSize} / {totalSize}'**
  String lessonProgress(int done, int total, String doneSize, String totalSize);

  /// No description provided for @updateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Có bản cập nhật nội dung'**
  String get updateTitle;

  /// No description provided for @updateChanged.
  ///
  /// In vi, this message translates to:
  /// **'{count} video thay đổi'**
  String updateChanged(int count);

  /// No description provided for @updateRemoved.
  ///
  /// In vi, this message translates to:
  /// **'{count} video bỏ'**
  String updateRemoved(int count);

  /// No description provided for @updateMore.
  ///
  /// In vi, this message translates to:
  /// **'… và {count} bài khác'**
  String updateMore(int count);

  /// No description provided for @updateLessonLine.
  ///
  /// In vi, this message translates to:
  /// **'{lesson}: {detail}'**
  String updateLessonLine(String lesson, String detail);

  /// Group label for changed files that do not belong to a known lesson.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get updateOtherGroup;

  /// No description provided for @updateTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng: {files} video (~{size}). Cập nhật để dùng bản mới nhất.'**
  String updateTotal(int files, String size);

  /// No description provided for @update.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get update;

  /// No description provided for @updateStarted.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải lại {count} video cập nhật…'**
  String updateStarted(int count);

  /// No description provided for @replay.
  ///
  /// In vi, this message translates to:
  /// **'Phát lại'**
  String get replay;

  /// No description provided for @pause.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In vi, this message translates to:
  /// **'Phát'**
  String get play;

  /// No description provided for @subtitles.
  ///
  /// In vi, this message translates to:
  /// **'Phụ đề'**
  String get subtitles;

  /// No description provided for @playbackSpeed.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ phát'**
  String get playbackSpeed;

  /// No description provided for @exitFullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhỏ'**
  String get exitFullscreen;

  /// No description provided for @fullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Toàn màn hình'**
  String get fullscreen;

  /// No description provided for @onboardingSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get onboardingStart;

  /// First onboarding step: interface language.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đổi lại bất cứ lúc nào trong Cài đặt.'**
  String get languageSubtitle;

  /// No description provided for @introWelcomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến với VSL School'**
  String get introWelcomeTitle;

  /// No description provided for @introWelcomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài giảng Ký hiệu Việt Nam cho Toán và Tiếng Việt, lớp 1–5 — xem trực tuyến hoặc tải về để học offline.'**
  String get introWelcomeBody;

  /// No description provided for @introOfflineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dùng offline hoàn toàn'**
  String get introOfflineTitle;

  /// No description provided for @introOfflineBody.
  ///
  /// In vi, this message translates to:
  /// **'Vào Cài đặt → “Tải toàn bộ nội dung” (~2,9 GB) để tải mọi bài học về máy. Sau đó tắt “Kiểm tra cập nhật khi mở ứng dụng” — khi đó app không cần mạng nữa.'**
  String get introOfflineBody;

  /// No description provided for @introSourceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nguồn dữ liệu'**
  String get introSourceTitle;

  /// No description provided for @introSourceBody.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung, video và phụ đề từ cổng Ký hiệu Việt Nam quốc gia: “App Khiem Thinh” (qipedc.moet.gov.vn) — Trung tâm Ký hiệu Việt Nam / Bộ Giáo dục và Đào tạo. Ứng dụng dùng làm cá nhân, không phải tác phẩm gốc. Chúc học tốt!'**
  String get introSourceBody;

  /// Android download notification title while a batch runs.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải trong nền'**
  String get notifRunningTitle;

  /// No description provided for @notifRunningBody.
  ///
  /// In vi, this message translates to:
  /// **'{total} video (~{size})'**
  String notifRunningBody(int total, String size);

  /// No description provided for @notifCompleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất tải'**
  String get notifCompleteTitle;

  /// Android notification body at 100%.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải xong {token} video'**
  String notifCompleteBody(String token);

  /// No description provided for @notifErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi tải bài học'**
  String get notifErrorTitle;

  /// Android notification body when downloads failed.
  ///
  /// In vi, this message translates to:
  /// **'{token} lỗi'**
  String notifErrorBody(String token);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
