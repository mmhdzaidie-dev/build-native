import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/playlist_cover_service.dart';
import '../theme/zeia_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  var tab = 0;

  Future<void> _create() async {
    final library = context.read<LibraryProvider>();
    final controller = TextEditingController();
    String? coverPath;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: zeiaCard,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Buat Playlist Baru', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final picked = await PlaylistCoverService.pickAndStore();
              if (picked != null) setSheetState(() => coverPath = picked);
            },
            child: Container(width: 126, height: 126, decoration: BoxDecoration(color: zeiaCard2, borderRadius: BorderRadius.circular(20)), child: coverPath == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 36), SizedBox(height: 7), Text('Pilih gambar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]) : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(coverPath!), fit: BoxFit.cover))),
          ),
          const SizedBox(height: 14),
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Nama playlist')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, controller.text.trim().isNotEmpty), child: const Text('Buat'))),
        ]),
      )),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (!mounted) return;
    if (result == true && name.isNotEmpty) await library.createPlaylist(name, coverPath: coverPath);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 170), children: [
      const Text('Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 15),
      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(14)), child: Row(children: [Expanded(child: _tabButton('Playlists', 0)), Expanded(child: _tabButton('Artists', 1))])),
      const SizedBox(height: 16),
      if (tab == 0) ...[
        Material(color: zeiaCard, borderRadius: BorderRadius.circular(18), child: ListTile(leading: const Icon(Icons.add_rounded, size: 28), title: const Text('Buat Playlist Baru', style: TextStyle(fontWeight: FontWeight.w900)), onTap: _create)),
        const SizedBox(height: 10),
        if (library.playlists.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: Text('Belum Ada Playlist', style: TextStyle(color: zeiaMuted, fontSize: 16)))) else ...library.playlists.map((playlist) => _playlistRow(context, playlist)),
      ] else ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Center(child: Text('Belum Ada Artist', style: TextStyle(color: zeiaMuted, fontSize: 16)))),
      ],
    ]);
  }

  Widget _tabButton(String text, int value) => GestureDetector(onTap: () => setState(() => tab = value), child: Container(padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: tab == value ? Colors.white12 : Colors.transparent, borderRadius: BorderRadius.circular(11)), alignment: Alignment.center, child: Text(text, style: TextStyle(color: tab == value ? Colors.white : zeiaMuted, fontWeight: FontWeight.w800))));

  Widget _playlistRow(BuildContext context, Map<String, dynamic> playlist) {
    final library = context.read<LibraryProvider>();
    final songs = library.songsForPlaylist(playlist);
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Material(
        color: zeiaCard,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: _cover(playlist, songs, 62),
          title: Text('${playlist['name'] ?? 'Playlist'}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${songs.length} lagu', style: const TextStyle(color: zeiaMuted)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: songs.isEmpty ? null : () => context.read<PlayerProvider>().playSong(songs.first, list: songs, requestedIndex: 0), icon: const Icon(Icons.play_arrow_rounded)),
            IconButton(onPressed: () => _playlistMenu(playlist), icon: const Icon(Icons.more_vert_rounded, color: zeiaMuted)),
          ]),
          onTap: () => _openPlaylist(context, playlist),
        ),
      ),
    );
  }

  Widget _cover(Map<String, dynamic> playlist, List<Song> songs, double size) {
    final path = '${playlist['coverPath'] ?? ''}';
    final url = '${playlist['coverUrl'] ?? ''}';
    if (path.isNotEmpty) return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(songs, size)));
    if (url.isNotEmpty) return ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, __, ___) => _fallback(songs, size)));
    return _fallback(songs, size);
  }

  Widget _fallback(List<Song> songs, double size) => Container(width: size, height: size, decoration: BoxDecoration(color: zeiaCard2, borderRadius: BorderRadius.circular(14)), child: songs.isEmpty ? const Icon(Icons.queue_music_rounded, color: zeiaMuted) : ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: songs.first.cover, fit: BoxFit.cover)));

  Future<void> _playlistMenu(Map<String, dynamic> playlist) async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();
    final action = await showModalBottomSheet<String>(context: context, backgroundColor: zeiaCard, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Text('${playlist['name'] ?? 'Playlist'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
      ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Rename'), onTap: () => Navigator.pop(sheetContext, 'rename')),
      ListTile(leading: const Icon(Icons.image_rounded), title: const Text('Ganti gambar'), onTap: () => Navigator.pop(sheetContext, 'cover')),
      ListTile(leading: const Icon(Icons.play_arrow_rounded), title: const Text('Putar semua'), onTap: () => Navigator.pop(sheetContext, 'play')),
      ListTile(leading: const Icon(Icons.shuffle_rounded), title: const Text('Putar acak'), onTap: () => Navigator.pop(sheetContext, 'shuffle')),
      ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Hapus'), onTap: () => Navigator.pop(sheetContext, 'delete')),
    ])));
    final id = '${playlist['id'] ?? ''}';
    if (!mounted) return;
    if (action == 'rename') {
      final controller = TextEditingController(text: '${playlist['name'] ?? ''}');
      final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: zeiaCard, title: const Text('Rename Playlist'), content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim().isNotEmpty), child: const Text('Simpan'))]));
      if (!mounted) {
        controller.dispose();
        return;
      }
      if (ok == true && controller.text.trim().isNotEmpty) await library.renamePlaylist(id, controller.text.trim());
      controller.dispose();
    } else if (action == 'cover') {
      final path = await PlaylistCoverService.pickAndStore();
      if (!mounted) return;
      if (path != null) await library.setPlaylistCover(id, path);
    } else {
      final songs = library.songsForPlaylist(playlist);
      if (songs.isEmpty) return;
      if (action == 'play') await player.playSong(songs.first, list: songs, requestedIndex: 0);
      if (action == 'shuffle') await player.playSong(songs.first, list: songs, requestedIndex: songs.length > 1 ? 1 : 0);
      if (action == 'delete') {
        if (!mounted) return;
        final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: zeiaCard, title: const Text('Hapus Playlist?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus'))]));
        if (!mounted) return;
        if (ok == true) await library.deletePlaylist(id);
      }
    }
  }

  Future<void> _openPlaylist(BuildContext context, Map<String, dynamic> playlist) async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: zeiaBg,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        final songs = library.songsForPlaylist(playlist);
        return FractionallySizedBox(heightFactor: .92, child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)), Expanded(child: Text('${playlist['name'] ?? 'Playlist'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), const SizedBox(width: 48)])),
          SizedBox(width: 150, height: 150, child: _cover(playlist, songs, 150)),
          const SizedBox(height: 12),
          Text('${songs.length} lagu', style: const TextStyle(color: zeiaMuted)),
          const SizedBox(height: 10),
          if (songs.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: [FilledButton.icon(onPressed: () => player.playSong(songs.first, list: songs, requestedIndex: 0), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Putar')), const SizedBox(width: 10), IconButton.filledTonal(onPressed: () => player.playSong(songs.first, list: songs, requestedIndex: songs.length > 1 ? 1 : 0), icon: const Icon(Icons.shuffle_rounded))]),
          const SizedBox(height: 8),
          Expanded(child: songs.isEmpty ? const Center(child: Text('Playlist ini masih kosong.', style: TextStyle(color: zeiaMuted))) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), itemCount: songs.length, separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (_, i) => ListTile(onTap: () => player.playSong(songs[i], list: songs, requestedIndex: i), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: songs[i].cover, width: 48, height: 48, fit: BoxFit.cover)), title: Text(songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(songs[i].artist, style: const TextStyle(color: zeiaMuted, fontSize: 11)), trailing: IconButton(onPressed: () async { await library.removeFromPlaylist('${playlist['id']}', songs[i].videoId); setSheetState(() {}); }, icon: const Icon(Icons.remove_circle_outline_rounded, color: zeiaMuted))))),
        ])));
      }),
    );
  }
}
