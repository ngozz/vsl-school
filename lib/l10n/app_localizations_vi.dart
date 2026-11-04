// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'VSL School';

  @override
  String get appWindowTitle => 'VSL School — Bài giảng Ký hiệu Việt Nam';

  @override
  String get settingsTooltip => 'Cài đặt';

  @override
  String loadError(String error) {
    return 'Lỗi tải dữ liệu:\n$error';
  }

  @override
  String get cdnUnavailable =>
      'CDN không khả dụng — tải/phát trực tuyến bị tắt.';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsTheme => 'Giao diện';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeBlack => 'Đen';

  @override
  String get themeLight => 'Sáng';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get rememberSpeed => 'Ghi nhớ tốc độ phát';

  @override
  String get rememberSpeedHint => 'Áp dụng tốc độ đã chọn cho video kế tiếp';

  @override
  String get settingsDownloads => 'Tải xuống & cập nhật';

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

    return 'Đã tải: $lessonsString/$lessonsTotalString bài ($videosString video, $size)';
  }

  @override
  String get checkUpdates => 'Kiểm tra cập nhật khi mở ứng dụng';

  @override
  String get checkUpdatesOff =>
      'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải';

  @override
  String get downloadAll => 'Tải toàn bộ nội dung';

  @override
  String get checkNow => 'Kiểm tra cập nhật';

  @override
  String get deleteDownloaded => 'Xoá dữ liệu đã tải';

  @override
  String get replayIntro => 'Xem lại hướng dẫn';

  @override
  String lessonCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Số bài học: $countString';
  }

  @override
  String get dataCredit =>
      'Nội dung bài học từ “App Khiem Thinh” (qipedc.moet.gov.vn).';

  @override
  String get allDownloaded => 'Toàn bộ nội dung đã được tải về máy.';

  @override
  String get downloadOnWifi => 'Sẽ tải khi có Wi-Fi (mở lại màn hình này).';

  @override
  String downloadStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đã bắt đầu tải $countString video…';
  }

  @override
  String deletedVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đã xoá $countString video.';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Không thể kiểm tra: $error';
  }

  @override
  String get upToDate => 'Nội dung đã là bản mới nhất.';

  @override
  String get subjectMath => 'Toán';

  @override
  String get subjectLiterature => 'Tiếng Việt';

  @override
  String get subjectMathShort => 'Số';

  @override
  String get subjectLiteratureShort => 'TV';

  @override
  String gradeChip(int grade) {
    return 'Lớp $grade';
  }

  @override
  String get hasUpdate => 'Có bản cập nhật';

  @override
  String get lessonDownloaded => 'Bài học đã được tải về máy.';

  @override
  String get lessonEmpty => 'Bài học chưa có nội dung';

  @override
  String get downloadedBadge => 'Đã tải về máy';

  @override
  String get cancelDownload => 'Huỷ tải';

  @override
  String get downloadLesson => 'Tải bài này về máy';

  @override
  String bannerDeleting(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang xoá $doneString/$totalString video…';
  }

  @override
  String get bannerCanceling => 'Đang huỷ tải…';

  @override
  String bannerDownloading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang tải $doneString/$totalString video…';
  }

  @override
  String get cancel => 'Huỷ';

  @override
  String get deleteTitle => 'Xoá dữ liệu đã tải';

  @override
  String deleteBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Xoá $countString video đã tải (~$size)? Video sẽ phát trực tuyến từ CDN.';
  }

  @override
  String get delete => 'Xoá';

  @override
  String get batchTitle => 'Tải xuống nội dung';

  @override
  String batchBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Sẽ tải $countString video (~$size).\nNên dùng Wi-Fi. Tiếp tục?';
  }

  @override
  String get later => 'Để sau';

  @override
  String get download => 'Tải';

  @override
  String get noWifiTitle => 'Không thấy Wi-Fi';

  @override
  String noWifiBody(String size) {
    return 'Thiết bị đang dùng dữ liệu di động. Tiếp tục tải (~$size)?';
  }

  @override
  String get continueLabel => 'Tiếp tục';

  @override
  String get lessonDownloadTitle => 'Đang tải bài học';

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

    return '$doneString/$totalString video — $doneSize / $totalSize';
  }

  @override
  String get updateTitle => 'Có bản cập nhật nội dung';

  @override
  String updateChanged(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString video thay đổi';
  }

  @override
  String updateRemoved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString video bỏ';
  }

  @override
  String updateMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '… và $countString bài khác';
  }

  @override
  String updateLessonLine(String lesson, String detail) {
    return '$lesson: $detail';
  }

  @override
  String get updateOtherGroup => 'Khác';

  @override
  String updateTotal(int files, String size) {
    final intl.NumberFormat filesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String filesString = filesNumberFormat.format(files);

    return 'Tổng: $filesString video (~$size). Cập nhật để dùng bản mới nhất.';
  }

  @override
  String get update => 'Cập nhật';

  @override
  String updateStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đang tải lại $countString video cập nhật…';
  }

  @override
  String get replay => 'Phát lại';

  @override
  String get pause => 'Tạm dừng';

  @override
  String get play => 'Phát';

  @override
  String get subtitles => 'Phụ đề';

  @override
  String get playbackSpeed => 'Tốc độ phát';

  @override
  String get exitFullscreen => 'Thu nhỏ';

  @override
  String get fullscreen => 'Toàn màn hình';

  @override
  String get onboardingSkip => 'Bỏ qua';

  @override
  String get onboardingNext => 'Tiếp tục';

  @override
  String get onboardingStart => 'Bắt đầu';

  @override
  String get languageTitle => 'Chọn ngôn ngữ';

  @override
  String get languageSubtitle =>
      'Bạn có thể đổi lại bất cứ lúc nào trong Cài đặt.';

  @override
  String get introWelcomeTitle => 'Chào mừng đến với VSL School';

  @override
  String get introWelcomeBody =>
      'Bài giảng Ký hiệu Việt Nam cho Toán và Tiếng Việt, lớp 1–5 — xem trực tuyến hoặc tải về để học offline.';

  @override
  String get introOfflineTitle => 'Dùng offline hoàn toàn';

  @override
  String get introOfflineBody =>
      'Vào Cài đặt → “Tải toàn bộ nội dung” (~2,9 GB) để tải mọi bài học về máy. Sau đó tắt “Kiểm tra cập nhật khi mở ứng dụng” — khi đó app không cần mạng nữa.';

  @override
  String get introSourceTitle => 'Nguồn dữ liệu';

  @override
  String get introSourceBody =>
      'Nội dung, video và phụ đề từ cổng Ký hiệu Việt Nam quốc gia: “App Khiem Thinh” (qipedc.moet.gov.vn) — Trung tâm Ký hiệu Việt Nam / Bộ Giáo dục và Đào tạo. Ứng dụng dùng làm cá nhân, không phải tác phẩm gốc. Chúc học tốt!';

  @override
  String get notifRunningTitle => 'Đang tải trong nền';

  @override
  String notifRunningBody(int total, String size) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString video (~$size)';
  }

  @override
  String get notifCompleteTitle => 'Hoàn tất tải';

  @override
  String notifCompleteBody(String token) {
    return 'Đã tải xong $token video';
  }

  @override
  String get notifErrorTitle => 'Lỗi tải bài học';

  @override
  String notifErrorBody(String token) {
    return '$token lỗi';
  }
}
