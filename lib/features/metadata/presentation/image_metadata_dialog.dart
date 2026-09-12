import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/novelai_metadata_parser.dart';
import '../data/png_metadata_reader.dart';
import '../domain/image_generation_metadata.dart';

/// 원본 이미지와 생성 메타데이터를 함께 보여주는 열람 창입니다.
class ImageMetadataDialog extends StatefulWidget {
  const ImageMetadataDialog({
    required this.files,
    required this.titles,
    required this.initialIndex,
    super.key,
  });

  /// 현재 캐릭터 또는 공용 분류 안에서 탐색할 이미지 목록입니다.
  final List<File> files;
  final List<String> titles;
  final int initialIndex;

  @override
  State<ImageMetadataDialog> createState() => _ImageMetadataDialogState();
}

class _ImageMetadataDialogState extends State<ImageMetadataDialog> {
  late int _index = widget.initialIndex;
  late Future<ImageGenerationMetadata> _metadata = _load();

  File get _file => widget.files[_index];
  String get _title => widget.titles[_index];
  bool get _hasPrevious => _index > 0;
  bool get _hasNext => _index < widget.files.length - 1;

  Future<ImageGenerationMetadata> _load() async {
    final raw = await const PngMetadataReader().read(_file);
    return const NovelAiMetadataParser().parse(raw);
  }

  void _move(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.files.length) return;
    setState(() {
      _index = next;
      _metadata = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowLeft): _PreviousImageIntent(),
      SingleActivator(LogicalKeyboardKey.arrowRight): _NextImageIntent(),
    },
    child: Actions(
      actions: {
        _PreviousImageIntent: CallbackAction<_PreviousImageIntent>(onInvoke: (_) { _move(-1); return null; }),
        _NextImageIntent: CallbackAction<_NextImageIntent>(onInvoke: (_) { _move(1); return null; }),
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(onPressed: _hasPrevious ? () => _move(-1) : null, tooltip: '이전 이미지 (←)', icon: const Icon(Icons.chevron_left)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Center(child: Text('${_index + 1} / ${widget.files.length}'))),
          IconButton(onPressed: _hasNext ? () => _move(1) : null, tooltip: '다음 이미지 (→)', icon: const Icon(Icons.chevron_right)),
          const SizedBox(width: 12),
          IconButton(onPressed: () => Navigator.pop(context), tooltip: '닫기', icon: const Icon(Icons.close)),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final image = Container(
          color: Colors.black87,
          alignment: Alignment.center,
          child: Stack(fit: StackFit.expand, children: [
            InteractiveViewer(key: ValueKey(_file.path), minScale: .2, maxScale: 8, child: Image.file(_file, fit: BoxFit.contain)),
            Align(alignment: Alignment.centerLeft, child: _ImageArrow(enabled: _hasPrevious, icon: Icons.chevron_left, onPressed: () => _move(-1))),
            Align(alignment: Alignment.centerRight, child: _ImageArrow(enabled: _hasNext, icon: Icons.chevron_right, onPressed: () => _move(1))),
          ]),
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
  ))));
}

class _PreviousImageIntent extends Intent {
  const _PreviousImageIntent();
}

class _NextImageIntent extends Intent {
  const _NextImageIntent();
}

class _ImageArrow extends StatelessWidget {
  const _ImageArrow({required this.enabled, required this.icon, required this.onPressed});
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      tooltip: icon == Icons.chevron_left ? '이전 이미지' : '다음 이미지',
      icon: Icon(icon, size: 32),
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
