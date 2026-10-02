import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class ZeiaAuthProvider extends ChangeNotifier {
  Session? session;
  bool loading = true;
  String? error;
  String? pendingEmail;
  String? pendingName;
  StreamSubscription<AuthState>? _subscription;

  bool get configured => SupabaseService.configured;
  bool get signedIn => session != null;
  bool get otpPending => pendingEmail != null && session == null;
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
      if (session != null) {
        pendingEmail = null;
        pendingName = null;
      }
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
      if (session == null) throw const AuthException('Login belum menghasilkan sesi. Periksa email dan password.');
      notifyListeners();
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
      final cleanEmail = email.trim();
      final cleanName = name.trim();
      final response = await SupabaseService.client.auth.signUp(email: cleanEmail, password: password, data: {'display_name': cleanName});
      if (response.user == null) throw const AuthException('Pendaftaran gagal.');
      session = response.session;
      if (session == null) {
        pendingEmail = cleanEmail;
        pendingName = cleanName;
      }
      notifyListeners();
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

  Future<bool> verifySignupOtp(String token) async {
    final mail = pendingEmail;
    if (mail == null) {
      error = 'Sesi verifikasi tidak ditemukan. Silakan daftar kembali.';
      notifyListeners();
      return false;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await SupabaseService.client.auth.verifyOTP(type: OtpType.email, token: token.trim(), email: mail);
      session = response.session;
      if (session == null) throw const AuthException('Kode berhasil diproses tetapi sesi belum tersedia. Silakan coba login.');
      pendingEmail = null;
      pendingName = null;
      notifyListeners();
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

  Future<bool> resendSignupOtp() async {
    final mail = pendingEmail;
    if (mail == null) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await SupabaseService.client.auth.resend(type: OtpType.signup, email: mail);
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

  void cancelOtp() {
    pendingEmail = null;
    pendingName = null;
    error = null;
    notifyListeners();
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
