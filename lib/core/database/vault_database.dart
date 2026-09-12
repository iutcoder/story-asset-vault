import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite 연결과 스키마 생성을 담당합니다.
///
/// SQL이 여러 화면에 흩어지는 것을 막기 위해 DB 생성 책임을 이 클래스에만
/// 둡니다. 정식판은 프로토타입과 별도의 디렉터리와 DB 파일을 사용합니다.
class VaultDatabase {
  VaultDatabase._({required this.connection, required this.rootDirectory});

  static const int schemaVersion = 1;

  final Database connection;
  final Directory rootDirectory;

  /// 정식 앱용 데이터 디렉터리와 DB를 엽니다.
  static Future<VaultDatabase> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'story_asset_vault'));
    await root.create(recursive: true);
    final database = VaultDatabase._(
      connection: sqlite3.open(p.join(root.path, 'vault.sqlite3')),
      rootDirectory: root,
    );
    database._createSchema();
    return database;
  }

  void _createSchema() {
    connection.execute('PRAGMA foreign_keys = ON');
    connection.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    connection.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('character', 'npc')),
        note TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL,
        UNIQUE(project_id, code)
      )
    ''');
    connection.execute('''
      CREATE TABLE IF NOT EXISTS character_assets (
        id TEXT PRIMARY KEY,
        entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
        number INTEGER NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        stored_path TEXT NOT NULL,
        original_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        UNIQUE(entity_id, number)
      )
    ''');
    connection.execute('''
      CREATE TABLE IF NOT EXISTS common_assets (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        category TEXT NOT NULL,
        number INTEGER NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        stored_path TEXT NOT NULL,
        original_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        UNIQUE(project_id, category, number)
      )
    ''');
    connection.execute('CREATE INDEX IF NOT EXISTS idx_entities_project ON entities(project_id)');
    connection.execute('CREATE INDEX IF NOT EXISTS idx_character_assets_entity ON character_assets(entity_id)');
    connection.execute('CREATE INDEX IF NOT EXISTS idx_common_assets_project ON common_assets(project_id)');
    connection.execute('PRAGMA user_version = $schemaVersion');
  }

  void dispose() => connection.dispose();
}
