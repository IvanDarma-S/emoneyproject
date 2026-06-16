import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import '../../../core/error/failures.dart';
import '../../../domain/usecases/auth/register_with_otp_usecase.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final sl = GetIt.instance;

  String _name = '';
  String _email = '';
  String _pw = '';
  bool _agree = false;
  bool _loading = false;

  bool get _valid =>
      _name.length > 1 && _email.contains('@') && _pw.length >= 6 && _agree;

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      // 1. Buat akun di Firebase
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: _email, password: _pw);
      await credential.user?.updateDisplayName(_name);

      // 2. Ambil Firebase ID Token lalu kirim ke backend
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) throw Exception('Gagal mendapatkan token Firebase');

      await sl<RegisterWithOtpUsecase>()(idToken);

      // 3. Backend sudah buat user + kirim OTP ke email -> ke halaman verifikasi
      if (mounted) context.go('/verify-email');
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? 'Terjadi kesalahan');
    } on ServerFailure catch (e) {
      _showErrorSnackBar(e.message);
    } on NetworkFailure catch (_) {
      _showErrorSnackBar('Tidak ada koneksi internet.');
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _name = value),
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => _email = value),
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => _pw = value),
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agree,
                onChanged: (value) => setState(() => _agree = value ?? false),
                title: const Text('Saya setuju dengan syarat & ketentuan'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valid && !_loading ? _register : null,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Daftar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
