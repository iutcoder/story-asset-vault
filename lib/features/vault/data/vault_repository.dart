import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/vault_database.dart';
import '../../../core/storage/vault_file_store.dart';
import '../../assets/domain/story_asset.dart';
import '../../entities/domain/story_entity.dart';
import '../../projects/domain/story_project.dart';

/// 프로젝트 한 개를 화면에 표시하기 위한 전체 조회 결과입니다.
class ProjectSnapshot {
  const ProjectSnapshot({required this.entities, required this.characterAssets, required this.commonAssets});

  final List<StoryEntity> entities;
  final List<CharacterAsset> characterAssets;
  final List<CommonAsset> commonAssets;
}

/// SQLite와 원본 보관소를 조합해 앱의 주요 작업을 제공합니다.
///
/// UI는 SQL이나 실제 파일 경로 규칙을 알지 않습니다. 데이터 구조가 바뀌면
/// 이 저장소와 DB 모듈을 수정하고, 화면은 공개 메서드만 계속 사용합니다.
class VaultRepository {
  VaultRepository({required VaultDatabase database, required VaultFileStore fileStore})
      : _database = database,
        _fileStore = fileStore;

  final VaultDatabase _database;
  final VaultFileStore _fileStore;
  final Uuid _uuid = const Uuid();

  List<StoryProject> getProjects() {
    return _database.connection.select('SELECT * FROM projects ORDER BY updated_at DESC').map((row) => StoryProject(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    )).toList();
  }

  StoryProject createProject({required String name, String description = ''}) {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    _database.connection.execute(
      'INSERT INTO projects(id, name, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [id, name.trim(), description.trim(), now.toIso8601String(), now.toIso8601String()],
    );
    return StoryProject(id: id, name: name.trim(), description: description.trim(), createdAt: now, updatedAt: now);
  }

  void updateProject(StoryProject project, {required String name, required String description}) {
    _database.connection.execute(
      'UPDATE projects SET name = ?, description = ?, updated_at = ? WHERE id = ?',
      [name.trim(), description.trim(), DateTime.now().toUtc().toIso8601String(), project.id],
    );
  }

  Future<void> deleteProject(StoryProject project) async {
    final paths = <String>[
      ..._database.connection.select('''SELECT a.stored_path FROM character_assets a
        JOIN entities e ON e.id = a.entity_id WHERE e.project_id = ?''', [project.id]).map((row) => row['stored_path'] as String),
      ..._database.connection.select('SELECT stored_path FROM common_assets WHERE project_id = ?', [project.id]).map((row) => row['stored_path'] as String),
    ];
    for (final path in paths) {
      await _fileStore.moveToTrash(path);
    }
    _database.connection.execute('DELETE FROM projects WHERE id = ?', [project.id]);
  }

  ProjectSnapshot getProjectSnapshot(String projectId) {
    final entities = _database.connection.select(
      'SELECT * FROM entities WHERE project_id = ? ORDER BY sort_order, name', [projectId],
    ).map((row) => StoryEntity(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      name: row['name'] as String,
      code: row['code'] as String,
      kind: row['kind'] == 'npc' ? EntityKind.npc : EntityKind.character,
      note: row['note'] as String,
      sortOrder: row['sort_order'] as int,
    )).toList();
    final assets = _database.connection.select('''SELECT a.* FROM character_assets a
      JOIN entities e ON e.id = a.entity_id WHERE e.project_id = ? ORDER BY a.entity_id, a.number''', [projectId]).map((row) => CharacterAsset(
      id: row['id'] as String,
      entityId: row['entity_id'] as String,
      number: row['number'] as int,
      label: row['label'] as String,
      storedPath: row['stored_path'] as String,
      originalName: row['original_name'] as String,
      importedAt: DateTime.parse(row['imported_at'] as String),
    )).toList();
    final common = _database.connection.select(
      'SELECT * FROM common_assets WHERE project_id = ? ORDER BY category, number', [projectId],
    ).map((row) => CommonAsset(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      category: row['category'] as String,
      number: row['number'] as int,
      label: row['label'] as String,
      storedPath: row['stored_path'] as String,
      originalName: row['original_name'] as String,
      importedAt: DateTime.parse(row['imported_at'] as String),
    )).toList();
    return ProjectSnapshot(entities: entities, characterAssets: assets, commonAssets: common);
  }

  StoryEntity createEntity({required String projectId, required String name, required String code, required EntityKind kind, String note = ''}) {
    final id = _uuid.v4();
    final order = _database.connection.select(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS value FROM entities WHERE project_id = ?', [projectId],
    ).first['value'] as int;
    _database.connection.execute(
      'INSERT INTO entities(id, project_id, name, code, kind, note, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, projectId, name.trim(), code.trim().toUpperCase(), kind.name, note.trim(), order],
    );
    return StoryEntity(id: id, projectId: projectId, name: name.trim(), code: code.trim().toUpperCase(), kind: kind, note: note.trim(), sortOrder: order);
  }

  bool entityCodeExists(String projectId, String code, {String? excludingId}) {
    final normalized = code.trim().toUpperCase();
    final rows = excludingId == null
        ? _database.connection.select('SELECT 1 FROM entities WHERE project_id = ? AND code = ? LIMIT 1', [projectId, normalized])
        : _database.connection.select('SELECT 1 FROM entities WHERE project_id = ? AND code = ? AND id != ? LIMIT 1', [projectId, normalized, excludingId]);
    return rows.isNotEmpty;
  }

  void updateEntity(StoryEntity entity, {required String name, required String code, required EntityKind kind, required String note}) {
    _database.connection.execute(
      'UPDATE entities SET name = ?, code = ?, kind = ?, note = ? WHERE id = ?',
      [name.trim(), code.trim().toUpperCase(), kind.name, note.trim(), entity.id],
    );
  }

  Future<void> deleteEntity(StoryEntity entity) async {
    final paths = _database.connection.select(
      'SELECT stored_path FROM character_assets WHERE entity_id = ?', [entity.id],
    ).map((row) => row['stored_path'] as String).toList();
    for (final path in paths) {
      await _fileStore.moveToTrash(path);
    }
    _database.connection.execute('DELETE FROM entities WHERE id = ?', [entity.id]);
  }

  Future<int> importCharacterAssets({required StoryEntity entity, required Iterable<File> sources}) async {
    var next = _nextCharacterNumber(entity.id);
    var imported = 0;
    for (final source in sources) {
      if (!_isSupportedImage(source.path) || !await source.exists()) continue;
      final storedPath = await _fileStore.importOriginal(projectId: entity.projectId, source: source);
      try {
        _database.connection.execute(
          'INSERT INTO character_assets(id, entity_id, number, label, stored_path, original_name, imported_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [_uuid.v4(), entity.id, next++, p.basenameWithoutExtension(source.path), storedPath, p.basename(source.path), DateTime.now().toUtc().toIso8601String()],
        );
        imported++;
      } catch (_) {
        await _fileStore.moveToTrash(storedPath);
        rethrow;
      }
    }
    return imported;
  }

  void renameCharacterAsset(CharacterAsset asset, String label) {
    _database.connection.execute('UPDATE character_assets SET label = ? WHERE id = ?', [label.trim(), asset.id]);
  }

  void reorderCharacterAssets(String entityId, List<String> orderedIds) {
    final db = _database.connection;
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('UPDATE character_assets SET number = number + 100000 WHERE entity_id = ?', [entityId]);
      for (var index = 0; index < orderedIds.length; index++) {
        db.execute('UPDATE character_assets SET number = ? WHERE id = ? AND entity_id = ?', [index + 1, orderedIds[index], entityId]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> deleteCharacterAsset(CharacterAsset asset) async {
    await _fileStore.moveToTrash(asset.storedPath);
    _database.connection.execute('DELETE FROM character_assets WHERE id = ?', [asset.id]);
    final ids = _database.connection.select(
      'SELECT id FROM character_assets WHERE entity_id = ? ORDER BY number', [asset.entityId],
    ).map((row) => row['id'] as String).toList();
    reorderCharacterAssets(asset.entityId, ids);
  }

  Future<int> importCommonAssets({required String projectId, required String category, required Iterable<File> sources}) async {
    var next = _database.connection.select(
      'SELECT COALESCE(MAX(number), 0) + 1 AS value FROM common_assets WHERE project_id = ? AND category = ?', [projectId, category],
    ).first['value'] as int;
    var imported = 0;
    for (final source in sources) {
      if (!_isSupportedImage(source.path) || !await source.exists()) continue;
      final storedPath = await _fileStore.importOriginal(projectId: projectId, source: source);
      _database.connection.execute(
        'INSERT INTO common_assets(id, project_id, category, number, label, stored_path, original_name, imported_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [_uuid.v4(), projectId, category.trim(), next++, p.basenameWithoutExtension(source.path), storedPath, p.basename(source.path), DateTime.now().toUtc().toIso8601String()],
      );
      imported++;
    }
    return imported;
  }

  void renameCommonAsset(CommonAsset asset, {required String category, required String label}) {
    _database.connection.execute('UPDATE common_assets SET category = ?, label = ? WHERE id = ?', [category.trim(), label.trim(), asset.id]);
  }

  Future<void> deleteCommonAsset(CommonAsset asset) async {
    await _fileStore.moveToTrash(asset.storedPath);
    _database.connection.execute('DELETE FROM common_assets WHERE id = ?', [asset.id]);
  }

  /// 원본 확장자를 유지해 프로젝트 전체를 규칙적인 ZIP으로 내보냅니다.
  Future<File> exportProject({required StoryProject project, required Directory destination}) async {
    final snapshot = getProjectSnapshot(project.id);
    final archive = Archive();
    final index = StringBuffer('type,code,number,label,original\n');
    for (final asset in snapshot.characterAssets) {
      final entity = snapshot.entities.firstWhere((item) => item.id == asset.entityId);
      final bytes = await File(asset.storedPath).readAsBytes();
      final name = '${entity.code}/${asset.formattedNumber}${p.extension(asset.storedPath).toLowerCase()}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      index.writeln('character,${entity.code},${asset.formattedNumber},"${_csv(asset.label)}","${_csv(asset.originalName)}"');
    }
    for (final asset in snapshot.commonAssets) {
      final bytes = await File(asset.storedPath).readAsBytes();
      final category = _safePath(asset.category);
      final name = '_공용/$category/${asset.formattedNumber}${p.extension(asset.storedPath).toLowerCase()}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      index.writeln('common,$category,${asset.formattedNumber},"${_csv(asset.label)}","${_csv(asset.originalName)}"');
    }
    final indexBytes = utf8.encode(index.toString());
    archive.addFile(ArchiveFile('index.csv', indexBytes.length, indexBytes));
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final output = File(p.join(destination.path, '${_safePath(project.name)}_$stamp.zip'));
    await output.writeAsBytes(ZipEncoder().encode(archive)!);
    return output;
  }

  int _nextCharacterNumber(String entityId) => _database.connection.select(
    'SELECT COALESCE(MAX(number), 0) + 1 AS value FROM character_assets WHERE entity_id = ?', [entityId],
  ).first['value'] as int;

  bool _isSupportedImage(String path) => const {'.png', '.jpg', '.jpeg', '.webp'}.contains(p.extension(path).toLowerCase());
  String _safePath(String value) => value.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  String _csv(String value) => value.replaceAll('"', '""');
}
