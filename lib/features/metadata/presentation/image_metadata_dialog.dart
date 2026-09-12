import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/novelai_metadata_parser.dart';
import '../data/png_metadata_reader.dart';
import '../domain/image_generation_metadata.dart';

/// 원본 이미지와 생성 메타데이터를 함께 보여주는 열람 창입니다.
class ImageMetadataDialog extends StatefulWidget {
  const ImageMetadataDialog({required this.file, required this.title, super.key});

  final File file;
  final String title;

  @override
  State<ImageMetadataDialog> createState() => _ImageMetadataDialogState();
}

class _ImageMetadataDialogState extends State<ImageMetadataDialog> {
  late final Future<ImageGenerationMetadata> _metadata = _load();

  Future<ImageGenerationMetadata> _load() async {
    final raw = await const PngMetadataReader().read(widget.file);
    return const NovelAiMetadataParser().parse(raw);
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: () => Navigator.pop(context), tooltip: '닫기', icon: const Icon(Icons.close))]),
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final image = Container(
          color: Colors.black87,
          alignment: Alignment.center,
          child: InteractiveViewer(minScale: .2, maxScale: 8, child: Image.file(widget.file, fit: BoxFit.contain)),
        );
        final info = FutureBuilder<ImageGenerationMetadata>(
          future: _metadata,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return _MetadataPanel(metadata: snapshot.data!);
          },
        );
        return compact
            ? Column(children: [Expanded(child: image), SizedBox(height: constraints.maxHeight * .48, child: info)])
            : Row(children: [Expanded(flex: 3, child: image), SizedBox(width: 440, child: info)]);
      }),
    ),
  );
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.metadata});
  final ImageGenerationMetadata metadata;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('생성 정보', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      if (metadata.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('읽을 수 있는 NovelAI 메타데이터가 없습니다.\nJPEG·WebP 또는 메타데이터가 제거된 PNG일 수 있습니다.')),
      _PromptBlock(label: 'Base Prompt', value: metadata.basePrompt),
      for (var index = 0; index < metadata.characterPrompts.length; index++) ...[
        const SizedBox(height: 12),
        _PromptBlock(label: 'Character Prompt ${index + 1}', value: metadata.characterPrompts[index]),
      ],
      const SizedBox(height: 12),
      _PromptBlock(label: 'Negative Prompt', value: metadata.negativePrompt),
      if (metadata.parameters.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Wrap(spacing: 24, runSpacing: 12, children: [
          for (final entry in metadata.parameters.entries)
            SizedBox(width: 170, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: Theme.of(context).textTheme.labelMedium), SelectableText(entry.value, style: const TextStyle(fontWeight: FontWeight.w600))])),
        ]),
      ],
    ]),
  );
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: value.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: value)), tooltip: '복사', icon: const Icon(Icons.copy_outlined, size: 19))]),
    Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(10), color: Theme.of(context).colorScheme.surface),
      child: SelectableText(value.isEmpty ? '—' : value),
    ),
  ]);
}

