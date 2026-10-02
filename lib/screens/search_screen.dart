import 'dart:async';
import 'package:flutter/material.dart';
import '../api/zeia_api.dart';
import '../models/song.dart';
import '../theme/zeia_theme.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  List<String> suggestions = [];
  List<Song> results = [];
  Timer? timer;
  bool searching = false;
  String lastQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      controller.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery && widget.initialQuery.trim().isNotEmpty && widget.initialQuery.trim() != lastQuery) {
      controller.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    timer?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => suggestions = []);
      return;
    }
    timer = Timer(const Duration(milliseconds: 260), () async {
      final data = await ZeiaApi.suggestions(q);
      if (mounted && controller.text.trim() == q) setState(() => suggestions = data.take(7).toList());
    });
  }

  Future<void> _search([String? value]) async {
    final q = (value ?? controller.text).trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    controller.text = q;
    setState(() {
      searching = true;
      suggestions = [];
      lastQuery = q;
    });
    try {
      final data = await ZeiaApi.search(q);
      if (mounted) setState(() => results = data);
    } catch (_) {
      if (mounted) setState(() => results = []);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 170),
      children: [
        Row(children: [Expanded(child: TextField(controller: controller, onChanged: _onChanged, onSubmitted: (_) => _search(), textInputAction: TextInputAction.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: zeiaMuted), hintText: 'Search music'))), const SizedBox(width: 8), IconButton(onPressed: () => _search(), icon: const Icon(Icons.arrow_forward_rounded, size: 30), splashRadius: 26)]),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(decoration: BoxDecoration(color: zeiaCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Column(children: suggestions.map((s) => ListTile(leading: const Icon(Icons.search_rounded, color: zeiaMuted), title: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _search(s))).toList())),
        ],
        const SizedBox(height: 25),
        if (searching) const Padding(padding: EdgeInsets.only(top: 170), child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))))
        else if (results.isEmpty) const Padding(padding: EdgeInsets.only(top: 250), child: Center(child: Text('Cari lagu, artis, atau album', style: TextStyle(color: zeiaMuted, fontSize: 16))))
        else ...[
          if (lastQuery.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Hasil untuk "$lastQuery"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ...results.map((song) => SongTile(song: song, contextQueue: results)),
        ],
      ],
    );
  }
}
