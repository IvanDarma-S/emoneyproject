
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';


import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();

  String get _email => _emailController.text.trim();
  String get _pw => _pwController.text;

  bool _gLoading = false;       // loading khusus tombol Google
  bool _obscurePw = true;       // toggle show/hide kata sandi

  // Validasi sederhana: email mengandung "@" & "." dan password >= 6 karakter
  bool get _valid {
    final email = _email;
    final pw = _pw;
    final emailOk = email.contains('@') && email.contains('.');
    return emailOk && pw.length >= 6;
  }

  @override
  void initState() {
    super.initState();
    // Update tombol "Masuk" enable/disable secara real-time
    _emailController.addListener(_onChanged);
    _pwController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------
  Future<void> _loginWithGoogle() async {
    setState(() => _gLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // agar dialog pilih akun selalu muncul
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _gLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null && mounted) {
        context.read<AuthBloc>().add(AuthLoginWithFirebase(idToken));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Gagal masuk dengan Google')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Email & Password Sign-In
  // ---------------------------------------------------------------------------
  Future<void> _loginWithEmail() async {
    if (!_valid) return;
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _pw,
      );
      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null && mounted) {
        context.read<AuthBloc>().add(AuthLoginWithFirebase(idToken));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Email atau kata sandi salah')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthNeedsVerification) {
              context.go('/2fa/smtp');
            } else if (state is AuthAuthenticated) {
              context.go('/home');
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Logo + Judul
                const Center(child: AppLogo()),
                const SizedBox(height: 24),
                Text(
                  'Masuk',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selamat datang kembali',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),

                // Tombol "Lanjut dengan Google"
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isConnecting = state is AuthLoading || _gLoading;
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isConnecting ? null : _loginWithGoogle,
                      icon: isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Image.asset(
                              'assets/icons/google.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.login, size: 20),
                            ),
                      label: Text(
                        isConnecting ? 'Menghubungkan…' : 'Lanjut dengan Google',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Divider "atau email"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau email',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 24),

                // AppField Email
                AppField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'nama@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // AppField Kata sandi (dengan toggle show/hide)
                AppField(
                  controller: _pwController,
                  label: 'Kata sandi',
                  hintText: 'Masukkan kata sandi',
                  obscureText: _obscurePw,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePw ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePw = !_obscurePw),
                  ),
                ),
                const SizedBox(height: 12),

                // Link "Lupa kata sandi?"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Lupa kata sandi?'),
                  ),
                ),
                const SizedBox(height: 16),

                // Tombol "Masuk"
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return AppButton(
                      text: 'Masuk',
                      isLoading: isLoading,
                      onPressed: (_valid && !isLoading) ? _loginWithEmail : null,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Link "Belum punya akun? Daftar"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text(
                        'Daftar',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
