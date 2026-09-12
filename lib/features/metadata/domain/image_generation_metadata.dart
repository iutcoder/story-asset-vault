/// 이미지에 기록된 NovelAI 생성 정보를 화면에서 사용하기 쉬운 형태로 정리합니다.
class ImageGenerationMetadata {
  const ImageGenerationMetadata({
    required this.basePrompt,
    required this.characterPrompts,
    required this.negativePrompt,
    required this.parameters,
    required this.raw,
  });

  final String basePrompt;
  final List<String> characterPrompts;
  final String negativePrompt;
  final Map<String, String> parameters;
  final Map<String, dynamic> raw;

  bool get isEmpty =>
      basePrompt.isEmpty &&
      characterPrompts.isEmpty &&
      negativePrompt.isEmpty &&
      parameters.isEmpty;
}

