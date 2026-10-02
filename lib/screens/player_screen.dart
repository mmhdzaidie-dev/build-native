import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/zeia_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  var view = 0;
  var glow = true;
  late final AnimationController glowController;
  final lyricsController = ScrollController();
  int lastActive = -1;

  @override
  void initState() {
    super.initState();
    glowController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  }

  @override
  void dispose() {
    glowController.dispose();
    lyricsController.dispose();
    super.dispose();
  }

  void _followLyrics(PlayerProvider player) {
    if (view != 1 || player.activeLyric < 0 || player.activeLyric == lastActive || !lyricsController.hasClients) return;
    lastActive = player.activeLyric;
    final offset = (player.activeLyric * 62.0).clamp(0.0, lyricsController.position.maxScrollExtent);
    lyricsController.animateTo(offset, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final song = player.current;
    if (song == null) return const Scaffold(backgroundColor: zeiaBg, body: SizedBox.shrink());
    _followLyrics(player);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (glow) Positioned.fill(child: AnimatedBuilder(animation: glowController, builder: (_, __) => Stack(children: [Positioned.fill(child: CachedNetworkImage(imageUrl: song.cover, fit: BoxFit.cover)), Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 38 + glowController.value * 12, sigmaY: 38 + glowController.value * 12), child: Container(color: Colors.black.withValues(alpha: .72)))), Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2 + glowController.value * .08), radius: 1.2, colors: [zeiaAccent.withValues(alpha: .18), Colors.black.withValues(alpha: .9)]))))]))),
        SafeArea(child: Column(children: [
          Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30)), const Expanded(child: Column(children: [Text('NOW PLAYING', style: TextStyle(fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w800, color: zeiaMuted)), SizedBox(height: 2), _HeaderArtist() ])), IconButton(onPressed: () => setState(() => glow = !glow), icon: Icon(glow ? Icons.graphic_eq_rounded : Icons.graphic_eq_outlined)), IconButton(onPressed: () => _more(context, player), icon: const Icon(Icons.more_vert_rounded))]),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(4), margin: const EdgeInsets.symmetric(horizontal: 28), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: Row(children: [_segment('Cover', 0), _segment('Lirik', 1)])),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: view == 0 ? _coverView(context, player, library, song) : _lyricsView(player, song))),
          _bottomControls(context, player, library, song),
          const SizedBox(height: 12),
        ])),
      ]),
    );
  }

  Widget _segment(String label, int value) => Expanded(child: GestureDetector(onTap: () => setState(() => view = value), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: view == value ? Colors.white12 : Colors.transparent, borderRadius: BorderRadius.circular(999)), alignment: Alignment.center, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: view == value ? Colors.white : zeiaMuted)))));

  Widget _coverView(BuildContext context, PlayerProvider player, LibraryProvider library, Song song) => SingleChildScrollView(key: const ValueKey('cover'), padding: const EdgeInsets.fromLTRB(24, 22, 24, 12), child: Column(children: [
    Hero(tag: 'zeia-art-${song.videoId}', child: ClipRRect(borderRadius: BorderRadius.circular(26), child: Container(color: Colors.black, padding: const EdgeInsets.all(1), child: CachedNetworkImage(imageUrl: song.cover, width: double.infinity, height: MediaQuery.of(context).size.width - 48, fit: BoxFit.cover)))),
    const SizedBox(height: 20),
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)), const SizedBox(height: 5), Text(song.artist, style: const TextStyle(color: zeiaMuted, fontSize: 14, fontWeight: FontWeight.w700))])), IconButton(onPressed: () => library.toggleLike(song), icon: Icon(library.isLiked(song) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: library.isLiked(song) ? Colors.white : zeiaMuted, size: 28))]),
    const SizedBox(height: 14),
    _progress(player),
  ]));

  Widget _lyricsView(PlayerProvider player, Song song) {
    final lines = player.lyrics;
    return Container(key: const ValueKey('lyrics'), padding: const EdgeInsets.fromLTRB(24, 16, 24, 10), child: Column(children: [
      Row(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: song.cover, width: 54, height: 54, fit: BoxFit.cover)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: zeiaMuted, fontSize: 11))])), IconButton(onPressed: () => player.setLyricOffset(-100), icon: const Icon(Icons.remove_rounded)), Text('${player.lyricOffsetMs}ms', style: const TextStyle(color: zeiaMuted, fontSize: 10)), IconButton(onPressed: () => player.setLyricOffset(100), icon: const Icon(Icons.add_rounded))]),
      const SizedBox(height: 12),
      Expanded(child: player.lyricsLoading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : lines.isEmpty ? const Center(child: Text('Lirik tidak tersedia.', style: TextStyle(color: zeiaMuted))) : ListView.builder(controller: lyricsController, padding: const EdgeInsets.only(top: 10, bottom: 30), itemCount: lines.length, itemBuilder: (_, i) { final line = lines[i]; final active = i == player.activeLyric; return AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.symmetric(vertical: 8), child: Text(line.text, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: active ? 25 : 19, fontWeight: active ? FontWeight.w900 : FontWeight.w700, height: 1.25))); })),
    ]));
  }

  Widget _progress(PlayerProvider player) => StreamBuilder<Duration>(stream: player.audio.player.positionStream, builder: (_, __) { final duration = player.duration; final position = player.position; final value = duration.inMilliseconds > 0 ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0).toDouble() : 0.0; return Column(children: [Slider(value: value, onChanged: duration.inMilliseconds <= 0 ? null : (v) => player.seek(Duration(milliseconds: (duration.inMilliseconds * v).round()))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(position), style: const TextStyle(color: zeiaMuted, fontSize: 11)), Text(_fmt(duration), style: const TextStyle(color: zeiaMuted, fontSize: 11))])]); });

  Widget _bottomControls(BuildContext context, PlayerProvider player, LibraryProvider library, Song song) => Padding(padding: const EdgeInsets.fromLTRB(30, 4, 30, 0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: player.toggleShuffle, icon: Icon(Icons.shuffle_rounded, color: player.shuffle ? Colors.white : zeiaMuted)), IconButton(onPressed: player.previous, icon: const Icon(Icons.skip_previous_rounded, size: 38)), Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: IconButton(onPressed: (player.loading || player.buffering) ? null : player.toggle, icon: player.loading || player.buffering ? const SizedBox(width: 27, height: 27, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)) : Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 39))), IconButton(onPressed: player.next, icon: const Icon(Icons.skip_next_rounded, size: 38)), IconButton(onPressed: player.toggleRepeat, icon: Stack(alignment: Alignment.center, children: [Icon(Icons.repeat_rounded, color: player.repeatMode == AudioServiceRepeatMode.none ? zeiaMuted : Colors.white), if (player.repeatMode == AudioServiceRepeatMode.one) const Positioned(right: 1, bottom: 4, child: Text('1', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))]))]), const SizedBox(height: 6)]));

  Future<void> _more(BuildContext context, PlayerProvider player) async {
    final song = player.current;
    if (song == null) return;
    showModalBottomSheet(context: context, backgroundColor: zeiaCard, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: song.cover, width: 50, height: 50, fit: BoxFit.cover)), const SizedBox(width: 10), Expanded(child: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)))])), ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Tambah ke Playlist'), onTap: () { Navigator.pop(context); _addPlaylist(context, song); }), ListTile(leading: const Icon(Icons.queue_music_rounded), title: const Text('Lihat Antrean'), onTap: () { Navigator.pop(context); _queue(context, player); }), ListTile(leading: const Icon(Icons.download_rounded), title: const Text('Download'), onTap: () => Navigator.pop(context)), ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Bagikan'), onTap: () => Navigator.pop(context))])));
  }

  Future<void> _addPlaylist(BuildContext context, Song song) async {
    final library = context.read<LibraryProvider>();
    final id = await showModalBottomSheet<String>(context: context, backgroundColor: zeiaCard, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 12), child: Text('Tambah ke Playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), ...library.playlists.map((p) => ListTile(leading: const Icon(Icons.playlist_play_rounded), title: Text('${p['name']}'), onTap: () => Navigator.pop(context, '${p['id']}')))])));
    if (id != null) await library.addToPlaylist(id, song);
  }

  void _queue(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(context: context, backgroundColor: zeiaCard, isScrollControlled: true, builder: (_) => FractionallySizedBox(heightFactor: .75, child: ListView(padding: const EdgeInsets.fromLTRB(12, 14, 12, 20), children: [const Padding(padding: EdgeInsets.all(8), child: Text('Antrean', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), ...player.queue.asMap().entries.map((entry) => ListTile(onTap: () => player.playSong(entry.value, list: player.queue, requestedIndex: entry.key), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: entry.value.cover, width: 48, height: 48, fit: BoxFit.cover)), title: Text(entry.value.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(entry.value.artist, style: const TextStyle(color: zeiaMuted, fontSize: 11))))])));
  }

  String _fmt(Duration value) => '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _HeaderArtist extends StatelessWidget {
  const _HeaderArtist();
  @override
  Widget build(BuildContext context) {
    final artist = context.select<PlayerProvider, String>((value) => value.current?.artist ?? '');
    return Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70));
  }
}
