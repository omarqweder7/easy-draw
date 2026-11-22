import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_draw/data/art_store.dart';
import 'package:easy_draw/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// ArtStore caches the sorted item list and file existence so widgets never
/// sort or touch the disk in build().
void main() {
  late Directory root;
  late ArtStore art;

  ArtItem item(String id, ArtType type, DateTime modified, String file) =>
      ArtItem(id: id, type: type, title: id, created: modified, modified: modified, file: file);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('easy_draw_store_');
    await Directory('${root.path}/images').create(recursive: true);
    await Directory('${root.path}/projects/proj').create(recursive: true);
    await File('${root.path}/images/old.png').writeAsBytes([1]);
    await File('${root.path}/projects/proj/composite.png').writeAsBytes([1]);
    // 'gone' has no file; 'empty' is a project that was never saved.
    await Directory('${root.path}/projects/empty').create(recursive: true);
    final items = [
      item('old', ArtType.imported, DateTime(2026, 1, 1), 'images/old.png'),
      item('gone', ArtType.imported, DateTime(2026, 3, 1), 'images/gone.png'),
      item('proj', ArtType.project, DateTime(2026, 2, 1), 'projects/proj'),
      item('empty', ArtType.project, DateTime(2026, 4, 1), 'projects/empty'),
    ];
    await File('${root.path}/items.json').writeAsString(jsonEncode(items.map((i) => i.toJson()).toList()));
    art = ArtStore();
    await art.init(root: root);
  });

  tearDown(() async {
    art.dispose();
    await root.delete(recursive: true);
  });

  test('items are newest first, cached, and refreshed when the index changes', () async {
    expect(art.items.map((i) => i.id), ['empty', 'gone', 'proj', 'old']);
    expect(identical(art.items, art.items), isTrue, reason: 'sorted list should be cached');
    expect(() => art.items.clear(), throwsUnsupportedError);
    await art.rename(art.byId('old')!, 'renamed'); // touches modified
    expect(art.items.first.id, 'old');
    final added = await art.addImage(Uint8List.fromList([1]), type: ArtType.imported, title: 'new');
    expect(art.items.first.id, added.id);
    await art.delete(added);
    expect(art.items.map((i) => i.id), isNot(contains(added.id)));
  });

  test('sourceFor is null for missing files, without touching the disk', () async {
    expect(art.sourceFor('art:old'), isNotNull);
    expect(art.sourceFor('art:proj'), isNotNull);
    expect(art.sourceFor('art:gone'), isNull);
    expect(art.sourceFor('art:empty'), isNull, reason: 'project without composite.png');
    // A project gets its composite on its first save; touchProject re-checks.
    await File('${root.path}/projects/empty/composite.png').writeAsBytes([1]);
    expect(art.sourceFor('art:empty'), isNull, reason: 'no disk access until the store is told');
    await art.touchProject(art.byId('empty')!);
    expect(art.sourceFor('art:empty'), isNotNull);
    // New items exist as soon as they are added; duplicates follow the original.
    final added = await art.addImage(Uint8List.fromList([1]), type: ArtType.imported, title: 'new');
    expect(art.sourceFor('art:${added.id}'), isNotNull);
    final dupGone = await art.duplicate(art.byId('proj')!, 'copy');
    expect(art.sourceFor('art:${dupGone.id}'), isNotNull);
    final created = await art.createProject(title: 'fresh');
    expect(art.sourceFor('art:${created.id}'), isNull);
  });
}
