import 'package:material_ui/material_ui.dart';

enum Difficulty { easy, medium, hard }

Difficulty difficultyFrom(String? s) =>
    Difficulty.values.firstWhere((d) => d.name == s, orElse: () => Difficulty.easy);

typedef LocText = Map<String, String>;

LocText locFrom(dynamic v) {
  if (v is String) return {'en': v};
  return (v as Map).map((k, val) => MapEntry('$k', '$val'));
}

class RefCategory {
  const RefCategory(this.id, this.icon, this.title);
  final String id;
  final IconData icon;
  final LocText title;
}

/// The fixed set of library categories (content is loaded from the manifest).
const refCategories = <RefCategory>[
  RefCategory('animals', Icons.pets_rounded, {'en': 'Animals', 'ar': 'حيوانات', 'he': 'בעלי חיים'}),
  RefCategory('vehicles', Icons.directions_car_rounded, {'en': 'Cars & vehicles', 'ar': 'سيارات ومركبات', 'he': 'מכוניות וכלי רכב'}),
  RefCategory('nature', Icons.landscape_rounded, {'en': 'Nature & landscapes', 'ar': 'طبيعة ومناظر', 'he': 'טבע ונופים'}),
  RefCategory('flowers', Icons.local_florist_rounded, {'en': 'Flowers & plants', 'ar': 'زهور ونباتات', 'he': 'פרחים וצמחים'}),
  RefCategory('food', Icons.icecream_rounded, {'en': 'Food', 'ar': 'طعام', 'he': 'אוכל'}),
  RefCategory('anime', Icons.auto_awesome_rounded, {'en': 'Anime-inspired characters', 'ar': 'شخصيات بأسلوب الأنمي', 'he': 'דמויות בהשראת אנימה'}),
  RefCategory('people', Icons.face_rounded, {'en': 'People & portraits', 'ar': 'أشخاص وبورتريه', 'he': 'אנשים ודיוקנאות'}),
  RefCategory('objects', Icons.home_work_rounded, {'en': 'Objects & architecture', 'ar': 'أشياء وعمارة', 'he': 'חפצים ואדריכלות'}),
  RefCategory('simple', Icons.emoji_emotions_rounded, {'en': 'Simple for beginners', 'ar': 'رسومات بسيطة للمبتدئين', 'he': 'ציורים פשוטים למתחילים'}),
  RefCategory('coloring', Icons.format_paint_rounded, {'en': 'Coloring pages', 'ar': 'صفحات تلوين', 'he': 'דפי צביעה'}),
];

RefCategory categoryById(String id) =>
    refCategories.firstWhere((c) => c.id == id, orElse: () => refCategories.first);

/// Drawing styles used for filtering.
const refStyles = <String, LocText>{
  'line': {'en': 'Line art', 'ar': 'رسم خطي', 'he': 'רישום קווי'},
  'cartoon': {'en': 'Cartoon', 'ar': 'كرتوني', 'he': 'מצויר'},
  'detailed': {'en': 'Detailed', 'ar': 'مفصّل', 'he': 'מפורט'},
  'pattern': {'en': 'Pattern', 'ar': 'نقش', 'he': 'דוגמה'},
};

class ReferenceItem {
  ReferenceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.style,
    required this.asset,
    this.featured = false,
    this.tags = const [],
  });

  final String id;
  final LocText title;
  final String category;
  final Difficulty difficulty;
  final String style;
  final String asset;
  final bool featured;
  final List<String> tags;

  bool get isColoringPage => category == 'coloring';

  factory ReferenceItem.fromJson(Map<String, dynamic> j) => ReferenceItem(
        id: j['id'] as String,
        title: locFrom(j['title']),
        category: j['category'] as String,
        difficulty: difficultyFrom(j['difficulty'] as String?),
        style: (j['style'] as String?) ?? 'line',
        asset: j['asset'] as String,
        featured: (j['featured'] as bool?) ?? false,
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      );

  RefSource toSource() => RefSource.asset(asset, title: title['en']!, refId: 'lib:$id', coloring: isColoringPage);
}

class LessonStep {
  LessonStep({required this.paths, required this.text, this.fills = const []});
  final List<String> paths;
  final List<String> fills; // optional filled shapes (e.g. pupils)
  final LocText text;

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        paths: ((j['paths'] as List?) ?? const []).cast<String>(),
        fills: ((j['fills'] as List?) ?? const []).cast<String>(),
        text: locFrom(j['text']),
      );
}

class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required this.subject,
    required this.difficulty,
    required this.minutes,
    required this.materials,
    required this.width,
    required this.height,
    required this.steps,
    this.stroke = 5,
  });

  final String id;
  final LocText title;
  final String subject; // a refCategories id
  final Difficulty difficulty;
  final int minutes;
  final List<LocText> materials;
  final double width;
  final double height;
  final double stroke;
  final List<LessonStep> steps;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: locFrom(j['title']),
        subject: j['subject'] as String,
        difficulty: difficultyFrom(j['difficulty'] as String?),
        minutes: (j['minutes'] as num).toInt(),
        materials: ((j['materials'] as List?) ?? const []).map(locFrom).toList(),
        width: ((j['width'] as num?) ?? 400).toDouble(),
        height: ((j['height'] as num?) ?? 400).toDouble(),
        stroke: ((j['stroke'] as num?) ?? 5).toDouble(),
        steps: (j['steps'] as List).map((s) => LessonStep.fromJson(s as Map<String, dynamic>)).toList(),
      );
}

enum ArtType { project, capture, recording, imported, sketch, textArt, export }

class ArtItem {
  ArtItem({
    required this.id,
    required this.type,
    required this.title,
    required this.created,
    required this.modified,
    this.file,
    this.thumb,
    this.favorite = false,
    this.finished = false,
    this.meta = const {},
  });

  final String id;
  final ArtType type;
  String title;
  final DateTime created;
  DateTime modified;

  /// Relative to the art root. For projects this is the project folder.
  String? file;
  String? thumb;
  bool favorite;
  bool finished;
  Map<String, dynamic> meta;

  bool get isImage => type != ArtType.recording && type != ArtType.project;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'created': created.toIso8601String(),
        'modified': modified.toIso8601String(),
        'file': file,
        'thumb': thumb,
        'favorite': favorite,
        'finished': finished,
        'meta': meta,
      };

  factory ArtItem.fromJson(Map<String, dynamic> j) => ArtItem(
        id: j['id'] as String,
        type: ArtType.values.firstWhere((t) => t.name == j['type'], orElse: () => ArtType.imported),
        title: (j['title'] as String?) ?? '',
        created: DateTime.tryParse('${j['created']}') ?? DateTime.now(),
        modified: DateTime.tryParse('${j['modified']}') ?? DateTime.now(),
        file: j['file'] as String?,
        thumb: j['thumb'] as String?,
        favorite: (j['favorite'] as bool?) ?? false,
        finished: (j['finished'] as bool?) ?? false,
        meta: ((j['meta'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

enum RefKind { asset, file, lessonStep }

/// Anything that can be used as a drawing reference: a bundled asset, a
/// user file, or a lesson step rendered on the fly.
class RefSource {
  const RefSource._(this.kind, this.path, {required this.title, this.refId, this.coloring = false, this.lesson, this.step = 0});

  const RefSource.asset(String path, {required String title, String? refId, bool coloring = false})
      : this._(RefKind.asset, path, title: title, refId: refId, coloring: coloring);

  const RefSource.file(String path, {required String title, String? refId})
      : this._(RefKind.file, path, title: title, refId: refId);

  RefSource.lessonStep(Lesson l, int stepIndex, {required String title})
      : this._(RefKind.lessonStep, l.id, title: title, lesson: l, step: stepIndex);

  final RefKind kind;
  final String path;
  final String title;

  /// Stable id for favourites/recents: `lib:<id>` or `art:<id>`.
  final String? refId;
  final bool coloring;
  final Lesson? lesson;
  final int step;

  bool get isSvg => path.toLowerCase().endsWith('.svg');
}
