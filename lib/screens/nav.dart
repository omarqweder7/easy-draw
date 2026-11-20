import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../services/share_service.dart';
import '../widgets/common.dart';
import 'camera_workspace.dart';
import 'canvas/canvas_screen.dart';
import 'import_editor.dart';
import 'reference_picker.dart';
import 'sketch_screen.dart';
import 'text_art.dart';
import 'trace_mode.dart';

/// Pushes a screen with the Easy Draw page transition (instant when motion
/// is reduced — handled by the theme's transition builder).
Future<T?> push<T>(BuildContext context, Widget screen) => Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => screen));

Future<void> openCamera(BuildContext context, [RefSource? src]) async {
  src ??= await pickReference(context, title: context.tr('pick.forCamera', 'Choose a reference for Camera Drawing'));
  if (src == null || !context.mounted) return;
  context.content.markUsed(src.refId);
  await push(context, CameraWorkspace(source: src));
}

Future<void> openTrace(BuildContext context, [RefSource? src]) async {
  src ??= await pickReference(context, title: context.tr('pick.forTrace', 'Choose a reference for Trace Mode'));
  if (src == null || !context.mounted) return;
  context.content.markUsed(src.refId);
  await push(context, TraceModeScreen(source: src));
}

Future<void> openCanvas(BuildContext context, {RefSource? reference, ArtItem? project}) async {
  if (reference != null) context.content.markUsed(reference.refId);
  await push(context, CanvasScreen(project: project, reference: reference));
}

Future<void> openTextArt(BuildContext context) => push(context, const TextArtScreen());

/// Lets the user choose the gallery or the camera, then returns a picked file
/// path. Handles denied permissions with a helpful message.
Future<String?> pickPhoto(BuildContext context) async {
  final source = await showEDSheet<ImageSource>(
    context,
    title: context.tr('import.title', 'Add a photo'),
    subtitle: context.tr('import.privacy', 'Photos are processed on this device. Nothing is uploaded.'),
    builder: (c) => EDGroup(children: [
      EDListRow(
        icon: Icons.photo_library_outlined,
        title: context.tr('import.gallery', 'Choose from photos'),
        subtitle: context.tr('import.galleryHint', 'Uses the system photo picker — no extra permission needed'),
        chevron: true,
        onTap: () => Navigator.pop(c, ImageSource.gallery),
      ),
      EDListRow(
        icon: Icons.photo_camera_outlined,
        title: context.tr('import.camera', 'Take a new photo'),
        chevron: true,
        onTap: () => Navigator.pop(c, ImageSource.camera),
      ),
    ]),
  );
  if (source == null || !context.mounted) return null;
  try {
    if (source == ImageSource.camera) {
      final st = await checkPermission(Permission.camera);
      if (!context.mounted) return null;
      if (st != PermState.granted) {
        showSnack(
          context.tr('perm.cameraDeniedPhoto', 'Camera access is off, so a new photo can’t be taken. You can still choose an existing photo.'),
          error: true,
          actionLabel: st == PermState.blocked ? context.tr('perm.openSettings', 'Open Settings') : null,
          onAction: st == PermState.blocked ? openSystemSettings : null,
        );
        return null;
      }
    }
    final x = await ImagePicker().pickImage(source: source, requestFullMetadata: false);
    return x?.path;
  } catch (e) {
    if (context.mounted) {
      showSnack(context.tr('import.failed', 'Couldn’t open the photo. Please try another one.'), error: true);
    }
    return null;
  }
}

/// Import → crop/rotate/flip → save to My Art. Returns the new reference.
Future<RefSource?> importReference(BuildContext context) async {
  final path = await pickPhoto(context);
  if (path == null || !context.mounted) return null;
  final item = await push<ArtItem>(context, ImportEditorScreen(path: path));
  if (item == null || !context.mounted) return null;
  return context.art.sourceFor('art:${item.id}');
}

/// Import a photo, then offer what to do with it.
Future<void> importPhotoFlow(BuildContext context) async {
  final src = await importReference(context);
  if (src == null || !context.mounted) return;
  await showUseSheet(context, src, allowSketch: true);
}

Future<void> photoToSketchFlow(BuildContext context) async {
  final path = await pickPhoto(context);
  if (path == null || !context.mounted) return;
  final item = await push<ArtItem>(context, ImportEditorScreen(path: path, nextLabel: context.tr('sketch.next', 'Next: sketch')));
  if (item == null || !context.mounted) return;
  await push(context, SketchScreen(sourcePath: context.art.fileOf(item).path, title: item.title));
}

/// "What next?" sheet used after importing, converting or creating text art.
Future<void> showUseSheet(BuildContext context, RefSource src, {bool allowSketch = false}) async {
  final choice = await showEDSheet<String>(
    context,
    title: context.tr('use.title', 'Saved to My Art. What next?'),
    builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 140, child: ClipRRect(borderRadius: Radii.cardR, child: RefThumb(src, padding: Space.s))),
      const SizedBox(height: Space.m),
      EDButton(label: context.tr('action.useCamera', 'Use in Camera'), icon: Icons.photo_camera_outlined, expand: true, onPressed: () => Navigator.pop(c, 'camera')),
      EDGroup(title: context.tr('use.more', 'Other ways to use it'), children: [
        EDListRow(icon: Icons.wb_sunny_outlined, title: context.tr('action.useTrace', 'Open in Trace Mode'), chevron: true, onTap: () => Navigator.pop(c, 'trace')),
        EDListRow(icon: Icons.brush_outlined, title: context.tr('action.useCanvas', 'Draw on Canvas'), chevron: true, onTap: () => Navigator.pop(c, 'canvas')),
        if (allowSketch)
          EDListRow(icon: Icons.auto_fix_high_outlined, title: context.tr('action.toSketch', 'Convert to sketch'), chevron: true, onTap: () => Navigator.pop(c, 'sketch')),
      ]),
    ]),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'camera':
      await openCamera(context, src);
    case 'trace':
      await openTrace(context, src);
    case 'canvas':
      await openCanvas(context, reference: src);
    case 'sketch':
      await push(context, SketchScreen(sourcePath: src.path, title: src.title));
  }
}
