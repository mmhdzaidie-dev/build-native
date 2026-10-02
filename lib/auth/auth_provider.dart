import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class ZeiaAuthProvider extends ChangeNotifier {
  Session? session;
  bool loading = true;
  String? error;
  StreamSubscription<AuthState>? _subscription;

  bool get configured => SupabaseService.configured;
  bool get signedIn => session != null;
  User? get user => session?.user;

  Future<void> init() async {
    if (!configured) {
      loading = false;
      notifyListeners();
      return;
    }
    session = SupabaseService.client.auth.currentSession;
    _subscription = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      session = data.session;
      loading = false;
      error = null;
      notifyListeners();
    });
    loading = false;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await SupabaseService.client.auth.signInWithPassword(email: email.trim(), password: password);
      session = response.session;
      if (session == null) throw const AuthException('Email belum terverifikasi atau sesi belum tersedia.');
      return true;
    } on AuthException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = '$e';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await SupabaseService.client.auth.signUp(email: email.trim(), password: password, data: {'display_name': name.trim()});
      session = response.session;
      if (response.user == null) throw const AuthException('Pendaftaran gagal.');
      return true;
    } on AuthException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = '$e';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!configured) return;
    await SupabaseService.client.auth.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
