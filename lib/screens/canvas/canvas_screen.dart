import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/l10n.dart';
import '../../app/scope.dart';
import '../../app/settings.dart';
import '../../data/art_store.dart';
import '../../data/models.dart';
import '../../services/image_ops.dart';
import '../../services/ref_loader.dart';
import '../../services/share_service.dart';
import '../../widgets/common.dart';
import 'canvas_model.dart';
import 'color_picker.dart';

enum _SaveState { idle, pending, saving, saved, failed }

/// Touch drawing canvas with layers, undo/redo, zoom/pan and autosave.
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, this.project, this.reference});
  final ArtItem? project;
  final RefSource? reference;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> with WidgetsBindingObserver {
  late final ArtStore _art;
  late final AppSettings _settings;
  ArtItem? _project;
  String _title = '';

  Size _doc = const Size(1536, 2048);
  final List<CanvasLayer> _layers = [];
  int _active = 0;
  bool _loading = true;
  String? _loadError;

  Tool _tool = Tool.pen;
  Color _color = const Color(0xFF121718);
  double _size = 8;
  double _opacity = 1;

  final List<HistoryEntry> _undo = [];
  final List<HistoryEntry> _redo = [];
  StrokeOp? _live;
  final _repaint = _Repaint();

  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _viewport = Size.zero;
  bool _fitted = false;

  // Gesture state.
  final Map<int, Offset> _pointers = {};
  int? _drawPointer;
  DateTime _strokeStart = DateTime.now();
  Offset? _downPos;
  bool _transforming = false;
  double _z0 = 1;
  Offset _p0 = Offset.zero;
  double _d0 = 1;
  Offset _f0 = Offset.zero;

  _SaveState _save = _SaveState.idle;
  Timer? _saveTimer;
  bool _saveAgain = false;
  bool _busy = false;
  String _busyText = '';
  int _layerSeq = 1;

  CanvasLayer get _activeLayer => _layers[_active];
  bool get _coloring => _layers.any((l) => l.kind == LayerKind.outline);

  @override
  void initState() {
    super.initState();
    _art = context.art;
    _settings = context.settings;
    _size = _settings.defaultBrushSize;
    WidgetsBinding.instance.addObserver(this);
    // Localized names need inherited widgets, which aren't ready in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    for (final l in _layers) {
      l.cache?.dispose();
      if (!identical(l.base, l.cache)) l.base?.dispose();
    }
    _repaint.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      if (_save == _SaveState.pending) _doSave();
    }
  }

  // ------------------------------------------------------------ load / init

  Future<void> _init() async {
    try {
      if (widget.project != null) {
        await _loadProject(widget.project!);
      } else {
        _title = widget.reference != null
            ? context.trf('canvas.nameRef', '{name} drawing', {'name': refTitle(context, widget.reference!)})
            : context.tr('canvas.untitled', 'Untitled drawing');
        final colorsLabel = context.tr('canvas.colors', 'Colors');
        final outlineLabel = context.tr('canvas.outline', 'Outline (protected)');
        final referenceLabel = context.tr('canvas.reference', 'Reference');
        final layer1Label = context.trf('canvas.layerN', 'Layer {n}', {'n': 1});
        if (widget.reference != null) {
          final ref = await loadRefImage(widget.reference!, maxSide: 2048);
          final s = 2048 / max(ref.width, ref.height);
          _doc = Size((ref.width * s).roundToDouble(), (ref.height * s).roundToDouble());
          final scaled = await _fitImage(ref, _doc);
          ref.dispose();
          final coloring = widget.reference!.coloring;
          if (coloring) {
            _layers.add(_newPaintLayer(colorsLabel));
            _layers.add(CanvasLayer(id: 'outline', name: outlineLabel, kind: LayerKind.outline, base: scaled)..cache = scaled);
            _active = 0;
            _tool = Tool.fill;
            _color = const Color(0xFFFF7EB3);
          } else {
            _layers.add(CanvasLayer(id: 'reference', name: referenceLabel, kind: LayerKind.reference, opacity: 0.35, base: scaled, exportable: false)
              ..cache = scaled);
            _layers.add(_newPaintLayer(layer1Label));
            _active = 1;
          }
        } else {
          _layers.add(_newPaintLayer(layer1Label));
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        debugPrint('Canvas load failed: $e');
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      }
    }
  }

  CanvasLayer _newPaintLayer(String name) => CanvasLayer(id: 'l${DateTime.now().microsecondsSinceEpoch}_${_layerSeq++}', name: name);

  Future<ui.Image> _fitImage(ui.Image src, Size doc) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImageRect(src, Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), Offset.zero & doc, Paint()..filterQuality = FilterQuality.high);
    return rec.endRecording().toImage(doc.width.round(), doc.height.round());
  }

  Future<void> _loadProject(ArtItem item) async {
    _project = item;
    _title = item.title;
    _save = _SaveState.saved;
    final dir = _art.projectDir(item);
    final f = File(p.join(dir.path, 'project.json'));
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    _doc = Size((j['w'] as num).toDouble(), (j['h'] as num).toDouble());
    for (final lj in (j['layers'] as List).cast<Map<String, dynamic>>()) {
      ui.Image? base;
      final file = File(p.join(dir.path, lj['file'] as String));
      if (await file.exists()) base = await decodeBytes(await file.readAsBytes(), maxSide: 8192);
      _layers.add(CanvasLayer(
        id: lj['id'] as String,
        name: lj['name'] as String,
        kind: LayerKind.values.firstWhere((k) => k.name == lj['kind'], orElse: () => LayerKind.paint),
        opacity: (lj['opacity'] as num).toDouble(),
        visible: lj['visible'] as bool,
        exportable: (lj['exportable'] as bool?) ?? true,
        base: base,
      )..cache = base);
      _layerSeq++;
    }
    final a = (j['active'] as int?) ?? 0;
    _active = a.clamp(0, _layers.length - 1);
    if (!_activeLayer.editable) _active = _layers.indexWhere((l) => l.editable).clamp(0, _layers.length - 1);
    if (_coloring) _tool = Tool.fill;
  }

  // ---------------------------------------------------------------- saving

  void _changed(CanvasLayer? layer) {
    layer?.dirty = true;
    setState(() => _save = _SaveState.pending);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), _doSave);
  }

  Future<bool> _doSave() async {
    _saveTimer?.cancel();
    if (_save == _SaveState.saving) {
      _saveAgain = true;
      return true;
    }
    if (mounted) setState(() => _save = _SaveState.saving);
    try {
      _project ??= await _art.createProject(title: _title, meta: {'coloring': _coloring});
      final dir = _art.projectDir(_project!);
      await dir.create(recursive: true);
      for (final l in _layers) {
        final file = File(p.join(dir.path, 'layer_${l.id}.png'));
        if (!l.dirty && await file.exists()) continue;
        final img = l.cache ?? l.base;
        if (img == null) {
          // Empty layer: write a transparent PNG of the document size.
          final rec = ui.PictureRecorder();
          Canvas(rec);
          final blank = await rec.endRecording().toImage(_doc.width.round(), _doc.height.round());
          await writeAtomic(file, await encodePng(blank));
          blank.dispose();
        } else {
          await writeAtomic(file, await encodePng(img));
        }
        l.dirty = false;
      }
      final meta = {
        'version': 1,
        'w': _doc.width,
        'h': _doc.height,
        'active': _active,
        'layers': [
          for (final l in _layers)
            {'id': l.id, 'name': l.name, 'kind': l.kind.name, 'opacity': l.opacity, 'visible': l.visible, 'exportable': l.exportable, 'file': 'layer_${l.id}.png'},
        ],
      };
      await writeAtomic(File(p.join(dir.path, 'project.json')), utf8.encode(jsonEncode(meta)));
      final comp = await composite(_layers, _doc);
      await writeAtomic(File(p.join(dir.path, 'composite.png')), await encodePng(comp));
      comp.dispose();
      final thumb = await composite(_layers, _doc, scale: 480 / max(_doc.width, _doc.height));
      final thumbPng = await encodePng(thumb);
      thumb.dispose();
      PaintingBindingHelper.evict(File(p.join(dir.path, 'composite.png')));
      await _art.touchProject(_project!, thumbPng: thumbPng);
      if (mounted) setState(() => _save = _SaveState.saved);
      if (_saveAgain) {
        _saveAgain = false;
        return await _doSave();
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _save = _SaveState.failed);
        showSnack(storageMessage(context, e), error: true, actionLabel: context.tr('common.retry', 'Retry'), onAction: _doSave);
      }
      return false;
    }
  }

  Future<void> _exit() async {
    if (_save == _SaveState.pending || _save == _SaveState.saving || _save == _SaveState.failed) {
      setState(() {
        _busy = true;
        _busyText = context.tr('canvas.saving', 'Saving…');
      });
      final ok = await _doSave();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) {
        final leave = await confirmDialog(
          context,
          title: context.tr('canvas.unsavedTitle', 'Leave without saving?'),
          message: context.tr('canvas.unsavedBody', 'Your latest changes couldn’t be saved. If you leave now they will be lost.'),
          confirmLabel: context.tr('canvas.discard', 'Discard changes'),
          destructive: true,
        );
        if (!leave || !mounted) return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  // ------------------------------------------------------------ operations

  Future<void> _commit(CanvasLayer layer, DrawOp op) async {
    layer.ops.add(op);
    _undo.add(HistoryEntry(layer, op));
    _redo.clear();
    await appendToLayer(layer, op, _doc);
    await _trim(layer);
    _repaint.ping();
    _changed(layer);
  }

  /// Keeps memory bounded: very old operations are flattened (not undoable).
  Future<void> _trim(CanvasLayer l) async {
    if (l.ops.length <= 50) return;
    final old = l.ops.sublist(0, 25);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & _doc);
    if (l.base != null) c.drawImage(l.base!, Offset.zero, Paint());
    for (final op in old) {
      paintOp(c, op, _doc);
    }
    final nb = await rec.endRecording().toImage(_doc.width.round(), _doc.height.round());
    if (!identical(l.base, l.cache)) l.base?.dispose();
    l.base = nb;
    l.ops.removeRange(0, 25);
    _undo.removeWhere((e) => old.contains(e.op));
  }

  Future<void> _undoOp() async {
    if (_undo.isEmpty) return;
    final e = _undo.removeLast();
    e.layer.ops.remove(e.op);
    _redo.add(e);
    await rebuildLayer(e.layer, _doc);
    _repaint.ping();
    _changed(e.layer);
  }

  Future<void> _redoOp() async {
    if (_redo.isEmpty) return;
    final e = _redo.removeLast();
    if (!_layers.contains(e.layer)) return;
    e.layer.ops.add(e.op);
    _undo.add(e);
    await appendToLayer(e.layer, e.op, _doc);
    _repaint.ping();
    _changed(e.layer);
  }

  Future<void> _clearLayer() async {
    final l = _activeLayer;
    if (!l.editable) return;
    final ok = await confirmDialog(
      context,
      title: context.tr('canvas.clearTitle', 'Clear this layer?'),
      message: context.trf('canvas.clearBody', 'Everything on “{name}” will be erased. You can undo this.', {'name': l.name}),
      confirmLabel: context.tr('canvas.clear', 'Clear layer'),
      destructive: true,
    );
    if (ok) await _commit(l, ClearOp());
  }

  Future<void> _fillAt(Offset doc) async {
    final layer = _activeLayer;
    if (!layer.editable) return _notEditable();
    if (!(Offset.zero & _doc).contains(doc)) return;
    setState(() {
      _busy = true;
      _busyText = context.tr('canvas.filling', 'Filling…');
    });
    try {
      final boundary = await composite(_layers.where((l) => l.kind != LayerKind.reference).toList(), _doc, whitePaper: false, forExport: false);
      final data = await boundary.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final w = boundary.width, h = boundary.height;
      boundary.dispose();
      final argb = _color.withValues(alpha: _opacity).toARGB32();
      final mask = await floodFillMask(data!.buffer.asUint8List(), w, h, doc.dx.floor().clamp(0, w - 1), doc.dy.floor().clamp(0, h - 1), argb);
      final img = await imageFromRgba(mask, w, h);
      await _commit(layer, FillOp(img));
    } catch (_) {
      if (mounted) showSnack(context.tr('canvas.fillFailed', 'Fill didn’t work here. Try another spot.'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notEditable() => showSnack(context.tr('canvas.protected', 'This layer is protected. Pick a drawing layer in Layers.'), error: true);

  // ---------------------------------------------------------------- gestures

  Offset _toDoc(Offset local) => (local - _pan) / _zoom;

  void _fit() {
    if (_viewport == Size.zero) return;
    final z = min((_viewport.width - 24) / _doc.width, (_viewport.height - 24) / _doc.height);
    setState(() {
      _zoom = z;
      _pan = Offset((_viewport.width - _doc.width * z) / 2, (_viewport.height - _doc.height * z) / 2);
    });
    _repaint.ping();
  }

  double get _fitZoom => min((_viewport.width - 24) / _doc.width, (_viewport.height - 24) / _doc.height);

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downPos = e.localPosition;
      _drawPointer = e.pointer;
      _strokeStart = DateTime.now();
      if (_tool != Tool.fill) {
        if (!_activeLayer.editable) {
          _drawPointer = null;
          _notEditable();
          return;
        }
        // Sizes are on-screen pixels at "fit" zoom, so they feel the same on any document size.
        _live = StrokeOp(tool: _tool, color: _color, size: _size / _fitZoom, opacity: _opacity)..add(_toDoc(e.localPosition), _pressure(e));
        _repaint.ping();
      }
    } else if (_pointers.length == 2) {
      // Second finger: switch to pan/zoom. Drop a stroke that just started.
      if (_live != null) {
        final young = DateTime.now().difference(_strokeStart) < const Duration(milliseconds: 250) || _live!.points.length < 6;
        if (young) {
          _live = null;
        } else {
          final s = _live!;
          _live = null;
          _commit(_activeLayer, s);
        }
      }
      _drawPointer = null;
      _transforming = true;
      final pts = _pointers.values.toList();
      _d0 = max(1, (pts[0] - pts[1]).distance);
      _f0 = (pts[0] + pts[1]) / 2;
      _z0 = _zoom;
      _p0 = _pan;
      _repaint.ping();
    }
  }

  double _pressure(PointerEvent e) {
    if (e.pressureMax > 1.0 || (e.pressure > 0 && e.pressure < 1)) {
      return (0.35 + 0.65 * ((e.pressure - e.pressureMin) / max(0.001, e.pressureMax - e.pressureMin))).clamp(0.2, 1.3);
    }
    return 1.0;
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_transforming && _pointers.length >= 2) {
      final pts = _pointers.values.take(2).toList();
      final d = max(1.0, (pts[0] - pts[1]).distance);
      final f = (pts[0] + pts[1]) / 2;
      final nz = (_z0 * d / _d0).clamp(_fitZoom * 0.3, _fitZoom * 10);
      _zoom = nz;
      _pan = f - (_f0 - _p0) * (nz / _z0);
      _repaint.ping();
      return;
    }
    if (e.pointer == _drawPointer && _live != null) {
      final pt = _toDoc(e.localPosition);
      final last = _live!.points.last;
      if ((pt - last).distance * _zoom < 1.5) return;
      var w = _pressure(e);
      if (_tool == Tool.brush && w == 1.0) {
        // No pressure: thinner when moving fast.
        final speed = (pt - last).distance * _zoom;
        w = (1.25 - speed / 60).clamp(0.45, 1.25);
        final prev = _live!.widths.last;
        w = prev * 0.6 + w * 0.4;
      }
      _live!.add(pt, w);
      _repaint.ping();
    }
  }

  void _onUp(PointerEvent e) {
    final wasDraw = e.pointer == _drawPointer;
    _pointers.remove(e.pointer);
    if (_transforming) {
      if (_pointers.isEmpty) _transforming = false;
      return;
    }
    if (!wasDraw) return;
    _drawPointer = null;
    if (_tool == Tool.fill && e is PointerUpEvent) {
      if (_downPos != null && (e.localPosition - _downPos!).distance < 12) _fillAt(_toDoc(e.localPosition));
      return;
    }
    final s = _live;
    _live = null;
    if (s != null && e is PointerUpEvent) _commit(_activeLayer, s);
    _repaint.ping();
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: p.isDark ? const Color(0xFF0B0F11) : const Color(0xFFE2E7E2),
        appBar: EDTopBar(
          title: _title,
          subtitle: _saveLabel(),
          onBack: _exit,
          onTitleTap: _save == _SaveState.failed ? _doSave : _rename,
          actions: [
            EDIconButton(icon: Icons.undo_rounded, tooltip: context.tr('canvas.undo', 'Undo'), onPressed: _undo.isEmpty ? null : _undoOp),
            EDIconButton(icon: Icons.redo_rounded, tooltip: context.tr('canvas.redo', 'Redo'), onPressed: _redo.isEmpty ? null : _redoOp),
            EDIconButton(icon: Icons.more_vert_rounded, tooltip: context.tr('art.more', 'More options'), onPressed: _loading ? null : _showMore),
          ],
        ),
        body: Stack(children: [
          if (_loading)
            EDLoading(message: context.tr('canvas.loading', 'Opening canvas…'))
          else if (_loadError != null)
            EDStateView(
              icon: Icons.broken_image_outlined,
              tone: EDStateTone.error,
              title: context.tr('canvas.loadFail', 'This project couldn’t be opened'),
              message: context.tr('canvas.loadFailBody', 'Its files may be missing or damaged. Other projects are not affected.'),
              actionLabel: context.tr('common.back', 'Go back'),
              onAction: () => Navigator.pop(context),
            )
          else
            _workspace(),
          if (_busy) BusyOverlay(message: _busyText),
        ]),
      ),
    );
  }

  Widget _saveLabel() {
    final p = context.ds;
    final (text, icon, color) = switch (_save) {
      _SaveState.idle => (context.tr('canvas.notSaved', 'Autosaves as you draw'), Icons.cloud_outlined, p.textMuted),
      _SaveState.pending || _SaveState.saving => (context.tr('canvas.savingShort', 'Saving…'), Icons.sync_rounded, p.textMuted),
      _SaveState.saved => (context.tr('canvas.saved', 'Saved on device'), Icons.check_rounded, p.accentText),
      _SaveState.failed => (context.tr('canvas.saveFailed', 'Not saved — tap here to retry'), Icons.error_outline_rounded, p.danger),
    };
    return Semantics(
      liveRegion: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: Space.xxs),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.caption.copyWith(color: color))),
      ]),
    );
  }

  Widget _workspace() {
    final left = _settings.handedness == Handedness.right;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final rail = _toolRail();
    final canvas = Expanded(
      child: LayoutBuilder(builder: (context, c) {
        final vp = Size(c.maxWidth, c.maxHeight);
        if (vp != _viewport) {
          _viewport = vp;
          if (!_fitted) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
          }
        }
        return Semantics(
          label: context.tr('canvas.area', 'Drawing canvas. Draw with one finger, pinch with two fingers to zoom and move.'),
          child: Listener(
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: ClipRect(
              child: CustomPaint(
                size: vp,
                painter: _CanvasPainter(
                  layers: _layers,
                  active: _layers.isEmpty ? null : _activeLayer,
                  live: () => _live,
                  view: () => (_zoom, _pan),
                  doc: _doc,
                  repaint: _repaint,
                  dark: context.ds.isDark,
                ),
              ),
            ),
          ),
        );
      }),
    );
    // Physical side (from the drawing-hand setting), independent of RTL.
    final main = Row(textDirection: TextDirection.ltr, children: left ? [rail, canvas] : [canvas, rail]);
    return SafeArea(
      top: false,
      child: Column(children: [
        Expanded(child: main),
        _bottomBar(compact: landscape),
      ]),
    );
  }

  Widget _toolRail() {
    final p = context.ds;
    final t = context.text;
    final tools = [
      (Tool.pencil, Icons.edit_outlined, context.tr('tool.pencil', 'Pencil')),
      (Tool.pen, Icons.draw_outlined, context.tr('tool.pen', 'Pen')),
      (Tool.brush, Icons.brush_outlined, context.tr('tool.brush', 'Brush')),
      (Tool.eraser, Icons.auto_fix_normal_outlined, context.tr('tool.eraser', 'Eraser')),
      (Tool.fill, Icons.format_color_fill_rounded, context.tr('tool.fill', 'Fill')),
    ];
    return Container(
      width: 80,
      height: double.infinity,
      decoration: BoxDecoration(color: p.surface, border: Border.symmetric(vertical: BorderSide(color: p.border))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(children: [
          for (final tool in tools)
            EDToolButton(
              dark: false,
              icon: tool.$2,
              label: tool.$3,
              active: _tool == tool.$1,
              toggle: true,
              onPressed: () => setState(() => _tool = tool.$1),
            ),
          Padding(padding: const EdgeInsets.symmetric(vertical: Space.xs, horizontal: Space.m), child: Divider(color: p.border)),
          Pressable(
            onTap: _pickColor,
            semanticLabel: context.trf('color.current', 'Color {hex}. Tap to change.', {'hex': hexOf(_color)}),
            excludeChildSemantics: true,
            borderRadius: Radii.buttonR,
            builder: (context, s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _color, borderRadius: Radii.buttonR, border: Border.all(color: _ringFor(_color, p), width: 2)),
                  child: Icon(Icons.palette_outlined, size: 18, color: _color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70),
                ),
                const SizedBox(height: Space.xxs),
                Text(context.tr('color.short', 'Color'), style: t.caption),
              ]),
            ),
          ),
          EDToolButton(dark: false, icon: Icons.layers_outlined, label: _activeLayer.name, onPressed: _showLayers),
        ]),
      ),
    );
  }

  Widget _bottomBar({required bool compact}) {
    final p = context.ds;
    final swatches = _settings.swatches.take(12).toList();
    return Container(
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
      padding: const EdgeInsets.fromLTRB(Space.m, Space.xxs, Space.m, Space.xs),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_tool != Tool.fill)
          EDSlider(
            dense: true,
            icon: Icons.line_weight_rounded,
            label: context.tr('canvas.size', 'Size'),
            value: _size,
            min: 1,
            max: 80,
            step: 1,
            valueText: _size.round().toString(),
            onChanged: (v) => setState(() => _size = v),
          ),
        if (_tool != Tool.eraser)
          EDSlider(
            dense: true,
            icon: Icons.opacity_rounded,
            label: context.tr('ov.opacity', 'Opacity'),
            value: _opacity,
            min: 0.05,
            max: 1,
            valueText: pctText(_opacity),
            onChanged: (v) => setState(() => _opacity = v),
          ),
        if (!compact)
          SizedBox(
            height: Sizes.touch,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: swatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.xxs),
              itemBuilder: (c, i) {
                final col = Color(swatches[i]);
                final sel = col.toARGB32() == _color.toARGB32();
                return Pressable(
                  onTap: () => setState(() {
                    _color = col;
                    if (_tool == Tool.eraser) _tool = Tool.pen;
                  }),
                  selected: sel,
                  semanticLabel: hexOf(col),
                  excludeChildSemantics: true,
                  borderRadius: Radii.controlR,
                  builder: (context, s) => SizedBox(
                    width: Sizes.touch,
                    height: Sizes.touch,
                    child: Center(
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        width: sel ? 38 : 32,
                        height: sel ? 38 : 32,
                        decoration: BoxDecoration(
                          color: col,
                          borderRadius: Radii.controlR,
                          border: Border.all(color: sel ? (p.isDark ? p.accent : p.accentText) : _ringFor(col, p), width: sel ? 3 : 1),
                        ),
                        child: sel ? Icon(Icons.check_rounded, size: 16, color: col.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  /// Outline colour for a swatch: dark inks on the dark UI (and light
  /// colours on the light UI) get a contrasting ring so they stay visible.
  Color _ringFor(Color c, EDPalette p) {
    final l = c.computeLuminance();
    if (p.isDark && l < 0.08) return p.textMuted;
    if (!p.isDark && l > 0.85) return p.borderStrong;
    return p.border;
  }

  String pctText(double v) => '${(v * 100).round()}%';

  Future<void> _pickColor() async {
    final c = await showColorPicker(context, _color);
    if (c != null && mounted) {
      setState(() {
        _color = c;
        if (_tool == Tool.eraser) _tool = Tool.pen;
      });
    }
  }

  Future<void> _rename() async {
    final t = await promptText(context, title: context.tr('art.rename', 'Rename'), initial: _title, confirmLabel: context.tr('common.save', 'Save'));
    if (t == null || t.trim().isEmpty || !mounted) return;
    setState(() => _title = t.trim());
    if (_project != null) await _art.rename(_project!, _title);
  }

  Future<void> _showMore() async {
    final choice = await showEDSheet<String>(
      context,
      title: context.tr('art.more', 'More options'),
      builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EDGroup(children: [
          EDListRow(icon: Icons.layers_outlined, title: context.tr('canvas.layers', 'Layers'), subtitle: _activeLayer.name, chevron: true, onTap: () => Navigator.pop(c, 'layers')),
          EDListRow(icon: Icons.ios_share_rounded, title: context.tr('canvas.export', 'Export / share'), chevron: true, onTap: () => Navigator.pop(c, 'export')),
        ]),
        EDGroup(title: context.tr('canvas.view', 'View & project'), children: [
          EDListRow(icon: Icons.fit_screen_outlined, title: context.tr('canvas.fit', 'Fit to screen'), onTap: () => Navigator.pop(c, 'fit')),
          EDListRow(icon: Icons.drive_file_rename_outline_rounded, title: context.tr('art.rename', 'Rename'), onTap: () => Navigator.pop(c, 'rename')),
        ]),
        EDGroup(title: context.tr('canvas.danger', 'Careful'), children: [
          EDListRow(icon: Icons.delete_sweep_outlined, destructive: true, title: context.tr('canvas.clear', 'Clear layer'), subtitle: _activeLayer.name, onTap: () => Navigator.pop(c, 'clear')),
        ]),
      ]),
    );
    if (!mounted) return;
    switch (choice) {
      case 'layers':
        _showLayers();
      case 'export':
        _showExport();
      case 'clear':
        _clearLayer();
      case 'fit':
        _fit();
      case 'rename':
        _rename();
    }
  }

  // -------------------------------------------------------------- layers UI

  Future<void> _showLayers() async {
    await showEDSheet<void>(
      context,
      title: context.tr('canvas.layers', 'Layers'),
      subtitle: _coloring
          ? context.tr('canvas.coloringHint', 'The outline stays on top and can’t be painted over. Color on the layers below it.')
          : context.tr('canvas.layersHint', 'Top of the list is drawn on top. The reference layer is a guide and isn’t exported unless you turn it on.'),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void upd(VoidCallback f, {CanvasLayer? dirty, bool meta = true}) {
          setState(f);
          setSheet(() {});
          _repaint.ping();
          if (meta) _changed(dirty);
        }

        final paintCount = _layers.where((l) => l.editable).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EDButton.secondary(
            icon: Icons.add_rounded,
            label: context.tr('canvas.addLayer', 'Add layer'),
            onPressed: paintCount >= 8
                ? null
                : () => upd(() {
                      final l = _newPaintLayer(context.trf('canvas.layerN', 'Layer {n}', {'n': paintCount + 1}));
                      // Insert above the active layer but below a protected outline.
                      var at = _active + 1;
                      final outline = _layers.indexWhere((x) => x.kind == LayerKind.outline);
                      if (outline >= 0 && at > outline) at = outline;
                      _layers.insert(at, l);
                      _active = at;
                    }),
          ),
          const SizedBox(height: Space.s),
          for (var i = _layers.length - 1; i >= 0; i--) ...[
            _layerTile(ctx, i, upd),
            const SizedBox(height: Space.xs),
          ],
        ]);
      }),
    );
  }

  Widget _layerTile(BuildContext ctx, int i, void Function(VoidCallback, {CanvasLayer? dirty, bool meta}) upd) {
    final l = _layers[i];
    final p = ctx.ds;
    final t = ctx.text;
    final selected = i == _active;
    final canUp = l.editable && i + 1 < _layers.length && _layers[i + 1].editable;
    final canDown = l.editable && i - 1 >= 0 && _layers[i - 1].editable;
    final subtitle = switch (l.kind) {
      LayerKind.paint => selected ? context.tr('canvas.activeLayer', 'Drawing on this layer') : context.tr('canvas.paintLayer', 'Drawing layer'),
      LayerKind.outline => context.tr('canvas.protectedLayer', 'Protected outline'),
      LayerKind.reference => context.tr('canvas.refLayer', 'Reference guide'),
    };
    return EDCard(
      selected: selected,
      onTap: l.editable ? () => upd(() => _active = i, meta: false) : null,
      semanticLabel: '${l.name}, $subtitle',
      child: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xxs, Space.xxs, Space.xxs, 0),
          child: Row(children: [
            EDIconButton(
              icon: l.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              tooltip: l.visible ? context.tr('canvas.hideLayer', 'Hide layer') : context.tr('canvas.showLayer', 'Show layer'),
              toggle: true,
              selected: !l.visible,
              onPressed: () => upd(() => l.visible = !l.visible),
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
                Text(subtitle, style: t.caption.copyWith(color: selected ? p.accentText : p.textMuted)),
              ]),
            ),
            if (l.editable)
              EDIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: context.trf('canvas.layerActions', '{name} options', {'name': l.name}),
                onPressed: () async {
                  final a = await showEDSheet<String>(
                    ctx,
                    title: l.name,
                    builder: (c) => EDGroup(children: [
                      if (canUp) EDListRow(icon: Icons.arrow_upward_rounded, title: context.tr('canvas.moveUp', 'Move up'), onTap: () => Navigator.pop(c, 'up')),
                      if (canDown) EDListRow(icon: Icons.arrow_downward_rounded, title: context.tr('canvas.moveDown', 'Move down'), onTap: () => Navigator.pop(c, 'down')),
                      EDListRow(icon: Icons.drive_file_rename_outline_rounded, title: context.tr('art.rename', 'Rename'), onTap: () => Navigator.pop(c, 'rename')),
                      if (_layers.where((x) => x.editable).length > 1)
                        EDListRow(icon: Icons.delete_outline_rounded, destructive: true, title: context.tr('common.delete', 'Delete'), onTap: () => Navigator.pop(c, 'delete')),
                    ]),
                  );
                  if (!ctx.mounted) return;
                  switch (a) {
                    case 'up':
                      upd(() {
                        _layers.removeAt(i);
                        _layers.insert(i + 1, l);
                        if (_active == i) _active = i + 1;
                      });
                    case 'down':
                      upd(() {
                        _layers.removeAt(i);
                        _layers.insert(i - 1, l);
                        if (_active == i) _active = i - 1;
                      });
                    case 'rename':
                      final nt = await promptText(ctx, title: ctx.tr('art.rename', 'Rename'), initial: l.name, confirmLabel: ctx.tr('common.save', 'Save'));
                      if (nt != null && nt.trim().isNotEmpty) upd(() => l.name = nt.trim());
                    case 'delete':
                      final ok = await confirmDialog(ctx,
                          title: ctx.tr('canvas.deleteLayerTitle', 'Delete this layer?'),
                          message: ctx.tr('canvas.deleteLayerBody', 'Its drawing will be removed. This can’t be undone.'),
                          confirmLabel: ctx.tr('common.delete', 'Delete'),
                          destructive: true);
                      if (ok) {
                        upd(() {
                          _layers.removeAt(i);
                          _undo.removeWhere((e) => e.layer == l);
                          _redo.removeWhere((e) => e.layer == l);
                          final idx = _layers.lastIndexWhere((x) => x.editable);
                          _active = idx < 0 ? 0 : idx;
                        });
                        _removeLayerFile(l);
                      }
                  }
                },
              )
            else
              Padding(
                padding: const EdgeInsets.all(Space.s),
                child: Icon(Icons.lock_outline_rounded, color: p.textMuted, semanticLabel: context.tr('canvas.protectedLayer', 'Protected outline')),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.xs),
          child: EDSlider(
            dense: true,
            label: context.tr('ov.opacity', 'Opacity'),
            value: l.opacity,
            min: 0,
            max: 1,
            valueText: pctText(l.opacity),
            onChanged: (v) => upd(() => l.opacity = v, meta: false),
            onChangeEnd: (_) => _changed(null),
          ),
        ),
        if (l.kind == LayerKind.reference)
          EDSwitchRow(title: context.tr('canvas.includeRef', 'Include in export'), value: l.exportable, onChanged: (v) => upd(() => l.exportable = v)),
      ]),
    );
  }

  Future<void> _removeLayerFile(CanvasLayer l) async {
    if (_project == null) return;
    try {
      final f = File(p.join(_art.projectDir(_project!).path, 'layer_${l.id}.png'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ----------------------------------------------------------------- export

  Future<void> _showExport() async {
    final choice = await showEDSheet<String>(
      context,
      title: context.tr('canvas.export', 'Export / share'),
      subtitle: context.tr('canvas.exportHint', 'No watermark is ever added.'),
      builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EDGroup(title: context.tr('export.toPhotos', 'Save to Photos'), children: [
          EDListRow(icon: Icons.image_outlined, title: context.tr('export.png', 'Save to Photos as PNG'), subtitle: context.tr('export.pngHint', 'Best quality, keeps transparency'), onTap: () => Navigator.pop(c, 'png')),
          EDListRow(icon: Icons.photo_outlined, title: context.tr('export.jpeg', 'Save to Photos as JPEG'), subtitle: context.tr('export.jpegHint', 'Smaller file, white background'), onTap: () => Navigator.pop(c, 'jpg')),
        ]),
        EDGroup(title: context.tr('export.other', 'Other'), children: [
          EDListRow(icon: Icons.share_outlined, title: context.tr('common.share', 'Share'), onTap: () => Navigator.pop(c, 'share')),
          EDListRow(icon: Icons.collections_outlined, title: context.tr('canvas.saveCopy', 'Save a copy to My Art'), onTap: () => Navigator.pop(c, 'copy')),
        ]),
      ]),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _busy = true;
      _busyText = context.tr('canvas.exporting', 'Exporting…');
    });
    try {
      final img = await composite(_layers, _doc);
      final png = await encodePng(img);
      final bytes = choice == 'jpg' ? await imageToJpeg(img) : png;
      img.dispose();
      if (choice == 'copy') {
        await _art.addImage(png, type: ArtType.export, title: _title);
        if (mounted) showSnack(context.tr('cap.saved', 'Saved to My Art'));
        return;
      }
      final tmp = await getTemporaryDirectory();
      final dir = Directory(p.join(tmp.path, 'exports'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'easy-draw-${DateTime.now().millisecondsSinceEpoch}.${choice == 'jpg' ? 'jpg' : 'png'}'));
      await file.writeAsBytes(bytes, flush: true);
      if (choice == 'share') {
        await shareFile(file.path, subject: _title);
      } else {
        final r = await saveToGallery(file.path);
        if (!mounted) return;
        switch (r) {
          case GalleryResult.saved:
            showSnack(context.tr('export.saved', 'Saved to your Photos in the “Easy Draw” album.'));
          case GalleryResult.denied:
            showSnack(context.tr('export.denied', 'Photos access was not allowed. You can still share the file instead.'),
                error: true, actionLabel: context.tr('common.share', 'Share'), onAction: () => shareFile(file.path));
          case GalleryResult.noSpace:
            showSnack(context.tr('err.storageFull', 'Your device is out of storage. Free up space and try again — your existing work is safe.'), error: true);
          case GalleryResult.failed:
            showSnack(context.tr('export.failed', 'Export failed. Your original is unchanged.'), error: true);
        }
      }
    } catch (e) {
      if (mounted) showSnack(storageMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.layers,
    required this.active,
    required this.live,
    required this.view,
    required this.doc,
    required Listenable repaint,
    required this.dark,
  }) : super(repaint: repaint);

  final List<CanvasLayer> layers;
  final CanvasLayer? active;
  final StrokeOp? Function() live;
  final (double, Offset) Function() view;
  final Size doc;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final (zoom, pan) = view();
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);
    final docRect = Offset.zero & doc;
    canvas.drawShadow(Path()..addRect(docRect), Colors.black, 6 / zoom, false);
    canvas.drawRect(docRect, Paint()..color = Colors.white);
    canvas.clipRect(docRect);
    final s = live();
    for (final l in layers) {
      if (!l.visible) continue;
      final img = l.cache ?? l.base;
      final paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, l.opacity)
        ..filterQuality = zoom < 1 ? FilterQuality.medium : FilterQuality.low;
      if (identical(l, active) && s != null) {
        canvas.saveLayer(docRect, paint);
        if (img != null) canvas.drawImage(img, Offset.zero, Paint());
        paintStroke(canvas, s);
        canvas.restore();
      } else if (img != null) {
        canvas.drawImage(img, Offset.zero, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
