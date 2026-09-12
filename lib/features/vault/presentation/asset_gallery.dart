import 'dart:io';

import 'package:flutter/material.dart';

import '../../assets/domain/story_asset.dart';
import '../../entities/domain/story_entity.dart';
import '../../metadata/presentation/image_metadata_dialog.dart';
import '../application/vault_controller.dart';

/// 등록 기능과 분리된 읽기 전용 에셋 갤러리입니다.
class AssetGallery extends StatelessWidget {
  const AssetGallery({required this.controller, super.key});
  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    final entity = controller.selectedEntity;
    final characterAssets = entity == null ? const <CharacterAsset>[] : controller.characterAssetsFor(entity);
    final commonAssets = controller.snapshot.commonAssets;
    final title = controller.showingCommonAssets ? '공용 에셋' : entity == null ? '에셋 열람' : '${entity.code} · ${entity.name}';
    final count = controller.showingCommonAssets ? commonAssets.length : characterAssets.length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        Text('$count개 이미지 · 이미지를 선택하면 원본과 생성 정보를 엽니다.'),
        const SizedBox(height: 16),
        Expanded(child: count == 0
            ? const Center(child: Text('열람할 이미지가 없습니다.'))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, childAspectRatio: .78, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: count,
                itemBuilder: (context, index) => controller.showingCommonAssets
                    ? _commonCard(context, commonAssets, index)
                    : _characterCard(context, entity!, characterAssets, index),
              )),
      ]),
    );
  }

  Widget _characterCard(BuildContext context, StoryEntity entity, List<CharacterAsset> assets, int index) {
    final asset = assets[index];
    return _GalleryCard(
    file: File(asset.storedPath),
    badge: '${entity.code}/${asset.formattedNumber}',
    label: asset.label,
    subtitle: entity.kind == EntityKind.npc ? 'NPC · ${entity.name}' : entity.name,
    onTap: () => _open(
      context,
      assets.map((item) => File(item.storedPath)).toList(),
      assets.map((item) => '${entity.code}/${item.formattedNumber} · ${item.label}').toList(),
      index,
    ),
  );
  }

  Widget _commonCard(BuildContext context, List<CommonAsset> assets, int index) {
    final asset = assets[index];
    return _GalleryCard(
    file: File(asset.storedPath),
    badge: asset.formattedNumber,
    label: asset.label,
    subtitle: asset.category,
    onTap: () => _open(
      context,
      assets.map((item) => File(item.storedPath)).toList(),
      assets.map((item) => '${item.category}/${item.formattedNumber} · ${item.label}').toList(),
      index,
    ),
  );
  }

  void _open(BuildContext context, List<File> files, List<String> titles, int initialIndex) => showDialog<void>(
    context: context,
    builder: (_) => ImageMetadataDialog(files: files, titles: titles, initialIndex: initialIndex),
  );
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.file, required this.badge, required this.label, required this.subtitle, required this.onTap});
  final File file;
  final String badge;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: Image.file(file, fit: BoxFit.cover, cacheWidth: 480)),
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)), child: Text(badge, style: Theme.of(context).textTheme.labelMedium)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)])),
        const Icon(Icons.open_in_full, size: 18),
      ])),
    ])),
  );
}
