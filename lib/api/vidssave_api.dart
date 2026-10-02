import 'dart:convert';
import 'package:http/http.dart' as http;

class VidsSaveApi {
  static Future<String?> audioUrl(String videoId) async {
    final link = 'https://www.youtube.com/watch?v=$videoId';
    try {
      final response = await http
          .post(
            Uri.parse('https://api.vidssave.com/api/contentsite_api/media/parse'),
            headers: const {
              'content-type': 'application/x-www-form-urlencoded',
              'origin': 'https://vidssave.com',
              'referer': 'https://vidssave.com/',
              'user-agent': 'Mozilla/5.0',
              'accept': 'application/json, text/plain, */*',
            },
            body: {
              'auth': '20250901majwlqo',
              'domain': 'api-ak.vidssave.com',
              'origin': 'source',
              'link': link,
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = _readJson(response.body);
      final resources = data?['data']?['resources'];
      if (resources is! List) return null;
      for (final resource in resources) {
        if (resource is Map && '${resource['type'] ?? ''}' == 'audio') {
          final quality = '${resource['quality'] ?? ''}'.toUpperCase();
          final url = '${resource['download_url'] ?? ''}';
          if (quality == '128KBPS' && url.isNotEmpty) return url;
        }
      }
      for (final resource in resources) {
        if (resource is Map && '${resource['type'] ?? ''}' == 'audio') {
          final url = '${resource['download_url'] ?? ''}';
          if (url.isNotEmpty) return url;
        }
      }
    } catch (_) {}
    return null;
  }

  static dynamic _readJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
}
