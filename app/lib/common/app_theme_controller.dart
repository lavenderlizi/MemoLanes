import 'package:flutter/material.dart';
import 'package:memolanes/common/mmkv_util.dart';
import 'package:memolanes/constants/style_constants.dart';

enum AppThemePreference {
  light('light'),
  dark('dark');

  const AppThemePreference(this.id);

  final String id;

  static AppThemePreference fromId(String? id) {
    return values.firstWhere(
      (preference) => preference.id == id,
      orElse: () => AppThemePreference.dark,
    );
  }
}

class AppThemeController extends ChangeNotifier {
  AppThemeController()
      : _preference = AppThemePreference.fromId(
          MMKVUtil.getStringOpt(MMKVKey.interfaceThemeMode),
        ) {
    _applyPalette();
  }

  AppThemePreference _preference;

  AppThemePreference get preference => _preference;

  Brightness get brightness => _preference == AppThemePreference.dark
      ? Brightness.dark
      : Brightness.light;

  void setPreference(AppThemePreference preference) {
    if (_preference == preference) return;
    _preference = preference;
    MMKVUtil.putString(MMKVKey.interfaceThemeMode, preference.id);
    _applyPalette();
    notifyListeners();
  }

  void _applyPalette() {
    StyleConstants.setDarkMode(_preference == AppThemePreference.dark);
  }
}
