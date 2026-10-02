import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/zeia_api.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/playlist_cover_service.dart';
import '../auth/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../theme/zeia_theme.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<String> onSearch;
  const HomeScreen({super.key, required this.onSearch});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query = TextEditingController();
  List<Song> quickPicks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHome());
  }

  Future<void> _loadHome() async {
    try {
      quickPicks = (await ZeiaApi.search('Trend Indonesia')).take(8).toList();
    } catch (_) {
      try {
        quickPicks = (await ZeiaApi.search('XXXTENTACION Lil Peep Juice WRLD')).take(8).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 170),
      children: [
        Row(children: [
          Image.asset('assets/logo.png', width: 44, height: 44),
          const SizedBox(width: 10),
          const Text('ZEIA', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const Spacer(),
          IconButton(onPressed: () => widget.onSearch(''), icon: const Icon(Icons.search_rounded, size: 27), splashRadius: 24),
          if (context.watch<ZeiaAuthProvider>().signedIn) IconButton(onPressed: () => _account(context), icon: const Icon(Icons.account_circle_outlined, size: 27)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Image.asset('assets/banner.png', height: 190, width: double.infinity, fit: BoxFit.cover),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, zeiaBg.withValues(alpha: .98)])))),
            const Positioned(left: 18, right: 18, bottom: 18, child: Text('your music. your space.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.5))),
          ]),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: query,
          onSubmitted: (value) {
            final q = value.trim();
            if (q.isNotEmpty) widget.onSearch(q);
          },
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: zeiaMuted), hintText: 'What do you want to listen to?'),
        ),
        const SizedBox(height: 24),
        Row(children: [const Text('Quick Picks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const Spacer(), if (loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))]),
        const SizedBox(height: 12),
        if (quickPicks.isEmpty && !loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Text('Tidak ada lagu ditemukan.', style: TextStyle(color: zeiaMuted)))
        else if (quickPicks.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quickPicks.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .82),
            itemBuilder: (_, i) => _quickCard(quickPicks[i]),
          ),
        if (library.recentlyPlayed.isNotEmpty) ...[
          const SizedBox(height: 26),
          const Text('Recently Played', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(height: 132, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: library.recentlyPlayed.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) {
            final song = library.recentlyPlayed[i];
            return SizedBox(width: 112, child: GestureDetector(onTap: () => context.read<PlayerProvider>().playSong(song, list: library.recentlyPlayed, requestedIndex: i), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: song.cover, width: 112, height: 92, fit: BoxFit.cover)),
              const SizedBox(height: 7),
              Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: zeiaMuted)),
            ])));
          })),
        ],
        const SizedBox(height: 26),
        const Text('Playlists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: library.playlists.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == 0) return _createPlaylistCard(context);
              final playlist = library.playlists[i - 1];
              return _playlistCard(context, playlist, library.songsForPlaylist(playlist).length);
            },
          ),
        ),
        const SizedBox(height: 28),
        const Text('Top Artists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final artist = _artists[i];
              return SizedBox(width: 104, child: Column(children: [
                ClipOval(child: CachedNetworkImage(imageUrl: artist.$2, width: 92, height: 92, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 92, height: 92, color: zeiaCard, child: const Icon(Icons.person_rounded, color: zeiaMuted)))),
                const SizedBox(height: 8),
                Text(artist.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ]));
            },
          ),
        ),
      ],
    );
  }

  Future<void> _account(BuildContext context) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Widget _quickCard(Song song) => GestureDetector(
    onTap: () => context.read<PlayerProvider>().playSong(song, list: quickPicks),
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(13), child: CachedNetworkImage(imageUrl: song.cover, width: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: zeiaCard2, child: const Icon(Icons.music_note_rounded, color: zeiaMuted))))),
        const SizedBox(height: 8),
        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: zeiaMuted, fontSize: 11)),
      ]),
    ),
  );

  Widget _createPlaylistCard(BuildContext context) => GestureDetector(
    onTap: () => _createPlaylist(context),
    child: Container(width: 150, decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, size: 34), SizedBox(height: 10), Text('Buat Playlist', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Mulai koleksimu', style: TextStyle(color: zeiaMuted, fontSize: 11))])),
  );

  Widget _playlistCard(BuildContext context, Map<String, dynamic> playlist, int count) {
    final coverPath = '${playlist['coverPath'] ?? ''}';
    final coverUrl = '${playlist['coverUrl'] ?? ''}';
    final cover = coverPath.isNotEmpty ? Image.file(File(coverPath), fit: BoxFit.cover) : (coverUrl.isNotEmpty ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover) : null);
    return GestureDetector(
      onTap: () => _openPlaylist(context, playlist),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: cover ?? Container(color: zeiaCard2, child: const Center(child: Icon(Icons.queue_music_rounded, size: 42, color: zeiaMuted))))),
          const SizedBox(height: 9),
          Text('${playlist['name'] ?? 'Playlist'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('$count lagu', style: const TextStyle(color: zeiaMuted, fontSize: 11)),
        ]),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    String? coverPath;
    final library = context.read<LibraryProvider>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: zeiaCard,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Buat Playlist Baru', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final picked = await PlaylistCoverService.pickAndStore();
              if (picked != null) setSheetState(() => coverPath = picked);
            },
            child: Container(width: 118, height: 118, decoration: BoxDecoration(color: zeiaCard2, borderRadius: BorderRadius.circular(20)), child: coverPath == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 34), SizedBox(height: 7), Text('Pilih gambar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]) : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(coverPath!), fit: BoxFit.cover))),
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

  Future<void> _openPlaylist(BuildContext context, Map<String, dynamic> playlist) async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();
    final songs = library.songsForPlaylist(playlist);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: zeiaBg,
      builder: (_) => FractionallySizedBox(heightFactor: .9, child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)), Expanded(child: Text('${playlist['name'] ?? 'Playlist'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), const SizedBox(width: 48)])),
        const SizedBox(height: 4),
        SizedBox(width: 150, height: 150, child: _playlistCover(playlist, songs)),
        const SizedBox(height: 12),
        Text('${songs.length} lagu', style: const TextStyle(color: zeiaMuted)),
        const SizedBox(height: 10),
        if (songs.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(onPressed: () => player.playSong(songs.first, list: songs, requestedIndex: 0), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Putar')),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: () => player.playSong(songs.first, list: songs, requestedIndex: songs.length > 1 ? 1 : 0), icon: const Icon(Icons.shuffle_rounded)),
        ]),
        const SizedBox(height: 8),
        Expanded(child: songs.isEmpty ? const Center(child: Text('Playlist ini masih kosong.', style: TextStyle(color: zeiaMuted))) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), itemCount: songs.length, separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (_, i) => ListTile(onTap: () => player.playSong(songs[i], list: songs, requestedIndex: i), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: songs[i].cover, width: 48, height: 48, fit: BoxFit.cover)), title: Text(songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(songs[i].artist, style: const TextStyle(color: zeiaMuted, fontSize: 11)), trailing: IconButton(onPressed: () => library.removeFromPlaylist('${playlist['id']}', songs[i].videoId), icon: const Icon(Icons.remove_circle_outline_rounded, color: zeiaMuted))))),
      ]))),
    );
  }

  Widget _playlistCover(Map<String, dynamic> playlist, List<Song> songs) {
    final path = '${playlist['coverPath'] ?? ''}';
    if (path.isNotEmpty) return ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _playlistFallback(songs)));
    return _playlistFallback(songs);
  }

  Widget _playlistFallback(List<Song> songs) => ClipRRect(borderRadius: BorderRadius.circular(20), child: songs.isEmpty ? Container(color: zeiaCard, child: const Icon(Icons.queue_music_rounded, size: 46, color: zeiaMuted)) : CachedNetworkImage(imageUrl: songs.first.cover, fit: BoxFit.cover));

  static const _artists = <(String, String)>[
    ('XXXTENTACION', 'https://i1.sndcdn.com/artworks-000306240468-19v7y7-t500x500.jpg'),
    ('Lil Peep', 'https://i.scdn.co/image/ab67616d0000b27336f2f7b76b8a0f3ab6f0f07f'),
    ('Juice WRLD', 'https://i.scdn.co/image/ab67616d0000b27333c4f4d184a6d1e2fd8b3c2a'),
    ('Lil Loaded', 'https://i.scdn.co/image/ab67616d0000b273bcf7f3b5aee8afadf0f3a746'),
    ('Hindia', 'https://i.scdn.co/image/ab6761610000e5eb8a847d0f3ebc0f3f6b75b3dd'),
  ];
}
