import 'package:flutter/material.dart';

import '../main.dart';

/// First-launch onboarding: three pages, shown once (re-openable from the
/// settings sheet). Hand-rolled PageView — no onboarding dependency.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.school_outlined,
      'Chào mừng đến với VSL School',
      'Bài giảng Ký hiệu Việt Nam cho Toán và Tiếng Việt, lớp 1–5 — xem '
          'trực tuyến hoặc tải về để học offline.',
    ),
    (
      Icons.wifi_off_outlined,
      'Dùng offline hoàn toàn',
      'Vào Cài đặt → “Tải toàn bộ nội dung” (~2,9 GB) để tải mọi bài học '
          'về máy. Sau đó tắt “Kiểm tra cập nhật khi mở ứng dụng” — khi đó '
          'app không cần mạng nữa.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'Nguồn dữ liệu',
      'Nội dung, video và phụ đề từ cổng Ký hiệu Việt Nam quốc gia: '
          '“App Khiem Thinh” (qipedc.moet.gov.vn) — Trung tâm Ký hiệu Việt '
          'Nam / Bộ Giáo dục và Đào tạo. Ứng dụng dùng làm cá nhân, không '
          'phải tác phẩm gốc. Chúc học tốt!',
    ),
  ];

  void _finish() {
    App.settings.setIntroSeen();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: _finish, child: const Text('Bỏ qua')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, title, body) in _pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 88, color: theme.colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Text(body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme
                                      .colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      _finish();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? 'Bắt đầu' : 'Tiếp tục'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
