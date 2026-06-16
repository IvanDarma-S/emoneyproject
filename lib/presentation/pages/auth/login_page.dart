import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _email = '';
  String _pw = '';

  bool _gLoading = false;
  bool _obscurePw = true;

  // Validasi email dengan regex yang lebih akurat
  bool get _valid {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    final emailOk = emailRegex.hasMatch(_email.trim());
    return emailOk && _pw.length >= 6;
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------
  Future<void> _loginWithGoogle() async {
    setState(() => _gLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
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
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
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
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email.trim(), password: _pw);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken != null && mounted) {
        context.read<AuthBloc>().add(AuthLoginWithFirebase(idToken));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan token. Silakan coba lagi'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Email atau kata sandi salah';
        if (e.code == 'user-not-found') {
          message = 'Email tidak terdaftar';
        } else if (e.code == 'wrong-password') {
          message = 'Kata sandi salah';
        } else if (e.code == 'invalid-email') {
          message = 'Format email tidak valid';
        } else if (e.code == 'user-disabled') {
          message = 'Akun telah dinonaktifkan';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
                        isConnecting
                            ? 'Menghubungkan…'
                            : 'Lanjut dengan Google',
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
                  label: 'Email',
                  placeholder: 'nama@email.com',
                  value: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (val) => setState(() => _email = val),
                ),
                const SizedBox(height: 16),

                // AppField Kata sandi (dengan toggle show/hide)
                AppField(
                  label: 'Kata sandi',
                  placeholder: 'Masukkan kata sandi',
                  value: _pw,
                  obscureText: _obscurePw,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) => setState(() => _pw = val),
                  onEditingComplete: () {
                    if (_valid) _loginWithEmail();
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePw ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscurePw = !_obscurePw),
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
                      label: 'Masuk',
                      isLoading: isLoading,
                      onPressed: (_valid && !isLoading)
                          ? _loginWithEmail
                          : null,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
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
