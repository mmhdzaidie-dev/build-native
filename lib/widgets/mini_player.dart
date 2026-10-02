import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/zeia_theme.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onOpen;
  const MiniPlayer({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 70,
        decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))]),
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Align(alignment: Alignment.bottomLeft, child: FractionallySizedBox(widthFactor: player.duration.inMilliseconds == 0 ? 0 : (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0).toDouble(), child: Container(height: 2, color: Colors.white54))))),
          InkWell(borderRadius: BorderRadius.circular(20), onTap: onOpen, child: Row(children: [
            const SizedBox(width: 8),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: song.cover, width: 52, height: 52, fit: BoxFit.cover)),
            const SizedBox(width: 10),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: zeiaMuted, fontSize: 11))])),
            if (player.loading || player.buffering)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            else
              IconButton(onPressed: player.toggle, icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            IconButton(onPressed: player.next, icon: const Icon(Icons.skip_next_rounded)),
            const SizedBox(width: 2),
          ])),
        ]),
      ),
    );
  }
}
