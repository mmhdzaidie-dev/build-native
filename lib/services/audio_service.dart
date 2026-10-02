import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class ZeiaAudioService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  Future<void> Function()? onCompleted;
  Future<void> Function()? onToggleRepeat;
  Future<void> Function()? onToggleShuffle;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<int?>? _indexSubscription;

  ZeiaAudioService() {
    _eventSubscription = player.playbackEventStream.listen((_) => _sync());
    _stateSubscription = player.playerStateStream.listen((state) {
      _sync();
      if (state.processingState == ProcessingState.completed) unawaited(onCompleted?.call());
    });
    _indexSubscription = player.currentIndexStream.listen((_) => _sync());
  }

  Future<void> load(Song song, String url, {bool forceRefresh = false}) async {
    final item = MediaItem(
      id: url,
      title: song.title,
      artist: song.artist,
      album: song.album.isNotEmpty ? song.album : 'ZEIA',
      artUri: song.cover.isNotEmpty ? Uri.tryParse(song.cover) : null,
    );
    final file = await _audioFile(song.videoId);
    if (forceRefresh && await file.exists()) await file.delete();
    if (!await file.exists() || await file.length() < 1024) await _download(url, file);
    mediaItem.add(item);
    queue.add(<MediaItem>[item]);
    await player.setAudioSource(AudioSource.file(file.path, tag: item), preload: true);
    await player.setLoopMode(LoopMode.off);
    _sync();
  }

  Future<File> _audioFile(String videoId) async {
    final directory = await getTemporaryDirectory();
    final folder = Directory('${directory.path}/zeia_audio');
    if (!await folder.exists()) await folder.create(recursive: true);
    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${folder.path}/$safeId.audio');
  }

  Future<void> _download(String url, File file) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.addAll(const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36',
        'Accept': '*/*',
      });
      final response = await client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Audio HTTP ${response.statusCode}');
      final sink = file.openWrite();
      await response.stream.timeout(const Duration(seconds: 45)).pipe(sink);
      if (!await file.exists() || await file.length() < 1024) throw Exception('Audio file kosong');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> fastForward() => player.seek(player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => player.seek(player.position - const Duration(seconds: 10));

  @override
  Future<void> skipToNext() async {
    final callback = onNext;
    if (callback != null) await callback();
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onPrevious;
    if (callback != null) await callback();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggleRepeat') {
      final callback = onToggleRepeat;
      if (callback != null) await callback();
    } else if (name == 'toggleShuffle') {
      final callback = onToggleShuffle;
      if (callback != null) await callback();
    }
    return null;
  }

  void _sync() {
    var processing = AudioProcessingState.ready;
    switch (player.processingState) {
      case ProcessingState.loading:
        processing = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        processing = AudioProcessingState.buffering;
        break;
      case ProcessingState.completed:
        processing = AudioProcessingState.completed;
        break;
      case ProcessingState.idle:
        processing = AudioProcessingState.idle;
        break;
      case ProcessingState.ready:
        processing = AudioProcessingState.ready;
        break;
    }
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      player.playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(androidIcon: 'drawable/ic_repeat', label: 'Repeat', name: 'toggleRepeat'),
      MediaControl.custom(androidIcon: 'drawable/ic_shuffle', label: 'Shuffle', name: 'toggleShuffle'),
    ];
    playbackState.add(playbackState.value.copyWith(controls: controls, systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward}, androidCompactActionIndices: const [0, 1, 2], playing: player.playing, updatePosition: player.position, bufferedPosition: player.bufferedPosition, speed: player.speed, processingState: processing, queueIndex: player.currentIndex));
  }

  Future<void> close() async {
    await _eventSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _indexSubscription?.cancel();
    await player.dispose();
  }
}
