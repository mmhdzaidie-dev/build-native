import 'vidssave_api.dart';
import 'savetube_api.dart';

class DownloadApi {
  static final Map<String, _CachedAudio> _cache = {};

  static Future<String?> audioUrl(String videoId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache[videoId];
      if (cached != null && cached.expiresAt.isAfter(DateTime.now())) return cached.url;
    }
    final providers = <Future<String?> Function()>[
      () => VidsSaveApi.audioUrl(videoId),
      () => SaveTubeApi.audioUrl(videoId),
    ];
    for (final provider in providers) {
      try {
        final value = await provider();
        if (value != null && value.isNotEmpty) {
          _cache[videoId] = _CachedAudio(value, DateTime.now().add(const Duration(minutes: 20)));
          return value;
        }
      } catch (_) {}
    }
    return null;
  }
}

class _CachedAudio {
  final String url;
  final DateTime expiresAt;
  const _CachedAudio(this.url, this.expiresAt);
}
