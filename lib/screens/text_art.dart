import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../services/ref_loader.dart';
import '../widgets/common.dart';
import 'nav.dart';

class TraceFont {
  const TraceFont(this.family, this.label, this.scripts);
  final String family;
  final String label;
  final String scripts; // L = Latin, A = Arabic, H = Hebrew
}

/// Bundled fonts (SIL Open Font License, see assets/fonts/OFL-*.txt).
const traceFonts = [
  TraceFont('Fredoka', 'Fredoka', 'LH'),
  TraceFont('Pacifico', 'Pacifico', 'L'),
  TraceFont('Lobster', 'Lobster', 'L'),
  TraceFont('Rubik', 'Rubik', 'LH'),
  TraceFont('SecularOne', 'Secular One', 'LH'),
  TraceFont('Cairo', 'Cairo', 'LA'),
  TraceFont('Amiri', 'Amiri', 'LA'),
  TraceFont('Lalezar', 'Lalezar', 'LA'),
];

class TextArtSpec {
  String text = 'Easy Draw';
  String family = 'Fredoka';
  double size = 96;
  TextAlign align = TextAlign.center;
  double letterSpacing = 0;
  double lineHeight = 1.2;
  bool outline = true;
  double strokeWidth = 3;
  Color color = const Color(0xFF1A1A1A);
  Color? background; // null = transparent
  double rotation = 0;
  bool mirror = false;

  bool get rtl => isRtlText(text);
  bool get arabic => containsArabic(text);

  TextPainter painter() {
    final style = TextStyle(
      fontFamily: family,
      // Ensures Arabic/Hebrew render even with a Latin-only display font.
      fontFamilyFallback: const ['Cairo', 'Rubik'],
      fontSize: size,
      height: lineHeight,
      // Extra spacing would break the joins between Arabic letters.
      letterSpacing: arabic ? 0 : letterSpacing,
      foreground: Paint()
        ..color = color
        ..style = outline ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textAlign: align,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    );
    tp.layout(maxWidth: size * 14);
    return tp;
  }
}

/// Paints the spec centred and fitted inside the canvas.
void paintTextArt(
  Canvas canvas,
  Size size,
  TextArtSpec spec, {
  required bool fit,
}) {
  if (spec.background != null) {
    canvas.drawRect(Offset.zero & size, Paint()..color = spec.background!);
  }
  final tp = spec.painter();
  final w = tp.width, h = tp.height;
  final c = cos(spec.rotation).abs(), s = sin(spec.rotation).abs();
  final bw = w * c + h * s, bh = w * s + h * c;
  final scale = fit
      ? min(size.width * 0.92 / bw, size.height * 0.92 / bh)
      : 1.0;
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(spec.rotation);
  canvas.scale(scale * (spec.mirror ? -1 : 1), scale);
  tp.paint(canvas, Offset(-w / 2, -h / 2));
  canvas.restore();
}

class _TextArtPainter extends CustomPainter {
  _TextArtPainter(this.spec, this.version);
  final TextArtSpec spec;
  final int version;
  @override
  void paint(Canvas canvas, Size size) =>
      paintTextArt(canvas, size, spec, fit: true);
  @override
  bool shouldRepaint(_TextArtPainter old) => old.version != version;
}

Future<ui.Image> renderTextArtImage(TextArtSpec spec) async {
  final tp = spec.painter();
  final c = cos(spec.rotation).abs(), s = sin(spec.rotation).abs();
  final bw = tp.width * c + tp.height * s, bh = tp.width * s + tp.height * c;
  final pad = spec.size * 0.4;
  // Render large enough for crisp tracing (about 2000 px on the long side).
  final k = 2000 / max(bw + pad * 2, bh + pad * 2);
  final w = ((bw + pad * 2) * k).round(), h = ((bh + pad * 2) * k).round();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(k);
  paintTextArt(canvas, Size(w / k, h / k), spec, fit: false);
  return rec.endRecording().toImage(max(1, w), max(1, h));
}

class TextArtScreen extends StatefulWidget {
  const TextArtScreen({super.key, this.pickMode = false});

  /// When true, the screen pops with a [RefSource] instead of offering "Open in…".
  final bool pickMode;

  @override
  State<TextArtScreen> createState() => _TextArtScreenState();
}

class _TextArtScreenState extends State<TextArtScreen> {
  final spec = TextArtSpec();
  late final TextEditingController _text = TextEditingController(
    text: spec.text,
  );
  int _v = 0;
  bool _saving = false;

  static const _palette = [
    Color(0xFF1A1A1A),
    Color(0xFF5B45B8),
    Color(0xFFC81D63),
    Color(0xFFFF4F9A),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF6D4C41),
    Color(0xFFFFFFFF),
  ];
  static const _bgPalette = [
    null,
    Color(0xFFFFFFFF),
    Color(0xFFF1F4EE),
    Color(0xFFE3F5BF),
    Color(0xFFFFF8E1),
    Color(0xFF1A1A1A),
  ];

  @override
  void initState() {
    super.initState();
    // Start with a sample in the interface language (and a font that supports it).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sample = switch (context.lang) {
        'ar' => ('ارسم بسهولة', 'Cairo'),
        'he' => ('מציירים בקלות', 'Fredoka'),
        _ => ('Easy Draw', 'Fredoka'),
      };
      _text.text = sample.$1;
      _set(() {
        spec.text = sample.$1;
        spec.family = sample.$2;
      });
    });
  }

  void _set(VoidCallback f) => setState(() {
    f();
    _v++;
  });

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (spec.text.trim().isEmpty) {
      showSnack(context.tr('text.empty', 'Type some text first.'), error: true);
      return;
    }
    setState(() => _saving = true);
    final art = context.art;
    try {
      final img = await renderTextArtImage(spec);
      final png = await encodePng(img);
      img.dispose();
      final title = spec.text.trim().split('\n').first;
      final item = await art.addImage(
        png,
        type: ArtType.textArt,
        title: title.length > 40 ? '${title.substring(0, 40)}…' : title,
        meta: {'font': spec.family},
      );
      if (!mounted) return;
      setState(() => _saving = false);
      final src = art.sourceFor('art:${item.id}');
      if (src == null) return;
      if (widget.pickMode) {
        Navigator.pop(context, src);
      } else {
        await showUseSheet(context, src);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(storageMessage(context, e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final preview = Padding(
      padding: const EdgeInsets.all(12),
      child: EDCard(
        child: Semantics(
          label: context.trf('text.previewLabel', 'Preview of text: {text}', {
            'text': spec.text,
          }),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (spec.background == null) CustomPaint(painter: _Checker()),
              CustomPaint(painter: _TextArtPainter(spec, _v)),
            ],
          ),
        ),
      ),
    );
    final controls = _controls();
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('tool.text', 'Text Art'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: EDButton(
              compact: true,
              loading: _saving,
              onPressed: _save,
              label: widget.pickMode
                  ? context.tr('text.use', 'Use')
                  : context.tr('common.save', 'Save'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: landscape
                ? Row(
                    children: [
                      Expanded(child: preview),
                      Expanded(child: controls),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.3,
                        child: preview,
                      ),
                      Expanded(child: controls),
                    ],
                  ),
          ),
          if (_saving)
            BusyOverlay(
              message: context.tr('text.rendering', 'Creating text art…'),
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    final cs = Theme.of(context).colorScheme;
    // Fonts that support the script being typed come first.
    final script = spec.arabic ? 'A' : (spec.rtl ? 'H' : 'L');
    final fonts = [
      ...traceFonts.where((f) => f.scripts.contains(script)),
      ...traceFonts.where((f) => !f.scripts.contains(script)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        EDTextField(
          controller: _text,
          minLines: 1,
          maxLines: 4,
          maxLength: 200,
          textDirection: isRtlText(_text.text)
              ? TextDirection.rtl
              : TextDirection.ltr,
          label: context.tr('text.input', 'Your text'),
          hint: context.tr('text.hint', 'Type a name, word or quote'),
          onChanged: (v) => _set(() => spec.text = v),
        ),
        Text(
          context.tr('text.font', 'Font'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: context.scaled(96),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (c, i) {
              final f = fonts[i];
              final sel = spec.family == f.family;
              final sample = [
                if (f.scripts.contains('L')) 'Aa',
                if (f.scripts.contains('A')) 'أب',
                if (f.scripts.contains('H')) 'אב',
              ].join(' ');
              return Semantics(
                selected: sel,
                button: true,
                label:
                    '${f.label}${sel ? ', ${context.tr('common.selected', 'selected')}' : ''}',
                excludeSemantics: true,
                child: Pressable(
                  onTap: () => _set(() => spec.family = f.family),
                  borderRadius: Radii.controlR,
                  builder: (context, state) => Container(
                    width: 104,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sel ? context.ds.elevated : context.ds.surface,
                      borderRadius: Radii.controlR,
                      border: Border.all(
                        color: sel ? context.ds.accentText : context.ds.border,
                        width: sel ? 2.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sample,
                          maxLines: 1,
                          style: TextStyle(fontFamily: f.family, fontSize: 20),
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (sel)
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: cs.primary,
                              ),
                            Flexible(
                              child: Text(
                                f.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        EDSegmented<bool>(
          segments: [
            EDSegment(
              true,
              context.tr('text.outline', 'Outline'),
              icon: Icons.format_color_text_rounded,
            ),
            EDSegment(
              false,
              context.tr('text.filled', 'Filled'),
              icon: Icons.format_bold_rounded,
            ),
          ],
          value: spec.outline,
          onChanged: (v) => _set(() => spec.outline = v),
        ),
        const SizedBox(height: 8),
        EDSlider(
          label: context.tr('text.size', 'Size'),
          value: spec.size,
          min: 24,
          max: 220,
          valueText: '${spec.size.round()}',
          onChanged: (v) => _set(() => spec.size = v),
        ),
        if (spec.outline)
          EDSlider(
            label: context.tr('text.stroke', 'Line width'),
            value: spec.strokeWidth,
            min: 1,
            max: 10,
            valueText: spec.strokeWidth.toStringAsFixed(1),
            onChanged: (v) => _set(() => spec.strokeWidth = v),
          ),
        EDSlider(
          label: context.tr('text.letter', 'Letters'),
          value: spec.letterSpacing,
          min: -4,
          max: 40,
          enabled: !spec.arabic,
          valueText: spec.letterSpacing.toStringAsFixed(0),
          onChanged: (v) => _set(() => spec.letterSpacing = v),
        ),
        if (spec.arabic)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              context.tr(
                'text.arabicSpacing',
                'Letter spacing is off for Arabic so the letters stay connected.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        EDSlider(
          label: context.tr('text.lines', 'Lines'),
          value: spec.lineHeight,
          min: 0.8,
          max: 2.5,
          valueText: spec.lineHeight.toStringAsFixed(1),
          onChanged: (v) => _set(() => spec.lineHeight = v),
        ),
        EDSlider(
          label: context.tr('ov.rotate', 'Rotate'),
          value: spec.rotation,
          min: -pi,
          max: pi,
          valueText: '${(spec.rotation * 180 / pi).round()}°',
          onChanged: (v) => _set(() => spec.rotation = v),
        ),
        const SizedBox(height: 4),
        EDSegmented<TextAlign>(
          segments: [
            EDSegment(
              TextAlign.start,
              context.tr('text.alignStart', 'Align to start'),
              icon: Icons.format_align_left_rounded,
            ),
            EDSegment(
              TextAlign.center,
              context.tr('text.alignCenter', 'Center'),
              icon: Icons.format_align_center_rounded,
            ),
            EDSegment(
              TextAlign.end,
              context.tr('text.alignEnd', 'Align to end'),
              icon: Icons.format_align_right_rounded,
            ),
          ],
          value: spec.align,
          onChanged: (v) => _set(() => spec.align = v),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: EDChip(
            icon: Icons.flip_rounded,
            label: context.tr('text.mirror', 'Mirror'),
            selected: spec.mirror,
            onTap: () => _set(() => spec.mirror = !spec.mirror),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('text.color', 'Text color'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _palette)
              _Swatch(
                color: c,
                selected: spec.color == c,
                onTap: () => _set(() => spec.color = c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('text.bg', 'Background'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _bgPalette)
              _Swatch(
                color: c,
                selected: spec.background == c,
                label: c == null
                    ? context.tr('text.transparent', 'Transparent')
                    : null,
                onTap: () => _set(() => spec.background = c),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color;
    return Semantics(
      button: true,
      selected: selected,
      label:
          label ??
          '#${(c!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: Radii.controlR,
        builder: (context, state) => Container(
          width: Sizes.touch,
          height: Sizes.touch,
          decoration: BoxDecoration(
            borderRadius: Radii.controlR,
            color: c,
            border: Border.all(
              color: selected ? context.ds.accentText : cs.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: c == null
              ? Icon(Icons.block_rounded, color: cs.onSurfaceVariant)
              : selected
              ? Icon(
                  Icons.check_rounded,
                  color: c.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _Checker extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final p = Paint()..color = const Color(0xFFE6EBE9);
    const s = 14.0;
    for (var y = 0.0; y < size.height; y += s) {
      for (
        var x = ((y / s).floor().isEven ? 0.0 : s);
        x < size.width;
        x += s * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => false;
}
