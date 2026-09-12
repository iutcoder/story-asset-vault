/// 캐릭터에 1:1로 배정된 이미지 슬롯입니다.
class CharacterAsset {
  const CharacterAsset({required this.id, required this.entityId, required this.number, required this.label, required this.storedPath, required this.originalName, required this.importedAt});

  final String id;
  final String entityId;
  final int number;
  final String label;
  final String storedPath;
  final String originalName;
  final DateTime importedAt;

  String get formattedNumber => number.toString().padLeft(2, '0');
}

/// 배경, 이벤트, 연출처럼 특정 캐릭터에 속하지 않는 이미지입니다.
class CommonAsset {
  const CommonAsset({required this.id, required this.projectId, required this.category, required this.number, required this.label, required this.storedPath, required this.originalName, required this.importedAt});

  final String id;
  final String projectId;
  final String category;
  final int number;
  final String label;
  final String storedPath;
  final String originalName;
  final DateTime importedAt;

  String get formattedNumber => number.toString().padLeft(2, '0');
}
