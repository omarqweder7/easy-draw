import 'package:material_ui/material_ui.dart';

import 'l10n_ar.dart';
import 'l10n_he.dart';

/// Lightweight string lookup.
///
/// UI code calls `context.tr(key, englishText)`. English lives inline at
/// the call site; Arabic and Hebrew live in [arStrings] / [heStrings]. Because
/// the lookup reads [Localizations.localeOf], widgets rebuild automatically when
/// the language changes.
const supportedLanguages = ['en', 'ar', 'he'];

const _tables = <String, Map<String, String>>{
  'ar': arStrings,
  'he': heStrings,
};

String lookup(String lang, String key, String en) => _tables[lang]?[key] ?? en;

extension TrContext on BuildContext {
  String get lang => Localizations.localeOf(this).languageCode;

  String tr(String key, String en) => lookup(lang, key, en);

  /// Translation with `{name}` placeholders.
  String trf(String key, String en, Map<String, Object> args) {
    var s = tr(key, en);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  /// Picks the right string from a `{"en": .., "ar": .., "he": ..}` map.
  String loc(Map<String, String> m) => m[lang] ?? m['en'] ?? m.values.first;
}

/// True when [text] begins (first strong character) with an RTL script.
bool isRtlText(String text) {
  for (final r in text.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      return true;
    }
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F) || (r >= 0x370 && r <= 0x4FF)) {
      return false;
    }
  }
  return false;
}

/// True if text contains Arabic-script letters (which join and must not get
/// extra letter spacing).
bool containsArabic(String text) =>
    text.runes.any((r) => (r >= 0x0600 && r <= 0x08FF) || (r >= 0xFB50 && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF));
