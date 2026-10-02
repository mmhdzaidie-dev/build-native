import 'package:flutter/material.dart';
import '../theme/zeia_theme.dart';

class ZeiaBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const ZeiaBottomNav({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.search_rounded, 'Search'),
      (Icons.queue_music_rounded, 'Library'),
      (Icons.person_rounded, 'Profile'),
    ];
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: zeiaCard2,
        border: const Border(top: BorderSide(color: zeiaBorder)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = index == i;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i].$1, size: 27, color: selected ? Colors.white : zeiaMuted),
                  const SizedBox(height: 4),
                  Text(items[i].$2, style: TextStyle(color: selected ? Colors.white : zeiaMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
