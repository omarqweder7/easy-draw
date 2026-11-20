import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:path_drawing/path_drawing.dart';

import '../data/models.dart';

final _pathCache = <String, Path>{};

Path _path(String d) => _pathCache.putIfAbsent(d, () => parseSvgPathData(d));

/// Paints lesson strokes up to [step] (inclusive) into [size].
///
/// Earlier steps are drawn in [doneColor]; the current step is drawn in
/// [newColor] so learners can see exactly what to add next.
void paintLesson(
  Canvas canvas,
  Size size,
  Lesson lesson,
  int step, {
  required Color doneColor,
  required Color newColor,
  bool highlightCurrent = true,
  double strokeScale = 1,
}) {
  final s = min(size.width / lesson.width, size.height / lesson.height);
  canvas.save();
  canvas.translate((size.width - lesson.width * s) / 2, (size.height - lesson.height * s) / 2);
  canvas.scale(s);
  final last = step.clamp(0, lesson.steps.length - 1);
  for (var i = 0; i <= last; i++) {
    final st = lesson.steps[i];
    final color = (highlightCurrent && i == last) ? newColor : doneColor;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final d in st.fills) {
      canvas.drawPath(_path(d), fill);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lesson.stroke * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final d in st.paths) {
      canvas.drawPath(_path(d), stroke);
    }
  }
  canvas.restore();
}

class LessonPainter extends CustomPainter {
  LessonPainter(this.lesson, this.step, {required this.doneColor, required this.newColor, this.highlightCurrent = true});
  final Lesson lesson;
  final int step;
  final Color doneColor;
  final Color newColor;
  final bool highlightCurrent;

  @override
  void paint(Canvas canvas, Size size) => paintLesson(canvas, size, lesson, step,
      doneColor: doneColor, newColor: newColor, highlightCurrent: highlightCurrent);

  @override
  bool shouldRepaint(LessonPainter old) =>
      old.lesson != lesson || old.step != step || old.doneColor != doneColor || old.newColor != newColor;
}

/// Renders a lesson step as a transparent line-art image for tracing.
Future<ui.Image> renderLessonImage(Lesson lesson, int step, {int maxSide = 2048}) async {
  final s = maxSide / max(lesson.width, lesson.height);
  final w = (lesson.width * s).round();
  final h = (lesson.height * s).round();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  paintLesson(canvas, Size(w.toDouble(), h.toDouble()), lesson, step,
      doneColor: const Color(0xFF1A1A1A), newColor: const Color(0xFF1A1A1A), highlightCurrent: false);
  return rec.endRecording().toImage(w, h);
}
