import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 원본 이미지 복사와 앱 휴지통 이동을 담당합니다.
///
/// DB는 파일의 위치만 기억하며 실제 파일 조작은 이 클래스에서만 수행합니다.
/// 따라서 향후 NAS나 사용자가 지정한 보관소로 변경할 때 이 모듈만 교체하면 됩니다.
class VaultFileStore {
  VaultFileStore(this.rootDirectory);

  final Directory rootDirectory;
  final Uuid _uuid = const Uuid();

  Directory get originalsDirectory => Directory(p.join(rootDirectory.path, 'originals'));
  Directory get trashDirectory => Directory(p.join(rootDirectory.path, 'trash'));

  Future<void> initialize() async {
    await originalsDirectory.create(recursive: true);
    await trashDirectory.create(recursive: true);
  }

  /// [source]를 프로젝트별 원본 디렉터리에 복사하고 새 경로를 반환합니다.
  Future<String> importOriginal({required String projectId, required File source}) async {
    final extension = p.extension(source.path).toLowerCase();
    final directory = Directory(p.join(originalsDirectory.path, projectId));
    await directory.create(recursive: true);
    final destination = p.join(directory.path, '${_uuid.v4()}$extension');
    await source.copy(destination);
    return destination;
  }

  /// 삭제 대상 원본을 복구 가능한 앱 휴지통으로 이동합니다.
  Future<void> moveToTrash(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return;
    final destination = p.join(
      trashDirectory.path,
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}',
    );
    await source.rename(destination);
  }
}
