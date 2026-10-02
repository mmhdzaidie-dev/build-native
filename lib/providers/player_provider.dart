import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../api/zeia_api.dart';
import '../models/song.dart';
import '../services/audio_service.dart';

class PlayerProvider extends ChangeNotifier {
  final ZeiaAudioService audio;
  List<Song> queue = [];
  Song? current;
  int index = 0;
  bool loading = false;
  bool initialized = false;
  bool shuffle = false;
  AudioServiceRepeatMode repeatMode = AudioServiceRepeatMode.all;
  List<LyricLine> lyrics = [];
  bool lyricsLoading = false;
  int activeLyric = -1;
  int lyricOffsetMs = 0;
  String? errorMessage;
  Future<void>? _initialization;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<ja.PlayerState>? _stateSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  bool _recovering = false;
  final Future<void> Function(Song song)? onPlayed;

  PlayerProvider(this.audio, {this.onPlayed}) {
    _positionSubscription = audio.player.positionStream.listen(_onPosition);
    _stateSubscription = audio.player.playerStateStream.listen(_onPlayerState);
    _errorSubscription = audio.player.errorStream.listen((_) {
      unawaited(_recoverFromError());
    });
  }

  bool get playing => audio.player.playing;
  bool get buffering => audio.player.processingState == ja.ProcessingState.loading || audio.player.processingState == ja.ProcessingState.buffering;
  Duration get position => audio.player.position;
  Duration get duration => audio.player.duration ?? Duration.zero;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await AudioService.init(
        builder: () => audio,
        config: AudioServiceConfig(
          androidNotificationChannelId: 'id.zdv.zeia.audio',
          androidNotificationChannelName: 'ZEIA Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidNotificationClickStartsActivity: true,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
      audio.onNext = next;
      audio.onPrevious = previous;
      audio.onCompleted = _handleCompleted;
      audio.onToggleRepeat = toggleRepeat;
      audio.onToggleShuffle = toggleShuffle;
      initialized = true;
      errorMessage = null;
      notifyListeners();
    } catch (e) {
      initialized = false;
      errorMessage = '$e';
      _initialization = null;
      notifyListeners();
    }
  }

  Future<void> playSong(Song song, {List<Song>? list, int? requestedIndex, bool forceRefresh = false}) async {
    final targetList = list ?? (queue.isNotEmpty ? queue : [song]);
    queue = List<Song>.from(targetList);
    final foundIndex = requestedIndex ?? queue.indexWhere((item) => item.videoId == song.videoId);
    index = foundIndex >= 0 ? foundIndex : 0;
    current = song;
    loading = true;
    errorMessage = null;
    lyrics = [];
    activeLyric = -1;
    lyricsLoading = true;
    notifyListeners();
    try {
      await _ensureInitialized();
      String? url;
      try {
        url = await ZeiaApi.audioUrl(song.videoId, forceRefresh: forceRefresh);
      } catch (_) {
        url = null;
      }
      if (url == null || url.isEmpty) throw Exception('Audio source unavailable');
      await audio.load(song, url, forceRefresh: forceRefresh);
      await audio.play();
      unawaited(onPlayed?.call(song) ?? Future<void>.value());
      loading = false;
      notifyListeners();
      unawaited(_loadLyrics(song));
    } catch (e) {
      if (!forceRefresh) {
        try {
          loading = true;
          final retryUrl = await ZeiaApi.audioUrl(song.videoId, forceRefresh: true);
          if (retryUrl != null && retryUrl.isNotEmpty) {
            await audio.load(song, retryUrl, forceRefresh: true);
            await audio.play();
            unawaited(onPlayed?.call(song) ?? Future<void>.value());
            loading = false;
            errorMessage = null;
            notifyListeners();
            unawaited(_loadLyrics(song));
            return;
          }
        } catch (_) {}
      }
      loading = false;
      errorMessage = 'Gagal memutar lagu';
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    await _ensureInitialized();
    if (playing) {
      await audio.pause();
    } else if (current != null) {
      await audio.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    final nextIndex = shuffle ? _randomNextIndex() : (index + 1) % queue.length;
    await playSong(queue[nextIndex], list: queue, requestedIndex: nextIndex);
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (audio.player.position > const Duration(seconds: 3)) {
      await audio.seek(Duration.zero);
      return;
    }
    final previousIndex = index == 0 ? queue.length - 1 : index - 1;
    await playSong(queue[previousIndex], list: queue, requestedIndex: previousIndex);
  }

  Future<void> seek(Duration value) async {
    await _ensureInitialized();
    await audio.seek(value);
  }

  Future<void> toggleRepeat() async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        repeatMode = AudioServiceRepeatMode.all;
        await audio.player.setLoopMode(ja.LoopMode.off);
        break;
      case AudioServiceRepeatMode.all:
        repeatMode = AudioServiceRepeatMode.one;
        await audio.player.setLoopMode(ja.LoopMode.one);
        break;
      case AudioServiceRepeatMode.one:
        repeatMode = AudioServiceRepeatMode.none;
        await audio.player.setLoopMode(ja.LoopMode.off);
        break;
      case AudioServiceRepeatMode.group:
        repeatMode = AudioServiceRepeatMode.none;
        await audio.player.setLoopMode(ja.LoopMode.off);
        break;
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    notifyListeners();
  }

  Future<void> setLyricOffset(int deltaMs) async {
    lyricOffsetMs = (lyricOffsetMs + deltaMs).clamp(-5000, 5000).toInt();
    notifyListeners();
  }

  void addToQueue(Song song) {
    if (queue.any((item) => item.videoId == song.videoId)) return;
    queue = [...queue, song];
    notifyListeners();
  }

  void playNext(Song song) {
    final remaining = queue.where((item) => item.videoId != song.videoId).toList();
    final insertAt = index + 1 > remaining.length ? remaining.length : index + 1;
    remaining.insert(insertAt, song);
    queue = remaining;
    notifyListeners();
  }

  Future<void> _loadLyrics(Song song) async {
    try {
      final loaded = await ZeiaApi.lyrics(song);
      if (current?.videoId != song.videoId) return;
      lyrics = loaded;
    } catch (_) {
      if (current?.videoId != song.videoId) return;
      lyrics = [];
    } finally {
      if (current?.videoId == song.videoId) {
        lyricsLoading = false;
        _updateActiveLyric(audio.player.position);
        notifyListeners();
      }
    }
  }

  void _onPlayerState(ja.PlayerState state) {
    notifyListeners();
  }

  void _onPosition(Duration value) {
    _updateActiveLyric(value);
    notifyListeners();
  }

  void _updateActiveLyric(Duration position) {
    if (lyrics.isEmpty) {
      activeLyric = -1;
      return;
    }
    if (lyrics.any((line) => line.time < 0)) {
      activeLyric = -1;
      return;
    }
    final seconds = position.inMilliseconds / 1000.0 + lyricOffsetMs / 1000.0;
    var candidate = -1;
    for (var i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= seconds) candidate = i;
      if (lyrics[i].time > seconds) break;
    }
    activeLyric = candidate;
  }

  Future<void> _handleCompleted() async {
    if (queue.isEmpty) return;
    if (repeatMode == AudioServiceRepeatMode.one) return;
    if (repeatMode == AudioServiceRepeatMode.none && index >= queue.length - 1) {
      notifyListeners();
      return;
    }
    final nextIndex = shuffle ? _randomNextIndex() : (index + 1) % queue.length;
    await playSong(queue[nextIndex], list: queue, requestedIndex: nextIndex);
  }

  int _randomNextIndex() {
    if (queue.length <= 1) return index;
    var nextIndex = index;
    while (nextIndex == index) {
      nextIndex = DateTime.now().microsecondsSinceEpoch % queue.length;
    }
    return nextIndex;
  }

  Future<void> _recoverFromError() async {
    if (_recovering || current == null) return;
    _recovering = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final song = current;
      if (song != null) await playSong(song, list: queue, requestedIndex: index, forceRefresh: true);
    } finally {
      _recovering = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (initialized) return;
    await initialize();
    if (!initialized) throw Exception(errorMessage ?? 'audio service initialization failed');
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _errorSubscription?.cancel();
    audio.onNext = null;
    audio.onPrevious = null;
    audio.onCompleted = null;
    audio.onToggleRepeat = null;
    audio.onToggleShuffle = null;
    unawaited(audio.close());
    super.dispose();
  }
}
