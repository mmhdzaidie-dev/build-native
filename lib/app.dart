import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/auth_provider.dart';
import 'auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/player_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/mini_player.dart';
import 'theme/zeia_theme.dart';

class ZeiaApp extends StatelessWidget {
  const ZeiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ZeiaAuthProvider>();
    if (auth.loading) return MaterialApp(debugShowCheckedModeBanner: false, theme: zeiaTheme(), home: const _Splash());
    if (auth.configured && !auth.signedIn) return MaterialApp(debugShowCheckedModeBanner: false, theme: zeiaTheme(), home: const AuthScreen());
    return const _MainShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(backgroundColor: zeiaBg, body: Center(child: Image.asset('assets/logo.png', width: 72, height: 72))));
}

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  var tab = 0;
  var searchQuery = '';

  void openPlayer(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, animation, __) => const PlayerScreen(),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: zeiaTheme(),
      home: Scaffold(
        backgroundColor: zeiaBg,
        body: SafeArea(
          bottom: false,
          child: Stack(children: [
            Positioned.fill(child: IndexedStack(index: tab, children: [HomeScreen(onSearch: (query) => setState(() { searchQuery = query; tab = 1; }),), SearchScreen(initialQuery: searchQuery), const LibraryScreen(), const ProfileScreen()])),
            Positioned(left: 12, right: 12, bottom: 78, child: MiniPlayer(onOpen: () => openPlayer(context))),
            Positioned(left: 0, right: 0, bottom: 0, child: ZeiaBottomNav(index: tab, onChanged: (value) => setState(() => tab = value))),
          ]),
        ),
      ),
    );
  }
}
