import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../app/settings.dart';
import '../data/models.dart';
import '../services/image_ops.dart';
import '../services/ref_loader.dart';
import '../services/share_service.dart';
import '../widgets/common.dart';
import '../widgets/overlay.dart';
import '../widgets/overlay_controls.dart';
import 'nav.dart';
import 'reference_picker.dart';
import 'trace_mode.dart';

enum _CamState {
  checking,
  explain,
  denied,
  blocked,
  noCamera,
  starting,
  ready,
  error,
}

enum _CaptureMode { photoOnly, withOverlay, both }

/// Live rear-camera view with an adjustable reference layered on top.
///
/// The reference is drawn on the phone screen only. Locking freezes it
/// relative to the screen; the phone and paper must stay still.
class CameraWorkspace extends StatefulWidget {
  const CameraWorkspace({super.key, required this.source});
  final RefSource source;

  @override
  State<CameraWorkspace> createState() => _CameraWorkspaceState();
}

class _CameraWorkspaceState extends State<CameraWorkspace>
    with WidgetsBindingObserver {
  late RefSource _source = widget.source;
  ui.Image? _ref;
  bool _refFailed = false;
  late final OverlayModel _m;
  late final AppSettings _settings;

  CameraController? _cam;
  _CamState _state = _CamState.checking;
  String? _errorText;
  bool _torch = false;
  bool _torchUnsupported = false;
  bool _grid = false;
  bool _panelOpen = true;
  bool _busy = false;
  String _busyText = '';
  bool _recording = false;
  bool _recordInfoShown = false;
  bool _audioThisSession = false;
  Duration _recElapsed = Duration.zero;
  Timer? _recTimer;
  final _viewportKey = GlobalKey();
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;

  @override
  void initState() {
    super.initState();
    _settings = context.settings;
    _m = OverlayModel(
      opacity: _settings.defaultOpacity,
      linesOnly: _settings.defaultLinesOnly,
    );
    _grid = _settings.defaultGrid;
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // keep the screen on during the session
    _loadRef();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _releaseCamera();
    WakelockPlus.disable(); // restore normal screen timeout
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _m.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      if (_recording) _stopRecording(interrupted: true);
      _releaseCamera();
      if (mounted && _state == _CamState.ready) {
        setState(() => _state = _CamState.starting);
      }
    } else if (s == AppLifecycleState.resumed) {
      if (_cam == null &&
          (_state == _CamState.starting ||
              _state == _CamState.blocked ||
              _state == _CamState.denied)) {
        _checkPermission(silent: true);
      }
    }
  }

  Future<void> _releaseCamera() async {
    final c = _cam;
    _cam = null;
    _torch = false;
    if (c != null) {
      try {
        if (c.value.isInitialized && c.value.flashMode == FlashMode.torch) {
          await c.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      await c.dispose();
    }
  }

  Future<void> _loadRef() async {
    try {
      final img = await loadRefImage(_source, maxSide: 2048);
      if (!mounted) return;
      setState(() {
        _ref?.dispose();
        _ref = img;
        _refFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _refFailed = true);
    }
  }

  Future<void> _checkPermission({bool silent = false}) async {
    final s = await Permission.camera.status;
    if (!mounted) return;
    if (s.isGranted) {
      await _startCamera();
    } else if (s.isPermanentlyDenied || s.isRestricted) {
      setState(() => _state = _CamState.blocked);
    } else {
      setState(
        () => _state = silent && _state == _CamState.denied
            ? _CamState.denied
            : _CamState.explain,
      );
    }
  }

  Future<void> _requestPermission() async {
    final st = await checkPermission(Permission.camera);
    if (!mounted) return;
    switch (st) {
      case PermState.granted:
        await _startCamera();
      case PermState.denied:
        setState(() => _state = _CamState.denied);
      case PermState.blocked:
        setState(() => _state = _CamState.blocked);
    }
  }

  Future<void> _startCamera() async {
    setState(() => _state = _CamState.starting);
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _state = _CamState.noCamera);
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: _audioThisSession,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      // Lock UI + capture to the current orientation so a phone lying flat on a
      // stand doesn't flip the view mid-drawing and exports stay aligned.
      var o = c.value.deviceOrientation;
      if (o == DeviceOrientation.portraitDown) o = DeviceOrientation.portraitUp;
      _orientation = o;
      await SystemChrome.setPreferredOrientations([o]);
      try {
        await c.lockCaptureOrientation(o);
      } catch (_) {}
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      _cam = c;
      setState(() => _state = _CamState.ready);
    } on CameraException catch (e) {
      if (!mounted) return;
      if (e.code.contains('Access') || e.code.contains('Permission')) {
        setState(() => _state = _CamState.denied);
      } else {
        setState(() {
          _state = _CamState.error;
          _errorText = e.description ?? e.code;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _CamState.error;
          _errorText = '$e';
        });
      }
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    try {
      await c.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } catch (_) {
      setState(() {
        _torch = false;
        _torchUnsupported = true;
      });
      if (mounted) {
        showSnack(
          context.tr(
            'cam.noTorch',
            'This device’s camera has no flashlight, or it’s in use by another app.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _changeReference() async {
    final src = await pickReference(
      context,
      title: context.tr('pick.change', 'Choose a different reference'),
    );
    if (src == null || !mounted) return;
    context.content.markUsed(src.refId);
    _source = src;
    _m.resetAll();
    await _loadRef();
  }

  void _toggleLock() {
    final locking = !_m.locked;
    _m.locked = locking;
    Haptics.select();
    if (locking) {
      showSnack(
        context.tr(
          'cam.lockedMsg',
          'Reference locked to the screen. Keep your phone and paper still while you draw.',
        ),
      );
    }
  }

  Size get _viewportSize {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? MediaQuery.sizeOf(context);
  }

  /// Display-oriented preview size used for the cover fit.
  Size _previewChildSize(CameraController c) {
    final ps = c.value.previewSize ?? const Size(1280, 720);
    final o = _orientation;
    final landscape =
        o == DeviceOrientation.landscapeLeft ||
        o == DeviceOrientation.landscapeRight;
    final long = max(ps.width, ps.height), short = min(ps.width, ps.height);
    return landscape ? Size(long, short) : Size(short, long);
  }

  Future<void> _capture() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _busy) {
      return;
    }
    final mode = await showEDSheet<_CaptureMode>(
      context,
      dark: true,
      title: context.tr('cap.title', 'Save a photo of your drawing'),
      builder: (ctx) => EDGroup(
        children: [
          EDListRow(
            icon: Icons.photo_camera_outlined,
            title: context.tr('cap.photoOnly', 'Camera photo only'),
            subtitle: context.tr(
              'cap.photoOnlyHint',
              'Just your real paper drawing, without the reference',
            ),
            onTap: () => Navigator.pop(ctx, _CaptureMode.photoOnly),
          ),
          EDListRow(
            icon: Icons.layers_outlined,
            title: context.tr(
              'cap.withOverlay',
              'Photo with reference overlay',
            ),
            subtitle: context.tr(
              'cap.withOverlayHint',
              'Exactly what you see on screen, cropped to the view',
            ),
            onTap: () => Navigator.pop(ctx, _CaptureMode.withOverlay),
          ),
          EDListRow(
            icon: Icons.collections_outlined,
            title: context.tr('cap.both', 'Save both'),
            onTap: () => Navigator.pop(ctx, _CaptureMode.both),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    final viewport = _viewportSize;
    final childSize = _previewChildSize(c);
    setState(() {
      _busy = true;
      _busyText = context.tr('cap.saving', 'Saving photo…');
    });
    final art = context.art;
    final title = context.trf('cap.name', 'Drawing {date}', {
      'date': _shortDate(),
    });
    final overlayTag = context.tr('cap.overlayTag', 'with reference');
    try {
      final shot = await c.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      ArtItem? saved;
      if (mode != _CaptureMode.withOverlay) {
        // Bake the EXIF rotation into the pixels so every app shows it upright.
        final upright = await processImport(
          shot.path,
          const ImportEdits(),
          maxSide: 4096,
        );
        saved = await art.addImage(
          upright.bytes,
          type: ArtType.capture,
          title: title,
          ext: 'jpg',
          meta: {'overlay': false},
        );
      }
      if (mode != _CaptureMode.photoOnly && _ref != null) {
        final jpg = await _compose(bytes, viewport, childSize);
        saved = await art.addImage(
          jpg,
          type: ArtType.capture,
          title: '$title · $overlayTag',
          ext: 'jpg',
          meta: {'overlay': true},
        );
      }
      try {
        await File(shot.path).delete();
      } catch (_) {}
      if (mounted && saved != null) {
        showSnack(
          context.tr('cap.saved', 'Saved to My Art'),
          actionLabel: context.tr('common.share', 'Share'),
          onAction: () => shareFile(art.fileOf(saved!).path),
        );
      }
    } on CameraException catch (_) {
      if (mounted) {
        showSnack(
          context.tr(
            'cap.failed',
            'The photo couldn’t be taken. Please try again.',
          ),
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showSnack(storageMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _shortDate() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)}';
  }

  /// Crops the photo to what was visible on screen and draws the reference
  /// with the same transform used on screen.
  Future<Uint8List> _compose(
    Uint8List photoBytes,
    Size viewport,
    Size child,
  ) async {
    final photo = await decodeBytes(photoBytes, maxSide: 4096);
    final pw = photo.width.toDouble(), ph = photo.height.toDouble();
    // 1. Centre-crop the photo to the preview's aspect ratio (same field of view).
    final aspect = child.width / child.height;
    var full = Rect.fromLTWH(0, 0, pw, ph);
    if (pw / ph > aspect) {
      final w = ph * aspect;
      full = Rect.fromLTWH((pw - w) / 2, 0, w, ph);
    } else {
      final h = pw / aspect;
      full = Rect.fromLTWH(0, (ph - h) / 2, pw, h);
    }
    // 2. The cover fit shows only the centre part of the preview.
    final s = max(viewport.width / child.width, viewport.height / child.height);
    final fx = viewport.width / (child.width * s),
        fy = viewport.height / (child.height * s);
    final visible = Rect.fromCenter(
      center: full.center,
      width: full.width * fx,
      height: full.height * fy,
    );
    // 3. Output at the visible resolution (capped).
    final k0 = visible.width / viewport.width;
    final cap = 2400 / max(visible.width, visible.height);
    final k = k0 * min(1.0, cap);
    final ow = (viewport.width * k).round(), oh = (viewport.height * k).round();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(
      photo,
      visible,
      Rect.fromLTWH(0, 0, ow.toDouble(), oh.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.scale(k);
    if (_m.visible) paintOverlay(canvas, viewport, _ref!, _m);
    final out = await rec.endRecording().toImage(ow, oh);
    photo.dispose();
    final jpg = await imageToJpeg(out, quality: 90);
    out.dispose();
    return jpg;
  }

  Future<void> _toggleRecording() async {
    if (_recording) return _stopRecording();
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (!_recordInfoShown) {
      final go = await _showRecordInfo();
      if (go != true || !mounted) return;
      _recordInfoShown = true;
    }
    final wantAudio = _settings.recordAudio;
    if (wantAudio != _audioThisSession) {
      // Audio is configured when the camera starts, so restart it.
      if (wantAudio) {
        final st = await checkPermission(Permission.microphone);
        if (!mounted) return;
        if (st != PermState.granted) {
          showSnack(
            context.tr(
              'rec.noMic',
              'Microphone access is off, so recording will be silent.',
            ),
            error: true,
          );
          _settings.update((s) => s.recordAudio = false);
        } else {
          _audioThisSession = true;
          await _releaseCamera();
          await _startCamera();
        }
      } else {
        _audioThisSession = false;
        await _releaseCamera();
        await _startCamera();
      }
    }
    final cam = _cam;
    if (cam == null || !mounted) return;
    try {
      await cam.prepareForVideoRecording();
      await cam.startVideoRecording();
      _recElapsed = Duration.zero;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recElapsed += const Duration(seconds: 1));
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        showSnack(
          context.tr(
            'rec.startFailed',
            'Recording isn’t available on this device right now. Your session is unaffected.',
          ),
          error: true,
        );
      }
    }
  }

  Future<bool?> _showRecordInfo() {
    return showEDSheet<bool>(
      context,
      dark: true,
      title: context.tr('rec.title', 'Record your drawing'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EDCard(
              elevated: true,
              padding: const EdgeInsets.all(Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.videocam_outlined, color: ctx.ds.accentText),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      context.tr(
                        'rec.what',
                        'What is recorded: the camera view of your paper only. The reference overlay, grid and buttons are not included in the video.',
                      ),
                      style: ctx.text.body,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s),
            EDGroup(
              children: [
                EDSwitchRow(
                  icon: Icons.mic_none_rounded,
                  title: context.tr('rec.audio', 'Include sound'),
                  subtitle: context.tr(
                    'rec.audioHint',
                    'Off by default. Turning it on asks for microphone access.',
                  ),
                  value: _settings.recordAudio,
                  onChanged: (v) {
                    _settings.update((s) => s.recordAudio = v);
                    setSheet(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            EDButton(
              dark: true,
              expand: true,
              icon: Icons.fiber_manual_record_rounded,
              label: context.tr('rec.start', 'Start recording'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopRecording({bool interrupted = false}) async {
    _recTimer?.cancel();
    final c = _cam;
    if (c == null || !_recording) return;
    final art = context.art;
    final title = context.trf('rec.name', 'Recording {date}', {
      'date': _shortDate(),
    });
    final msgSaved = context.tr('rec.saved', 'Recording saved to My Art');
    final msgInterrupted = context.tr(
      'rec.interrupted',
      'Recording stopped because the app was interrupted. What was recorded has been saved.',
    );
    final msgFailed = context.tr(
      'rec.failed',
      'The recording couldn’t be saved. Your drawing session is unaffected.',
    );
    if (mounted) setState(() => _recording = false);
    try {
      final f = await c.stopVideoRecording();
      await art.addVideo(
        File(f.path),
        title: title,
        meta: {'audio': _audioThisSession, 'overlay': false},
      );
      showSnack(interrupted ? msgInterrupted : msgSaved);
    } catch (e) {
      showSnack(msgFailed, error: true);
    }
  }

  void _showHelp() {
    showStepsSheet(
      context,
      dark: true,
      title: context.tr('cam.helpTitle', 'How Camera Drawing works'),
      steps: [
        context.tr(
          'cam.help1',
          'The reference is shown on your phone screen over the camera view. Nothing is projected onto the paper.',
        ),
        context.tr(
          'cam.help2',
          'Put the phone on a stable stand (or a stack of books) 20–40 cm above the paper, camera pointing down.',
        ),
        context.tr(
          'cam.help3',
          'Drag to move, pinch to resize and twist with two fingers to rotate the reference. Sliders give fine control.',
        ),
        context.tr(
          'cam.help4',
          'Tap Lock when it’s aligned. Lock freezes the reference on the screen — it does not follow the paper, so keep the phone and paper still.',
        ),
        context.tr(
          'cam.help5',
          'Draw while looking at the screen: your pencil appears in the camera view under the reference.',
        ),
        context.tr(
          'cam.help6',
          'Use Hide to check your real drawing, then Capture to save a photo.',
        ),
      ],
    );
  }

  // --------------------------------------------------------------------- UI

  static const _g = EDPalette.dark; // workspaces are always graphite

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: Theme.of(context)
            .copyWith(extensions: [_g, EDText.build(_g, context.lang)]),
        child: PopScope(
          canPop: !_recording,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _recording) {
              showSnack(
                context.tr(
                  'rec.stopFirst',
                  'Stop the recording before leaving.',
                ),
                error: true,
              );
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(child: _viewport()),
                _topBar(),
                if (_state == _CamState.ready) _bottomPanel(),
                if (_busy) BusyOverlay(message: _busyText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewport() {
    final c = _cam;
    Widget base;
    if (_state == _CamState.ready && c != null && c.value.isInitialized) {
      final child = _previewChildSize(c);
      base = ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: child.width,
            height: child.height,
            child: _preview(c),
          ),
        ),
      );
    } else {
      base = ColoredBox(color: _g.bg, child: _stateCard());
    }
    return Stack(
      key: _viewportKey,
      fit: StackFit.expand,
      children: [
        base,
        if (_state == _CamState.ready && _grid)
          IgnorePointer(
            child: CustomPaint(painter: GridPainter(color: _g.text)),
          ),
        if (_state == _CamState.ready && _ref != null)
          ReferenceOverlay(
            image: _ref!,
            model: _m,
            semanticLabel: context.trf('cam.refLabel', 'Reference: {name}', {
              'name': refTitle(context, _source),
            }),
          ),
        if (_state == _CamState.ready && _refFailed)
          EDStateView(
            dark: true,
            tone: EDStateTone.error,
            icon: Icons.broken_image_outlined,
            title: context.tr(
              'cam.refFailed',
              'This reference couldn’t be loaded.',
            ),
            message: context.tr(
              'cam.refFailedBody',
              'The file may have been moved or deleted.',
            ),
            actionLabel: context.tr(
              'pick.change',
              'Choose a different reference',
            ),
            onAction: _changeReference,
          ),
      ],
    );
  }

  /// The plugin's CameraPreview re-rotates while recording; the session is
  /// locked to one orientation, so rotate once by that orientation instead.
  Widget _preview(CameraController c) {
    final p = c.buildPreview();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return p;
    const turns = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeRight: 1,
      DeviceOrientation.portraitDown: 2,
      DeviceOrientation.landscapeLeft: 3,
    };
    return RotatedBox(quarterTurns: turns[_orientation] ?? 0, child: p);
  }

  Widget _stateCard() {
    final alternatives = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(
            'perm.alternatives',
            'Or keep drawing without the camera:',
          ),
          style: context.text.bodySm,
        ),
        const SizedBox(height: Space.xs),
        EDButton.secondary(
          dark: true,
          icon: Icons.wb_sunny_outlined,
          label: context.tr('cam.useTrace', 'Use Trace Mode instead'),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => traceScreenFor(_source)),
          ),
        ),
        const SizedBox(height: Space.xs),
        EDButton.secondary(
          dark: true,
          icon: Icons.brush_outlined,
          label: context.tr('cam.useCanvas', 'Draw on Digital Canvas'),
          onPressed: () {
            Navigator.pop(context);
            openCanvas(context, reference: _source);
          },
        ),
      ],
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: switch (_state) {
          _CamState.checking || _CamState.starting => EDLoading(
            dark: true,
            message: context.tr('cam.starting', 'Starting camera…'),
          ),
          _CamState.explain ||
          _CamState.denied ||
          _CamState.blocked => EDStateView(
            dark: true,
            icon: Icons.photo_camera_outlined,
            tone: _state == _CamState.explain
                ? EDStateTone.neutral
                : EDStateTone.warning,
            title: context.tr('perm.cameraTitle', 'Camera access needed'),
            message: [
              context.tr(
                'perm.cameraWhy',
                'Camera Drawing shows your paper through the rear camera with the reference on top. The video stays on your device and is never uploaded.',
              ),
              if (_state == _CamState.denied)
                context.tr('perm.cameraDenied', 'Camera access was declined.'),
              if (_state == _CamState.blocked)
                context.tr(
                  'perm.cameraBlocked',
                  'Camera access is turned off for Easy Draw. You can turn it on in Settings.',
                ),
            ].join('\n\n'),
            actionLabel: _state == _CamState.blocked
                ? context.tr('perm.openSettings', 'Open Settings')
                : _state == _CamState.denied
                ? context.tr('common.tryAgain', 'Try again')
                : context.tr('perm.allowCamera', 'Allow camera access'),
            onAction: _state == _CamState.blocked
                ? openSystemSettings
                : _requestPermission,
            extra: Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: alternatives,
            ),
          ),
          _CamState.noCamera => EDStateView(
            dark: true,
            icon: Icons.no_photography_outlined,
            tone: EDStateTone.warning,
            title: context.tr(
              'cam.none',
              'No camera was found on this device.',
            ),
            message: context.tr(
              'cam.noneBody',
              'You can still trace on the screen or draw on the canvas.',
            ),
            extra: alternatives,
          ),
          _CamState.error => EDStateView(
            dark: true,
            icon: Icons.error_outline_rounded,
            tone: EDStateTone.error,
            title: context.tr(
              'cam.error',
              'The camera couldn’t start. Another app may be using it.',
            ),
            message: _errorText ?? '',
            actionLabel: context.tr('common.retry', 'Retry'),
            onAction: _startCamera,
            extra: alternatives,
          ),
          _CamState.ready => const SizedBox(),
        },
      ),
    );
  }

  Widget _topBar() {
    final t = context.text;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xxs,
              Space.xxs,
              Space.xxs,
              Space.m,
            ),
            child: Row(
              children: [
                EDIconButton(
                  dark: true,
                  icon: context.isRtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: Space.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('tool.camera', 'Camera Drawing'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSm.copyWith(color: _g.text),
                      ),
                      Text(
                        refTitle(context, _source),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: _g.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_recording)
                  Semantics(
                    liveRegion: true,
                    label: context.tr('rec.on', 'Recording'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.xs,
                        vertical: Space.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: Radii.tagR,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fiber_manual_record_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: Space.xxs),
                          Text(
                            'REC ${_fmt(_recElapsed)}',
                            style: t.numeric.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_state == _CamState.ready)
                  ListenableBuilder(
                    listenable: _m,
                    builder: (context, _) => EDIconButton(
                      dark: true,
                      icon: Icons.photo_library_outlined,
                      tooltip: context.tr(
                        'pick.change',
                        'Choose a different reference',
                      ),
                      onPressed: _m.locked || _recording
                          ? null
                          : _changeReference,
                    ),
                  ),
                EDIconButton(
                  dark: true,
                  icon: Icons.help_outline_rounded,
                  tooltip: context.tr('common.help', 'Help'),
                  onPressed: _showHelp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Bottom panel: a collapsible tray (sliders + tools) above an always-visible
  /// action bar. Primary actions sit on the thumb side for the drawing hand.
  Widget _bottomPanel() {
    final t = context.text;
    final dur = Motion.of(context);
    final rightHanded = _settings.handedness == Handedness.right;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.xs),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                decoration: BoxDecoration(
                  color: _g.panel,
                  borderRadius: BorderRadius.circular(Radii.sheet),
                  border: Border.all(color: _g.border),
                ),
                child: ListenableBuilder(
                  listenable: _m,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expand / collapse handle.
                      Pressable(
                        onTap: () => setState(() => _panelOpen = !_panelOpen),
                        semanticLabel: _panelOpen
                            ? context.tr('panel.collapse', 'Collapse controls')
                            : context.tr('panel.expand', 'Expand controls'),
                        excludeChildSemantics: true,
                        scale: 1,
                        builder: (context, s) => SizedBox(
                          height: 32,
                          width: double.infinity,
                          child: Center(
                            child: AnimatedRotation(
                              turns: _panelOpen ? 0 : 0.5,
                              duration: dur,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _g.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: dur,
                        curve: Motion.curve,
                        alignment: Alignment.bottomCenter,
                        child: _panelOpen
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.m,
                                  0,
                                  Space.m,
                                  Space.xs,
                                ),
                                child: Column(
                                  children: [
                                    OverlaySliders(model: _m),
                                    const SizedBox(height: Space.xs),
                                    OverlayToolRow(
                                      model: _m,
                                      extra: [
                                        EDToolButton(
                                          icon: Icons.grid_4x4_rounded,
                                          label: context.tr('ov.grid', 'Grid'),
                                          toggle: true,
                                          active: _grid,
                                          onPressed: () =>
                                              setState(() => _grid = !_grid),
                                        ),
                                        EDToolButton(
                                          icon: _torch
                                              ? Icons.flashlight_on_outlined
                                              : Icons.flashlight_off_outlined,
                                          label: context.tr(
                                            'cam.torch',
                                            'Light',
                                          ),
                                          toggle: true,
                                          active: _torch,
                                          onPressed: _torchUnsupported
                                              ? null
                                              : _toggleTorch,
                                        ),
                                      ],
                                    ),
                                    Divider(height: Space.m, color: _g.border),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      // Action bar (always visible).
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.s,
                          0,
                          Space.s,
                          Space.s,
                        ),
                        child: Row(
                          textDirection: rightHanded
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          children: [
                            if (_m.locked)
                              HoldToUnlockButton(
                                compact: true,
                                duration: const Duration(milliseconds: 600),
                                label: context.tr('lock.unlock', 'Unlock'),
                                onUnlocked: _toggleLock,
                              )
                            else
                              EDToolButton(
                                icon: Icons.lock_open_rounded,
                                label: context.tr('lock.lock', 'Lock'),
                                toggle: true,
                                onPressed: _toggleLock,
                              ),
                            EDToolButton(
                              icon: _m.visible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              label: _m.visible
                                  ? context.tr('ov.hide', 'Hide')
                                  : context.tr('ov.show', 'Show'),
                              toggle: true,
                              active: !_m.visible,
                              onPressed: () => _m.visible = !_m.visible,
                            ),
                            const Spacer(),
                            _RoundAction(
                              icon: _recording
                                  ? Icons.stop_rounded
                                  : Icons.fiber_manual_record_rounded,
                              label: _recording
                                  ? context.tr('rec.stop', 'Stop')
                                  : context.tr('rec.record', 'Record'),
                              kind: _recording
                                  ? _ActionKind.recording
                                  : _ActionKind.record,
                              onTap: _toggleRecording,
                            ),
                            const SizedBox(width: Space.s),
                            _RoundAction(
                              icon: Icons.camera_outlined,
                              label: context.tr('cap.capture', 'Capture'),
                              kind: _ActionKind.capture,
                              enabled: !_recording,
                              onTap: _capture,
                            ),
                          ],
                        ),
                      ),
                      if (_m.locked)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.m,
                            0,
                            Space.m,
                            Space.s,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: _g.accent,
                              ),
                              const SizedBox(width: Space.xs),
                              Expanded(
                                child: Text(
                                  context.tr(
                                    'cam.lockedHint',
                                    'Locked to screen · keep phone & paper still',
                                  ),
                                  style: t.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActionKind { capture, record, recording }

/// Large workspace action (capture = lime, record = red dot / red stop).
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final _ActionKind kind;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const g = EDPalette.dark;
    const red = Color(0xFFE53935);
    final big = kind == _ActionKind.capture;
    final size = big ? 60.0 : 52.0;
    final (bg, fg, border) = switch (kind) {
      _ActionKind.capture => (g.accent, g.onAccent, g.accent),
      _ActionKind.record => (g.elevated, red, g.border),
      _ActionKind.recording => (red, Colors.white, red),
    };
    return Pressable(
      onTap: enabled ? onTap : null,
      haptic: PressHaptic.press,
      semanticLabel: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(16),
      builder: (context, s) => AnimatedOpacity(
        duration: Motion.of(context, Motion.fast),
        opacity: enabled ? 1 : 0.38,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color.alphaBlend(stateOverlay(g, s), bg),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1.5),
                boxShadow: big
                    ? [
                        BoxShadow(
                          color: g.accent.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, color: fg, size: big ? 30 : 26),
            ),
            const SizedBox(height: Space.xxs),
            Text(
              label,
              style: context.text.caption.copyWith(
                color: g.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
