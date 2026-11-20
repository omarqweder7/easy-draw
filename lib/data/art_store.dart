import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Thrown when a file operation fails, with a reason the UI can show.
class StorageFailure implements Exception {
  StorageFailure(this.reason, [this.cause]);
  final StorageReason reason;
  final Object? cause;
  @override
  String toString() => 'StorageFailure($reason, $cause)';
}

enum StorageReason { full, missing, other }

StorageFailure _wrap(Object e) {
  if (e is StorageFailure) return e;
  if (e is FileSystemException) {
    final code = e.osError?.errorCode;
    final msg = '${e.osError?.message}'.toLowerCase();
    // ENOSPC = 28 on Linux/Android, 28 on Darwin as well.
    if (code == 28 || msg.contains('no space')) {
      return StorageFailure(StorageReason.full, e);
    }
    if (code == 2 || msg.contains('no such file')) {
      return StorageFailure(StorageReason.missing, e);
    }
  }
  return StorageFailure(StorageReason.other, e);
}

/// Writes [bytes] to a temp file first, then renames it over [target], so an
/// interrupted write never corrupts the existing file.
Future<void> writeAtomic(File target, List<int> bytes) async {
  try {
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  } catch (e) {
    throw _wrap(e);
  }
}

/// Makes a small PNG thumbnail using the platform image decoder.
Future<Uint8List?> makeThumbnail(Uint8List bytes, {int maxSide = 480}) async {
  try {
    final probe = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(probe);
    final w = desc.width, h = desc.height;
    final scale = min(1.0, maxSide / max(w, h));
    final codec = await desc.instantiateCodec(
      targetWidth: max(1, (w * scale).round()),
      targetHeight: max(1, (h * scale).round()),
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    desc.dispose();
    probe.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// The "My Art" store: an index file plus media files in the app's private
/// documents folder. Nothing leaves the device unless the user shares it.
class ArtStore extends ChangeNotifier {
  late Directory root;
  final List<ArtItem> _items = [];
  bool loadError = false;

  List<ArtItem> get items {
    final list = [..._items]..sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  File get _index => File(p.join(root.path, 'items.json'));

  Future<void> init({Directory? root}) async {
    this.root =
        root ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'easydraw'),
        );
    final storeRoot = this.root;
    await storeRoot.create(recursive: true);
    for (final d in ['images', 'projects', 'videos', 'thumbs']) {
      await Directory(p.join(storeRoot.path, d)).create(recursive: true);
    }
    await _loadIndex();
  }

  Future<void> _loadIndex() async {
    _items.clear();
    for (final f in [_index, File('${_index.path}.bak')]) {
      if (!await f.exists()) continue;
      try {
        final list = jsonDecode(await f.readAsString()) as List;
        _items.addAll(
          list.map((e) => ArtItem.fromJson((e as Map).cast<String, dynamic>())),
        );
        return;
      } catch (_) {
        loadError = true; // fall through to backup
      }
    }
  }

  Future<void> _saveIndex() async {
    final data = utf8.encode(
      const JsonEncoder.withIndent(' ')
          .convert(_items.map((e) => e.toJson()).toList()),
    );
    if (await _index.exists()) {
      try {
        await _index.copy('${_index.path}.bak');
      } catch (_) {}
    }
    await writeAtomic(_index, data);
    notifyListeners();
  }

  String newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  File fileOf(ArtItem item) => File(p.join(root.path, item.file ?? ''));
  File? thumbOf(ArtItem item) =>
      item.thumb == null ? null : File(p.join(root.path, item.thumb!));
  Directory projectDir(ArtItem item) =>
      Directory(p.join(root.path, item.file ?? ''));

  ArtItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Resolves an `art:<id>` reference to a [RefSource] if the file still exists.
  RefSource? sourceFor(String refId) {
    if (!refId.startsWith('art:')) return null;
    final item = byId(refId.substring(4));
    if (item == null) return null;
    if (item.type == ArtType.project) {
      final f = File(p.join(projectDir(item).path, 'composite.png'));
      return RefSource.file(f.path, title: item.title, refId: refId);
    }
    if (!item.isImage) return null;
    return RefSource.file(fileOf(item).path, title: item.title, refId: refId);
  }

  Future<ArtItem> addImage(
    Uint8List bytes, {
    required ArtType type,
    required String title,
    String ext = 'png',
    Map<String, dynamic> meta = const {},
  }) async {
    final id = newId();
    final rel = p.join('images', '$id.$ext');
    await writeAtomic(File(p.join(root.path, rel)), bytes);
    String? thumbRel;
    final thumb = await makeThumbnail(bytes);
    if (thumb != null) {
      thumbRel = p.join('thumbs', '$id.png');
      await writeAtomic(File(p.join(root.path, thumbRel)), thumb);
    }
    final now = DateTime.now();
    final item = ArtItem(
      id: id,
      type: type,
      title: title,
      created: now,
      modified: now,
      file: rel,
      thumb: thumbRel,
      meta: {...meta},
    );
    _items.add(item);
    await _saveIndex();
    return item;
  }

  Future<ArtItem> addVideo(
    File source, {
    required String title,
    Map<String, dynamic> meta = const {},
  }) async {
    final id = newId();
    final ext = p.extension(source.path).isEmpty
        ? '.mp4'
        : p.extension(source.path);
    final rel = p.join('videos', '$id$ext');
    final dest = File(p.join(root.path, rel));
    try {
      try {
        await source.rename(dest.path);
      } on FileSystemException {
        await source.copy(dest.path);
        try {
          await source.delete();
        } catch (_) {}
      }
    } catch (e) {
      throw _wrap(e);
    }
    final now = DateTime.now();
    final item = ArtItem(
      id: id,
      type: ArtType.recording,
      title: title,
      created: now,
      modified: now,
      file: rel,
      meta: {...meta},
    );
    _items.add(item);
    await _saveIndex();
    return item;
  }

  /// Creates an empty project folder and index entry; the canvas fills it.
  Future<ArtItem> createProject({
    required String title,
    Map<String, dynamic> meta = const {},
  }) async {
    final id = newId();
    final rel = p.join('projects', id);
    await Directory(p.join(root.path, rel)).create(recursive: true);
    final now = DateTime.now();
    final item = ArtItem(
      id: id,
      type: ArtType.project,
      title: title,
      created: now,
      modified: now,
      file: rel,
      meta: {...meta},
    );
    _items.add(item);
    await _saveIndex();
    return item;
  }

  /// Called by the canvas after it has written project files.
  Future<void> touchProject(ArtItem item, {Uint8List? thumbPng}) async {
    item.modified = DateTime.now();
    if (thumbPng != null) {
      final rel = p.join('thumbs', '${item.id}.png');
      await writeAtomic(File(p.join(root.path, rel)), thumbPng);
      item.thumb = rel;
      // Evict the cached thumbnail so lists show the new one.
      PaintingBindingHelper.evict(File(p.join(root.path, rel)));
    }
    await _saveIndex();
  }

  Future<void> rename(ArtItem item, String title) async {
    item.title = title.trim().isEmpty ? item.title : title.trim();
    item.modified = DateTime.now();
    await _saveIndex();
  }

  Future<void> toggleFavorite(ArtItem item) async {
    item.favorite = !item.favorite;
    await _saveIndex();
  }

  Future<void> setFinished(ArtItem item, bool finished) async {
    item.finished = finished;
    await _saveIndex();
  }

  Future<ArtItem> duplicate(ArtItem item, String copyTitle) async {
    final id = newId();
    String? newFile;
    String? newThumb;
    try {
      if (item.type == ArtType.project) {
        newFile = p.join('projects', id);
        await _copyDir(projectDir(item), Directory(p.join(root.path, newFile)));
      } else if (item.file != null) {
        newFile = p.join(
          p.dirname(item.file!),
          '$id${p.extension(item.file!)}',
        );
        await fileOf(item).copy(p.join(root.path, newFile));
      }
      final t = thumbOf(item);
      if (t != null && await t.exists()) {
        newThumb = p.join('thumbs', '$id.png');
        await t.copy(p.join(root.path, newThumb));
      }
    } catch (e) {
      throw _wrap(e);
    }
    final now = DateTime.now();
    final copy = ArtItem(
      id: id,
      type: item.type,
      title: copyTitle,
      created: now,
      modified: now,
      file: newFile,
      thumb: newThumb,
      meta: {...item.meta},
    );
    _items.add(copy);
    await _saveIndex();
    return copy;
  }

  Future<void> delete(ArtItem item) async {
    try {
      if (item.type == ArtType.project) {
        final d = projectDir(item);
        if (await d.exists()) await d.delete(recursive: true);
      } else if (item.file != null) {
        final f = fileOf(item);
        if (await f.exists()) await f.delete();
      }
      final t = thumbOf(item);
      if (t != null && await t.exists()) await t.delete();
    } catch (_) {
      // Removing the index entry still matters even if a file is gone.
    }
    _items.removeWhere((i) => i.id == item.id);
    await _saveIndex();
  }

  Future<void> deleteWhere(bool Function(ArtItem) test) async {
    for (final i in _items.where(test).toList()) {
      await delete(i);
    }
  }

  Future<int> totalBytes([bool Function(ArtItem)? test]) async {
    var sum = 0;
    for (final i in _items.where(test ?? (_) => true)) {
      try {
        if (i.type == ArtType.project) {
          final d = projectDir(i);
          if (await d.exists()) {
            await for (final e in d.list(recursive: true)) {
              if (e is File) sum += await e.length();
            }
          }
        } else if (i.file != null) {
          final f = fileOf(i);
          if (await f.exists()) sum += await f.length();
        }
      } catch (_) {}
    }
    return sum;
  }

  Future<bool> exists(ArtItem item) async {
    if (item.type == ArtType.project) return projectDir(item).exists();
    return fileOf(item).exists();
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final e in from.list()) {
      if (e is File) {
        await e.copy(p.join(to.path, p.basename(e.path)));
      } else if (e is Directory) {
        await _copyDir(e, Directory(p.join(to.path, p.basename(e.path))));
      }
    }
  }
}

/// Small helper so the store can evict stale file images from Flutter's cache
/// without importing the whole widgets library here.
class PaintingBindingHelper {
  static void Function(File f)? evictor;
  static void evict(File f) => evictor?.call(f);
}
