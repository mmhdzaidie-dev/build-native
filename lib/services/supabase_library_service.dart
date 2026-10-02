import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song.dart';
import 'supabase_service.dart';

class SupabaseLibraryService {
  SupabaseClient get client => SupabaseService.client;
  String get userId => client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> fetchPlaylists() async {
    final rows = await client.from('playlists').select('id,name,cover_url,created_at,playlist_songs(song: songs(*))').eq('user_id', userId).order('created_at', ascending: false);
    return rows.map((row) {
      final data = Map<String, dynamic>.from(row);
      final relations = data.remove('playlist_songs');
      final songs = <Map<String, dynamic>>[];
      if (relations is List) {
        for (final item in relations.whereType<Map>()) {
          final song = item['song'];
          if (song is Map) songs.add(Map<String, dynamic>.from(song));
        }
      }
      return {'id': '${data['id']}', 'name': '${data['name'] ?? 'Playlist'}', 'coverUrl': '${data['cover_url'] ?? ''}', 'songs': songs};
    }).toList();
  }

  Future<List<Song>> fetchLiked() async {
    final rows = await client.from('liked_songs').select('song:songs(*)').eq('user_id', userId).order('created_at', ascending: false);
    return rows.whereType<Map>().map((row) {
      final song = row['song'];
      return song is Map ? Song.fromJson(Map<String, dynamic>.from(song)) : null;
    }).whereType<Song>().toList();
  }

  Future<List<Song>> fetchRecentlyPlayed() async {
    final rows = await client.from('recently_played').select('played_at,song:songs(*)').eq('user_id', userId).order('played_at', ascending: false).limit(12);
    return rows.whereType<Map>().map((row) {
      final song = row['song'];
      return song is Map ? Song.fromJson(Map<String, dynamic>.from(song)) : null;
    }).whereType<Song>().toList();
  }

  Future<void> createPlaylist(String name, {String? coverPath}) async {
    String? coverUrl;
    if (coverPath != null && coverPath.isNotEmpty) coverUrl = await uploadPlaylistCover(coverPath);
    await client.from('playlists').insert({'user_id': userId, 'name': name.trim(), 'cover_url': coverUrl});
  }

  Future<void> renamePlaylist(String id, String name) async {
    await client.from('playlists').update({'name': name.trim()}).eq('id', id).eq('user_id', userId);
  }

  Future<void> deletePlaylist(String id) async {
    await client.from('playlists').delete().eq('id', id).eq('user_id', userId);
  }

  Future<void> addToPlaylist(String playlistId, Song song, int position) async {
    await client.from('songs').upsert({'id': song.videoId, 'title': song.title, 'artist': song.artist, 'cover': song.cover, 'duration': song.duration, 'album': song.album, 'album_id': song.albumId, 'artist_id': song.artistId, 'yt_url': song.ytUrl});
    await client.from('playlist_songs').upsert({'playlist_id': playlistId, 'song_id': song.videoId, 'position': position});
  }

  Future<void> removeFromPlaylist(String playlistId, String videoId) async {
    await client.from('playlist_songs').delete().eq('playlist_id', playlistId).eq('song_id', videoId);
  }

  Future<void> toggleLike(Song song, bool liked) async {
    await client.from('songs').upsert({'id': song.videoId, 'title': song.title, 'artist': song.artist, 'cover': song.cover, 'duration': song.duration, 'album': song.album, 'album_id': song.albumId, 'artist_id': song.artistId, 'yt_url': song.ytUrl});
    if (liked) {
      await client.from('liked_songs').upsert({'user_id': userId, 'song_id': song.videoId});
    } else {
      await client.from('liked_songs').delete().eq('user_id', userId).eq('song_id', song.videoId);
    }
  }

  Future<void> recordPlayed(Song song) async {
    await client.from('songs').upsert({'id': song.videoId, 'title': song.title, 'artist': song.artist, 'cover': song.cover, 'duration': song.duration, 'album': song.album, 'album_id': song.albumId, 'artist_id': song.artistId, 'yt_url': song.ytUrl});
    await client.from('recently_played').upsert({'user_id': userId, 'song_id': song.videoId, 'played_at': DateTime.now().toUtc().toIso8601String()});
  }

  Future<String> uploadPlaylistCover(String path) async {
    final ext = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final objectPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await client.storage.from('playlist-covers').upload(objectPath, File(path), fileOptions: FileOptions(upsert: true, contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
    return client.storage.from('playlist-covers').getPublicUrl(objectPath);
  }

  Future<void> setPlaylistCover(String id, String path) async {
    final url = await uploadPlaylistCover(path);
    await client.from('playlists').update({'cover_url': url}).eq('id', id).eq('user_id', userId);
  }
}
