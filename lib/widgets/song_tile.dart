import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/zeia_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song>? contextQueue;
  final int? index;
  const SongTile({super.key, required this.song, this.contextQueue, this.index});

  Future<void> _showMenu(BuildContext context) async {
    final player = context.read<PlayerProvider>();
    final library = context.read<LibraryProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 10), child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: song.cover, width: 56, height: 56, fit: BoxFit.cover)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 3),
                Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: zeiaMuted, fontSize: 12)),
              ])),
            ])),
            _action(context, Icons.play_arrow_rounded, 'Putar', () async {
              Navigator.pop(context);
              await player.playSong(song, list: contextQueue);
            }),
            _action(context, library.isLiked(song) ? Icons.favorite_rounded : Icons.favorite_border_rounded, library.isLiked(song) ? 'Hapus dari Liked' : 'Tambah ke Liked', () async {
              Navigator.pop(context);
              await library.toggleLike(song);
            }),
            _action(context, Icons.queue_play_next_rounded, 'Putar Berikutnya', () {
              Navigator.pop(context);
              player.playNext(song);
            }),
            _action(context, Icons.queue_music_rounded, 'Tambah ke Antrean', () {
              Navigator.pop(context);
              player.addToQueue(song);
            }),
            _action(context, Icons.playlist_add_rounded, 'Tambah ke Playlist', () {
              Navigator.pop(context);
              _playlistPicker(context, library);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, VoidCallback onTap) => ListTile(leading: Icon(icon, color: Colors.white), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), onTap: onTap);

  Future<void> _playlistPicker(BuildContext context, LibraryProvider library) async {
    if (library.playlists.isEmpty) {
      await library.createPlaylist('Playlist Baru');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: zeiaCard,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
          const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 12), child: Text('Tambah ke Playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ...library.playlists.map((item) => ListTile(title: Text('${item['name'] ?? 'Playlist'}', style: const TextStyle(fontWeight: FontWeight.w700)), leading: const Icon(Icons.playlist_play_rounded), onTap: () => Navigator.pop(context, '${item['id']}'))),
        ]),
      ),
    );
    if (id != null) await library.addToPlaylist(id, song);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.current?.videoId == song.videoId;
    final isBusy = isCurrent && (player.loading || player.buffering);
    final isPlaying = isCurrent && player.playing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isPlaying ? zeiaCard3 : zeiaCard,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => player.playSong(song, list: contextQueue),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(11), child: CachedNetworkImage(imageUrl: song.cover, width: 58, height: 58, fit: BoxFit.cover, placeholder: (_, __) => Container(color: zeiaCard2), errorWidget: (_, __, ___) => Container(color: zeiaCard2, child: const Icon(Icons.music_note_rounded, color: zeiaMuted)))),
                  if (isPlaying)
                    Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(11)), child: const Center(child: Icon(Icons.pause_rounded, color: Colors.white))))
                  else if (isBusy)
                    Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(11)), child: const Center(child: SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w800))), if (isPlaying) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.equalizer_rounded, size: 16, color: Colors.white))]),
                const SizedBox(height: 4),
                Text(song.artist.isNotEmpty ? song.artist : 'Song', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: zeiaMuted, fontSize: 12)),
              ])),
              IconButton(onPressed: () => _showMenu(context), icon: const Icon(Icons.more_vert_rounded, color: zeiaMuted), splashRadius: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
