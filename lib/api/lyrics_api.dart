import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class LyricsApi {
  static Future<List<LyricLine>> get(Song song) async {
    var title = _cleanTitle(song.title);
    var artist = _cleanArtist(song.artist);
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length > 1 && artist.isEmpty) {
        artist = parts.first.trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }
    final queries = <String>{};
    if (title.isNotEmpty && artist.isNotEmpty) queries.add('$title $artist');
    if (title.isNotEmpty) queries.add(title);
    if (song.title.isNotEmpty) queries.add(_cleanTitle(song.title));
    for (final query in queries) {
      try {
        final response = await http
            .get(
              Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}'),
              headers: const {'User-Agent': 'ZEIA/1.0'},
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data is! List || data.isEmpty) continue;
        Map<String, dynamic>? best;
        for (final value in data) {
          if (value is Map<String, dynamic> && '${value['syncedLyrics'] ?? ''}'.trim().isNotEmpty) {
            best = value;
            break;
          }
        }
        best ??= data.first is Map<String, dynamic> ? data.first as Map<String, dynamic> : null;
        if (best == null) continue;
        final synced = '${best['syncedLyrics'] ?? ''}';
        if (synced.trim().isNotEmpty) {
          final lines = parse(synced);
          if (lines.isNotEmpty) return lines;
        }
        final plain = '${best['plainLyrics'] ?? ''}';
        if (plain.trim().isNotEmpty) {
          return plain
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .map((line) => LyricLine(-1, line))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static List<LyricLine> parse(String value) {
    final result = <LyricLine>[];
    final regex = RegExp(r'\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]\s*(.*)');
    for (final raw in value.split('\n')) {
      final match = regex.firstMatch(raw.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fractionRaw = match.group(3);
      final fraction = fractionRaw == null
          ? 0.0
          : fractionRaw.length == 3
              ? int.parse(fractionRaw) / 1000.0
              : int.parse(fractionRaw) / 100.0;
      final text = match.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      result.add(LyricLine(minutes * 60 + seconds + fraction, text));
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  static String _cleanTitle(String value) => value
      .replaceAll(RegExp(r'\(.*?(official|lyric|video|audio|mv|visualizer).*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[.*?(official|lyric|video|audio|mv|visualizer).*?\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'Official\s*Music\s*Video|Official\s*Video|Official\s*Audio|Lyric\s*Video|Full\s*Audio', caseSensitive: false), '')
      .replaceAll(RegExp(r'f(ea)?t\..*', caseSensitive: false), '')
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _cleanArtist(String value) => value.replaceAll(RegExp(r'- Topic', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}
