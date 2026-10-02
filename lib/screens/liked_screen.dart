import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import '../theme/zeia_theme.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final songs = library.liked;
    final player = context.read<PlayerProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 170),
      children: [
        const Text('Liked Songs', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text('${songs.length} lagu', style: const TextStyle(color: zeiaMuted)),
        const SizedBox(height: 16),
        if (songs.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => player.playSong(songs.first, list: songs),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Putar Semua'),
            ),
          ),
        const SizedBox(height: 16),
        if (songs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 130),
            child: Center(
              child: Text(
                'Belum ada lagu yang disukai.',
                style: TextStyle(color: zeiaMuted, fontSize: 16),
              ),
            ),
          )
        else
          ...songs.map((song) => SongTile(song: song, contextQueue: songs)),
      ],
    );
  }
}
