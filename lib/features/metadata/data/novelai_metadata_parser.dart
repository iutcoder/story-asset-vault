import '../domain/image_generation_metadata.dart';

/// PNG에서 꺼낸 느슨한 맵을 NovelAI 4/4.5 계열 표시 모델로 변환합니다.
class NovelAiMetadataParser {
  const NovelAiMetadataParser();

  ImageGenerationMetadata parse(Map<String, dynamic> source) {
    final v4Prompt = _map(source['v4_prompt']);
    final caption = _map(v4Prompt['caption']);
    final negativeV4 = _map(source['v4_negative_prompt']);
    final negativeCaption = _map(negativeV4['caption']);
    final characters = <String>[];
    final entries = caption['char_captions'];
    if (entries is List) {
      for (final entry in entries.take(6)) {
        final value = _map(entry)['char_caption']?.toString().trim() ?? '';
        if (value.isNotEmpty) characters.add(value);
      }
    }

    final width = _value(source, ['width']);
    final height = _value(source, ['height']);
    final parameters = <String, String>{
      'Model': _value(source, ['model', 'model_name']),
      'Seed': _value(source, ['seed']),
      'Size': width.isNotEmpty && height.isNotEmpty ? '$width × $height' : '',
      'Steps': _value(source, ['steps']),
      'CFG': _value(source, ['scale', 'cfg']),
      'Rescale': _value(source, ['cfg_rescale', 'guidance_rescale']),
      'Sampler': _value(source, ['sampler']),
      'Scheduler': _value(source, ['noise_schedule', 'scheduler']),
      'SMEA': _flag(source['sm'], fallback: source['smea']),
      'Quality Tags': _flag(source['qualityToggle']),
      'UC Preset': _value(source, ['ucPreset', 'uc_preset']),
      'Variety+': _flag(source['dynamic_thresholding']),
    }..removeWhere((_, value) => value.isEmpty);

    return ImageGenerationMetadata(
      basePrompt: _first([caption['base_caption'], source['prompt'], source['Description']]),
      characterPrompts: characters,
      negativePrompt: _first([negativeCaption['base_caption'], source['negative_prompt'], source['uc']]),
      parameters: parameters,
      raw: source,
    );
  }

  Map<String, dynamic> _map(Object? value) => value is Map
      ? value.map((key, value) => MapEntry('$key', value))
      : const {};

  String _value(Map<String, dynamic> source, List<String> keys) =>
      _first(keys.map((key) => source[key]));

  String _first(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _flag(Object? value, {Object? fallback}) {
    final actual = value ?? fallback;
    if (actual == null) return '';
    if (actual == true || actual == 1) return 'On';
    if (actual == false || actual == 0) return 'Off';
    return '$actual';
  }
}
