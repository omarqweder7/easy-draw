import 'dart:typed_data';
import 'package:easy_draw/services/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blur preserves brightness', () {
    const w = 60, h = 40;
    final c = Float32List(w * h)..fillRange(0, w * h, 100);
    final bc = gaussianForTest(c, w, h, 9.25);
    for (final v in bc) {
      expect(v, closeTo(100, 0.01));
    }
  });
}
