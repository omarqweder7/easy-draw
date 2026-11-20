import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Handedness { right, left }

/// User preferences, persisted locally with SharedPreferences.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.dark; // graphite is the signature look
  String? language; // null = follow system
  bool reduceMotion = false;
  Handedness handedness = Handedness.right;
  double defaultOpacity = 0.5;
  bool defaultGrid = false;
  bool defaultLinesOnly = true;
  double defaultBrushSize = 8;
  bool onboardingDone = false;
  bool recordAudio = false;
  bool traceMaxBrightness = true;
  bool haptics = true;
  List<int> swatches = [
    0xFF2A1F26, 0xFFFFFFFF, 0xFFE53935, 0xFFFF7043, 0xFFFFCA28, 0xFF66BB6A,
    0xFF29B6F6, 0xFF5C6BC0, 0xFFAB47BC, 0xFFFF4F9A, 0xFF8D6E63, 0xFF9E9E9E,
  ];

  void _load() {
    final p = _prefs;
    themeMode = ThemeMode.values[(p.getInt('themeMode') ?? ThemeMode.dark.index).clamp(0, 2)];
    language = p.getString('language');
    reduceMotion = p.getBool('reduceMotion') ?? false;
    handedness = (p.getString('handedness') ?? 'right') == 'left' ? Handedness.left : Handedness.right;
    defaultOpacity = p.getDouble('defaultOpacity') ?? 0.5;
    defaultGrid = p.getBool('defaultGrid') ?? false;
    defaultLinesOnly = p.getBool('defaultLinesOnly') ?? true;
    defaultBrushSize = p.getDouble('defaultBrushSize') ?? 8;
    onboardingDone = p.getBool('onboardingDone') ?? false;
    recordAudio = p.getBool('recordAudio') ?? false;
    traceMaxBrightness = p.getBool('traceMaxBrightness') ?? true;
    haptics = p.getBool('haptics') ?? true;
    final sw = p.getString('swatches');
    if (sw != null) {
      try {
        swatches = (jsonDecode(sw) as List).cast<int>();
      } catch (_) {}
    }
  }

  Locale? get locale => language == null ? null : Locale(language!);

  void update(void Function(AppSettings s) change) {
    change(this);
    _save();
    notifyListeners();
  }

  void _save() {
    final p = _prefs;
    p.setInt('themeMode', themeMode.index);
    if (language == null) {
      p.remove('language');
    } else {
      p.setString('language', language!);
    }
    p.setBool('reduceMotion', reduceMotion);
    p.setString('handedness', handedness.name);
    p.setDouble('defaultOpacity', defaultOpacity);
    p.setBool('defaultGrid', defaultGrid);
    p.setBool('defaultLinesOnly', defaultLinesOnly);
    p.setDouble('defaultBrushSize', defaultBrushSize);
    p.setBool('onboardingDone', onboardingDone);
    p.setBool('recordAudio', recordAudio);
    p.setBool('traceMaxBrightness', traceMaxBrightness);
    p.setBool('haptics', haptics);
    p.setString('swatches', jsonEncode(swatches));
  }

  /// Whether animations should be minimised, combining the in-app switch with
  /// the operating system's accessibility setting.
  bool motionReduced(BuildContext context) => reduceMotion || MediaQuery.of(context).disableAnimations;

  Duration anim(BuildContext context, [int ms = 250]) =>
      motionReduced(context) ? Duration.zero : Duration(milliseconds: ms);
}
