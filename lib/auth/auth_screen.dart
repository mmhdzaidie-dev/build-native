import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/zeia_theme.dart';
import 'auth_provider.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  var register = false;
  var obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final auth = context.read<ZeiaAuthProvider>();
    FocusManager.instance.primaryFocus?.unfocus();
    final mail = email.text.trim();
    final pass = password.text;
    if (mail.isEmpty || !mail.contains('@') || pass.length < 6 || (register && name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi data dengan benar. Password minimal 6 karakter.')));
      return;
    }
    final ok = register ? await auth.signUp(name.text, mail, pass) : await auth.signIn(mail, pass);
    if (!mounted) return;
    if (ok && register && auth.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun dibuat. Cek email untuk verifikasi jika konfirmasi email aktif.')));
    }
    if (!ok && auth.error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ZeiaAuthProvider>();
    return Scaffold(
      backgroundColor: zeiaBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 78, height: 78, decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24)]), child: ClipRRect(borderRadius: BorderRadius.circular(25), child: Image.asset('assets/logo.png', fit: BoxFit.cover)))),
              const SizedBox(height: 28),
              Text(register ? 'Create your space.' : 'Welcome back.', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
              const SizedBox(height: 8),
              Text(register ? 'Buat akun ZEIA dan sinkronkan musikmu di semua perangkat.' : 'Masuk ke ZEIA untuk melanjutkan musikmu.', style: const TextStyle(color: zeiaMuted, fontSize: 15, height: 1.45)),
              const SizedBox(height: 30),
              if (register) ...[
                const Text('Nama', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Nama kamu', prefixIcon: Icon(Icons.person_outline_rounded))),
                const SizedBox(height: 16),
              ],
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded))),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(controller: password, obscureText: obscure, onSubmitted: (_) => submit(), decoration: InputDecoration(hintText: 'Minimal 6 karakter', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded)))),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: auth.loading ? null : submit, child: auth.loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(register ? 'Create account' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w900)))),
              const SizedBox(height: 18),
              Center(child: TextButton(onPressed: auth.loading ? null : () => setState(() => register = !register), child: Text(register ? 'Sudah punya akun? Sign in' : 'Belum punya akun? Create account'))),
              if (!auth.configured) const Padding(padding: EdgeInsets.only(top: 24), child: Text('Supabase belum dikonfigurasi. Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY sebelum login.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orangeAccent))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
