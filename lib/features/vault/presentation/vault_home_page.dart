import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../assets/domain/story_asset.dart';
import '../../entities/domain/story_entity.dart';
import '../../projects/domain/story_project.dart';
import '../application/vault_controller.dart';

const _imageTypes = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp']);

/// 프로젝트·캐릭터·에셋을 한 창에서 관리하는 메인 화면입니다.
class VaultHomePage extends StatelessWidget {
  const VaultHomePage({required this.controller, super.key});

  final VaultController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (controller.errorMessage != null) return Scaffold(body: Center(child: Text(controller.errorMessage!)));
      return Scaffold(
        appBar: AppBar(
          title: const Text('스토리 에셋 볼트'),
          actions: [
            TextButton.icon(
              onPressed: controller.selectedProject == null ? null : () => _export(context),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('프로젝트 추출'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: controller.selectedProject == null ? _emptyProject(context) : Row(children: [
          SizedBox(width: 280, child: _sidebar(context)),
          const VerticalDivider(width: 1),
          Expanded(child: controller.showingCommonAssets ? _CommonWorkspace(controller: controller) : _CharacterWorkspace(controller: controller)),
        ]),
      );
    },
  );

  Widget _emptyProject(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
    const SizedBox(height: 16),
    Text('첫 프로젝트를 만들어 시작하세요', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8),
    const Text('프로젝트마다 캐릭터 코드와 에셋 번호를 독립적으로 관리합니다.'),
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: () => _projectDialog(context), icon: const Icon(Icons.add), label: const Text('프로젝트 만들기')),
  ]));

  Widget _sidebar(BuildContext context) {
    final project = controller.selectedProject!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true,
            value: project.id,
            items: controller.projects.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (id) => controller.selectProject(controller.projects.firstWhere((item) => item.id == id)),
          ))),
          IconButton(onPressed: () => _projectDialog(context), icon: const Icon(Icons.add), tooltip: '프로젝트 추가'),
          PopupMenuButton<String>(
            tooltip: '프로젝트 메뉴',
            onSelected: (value) => value == 'edit' ? _projectDialog(context, project: project) : _deleteProject(context, project),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('프로젝트 수정')),
              PopupMenuItem(value: 'delete', child: Text('프로젝트 삭제')),
            ],
          ),
        ]),
        const Divider(),
        Row(children: [Expanded(child: Text('캐릭터·NPC', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _entityDialog(context), icon: const Icon(Icons.person_add_alt_1), tooltip: '추가')]),
        Expanded(child: ListView(children: [
          for (final entity in controller.snapshot.entities)
            ListTile(
              selected: controller.selectedEntity?.id == entity.id && !controller.showingCommonAssets,
              leading: CircleAvatar(child: Text(entity.code)),
              title: Text(entity.name),
              subtitle: Text(entity.kind == EntityKind.npc ? 'NPC' : '캐릭터'),
              onTap: () => controller.selectEntity(entity),
              trailing: PopupMenuButton<String>(
                tooltip: '캐릭터 메뉴',
                onSelected: (value) => value == 'edit' ? _entityDialog(context, entity: entity) : _deleteEntity(context, entity),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('이름·코드 수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ),
        ])),
        const Divider(),
        ListTile(
          selected: controller.showingCommonAssets,
          leading: const Icon(Icons.collections_outlined),
          title: const Text('공용 에셋'),
          subtitle: Text('${controller.snapshot.commonAssets.length}개'),
          onTap: controller.showCommonAssets,
        ),
      ]),
    );
  }

  Future<void> _projectDialog(BuildContext context, {StoryProject? project}) async {
    final name = TextEditingController(text: project?.name ?? '');
    final description = TextEditingController(text: project?.description ?? '');
    String? error;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(project == null ? '프로젝트 만들기' : '프로젝트 수정'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: '프로젝트 이름', errorText: error)),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: '설명(선택)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(onPressed: () {
        if (name.text.trim().isEmpty) { update(() => error = '프로젝트 이름을 입력하세요.'); return; }
        Navigator.pop(context, true);
      }, child: const Text('저장'))],
    )));
    if (saved == true) {
      project == null ? controller.createProject(name.text, description.text) : controller.updateProject(project, name.text, description.text);
    }
  }

  Future<void> _entityDialog(BuildContext context, {StoryEntity? entity}) async {
    final name = TextEditingController(text: entity?.name ?? '');
    final code = TextEditingController(text: entity?.code ?? controller.suggestCode());
    final note = TextEditingController(text: entity?.note ?? '');
    var kind = entity?.kind ?? EntityKind.character;
    String? nameError;
    String? codeError;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(entity == null ? '캐릭터 추가' : '캐릭터 수정'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: '이름', errorText: nameError)),
        TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: '추출 코드', helperText: '프로젝트 안에서 중복될 수 없습니다.', errorText: codeError)),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: '메모(선택)')),
        const SizedBox(height: 12),
        SegmentedButton<EntityKind>(segments: const [ButtonSegment(value: EntityKind.character, label: Text('캐릭터')), ButtonSegment(value: EntityKind.npc, label: Text('NPC'))], selected: {kind}, onSelectionChanged: (value) => update(() => kind = value.first)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(onPressed: () {
        final normalized = code.text.trim().toUpperCase();
        final missingName = name.text.trim().isEmpty;
        final missingCode = normalized.isEmpty;
        final duplicate = !missingCode && controller.codeExists(normalized, excludingId: entity?.id);
        if (missingName || missingCode || duplicate) {
          update(() { nameError = missingName ? '이름을 입력하세요.' : null; codeError = missingCode ? '코드를 입력하세요.' : duplicate ? '이미 사용 중인 코드입니다.' : null; });
          return;
        }
        code.text = normalized;
        Navigator.pop(context, true);
      }, child: const Text('저장'))],
    )));
    if (saved == true) {
      entity == null ? controller.createEntity(name.text, code.text, kind, note.text) : controller.updateEntity(entity, name.text, code.text, kind, note.text);
    }
  }

  Future<void> _deleteProject(BuildContext context, StoryProject project) async {
    if (await _confirm(context, '${project.name} 삭제', '프로젝트에 속한 캐릭터와 에셋이 모두 목록에서 제거됩니다. 원본 복사본은 앱 휴지통으로 이동합니다.')) await controller.deleteProject(project);
  }

  Future<void> _deleteEntity(BuildContext context, StoryEntity entity) async {
    if (await _confirm(context, '${entity.name} 삭제', '연결된 이미지가 함께 목록에서 제거되며 원본 복사본은 앱 휴지통으로 이동합니다.')) await controller.deleteEntity(entity);
  }

  Future<void> _export(BuildContext context) async {
    final path = await getDirectoryPath(confirmButtonText: '이 위치에 추출');
    if (path == null) return;
    final file = await controller.exportProject(Directory(path));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP을 만들었습니다: ${file.path}')));
  }
}

class _CharacterWorkspace extends StatefulWidget {
  const _CharacterWorkspace({required this.controller});
  final VaultController controller;
  @override State<_CharacterWorkspace> createState() => _CharacterWorkspaceState();
}

class _CharacterWorkspaceState extends State<_CharacterWorkspace> {
  bool draggingFiles = false;

  @override
  Widget build(BuildContext context) {
    final entity = widget.controller.selectedEntity;
    if (entity == null) return const Center(child: Text('왼쪽에서 캐릭터를 추가하거나 선택하세요.'));
    final assets = widget.controller.characterAssetsFor(entity);
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${entity.code} · ${entity.name}', style: Theme.of(context).textTheme.headlineSmall), Text('${assets.length}개 에셋')])),
        OutlinedButton.icon(onPressed: () => _pickFiles(entity), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('여러 이미지 선택')),
      ]),
      const SizedBox(height: 16),
      DropTarget(
        onDragEntered: (_) => setState(() => draggingFiles = true),
        onDragExited: (_) => setState(() => draggingFiles = false),
        onDragDone: (details) async { setState(() => draggingFiles = false); await _import(entity, details.files.map((item) => File(item.path))); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120), height: 96, width: double.infinity,
          decoration: BoxDecoration(color: draggingFiles ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: draggingFiles ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.move_to_inbox_outlined, size: 32), Text('이미지 여러 장을 여기에 드롭하세요'), Text('가져온 순서대로 번호가 붙습니다.', style: TextStyle(fontSize: 12))]),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(child: assets.isEmpty ? const Center(child: Text('등록된 이미지가 없습니다.')) : GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, childAspectRatio: .75, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: assets.length,
        itemBuilder: (context, index) => DragTarget<String>(
          onWillAcceptWithDetails: (details) => details.data != assets[index].id,
          onAcceptWithDetails: (details) => widget.controller.moveCharacterAsset(details.data, assets[index].id),
          builder: (context, candidates, _) => AnimatedScale(scale: candidates.isEmpty ? 1 : .96, duration: const Duration(milliseconds: 100), child: _assetCard(assets[index])),
        ),
      )),
    ]));
  }

  Widget _assetCard(CharacterAsset asset) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: Image.file(File(asset.storedPath), fit: BoxFit.cover, cacheWidth: 480)),
      Padding(padding: const EdgeInsets.fromLTRB(10, 8, 6, 8), child: Row(children: [
        CircleAvatar(radius: 19, child: Text(asset.formattedNumber, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(onTap: () => _rename(asset), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(asset.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)), Text(asset.originalName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]))),
        Tooltip(message: '드래그해 순서 이동', child: Draggable<String>(data: asset.id, feedback: const Material(elevation: 6, child: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_indicator))), childWhenDragging: const Icon(Icons.drag_indicator, color: Colors.black26), child: const Icon(Icons.drag_indicator))),
        PopupMenuButton<String>(tooltip: '에셋 메뉴', onSelected: (value) => value == 'edit' ? _rename(asset) : _delete(asset), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('이름 수정')), PopupMenuItem(value: 'delete', child: Text('이미지 삭제'))]),
      ])),
    ]),
  );

  Future<void> _pickFiles(StoryEntity entity) async => _import(entity, (await openFiles(acceptedTypeGroups: const [_imageTypes])).map((item) => File(item.path)));
  Future<void> _import(StoryEntity entity, Iterable<File> files) async {
    final count = await widget.controller.importCharacterAssets(entity, files);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count개 이미지를 가져왔습니다.')));
  }
  Future<void> _rename(CharacterAsset asset) async {
    final value = await _textDialog(context, title: '${asset.formattedNumber} 이름 수정', label: '표정·상황 이름', initialValue: asset.label);
    if (value != null) widget.controller.renameCharacterAsset(asset, value);
  }
  Future<void> _delete(CharacterAsset asset) async {
    if (await _confirm(context, '${asset.formattedNumber} · ${asset.label} 삭제', '목록에서 제거한 뒤 번호를 다시 매깁니다. 원본 복사본은 앱 휴지통으로 이동합니다.')) await widget.controller.deleteCharacterAsset(asset);
  }
}

class _CommonWorkspace extends StatelessWidget {
  const _CommonWorkspace({required this.controller});
  final VaultController controller;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [Expanded(child: Text('공용 에셋', style: Theme.of(context).textTheme.headlineSmall)), FilledButton.icon(onPressed: () => _import(context), icon: const Icon(Icons.add), label: const Text('여러 이미지 추가'))]),
    const SizedBox(height: 16),
    Expanded(child: controller.snapshot.commonAssets.isEmpty ? const Center(child: Text('배경·이벤트·연출 에셋을 추가하세요.')) : ListView.builder(itemCount: controller.snapshot.commonAssets.length, itemBuilder: (context, index) {
      final asset = controller.snapshot.commonAssets[index];
      return ListTile(
        leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(asset.storedPath), width: 58, height: 58, fit: BoxFit.cover, cacheWidth: 116)),
        title: Text('${asset.category} / ${asset.formattedNumber} · ${asset.label}'),
        subtitle: Text(asset.originalName),
        trailing: PopupMenuButton<String>(onSelected: (value) => value == 'edit' ? _rename(context, asset) : _delete(context, asset), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('분류·이름 수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))]),
      );
    })),
  ]));

  Future<void> _import(BuildContext context) async {
    final category = await _textDialog(context, title: '공용 에셋 추가', label: '분류', initialValue: '배경');
    if (category == null || category.trim().isEmpty) return;
    final files = await openFiles(acceptedTypeGroups: const [_imageTypes]);
    final count = await controller.importCommonAssets(category, files.map((item) => File(item.path)));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count개 공용 에셋을 가져왔습니다.')));
  }
  Future<void> _rename(BuildContext context, CommonAsset asset) async {
    final category = await _textDialog(context, title: '분류 수정', label: '분류', initialValue: asset.category);
    if (category == null) return;
    if (!context.mounted) return;
    final label = await _textDialog(context, title: '이름 수정', label: '에셋 이름', initialValue: asset.label);
    if (label != null) controller.renameCommonAsset(asset, category, label);
  }
  Future<void> _delete(BuildContext context, CommonAsset asset) async {
    if (await _confirm(context, '${asset.label} 삭제', '원본 복사본은 앱 휴지통으로 이동합니다.')) await controller.deleteCommonAsset(asset);
  }
}

Future<String?> _textDialog(BuildContext context, {required String title, required String label, required String initialValue}) async {
  final input = TextEditingController(text: initialValue);
  return showDialog<String>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: TextField(controller: input, autofocus: true, decoration: InputDecoration(labelText: label), onSubmitted: (_) => Navigator.pop(context, input.text.trim())),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: const Text('저장'))],
  ));
}

Future<bool> _confirm(BuildContext context, String title, String body) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(
  title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('삭제'))],
)) ?? false;
