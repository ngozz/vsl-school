import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart' show AppConfig;

/// App settings (theme + video player prefs) stored in shared_preferences.
/// Theme logic mirrors vsl-dictionary.
enum ThemeChoice { dark, black, light }

class SettingsService extends ChangeNotifier {
  static const _themeKey = 'vsl_school.theme';
  static const _subtitlesKey = 'vsl_school.subtitles';
  static const _rememberSpeedKey = 'vsl_school.remember_speed';
  static const _speedKey = 'vsl_school.speed';
  static const _checkUpdatesKey = 'vsl_school.check_updates';
  static const _introKey = 'vsl_school.intro_seen';

  ThemeChoice _theme = ThemeChoice.dark;
  bool _subtitles = true; // CC on/off — always remembered, on by default
  bool _rememberSpeed = false; // opt-in: reuse the last speed for new videos
  double _speed = 1.0; // last chosen speed (only applied if _rememberSpeed)
  bool _checkUpdates = true; // auto-check for content updates at startup
  bool _introSeen = false; // first-launch onboarding shown

  ThemeChoice get theme => _theme;
  bool get subtitles => _subtitles;
  bool get rememberSpeed => _rememberSpeed;
  double get speed => _speed;
  bool get checkUpdates => _checkUpdates;
  bool get introSeen => _introSeen;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _theme = ThemeChoice.values.asNameMap()[p.getString(_themeKey)] ??
        ThemeChoice.dark;
    _subtitles = p.getBool(_subtitlesKey) ?? AppConfig.defaultSubtitles;
    _rememberSpeed = p.getBool(_rememberSpeedKey) ?? false;
    _speed = p.getDouble(_speedKey) ?? 1.0;
    _checkUpdates = p.getBool(_checkUpdatesKey) ?? AppConfig.checkUpdatesAtStart;
    _introSeen = p.getBool(_introKey) ?? false;
  }

  /// Marks the onboarding as seen (first-run intro and manual re-views).
  Future<void> setIntroSeen() async {
    if (_introSeen) return;
    _introSeen = true;
    (await SharedPreferences.getInstance()).setBool(_introKey, true);
  }

  Future<void> setCheckUpdates(bool on) async {
    if (on == _checkUpdates) return;
    _checkUpdates = on;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_checkUpdatesKey, on);
  }

  Future<void> setTheme(ThemeChoice choice) async {
    if (choice == _theme) return;
    _theme = choice;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_themeKey, choice.name);
  }

  Future<void> setSubtitles(bool on) async {
    if (on == _subtitles) return;
    _subtitles = on;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_subtitlesKey, on);
  }

  Future<void> setRememberSpeed(bool on) async {
    if (on == _rememberSpeed) return;
    _rememberSpeed = on;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_rememberSpeedKey, on);
  }

  /// No notifyListeners: nothing displays the speed, and the app listens to
  /// this service for theme changes.
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    (await SharedPreferences.getInstance()).setDouble(_speedKey, speed);
  }
}