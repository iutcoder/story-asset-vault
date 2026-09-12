import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../assets/domain/story_asset.dart';
import '../../entities/domain/story_entity.dart';
import '../../projects/domain/story_project.dart';
import '../data/vault_repository.dart';

/// 화면 상태와 사용자 명령을 연결하는 컨트롤러입니다.
///
/// 위젯에서 DB 작업을 직접 하지 않게 하여 UI 교체와 단위 테스트를 쉽게 합니다.
class VaultController extends ChangeNotifier {
  VaultController({required VaultRepository repository}) : _repository = repository;

  final VaultRepository _repository;

  bool isLoading = true;
  bool isExporting = false;
  String? errorMessage;
  List<StoryProject> projects = const [];
  StoryProject? selectedProject;
  ProjectSnapshot snapshot = const ProjectSnapshot(entities: [], characterAssets: [], commonAssets: []);
  StoryEntity? selectedEntity;
  bool showingCommonAssets = false;

  Future<void> initialize() async {
    try {
      projects = _repository.getProjects();
      if (projects.isNotEmpty) selectProject(projects.first);
    } catch (error) {
      errorMessage = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectProject(StoryProject project) {
    selectedProject = project;
    snapshot = _repository.getProjectSnapshot(project.id);
    selectedEntity = snapshot.entities.firstOrNull;
    showingCommonAssets = false;
    notifyListeners();
  }

  void selectEntity(StoryEntity entity) {
    selectedEntity = entity;
    showingCommonAssets = false;
    notifyListeners();
  }

  void showCommonAssets() {
    selectedEntity = null;
    showingCommonAssets = true;
    notifyListeners();
  }

  void createProject(String name, String description) {
    final project = _repository.createProject(name: name, description: description);
    _refreshProjects();
    selectProject(project);
  }

  void updateProject(StoryProject project, String name, String description) {
    _repository.updateProject(project, name: name, description: description);
    _refreshProjects(preferredProjectId: project.id);
  }

  Future<void> deleteProject(StoryProject project) async {
    await _repository.deleteProject(project);
    _refreshProjects();
    if (projects.isEmpty) {
      selectedProject = null;
      selectedEntity = null;
      snapshot = const ProjectSnapshot(entities: [], characterAssets: [], commonAssets: []);
      notifyListeners();
    } else {
      selectProject(projects.first);
    }
  }

  void createEntity(String name, String code, EntityKind kind, String note) {
    final project = selectedProject!;
    final entity = _repository.createEntity(projectId: project.id, name: name, code: code, kind: kind, note: note);
    _refreshSnapshot(preferredEntityId: entity.id);
  }

  void updateEntity(StoryEntity entity, String name, String code, EntityKind kind, String note) {
    _repository.updateEntity(entity, name: name, code: code, kind: kind, note: note);
    _refreshSnapshot(preferredEntityId: entity.id);
  }

  Future<void> deleteEntity(StoryEntity entity) async {
    await _repository.deleteEntity(entity);
    _refreshSnapshot();
  }

  bool codeExists(String code, {String? excludingId}) {
    return _repository.entityCodeExists(selectedProject!.id, code, excludingId: excludingId);
  }

  String suggestCode() {
    final used = snapshot.entities.map((item) => item.code.toUpperCase()).toSet();
    for (var value = 'A'.codeUnitAt(0); value <= 'Y'.codeUnitAt(0); value++) {
      final code = String.fromCharCode(value);
      if (!used.contains(code)) return code;
    }
    return '';
  }

  Future<int> importCharacterAssets(StoryEntity entity, Iterable<File> files) async {
    final count = await _repository.importCharacterAssets(entity: entity, sources: files);
    _refreshSnapshot(preferredEntityId: entity.id);
    return count;
  }

  void renameCharacterAsset(CharacterAsset asset, String label) {
    _repository.renameCharacterAsset(asset, label);
    _refreshSnapshot(preferredEntityId: asset.entityId);
  }

  void moveCharacterAsset(String draggedId, String targetId) {
    final entity = selectedEntity!;
    final assets = characterAssetsFor(entity);
    final oldIndex = assets.indexWhere((item) => item.id == draggedId);
    final targetIndex = assets.indexWhere((item) => item.id == targetId);
    if (oldIndex < 0 || targetIndex < 0 || oldIndex == targetIndex) return;
    final moved = assets.removeAt(oldIndex);
    var insertion = assets.indexWhere((item) => item.id == targetId);
    if (oldIndex < targetIndex) insertion++;
    assets.insert(insertion, moved);
    _repository.reorderCharacterAssets(entity.id, assets.map((item) => item.id).toList());
    _refreshSnapshot(preferredEntityId: entity.id);
  }

  Future<void> deleteCharacterAsset(CharacterAsset asset) async {
    await _repository.deleteCharacterAsset(asset);
    _refreshSnapshot(preferredEntityId: asset.entityId);
  }

  Future<int> importCommonAssets(String category, Iterable<File> files) async {
    final count = await _repository.importCommonAssets(projectId: selectedProject!.id, category: category, sources: files);
    _refreshSnapshot(showCommon: true);
    return count;
  }

  void renameCommonAsset(CommonAsset asset, String category, String label) {
    _repository.renameCommonAsset(asset, category: category, label: label);
    _refreshSnapshot(showCommon: true);
  }

  Future<void> deleteCommonAsset(CommonAsset asset) async {
    await _repository.deleteCommonAsset(asset);
    _refreshSnapshot(showCommon: true);
  }

  Future<File> exportProject(Directory destination) {
    return _exportWithProgress(destination);
  }

  Future<File> _exportWithProgress(Directory destination) async {
    isExporting = true;
    notifyListeners();
    try {
      return await _repository.exportProject(project: selectedProject!, destination: destination);
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  List<CharacterAsset> characterAssetsFor(StoryEntity entity) => snapshot.characterAssets.where((item) => item.entityId == entity.id).toList();

  void _refreshProjects({String? preferredProjectId}) {
    projects = _repository.getProjects();
    if (preferredProjectId != null) {
      selectedProject = projects.where((item) => item.id == preferredProjectId).firstOrNull;
      if (selectedProject != null) _refreshSnapshot();
    }
    notifyListeners();
  }

  void _refreshSnapshot({String? preferredEntityId, bool showCommon = false}) {
    snapshot = _repository.getProjectSnapshot(selectedProject!.id);
    showingCommonAssets = showCommon;
    selectedEntity = showCommon ? null : snapshot.entities.where((item) => item.id == (preferredEntityId ?? selectedEntity?.id)).firstOrNull;
    selectedEntity ??= showCommon ? null : snapshot.entities.firstOrNull;
    notifyListeners();
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
