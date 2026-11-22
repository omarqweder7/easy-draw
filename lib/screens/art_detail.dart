import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../services/share_service.dart';
import '../widgets/common.dart';
import 'canvas/canvas_screen.dart';
import 'my_art.dart';
import 'nav.dart';
import 'sketch_screen.dart';

class ArtDetailScreen extends StatefulWidget {
  const ArtDetailScreen({super.key, required this.item});
  final ArtItem item;

  @override
  State<ArtDetailScreen> createState() => _ArtDetailScreenState();
}

class _ArtDetailScreenState extends State<ArtDetailScreen> {
  bool _busy = false;
  bool? _exists;
  int _previewVersion = 0; // bumped when a stale project preview is rebuilt

  ArtItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    final art = context.art;
    art.exists(item).then((v) {
      if (mounted) setState(() => _exists = v);
    });
    art.ensureComposite(item).then((rebuilt) {
      if (rebuilt && mounted) setState(() => _previewVersion++);
    });
  }

  /// The image file representing this item (composite for projects).
  String? get _imagePath {
    final art = context.art;
    if (item.type == ArtType.project) {
      return p.join(art.projectDir(item).path, 'composite.png');
    }
    if (item.type == ArtType.recording) return null;
    return art.fileOf(item).path;
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showSnack(storageMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run(() async {
    if (item.type == ArtType.recording) {
      await shareFile(context.art.fileOf(item).path, subject: item.title);
    } else {
      final path = _imagePath!;
      await context.art.ensureComposite(item);
      if (!await File(path).exists()) throw StateError('missing');
      await shareFile(path, subject: item.title);
    }
  });

  Future<void> _export(ExportFormat f) => _run(() async {
    final path = _imagePath!;
    await context.art.ensureComposite(item);
    final out = await exportImageFile(path, f, item.title);
    if (!mounted) return;
    final r = await saveToGallery(out);
    if (!mounted) return;
    _galleryMessage(r, retry: () => _export(f), sharePath: out);
  });

  Future<void> _saveVideo() => _run(() async {
    final r = await saveToGallery(context.art.fileOf(item).path, video: true);
    if (mounted) {
      _galleryMessage(
        r,
        retry: _saveVideo,
        sharePath: context.art.fileOf(item).path,
      );
    }
  });

  void _galleryMessage(
    GalleryResult r, {
    required VoidCallback retry,
    required String sharePath,
  }) {
    switch (r) {
      case GalleryResult.saved:
        showSnack(
          context.tr(
            'export.saved',
            'Saved to your Photos in the “Easy Draw” album.',
          ),
        );
      case GalleryResult.denied:
        showSnack(
          context.tr(
            'export.denied',
            'Photos access was not allowed. You can still share the file instead.',
          ),
          error: true,
          actionLabel: context.tr('common.share', 'Share'),
          onAction: () => shareFile(sharePath),
        );
      case GalleryResult.noSpace:
        showSnack(
          context.tr(
            'err.storageFull',
            'Your device is out of storage. Free up space and try again — your existing work is safe.',
          ),
          error: true,
        );
      case GalleryResult.failed:
        showSnack(
          context.tr(
            'export.failed',
            'Export failed. Your original is unchanged.',
          ),
          error: true,
          actionLabel: context.tr('common.retry', 'Retry'),
          onAction: retry,
        );
    }
  }

  Future<void> _rename() async {
    final t = await promptText(
      context,
      title: context.tr('art.rename', 'Rename'),
      initial: item.title,
      confirmLabel: context.tr('common.save', 'Save'),
    );
    if (t == null || !mounted) return;
    await _run(() => context.art.rename(item, t));
  }

  Future<void> _duplicate() => _run(() async {
    final copy = await context.art.duplicate(
      item,
      context.trf('art.copyOf', '{name} (copy)', {'name': item.title}),
    );
    if (mounted) {
      showSnack(
        context.trf('art.duplicated', 'Duplicated as “{name}”', {
          'name': copy.title,
        }),
      );
    }
  });

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: context.tr('art.deleteTitle', 'Delete this item?'),
      message: context.tr(
        'art.deleteBody',
        'It will be permanently removed from this device. This can’t be undone.',
      ),
      confirmLabel: context.tr('common.delete', 'Delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final art = context.art;
    final content = context.content;
    await art.delete(item);
    content.forget('art:${item.id}');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final art = context.art;
    final src = art.sourceFor('art:${item.id}');
    final cs = Theme.of(context).colorScheme;
    final missing = _exists == false;

    Widget preview;
    if (missing) {
      preview = EDStateView(
        icon: Icons.broken_image_outlined,
        title: context.tr('art.missingTitle', 'File not found'),
        message: context.tr(
          'art.missingBody',
          'The file for this item is missing, possibly removed by a cleanup app. You can delete the entry.',
        ),
      );
    } else if (item.type == ArtType.recording) {
      preview = _VideoPreview(file: art.fileOf(item));
    } else {
      preview = InteractiveViewer(
        maxScale: 6,
        child: ColoredBox(
          color: Colors.white,
          child: Image.file(
            File(_imagePath!),
            key: ValueKey(_previewVersion),
            fit: BoxFit.contain,
            // Captures can be 4096 px (~50 MB decoded). Twice the screen
            // width keeps pinch-zoom sharp; smaller images aren't upscaled.
            cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) * 2).round(),
            errorBuilder: (_, _, _) => const MissingFile(),
          ),
        ),
      );
    }

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ListenableBuilder(
          listenable: art,
          builder: (context, _) => EDTopBar(title: item.title),
        ),
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: art,
            builder: (context, _) {
              final actions = <Widget>[
                if (!missing && item.type == ArtType.project)
                  EDButton(
                    onPressed: () => push(context, CanvasScreen(project: item)),
                    icon: Icons.edit_rounded,
                    label: context.tr('art.continue', 'Continue drawing'),
                  ),
                if (!missing && src != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      EDButton.secondary(
                        onPressed: () => openCamera(context, src),
                        icon: Icons.camera_alt_rounded,
                        label: context.tr('action.useCamera', 'Use in Camera'),
                      ),
                      EDButton.secondary(
                        onPressed: () => openTrace(context, src),
                        icon: Icons.light_mode_rounded,
                        label: context.tr(
                          'action.useTrace',
                          'Open in Trace Mode',
                        ),
                      ),
                      if (item.type != ArtType.project)
                        EDButton.secondary(
                          onPressed: () => openCanvas(context, reference: src),
                          icon: Icons.brush_rounded,
                          label: context.tr(
                            'action.useCanvas',
                            'Draw on Canvas',
                          ),
                        ),
                      if (item.type == ArtType.imported ||
                          item.type == ArtType.capture)
                        EDButton.secondary(
                          onPressed: () => push(
                            context,
                            SketchScreen(
                              sourcePath: src.path,
                              title: item.title,
                            ),
                          ),
                          icon: Icons.auto_fix_high_rounded,
                          label: context.tr(
                            'action.toSketch',
                            'Convert to sketch',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (!missing)
                  EDListRow(
                    icon: Icons.share_rounded,
                    title: context.tr('common.share', 'Share'),
                    onTap: _share,
                  ),
                if (!missing && item.type != ArtType.recording) ...[
                  EDListRow(
                    icon: Icons.image_rounded,
                    title: context.tr('export.png', 'Save to Photos as PNG'),
                    subtitle: context.tr(
                      'export.pngHint',
                      'Best quality, keeps transparency',
                    ),
                    onTap: () => _export(ExportFormat.png),
                  ),
                  EDListRow(
                    icon: Icons.photo_rounded,
                    title: context.tr('export.jpeg', 'Save to Photos as JPEG'),
                    subtitle: context.tr(
                      'export.jpegHint',
                      'Smaller file, white background',
                    ),
                    onTap: () => _export(ExportFormat.jpeg),
                  ),
                ],
                if (!missing && item.type == ArtType.recording)
                  EDListRow(
                    icon: Icons.video_library_rounded,
                    title: context.tr('export.video', 'Save video to Photos'),
                    onTap: _saveVideo,
                  ),
                EDListRow(
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: context.tr('art.rename', 'Rename'),
                  onTap: _rename,
                ),
                EDListRow(
                  icon: item.favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  title: item.favorite
                      ? context.tr('action.unfavorite', 'Remove from favorites')
                      : context.tr('action.favorite', 'Favorite'),
                  onTap: () => _run(() => art.toggleFavorite(item)),
                ),
                if (!missing)
                  EDListRow(
                    icon: Icons.copy_rounded,
                    title: context.tr('art.duplicate', 'Duplicate'),
                    onTap: _duplicate,
                  ),
                if (item.type == ArtType.project)
                  EDSwitchRow(
                    icon: Icons.task_alt_rounded,
                    title: context.tr('art.finished', 'Mark as finished'),
                    subtitle: context.tr(
                      'art.finishedHint',
                      'Finished projects are hidden from “Continue creating”',
                    ),
                    value: item.finished,
                    onChanged: (v) => _run(() => art.setFinished(item, v)),
                  ),
                EDListRow(
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  title: context.tr('common.delete', 'Delete'),
                  onTap: _delete,
                ),
              ];

              final info = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Icon(artTypeIcon(item.type), size: 18, color: cs.secondary),
                    const SizedBox(width: 6),
                    Text(
                      artTypeLabel(context, item.type),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd(context.lang)
                            .add_jm()
                            .format(item.modified),
                        style: TextStyle(color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
              if (landscape) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: EDCard(child: preview),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          info,
                          EDGroup(children: actions),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AspectRatio(aspectRatio: 1, child: EDCard(child: preview)),
                  info,
                  EDGroup(children: actions),
                ],
              );
            },
          ),
          if (_busy)
            BusyOverlay(message: context.tr('common.working', 'Working…')),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.file});
  final File file;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _c = VideoPlayerController.file(widget.file);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text(
          context.tr(
            'art.videoFail',
            'This video can’t be played here. Try sharing it to another app.',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!_c.value.isInitialized) return const EDLoading(dark: true);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _c.value.aspectRatio,
            child: VideoPlayer(_c),
          ),
          ValueListenableBuilder(
            valueListenable: _c,
            builder: (context, v, _) => EDIconButton(
              dark: true,
              variant: EDIconVariant.tonal,
              size: 56,
              tooltip: v.isPlaying
                  ? context.tr('video.pause', 'Pause')
                  : context.tr('video.play', 'Play'),
              onPressed: () => v.isPlaying ? _c.pause() : _c.play(),
              icon: v.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: Sizes.touch,
              child: Center(
                child: VideoProgressIndicator(
                  _c,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: EDPalette.dark.accent,
                    bufferedColor: EDPalette.dark.borderStrong,
                    backgroundColor: EDPalette.dark.surface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
