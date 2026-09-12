/// 하나의 스토리와 그에 속한 모든 에셋을 나타냅니다.
class StoryProject {
  const StoryProject({required this.id, required this.name, required this.description, required this.createdAt, required this.updatedAt});

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
}
