import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class YoutubeApi {
  static const _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36',
    'Origin': 'https://music.youtube.com',
  };

  static String thumb(String id) => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  static Future<List<Song>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final body = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.00.00',
          'hl': 'en',
          'gl': 'ID',
        }
      },
      'query': query,
    };
    final response = await http
        .post(
          Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('search failed');
    final decoded = jsonDecode(response.body);
    final results = <Song>[];
    final seen = <String>{};

    void walk(dynamic value) {
      if (value is Map) {
        final renderer = value['musicResponsiveListItemRenderer'];
        if (renderer is Map) {
          final columns = renderer['flexColumns'];
          if (columns is List) {
            String columnText(int index) {
              if (index < 0 || index >= columns.length) return '';
              final block = columns[index];
              if (block is! Map) return '';
              final rendererValue = block['musicResponsiveListItemFlexColumnRenderer'];
              if (rendererValue is! Map) return '';
              final text = rendererValue['text'];
              if (text is! Map) return '';
              final runs = text['runs'];
              if (runs is! List) return '';
              return runs.map((run) => run is Map ? '${run['text'] ?? ''}' : '').join();
            }

            final title = columnText(0).trim();
            final subtitle = columnText(1).trim();
            final videoId = '${renderer['playlistItemData']?['videoId'] ?? ''}';
            if (videoId.isNotEmpty && title.isNotEmpty && seen.add(videoId)) {
              results.add(
                Song(
                  title: title,
                  artist: subtitle.split(' • ').first.trim(),
                  videoId: videoId,
                  cover: thumb(videoId),
                  ytUrl: 'https://www.youtube.com/watch?v=$videoId',
                ),
              );
            }
          }
        }
        for (final child in value.values) {
          walk(child);
        }
      } else if (value is List) {
        for (final child in value) {
          walk(child);
        }
      }
    }

    walk(decoded);
    return results.take(30).toList();
  }

  static Future<List<String>> suggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await http
          .get(
            Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(query)}'),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.length > 1 && decoded[1] is List) {
        return (decoded[1] as List).map((value) => '$value').toList();
      }
    } catch (_) {}
    return [];
  }
}
