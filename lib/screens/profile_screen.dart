import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/supabase_service.dart';
import '../theme/zeia_theme.dart';
import '../widgets/song_tile.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    if (!SupabaseService.configured || SupabaseService.client.auth.currentUser == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final user = SupabaseService.client.auth.currentUser!;
      final row = await SupabaseService.client.from('profiles').select('id,display_name,bio,avatar_url,created_at').eq('id', user.id).maybeSingle();
      if (!mounted) return;
      if (row != null) {
        setState(() {
          profile = Map<String, dynamic>.from(row);
          loading = false;
        });
        return;
      }
      final metadataName = '${user.userMetadata?['display_name'] ?? ''}'.trim();
      final name = metadataName.isNotEmpty ? metadataName : (user.email?.split('@').first ?? 'ZEIA User');
      final created = await SupabaseService.client.from('profiles').upsert({'id': user.id, 'display_name': name}, onConflict: 'id').select('id,display_name,bio,avatar_url,created_at').single();
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(created);
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1200);
    if (file == null || !mounted) return;
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;
      final ext = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final objectPath = '${user.id}/avatar.$ext';
      await SupabaseService.client.storage.from('avatars').upload(objectPath, File(file.path), fileOptions: FileOptions(upsert: true, contentType: ext == 'png' ? 'image/png' : 'image/jpeg', cacheControl: '3600'));
      final url = '${SupabaseService.client.storage.from('avatars').getPublicUrl(objectPath)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await SupabaseService.client.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      if (!mounted) return;
      setState(() => profile = {...?profile, 'avatar_url': url});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah foto: $e')));
    }
  }

  Future<void> _editProfile() async {
    final pageContext = context;
    final name = TextEditingController(text: '${profile?['display_name'] ?? ''}');
    final bio = TextEditingController(text: '${profile?['bio'] ?? ''}');
    final ok = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: zeiaCard,
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, name.text.trim().isNotEmpty), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) {
      name.dispose();
      bio.dispose();
      return;
    }
    if (ok == true && name.text.trim().isNotEmpty) {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client.from('profiles').update({'display_name': name.text.trim(), 'bio': bio.text.trim()}).eq('id', user.id);
        if (mounted) {
          setState(() => profile = {...?profile, 'display_name': name.text.trim(), 'bio': bio.text.trim()});
        }
      }
    }
    name.dispose();
    bio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.read<PlayerProvider>();
    final auth = context.read<ZeiaAuthProvider>();
    final songs = library.liked;
    final name = '${profile?['display_name'] ?? 'ZEIA User'}';
    final bio = '${profile?['bio'] ?? ''}';
    final avatar = '${profile?['avatar_url'] ?? ''}';

    return Scaffold(
      backgroundColor: zeiaBg,
      appBar: AppBar(
        backgroundColor: zeiaBg,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: auth.signOut, icon: const Icon(Icons.logout_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Center(child: GestureDetector(onTap: _pickAvatar, child: _avatar(avatar, 104))),
                const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: Text('Tap foto untuk ganti', style: TextStyle(color: zeiaMuted, fontSize: 11)))),
                const SizedBox(height: 12),
                Center(child: Text(name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: zeiaMuted))),
                ],
                const SizedBox(height: 18),
                Center(child: Text('${songs.length} Liked Songs', style: const TextStyle(fontWeight: FontWeight.w800, color: zeiaMuted))),
                const SizedBox(height: 18),
                OutlinedButton.icon(onPressed: _editProfile, icon: const Icon(Icons.edit_rounded), label: const Text('Edit profile')),
                const SizedBox(height: 22),
                const Text('Liked Songs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (songs.isNotEmpty) ...[
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => player.playSong(songs.first, list: songs), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Putar semua'))),
                  const SizedBox(height: 10),
                  ...songs.map((song) => SongTile(song: song, contextQueue: songs)),
                ] else
                  const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('Belum ada lagu yang disukai.', style: TextStyle(color: zeiaMuted)))),
              ],
            ),
    );
  }

  Widget _avatar(String url, double size) {
    if (url.isNotEmpty) {
      return ClipOval(child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, __, ___) => _avatarFallback(size)));
    }
    return _avatarFallback(size);
  }

  Widget _avatarFallback(double size) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: zeiaCard2, border: Border.all(color: Colors.white12)), child: Icon(Icons.person_rounded, size: size * .48, color: zeiaMuted));
}

