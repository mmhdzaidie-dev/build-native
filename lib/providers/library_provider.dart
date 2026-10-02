import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song.dart';
import '../services/supabase_service.dart';
import '../services/supabase_library_service.dart';

class LibraryProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  final _remote = SupabaseLibraryService();
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  List<Song> liked = [];
  List<Map<String, dynamic>> playlists = [];
  List<Song> recentlyPlayed = [];
  bool ready = false;
  bool syncing = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocal();
    if (SupabaseService.configured) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((_) => unawaited(_connectRemote()));
      await _connectRemote();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _connectRemote() async {
    if (SupabaseService.client.auth.currentUser == null) return;
    syncing = true;
    notifyListeners();
    try {
      final remotePlaylists = await _remote.fetchPlaylists();
      final remoteLiked = await _remote.fetchLiked();
      final remoteRecent = await _remote.fetchRecentlyPlayed();
      playlists = remotePlaylists;
      liked = remoteLiked;
      recentlyPlayed = remoteRecent;
      await _saveLocal();
      _channel?.unsubscribe();
      _channel = SupabaseService.client.channel('zeia-library-${SupabaseService.client.auth.currentUser!.id}')
        ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'playlists', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: SupabaseService.client.auth.currentUser!.id), callback: (_) => unawaited(_refreshRemote()))
        ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'playlist_songs', callback: (_) => unawaited(_refreshRemote()))
        ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'liked_songs', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: SupabaseService.client.auth.currentUser!.id), callback: (_) => unawaited(_refreshRemote()))
        ..subscribe();
    } catch (_) {
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshRemote() async {
    if (SupabaseService.client.auth.currentUser == null) return;
    try {
      playlists = await _remote.fetchPlaylists();
      liked = await _remote.fetchLiked();
      recentlyPlayed = await _remote.fetchRecentlyPlayed();
      await _saveLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadLocal() async {
    final likedRaw = _prefs?.getString('zeia_liked');
    final playlistRaw = _prefs?.getString('zeia_playlists');
    final recentRaw = _prefs?.getString('zeia_recently_played');
    if (likedRaw != null && likedRaw.isNotEmpty) {
      try {
        final value = jsonDecode(likedRaw);
        if (value is List) liked = value.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    if (playlistRaw != null && playlistRaw.isNotEmpty) {
      try {
        final value = jsonDecode(playlistRaw);
        if (value is List) playlists = value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    if (recentRaw != null && recentRaw.isNotEmpty) {
      try {
        final value = jsonDecode(recentRaw);
        if (value is List) recentlyPlayed = value.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
  }

  bool isLiked(Song song) => liked.any((item) => item.videoId == song.videoId);

  Future<void> toggleLike(Song song) async {
    final next = !isLiked(song);
    if (next) {
      liked = [song, ...liked.where((item) => item.videoId != song.videoId)];
    } else {
      liked.removeWhere((item) => item.videoId == song.videoId);
    }
    notifyListeners();
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      try {
        await _remote.toggleLike(song, next);
      } catch (_) {}
    }
    await _saveLocal();
  }

  Future<void> createPlaylist(String name, {String? coverPath}) async {
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      await _remote.createPlaylist(name, coverPath: coverPath);
      await _refreshRemote();
      return;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    playlists = [{'id': id, 'name': name, 'coverPath': coverPath ?? '', 'songs': <Map<String, dynamic>>[]}, ...playlists];
    await _saveLocal();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String name) async {
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      await _remote.renamePlaylist(id, name);
      await _refreshRemote();
      return;
    }
    final index = playlists.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return;
    final updated = Map<String, dynamic>.from(playlists[index]);
    updated['name'] = name;
    playlists[index] = updated;
    await _saveLocal();
    notifyListeners();
  }

  Future<void> setPlaylistCover(String id, String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return;
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      await _remote.setPlaylistCover(id, coverPath);
      await _refreshRemote();
      return;
    }
    final index = playlists.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return;
    final updated = Map<String, dynamic>.from(playlists[index]);
    final oldPath = '${updated['coverPath'] ?? ''}';
    updated['coverPath'] = coverPath;
    playlists[index] = updated;
    if (oldPath.isNotEmpty && oldPath != coverPath) {
      try { final file = File(oldPath); if (await file.exists()) await file.delete(); } catch (_) {}
    }
    await _saveLocal();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      await _remote.deletePlaylist(id);
      await _refreshRemote();
      return;
    }
    final index = playlists.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return;
    final playlist = playlists[index];
    final coverPath = '${playlist['coverPath'] ?? ''}';
    playlists.removeAt(index);
    if (coverPath.isNotEmpty) {
      try { final file = File(coverPath); if (await file.exists()) await file.delete(); } catch (_) {}
    }
    await _saveLocal();
    notifyListeners();
  }

  Future<void> addToPlaylist(String id, Song song) async {
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      final playlist = playlists.firstWhere((item) => '${item['id']}' == id, orElse: () => {});
      final songs = songsForPlaylist(playlist);
      await _remote.addToPlaylist(id, song, songs.length);
      await _refreshRemote();
      return;
    }
    final index = playlists.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return;
    final updated = Map<String, dynamic>.from(playlists[index]);
    final rawSongs = updated['songs'];
    final songs = rawSongs is List ? rawSongs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    if (!songs.any((item) => '${item['videoId']}' == song.videoId)) songs.add(song.toJson());
    updated['songs'] = songs;
    playlists[index] = updated;
    await _saveLocal();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String id, String videoId) async {
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      await _remote.removeFromPlaylist(id, videoId);
      await _refreshRemote();
      return;
    }
    final index = playlists.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return;
    final updated = Map<String, dynamic>.from(playlists[index]);
    final rawSongs = updated['songs'];
    final songs = rawSongs is List ? rawSongs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    songs.removeWhere((item) => '${item['videoId']}' == videoId);
    updated['songs'] = songs;
    playlists[index] = updated;
    await _saveLocal();
    notifyListeners();
  }

  List<Song> songsForPlaylist(Map<String, dynamic> playlist) {
    final raw = playlist['songs'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> recordPlayed(Song song) async {
    recentlyPlayed = [song, ...recentlyPlayed.where((item) => item.videoId != song.videoId)].take(12).toList();
    await _saveLocal();
    notifyListeners();
    if (SupabaseService.configured && SupabaseService.client.auth.currentUser != null) {
      try { await _remote.recordPlayed(song); } catch (_) {}
    }
  }

  Future<void> _saveLocal() async {
    await _prefs?.setString('zeia_liked', jsonEncode(liked.map((song) => song.toJson()).toList()));
    await _prefs?.setString('zeia_playlists', jsonEncode(playlists));
    await _prefs?.setString('zeia_recently_played', jsonEncode(recentlyPlayed.map((song) => song.toJson()).toList()));
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _authSubscription?.cancel();
    super.dispose();
  }
}
