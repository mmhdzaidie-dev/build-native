import '../models/song.dart';
import 'download_api.dart';
import 'lyrics_api.dart';
import 'youtube_api.dart';

class ZeiaApi {
  static Future<List<Song>> search(String query) => YoutubeApi.search(query);
  static Future<List<String>> suggestions(String query) => YoutubeApi.suggestions(query);
  static Future<List<LyricLine>> lyrics(Song song) => LyricsApi.get(song);
  static Future<String?> audioUrl(String videoId, {bool forceRefresh = false}) => DownloadApi.audioUrl(videoId, forceRefresh: forceRefresh);
}
