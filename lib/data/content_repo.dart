import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Bundled references and lessons, plus the user's favourites, recently used
/// references and lesson progress. Everything is local.
///
/// To add content, drop SVG/PNG files under `assets/library/` or add a lesson
/// to `assets/lessons/lessons.json`, then list them in the manifest.
class ContentRepo extends ChangeNotifier {
  ContentRepo(this._prefs);

  final SharedPreferences _prefs;

  List<ReferenceItem> references = [];
  List<Lesson> lessons = [];
  Set<String> favorites = {};
  List<String> recents = [];
  Map<String, Map<String, dynamic>> lessonProgress = {};

  /// True if the bundled manifests couldn't be read (shown as an error state).
  bool loadFailed = false;

  Future<void> load() async {
    try {
      await _loadManifests();
    } catch (_) {
      loadFailed = true;
    }
    _loadUserData();
  }

  Future<void> _loadManifests() async {
    final refJson = jsonDecode(await rootBundle.loadString('assets/library/references.json')) as Map<String, dynamic>;
    references = (refJson['references'] as List).map((e) => ReferenceItem.fromJson(e as Map<String, dynamic>)).toList();
    final lessonJson = jsonDecode(await rootBundle.loadString('assets/lessons/lessons.json')) as Map<String, dynamic>;
    lessons = (lessonJson['lessons'] as List).map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _loadUserData() {

    favorites = (_prefs.getStringList('favorites') ?? const []).toSet();
    recents = _prefs.getStringList('recents') ?? [];
    final lp = _prefs.getString('lessonProgress');
    if (lp != null) {
      try {
        lessonProgress = (jsonDecode(lp) as Map).map((k, v) => MapEntry('$k', (v as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
  }

  ReferenceItem? referenceById(String id) {
    for (final r in references) {
      if (r.id == id) return r;
    }
    return null;
  }

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  bool isFavorite(String refId) => favorites.contains(refId);

  void toggleFavorite(String refId) {
    if (!favorites.remove(refId)) favorites.add(refId);
    _prefs.setStringList('favorites', favorites.toList());
    notifyListeners();
  }

  void markUsed(String? refId) {
    if (refId == null) return;
    recents.remove(refId);
    recents.insert(0, refId);
    if (recents.length > 16) recents = recents.sublist(0, 16);
    _prefs.setStringList('recents', recents);
    notifyListeners();
  }

  void forget(String refId) {
    final changed = recents.remove(refId) | favorites.remove(refId);
    if (changed) {
      _prefs.setStringList('recents', recents);
      _prefs.setStringList('favorites', favorites.toList());
      notifyListeners();
    }
  }

  int lessonStep(String lessonId) => (lessonProgress[lessonId]?['step'] as int?) ?? 0;
  bool lessonDone(String lessonId) => (lessonProgress[lessonId]?['done'] as bool?) ?? false;
  bool lessonStarted(String lessonId) => lessonProgress.containsKey(lessonId);

  void saveLessonProgress(String lessonId, int step, {bool? done}) {
    final prev = lessonProgress[lessonId] ?? {};
    lessonProgress[lessonId] = {
      'step': step,
      'done': done ?? (prev['done'] as bool? ?? false),
      'at': DateTime.now().toIso8601String(),
    };
    _prefs.setString('lessonProgress', jsonEncode(lessonProgress));
    notifyListeners();
  }

  void resetLesson(String lessonId) {
    lessonProgress.remove(lessonId);
    _prefs.setString('lessonProgress', jsonEncode(lessonProgress));
    notifyListeners();
  }

  /// Search & filter the library.
  List<ReferenceItem> query({String text = '', String? category, Difficulty? difficulty, String? style}) {
    final q = text.trim().toLowerCase();
    return references.where((r) {
      if (category != null && r.category != category) return false;
      if (difficulty != null && r.difficulty != difficulty) return false;
      if (style != null && r.style != style) return false;
      if (q.isEmpty) return true;
      final hay = [...r.title.values, ...r.tags, ...categoryById(r.category).title.values].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }
}
