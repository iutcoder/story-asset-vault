import 'package:flutter_test/flutter_test.dart';
import 'package:story_asset_vault/features/metadata/data/novelai_metadata_parser.dart';

void main() {
  test('NAI 4.5 캐릭터 프롬프트는 최대 여섯 개까지 순서대로 읽는다', () {
    final metadata = const NovelAiMetadataParser().parse({
      'v4_prompt': {
        'caption': {
          'base_caption': 'masterpiece, two girls',
          'char_captions': List.generate(7, (index) => {'char_caption': 'character ${index + 1}'}),
        },
      },
      'v4_negative_prompt': {'caption': {'base_caption': 'lowres'}},
      'seed': 1234,
      'steps': 28,
      'width': 1216,
      'height': 832,
    });

    expect(metadata.basePrompt, 'masterpiece, two girls');
    expect(metadata.characterPrompts, hasLength(6));
    expect(metadata.characterPrompts.last, 'character 6');
    expect(metadata.negativePrompt, 'lowres');
    expect(metadata.parameters['Size'], '1216 × 832');
  });

  test('구형 prompt와 uc 키도 대체값으로 사용한다', () {
    final metadata = const NovelAiMetadataParser().parse({'prompt': 'girl', 'uc': 'bad anatomy'});
    expect(metadata.basePrompt, 'girl');
    expect(metadata.negativePrompt, 'bad anatomy');
  });
}
