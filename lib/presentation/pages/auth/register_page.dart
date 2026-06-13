import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/dkg_icons.dart';
import '../../../domain/usecases/register_with_otp_usecase.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String _name = '';
  String _email = '';
  String _pw = '';

  bool _agree = true;
  bool _loading = false;
  bool _obscurePassword = true;

  bool get _valid =>
      _name.length > 1 &&
      _email.contains('@') &&
      _pw.length >= 6 &&
      _agree;

  Future<void> _register() async {
    if (!_valid || _loading) return;

    setState(() => _loading = true);

    try {
      // 1. Buat akun Firebase
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.trim(),
        password: _pw,
      );

      await credential.user?.updateDisplayName(_name);

      // 2. Ambil Firebase ID Token
      final idToken = await credential.user?.getIdToken();

      if (idToken == null) {
        throw Exception('Gagal mendapatkan token Firebase');
      }

      // 3. Kirim ke backend
      await sl<RegisterWithOtpUsecase>()(idToken);

      // 4. Ke halaman verifikasi email
      if (mounted) {
        context.go('/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Terjadi kesalahan saat membuat akun.',
          ),
        ),
      );
    } on ServerFailure catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } on NetworkFailure {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada koneksi internet.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Back Button
              IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(DkgIcons.arrowLeft),
              ),

              const SizedBox(height: 20),

              /// Title
              const Text(
                'Buat akun',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Daftar gratis dalam 1 menit',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 32),

              /// Nama Lengkap
              AppField(
                label: 'Nama lengkap',
                prefixIcon: DkgIcons.user,
                onChanged: (value) {
                  setState(() => _name = value.trim());
                },
              ),

              const SizedBox(height: 16),

              /// Email
              AppField(
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: DkgIcons.mail,
                onChanged: (value) {
                  setState(() => _email = value.trim());
                },
              ),

              const SizedBox(height: 16),

              /// Password
              AppField(
                label: 'Kata sandi',
                prefixIcon: DkgIcons.lock,
                obscureText: _obscurePassword,
                onChanged: (value) {
                  setState(() => _pw = value);
                },
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? DkgIcons.eye
                        : DkgIcons.eyeOff,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// Agreement Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    _agree = !_agree;
                  });
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agree,
                      onChanged: (value) {
                        setState(() {
                          _agree = value ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// Register Button
              AppButton(
                label: 'Daftar',
                onPressed: _valid && !_loading
                    ? _register
                    : null,
                loading: _loading,
              ),

              const SizedBox(height: 24),

              /// Login Link
              Center(
                child: TextButton(
                  onPressed: () {
                    context.go('/login');
                  },
                  child: const Text(
                    'Sudah punya akun? Masuk',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
