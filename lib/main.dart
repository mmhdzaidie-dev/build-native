import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'auth/auth_provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'services/audio_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  final library = LibraryProvider();
  final audio = ZeiaAudioService();
  final player = PlayerProvider(audio, onPlayed: library.recordPlayed);
  final auth = ZeiaAuthProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: player),
      ],
      child: const ZeiaApp(),
    ),
  );
  unawaited(auth.init());
  unawaited(library.init());
  unawaited(player.initialize());
  if (defaultTargetPlatform == TargetPlatform.android) unawaited(Permission.notification.request());
}
