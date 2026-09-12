import '../../features/vault/data/vault_repository.dart';
import '../database/vault_database.dart';
import '../storage/vault_file_store.dart';

/// 애플리케이션에서 공유하는 의존성 묶음입니다.
class AppDependencies {
  const AppDependencies({required this.database, required this.repository});

  final VaultDatabase database;
  final VaultRepository repository;

  void dispose() => database.dispose();
}

/// 앱 시작에 필요한 저장소를 조립합니다.
class AppBootstrap {
  const AppBootstrap._();

  static Future<AppDependencies> initialize() async {
    final database = await VaultDatabase.open();
    final fileStore = VaultFileStore(database.rootDirectory);
    await fileStore.initialize();
    return AppDependencies(
      database: database,
      repository: VaultRepository(database: database, fileStore: fileStore),
    );
  }
}
