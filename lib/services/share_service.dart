import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../services/image_ops.dart';
import '../services/ref_loader.dart';

enum ExportFormat { png, jpeg }

enum GalleryResult { saved, denied, noSpace, failed }

enum PermState { granted, denied, blocked }

Future<PermState> checkPermission(Permission perm, {bool request = true}) async {
  var s = await perm.status;
  if (s.isGranted || s.isLimited) return PermState.granted;
  if (s.isPermanentlyDenied || s.isRestricted) return PermState.blocked;
  if (!request) return PermState.denied;
  s = await perm.request();
  if (s.isGranted || s.isLimited) return PermState.granted;
  if (s.isPermanentlyDenied || s.isRestricted) return PermState.blocked;
  return PermState.denied;
}

Future<void> openSystemSettings() => openAppSettings();

/// Opens the platform share sheet for a file. Nothing is uploaded by the app.
Future<void> shareFile(String path, {String? subject}) async {
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: subject));
}

/// Saves a copy to the device's Photos / Gallery app.
Future<GalleryResult> saveToGallery(String path, {bool video = false}) async {
  try {
    if (!await Gal.hasPermission(toAlbum: true)) {
      if (!await Gal.requestPermission(toAlbum: true)) return GalleryResult.denied;
    }
    if (video) {
      await Gal.putVideo(path, album: 'Easy Draw');
    } else {
      await Gal.putImage(path, album: 'Easy Draw');
    }
    return GalleryResult.saved;
  } on GalException catch (e) {
    if (e.type == GalExceptionType.permissionDenied) return GalleryResult.denied;
    if (e.type == GalExceptionType.notEnoughSpace) return GalleryResult.noSpace;
    return GalleryResult.failed;
  } catch (_) {
    return GalleryResult.failed;
  }
}

/// Converts an image file into the requested export format in the temp folder.
/// Returns the path of the exported file. Never adds watermarks.
Future<String> exportImageFile(String sourcePath, ExportFormat format, String baseName) async {
  final tmp = await getTemporaryDirectory();
  final dir = Directory(p.join(tmp.path, 'exports'));
  await dir.create(recursive: true);
  final safe = baseName.replaceAll(RegExp(r'[^\w֐-׿؀-ۿ\- ]'), '').trim();
  final name = '${safe.isEmpty ? 'easy-draw' : safe}-${DateTime.now().millisecondsSinceEpoch}';
  final src = File(sourcePath);
  final bytes = await src.readAsBytes();
  final isPng = sourcePath.toLowerCase().endsWith('.png');
  final isJpg = sourcePath.toLowerCase().endsWith('.jpg') || sourcePath.toLowerCase().endsWith('.jpeg');
  Uint8List out;
  String ext;
  if (format == ExportFormat.png) {
    ext = 'png';
    if (isPng) {
      out = bytes;
    } else {
      final im = await decodeBytes(bytes, maxSide: 8192);
      out = await encodePng(im);
      im.dispose();
    }
  } else {
    ext = 'jpg';
    if (isJpg) {
      out = bytes;
    } else {
      final im = await decodeBytes(bytes, maxSide: 8192);
      out = await imageToJpeg(im);
      im.dispose();
    }
  }
  final dest = File(p.join(dir.path, '$name.$ext'));
  await dest.writeAsBytes(out, flush: true);
  return dest.path;
}

Future<void> clearTempExports() async {
  final tmp = await getTemporaryDirectory();
  final dir = Directory(p.join(tmp.path, 'exports'));
  if (await dir.exists()) await dir.delete(recursive: true);
}

Future<int> tempBytes() async {
  final tmp = await getTemporaryDirectory();
  var sum = 0;
  try {
    await for (final e in tmp.list(recursive: true, followLinks: false)) {
      if (e is File) sum += await e.length();
    }
  } catch (_) {}
  return sum;
}

Future<void> clearTemp() async {
  final tmp = await getTemporaryDirectory();
  try {
    await for (final e in tmp.list(followLinks: false)) {
      try {
        await e.delete(recursive: true);
      } catch (_) {}
    }
  } catch (_) {}
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
