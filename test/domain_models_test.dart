import 'package:flutter_test/flutter_test.dart';
import 'package:story_asset_vault/features/assets/domain/story_asset.dart';

void main() {
  test('에셋 번호는 두 자리 문자열로 표시된다', () {
    final asset = CharacterAsset(
      id: 'asset',
      entityId: 'character',
      number: 3,
      label: '웃음',
      storedPath: '/tmp/image.png',
      originalName: 'image.png',
      importedAt: DateTime.utc(2026),
    );
    expect(asset.formattedNumber, '03');
  });
}
