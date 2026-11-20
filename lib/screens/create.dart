import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'settings_screen.dart';

/// All creation tools. Camera Drawing leads as the main activity; each tool
/// card previews real artwork from the library.
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final p = context.ds;
    final content = context.content;
    RefSource? art(String id) => content.referenceById(id)?.toSource();
    final tools = [
      (Icons.wb_sunny_outlined, context.tr('tool.trace', 'Trace Mode'), context.tr('tool.traceDesc', 'Show a reference on a bright screen and trace it through thin paper.'), art('tulip'), () => openTrace(context)),
      (Icons.add_photo_alternate_outlined, context.tr('tool.import', 'Import Photo'), context.tr('tool.importDesc', 'Use your own photo. Crop, rotate and flip it first.'), art('portrait'), () => importPhotoFlow(context)),
      (Icons.auto_fix_high_outlined, context.tr('tool.sketch', 'Photo to Sketch'), context.tr('tool.sketchDesc', 'Turn a photo into outlines, pencil shading or bold black and white.'), art('lighthouse'), () => photoToSketchFlow(context)),
      (Icons.text_fields_rounded, context.tr('tool.text', 'Text Art'), context.tr('tool.textDesc', 'Type a name or quote and trace beautiful letters. Arabic and Hebrew supported.'), null, () => openTextArt(context)),
      (Icons.brush_outlined, context.tr('tool.canvas', 'Digital Canvas'), context.tr('tool.canvasDesc', 'Draw and color on screen with brushes, layers and undo.'), art('butterfly_color'), () => openCanvas(context)),
    ];
    return Scaffold(
      appBar: EDTopBar(title: context.tr('nav.create', 'Create'), large: true, showBack: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.xl), children: [
        // Lead tool.
        EDCard(
          onTap: () => openCamera(context),
          semanticLabel: context.tr('tool.camera', 'Camera Drawing'),
          color: EDPalette.dark.surface,
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Row(children: [
              SizedBox(
                width: 84,
                height: 84,
                child: ViewfinderCorners(
                  color: EDPalette.dark.accent,
                  length: 14,
                  child: Padding(padding: const EdgeInsets.all(Space.s), child: Icon(Icons.photo_camera_outlined, size: 36, color: EDPalette.dark.text)),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('tool.camera', 'Camera Drawing'), style: t.title.copyWith(color: EDPalette.dark.text)),
                  const SizedBox(height: Space.xxs),
                  Text(context.tr('tool.cameraDesc', 'See a reference over your live camera view and copy it onto paper.'),
                      style: t.bodySm.copyWith(color: EDPalette.dark.textMuted)),
                  const SizedBox(height: Space.s),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
                    decoration: BoxDecoration(color: EDPalette.dark.accent, borderRadius: Radii.controlR),
                    child: Text(context.tr('home.start', 'Start Drawing'), style: t.labelSm.copyWith(color: EDPalette.dark.onAccent)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: Space.l),
        Text(context.tr('create.more', 'More tools').toUpperCase(), style: t.overline),
        const SizedBox(height: Space.xs),
        for (final tool in tools) ...[
          EDCard(
            onTap: tool.$5,
            semanticLabel: tool.$2,
            child: Row(children: [
              SizedBox(
                width: 88,
                height: 88,
                child: tool.$4 != null
                    ? RefThumb(tool.$4!, padding: Space.xs)
                    : ColoredBox(
                        color: p.paper,
                        child: Center(child: Text('Aa', style: TextStyle(fontFamily: 'Fredoka', fontSize: 34, color: EDPalette.light.text))),
                      ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(tool.$1, size: 18, color: p.accentText),
                      const SizedBox(width: Space.xs),
                      Expanded(child: Text(tool.$2, style: t.titleSm)),
                    ]),
                    const SizedBox(height: Space.xxs),
                    Text(tool.$3, style: t.bodySm, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.s),
                child: Icon(context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.textFaint),
              ),
            ]),
          ),
          const SizedBox(height: Space.s),
        ],
        const SizedBox(height: Space.s),
        EDGroup(children: [
          EDListRow(
            icon: Icons.menu_book_outlined,
            title: context.tr('guide.title', 'Drawing setup guide'),
            subtitle: context.tr('guide.subtitle', 'How to place your phone, paper and light'),
            chevron: true,
            onTap: () => push(context, const SetupGuideScreen()),
          ),
        ]),
      ]),
    );
  }
}
