import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// PNG의 tEXt, zTXt, iTXt 청크를 읽는 작은 메타데이터 리더입니다.
///
/// 이미지 디코더와 무관하게 원본 바이트만 훑으므로 갤러리 썸네일 로딩과 분리해서
/// 사용할 수 있습니다. PNG가 아니거나 손상된 경우 빈 맵을 반환합니다.
class PngMetadataReader {
  const PngMetadataReader();

  static const _signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  Future<Map<String, dynamic>> read(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 8 || !_matches(bytes, 0, _signature)) return const {};
      final result = <String, dynamic>{};
      var offset = 8;
      while (offset + 12 <= bytes.length) {
        final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
        final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
        final start = offset + 8;
        final end = start + length;
        if (end + 4 > bytes.length) break;
        final data = bytes.sublist(start, end);
        if (type == 'tEXt') _readText(data, result);
        if (type == 'zTXt') _readCompressedText(data, result);
        if (type == 'iTXt') _readInternationalText(data, result);
        offset = end + 4;
        if (type == 'IEND') break;
      }
      return result;
    } on Object {
      return const {};
    }
  }

  void _readText(Uint8List data, Map<String, dynamic> result) {
    final zero = data.indexOf(0);
    if (zero <= 0) return;
    _store(result, latin1.decode(data.sublist(0, zero)), latin1.decode(data.sublist(zero + 1)));
  }

  void _readCompressedText(Uint8List data, Map<String, dynamic> result) {
    final zero = data.indexOf(0);
    if (zero <= 0 || zero + 2 > data.length || data[zero + 1] != 0) return;
    final value = utf8.decode(zlib.decode(data.sublist(zero + 2)), allowMalformed: true);
    _store(result, latin1.decode(data.sublist(0, zero)), value);
  }

  void _readInternationalText(Uint8List data, Map<String, dynamic> result) {
    final keywordEnd = data.indexOf(0);
    if (keywordEnd <= 0 || keywordEnd + 3 > data.length) return;
    final compressed = data[keywordEnd + 1] == 1;
    var cursor = keywordEnd + 3;
    final languageEnd = data.indexOf(0, cursor);
    if (languageEnd < 0) return;
    cursor = languageEnd + 1;
    final translatedEnd = data.indexOf(0, cursor);
    if (translatedEnd < 0) return;
    cursor = translatedEnd + 1;
    final payload = data.sublist(cursor);
    final decoded = compressed ? zlib.decode(payload) : payload;
    _store(result, utf8.decode(data.sublist(0, keywordEnd)), utf8.decode(decoded, allowMalformed: true));
  }

  void _store(Map<String, dynamic> result, String key, String value) {
    result[key] = value;
    if (key.toLowerCase() != 'comment') return;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) result.addAll(decoded.map((key, value) => MapEntry('$key', value)));
    } on FormatException {
      // 일부 생성기는 Comment에 일반 문자열을 기록합니다. 원문은 이미 보존했습니다.
    }
  }

  static bool _matches(Uint8List bytes, int offset, List<int> expected) {
    for (var i = 0; i < expected.length; i++) {
      if (bytes[offset + i] != expected[i]) return false;
    }
    return true;
  }
}

