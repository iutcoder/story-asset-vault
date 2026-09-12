/// 캐릭터와 NPC를 구분하는 값입니다.
enum EntityKind { character, npc }

/// 프로젝트에 등장하는 캐릭터 또는 NPC입니다.
class StoryEntity {
  const StoryEntity({required this.id, required this.projectId, required this.name, required this.code, required this.kind, required this.note, required this.sortOrder});

  final String id;
  final String projectId;
  final String name;
  final String code;
  final EntityKind kind;
  final String note;
  final int sortOrder;
}
