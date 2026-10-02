import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

class SaveTubeApi {
  static const _cdns = ['cdn405.savetube.vip', 'cdn403.savetube.vip', 'cdn401.savetube.vip'];

  static Future<String?> audioUrl(String videoId) async {
    final fullUrl = 'https://www.youtube.com/watch?v=$videoId';
    for (final cdn in _cdns) {
      try {
        final info = await http
            .post(
              Uri.parse('https://$cdn/v2/info'),
              headers: const {
                'content-type': 'application/json',
                'origin': 'https://yt.savetube.me',
                'user-agent': 'Mozilla/5.0',
              },
              body: jsonEncode({'url': fullUrl}),
            )
            .timeout(const Duration(seconds: 20));
        if (info.statusCode != 200) continue;
        final infoJson = jsonDecode(info.body);
        final encrypted = '${infoJson['data'] ?? ''}';
        if (encrypted.isEmpty) continue;
        final keyData = _decrypt(encrypted);
        final key = '${keyData['key'] ?? ''}';
        if (key.isEmpty) continue;
        final response = await http
            .post(
              Uri.parse('https://$cdn/download'),
              headers: const {
                'content-type': 'application/json',
                'origin': 'https://yt.savetube.me',
              },
              body: jsonEncode({'id': videoId, 'downloadType': 'audio', 'quality': '128', 'key': key}),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final url = '${data['data']?['downloadUrl'] ?? data['downloadUrl'] ?? ''}';
        if (url.isNotEmpty) return url;
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic> _decrypt(String encoded) {
    final all = base64.decode(encoded);
    final iv = all.sublist(0, 16);
    final cipher = all.sublist(16);
    final key = Uint8List.fromList(const [
      0xC5,
      0xD5,
      0x8E,
      0xF6,
      0x7A,
      0x75,
      0x84,
      0xE4,
      0xA2,
      0x9F,
      0x6C,
      0x35,
      0xBB,
      0xC4,
      0xEB,
      0x12,
    ]);
    final cbc = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(cipher.length);
    var offset = 0;
    while (offset < cipher.length) {
      offset += cbc.processBlock(cipher, offset, out, offset);
    }
    var text = utf8.decode(out, allowMalformed: true);
    while (text.endsWith('\u0000')) {
      text = text.substring(0, text.length - 1);
    }
    final cut = text.lastIndexOf('}');
    if (cut >= 0) text = text.substring(0, cut + 1);
    return Map<String, dynamic>.from(jsonDecode(text));
  }
}
