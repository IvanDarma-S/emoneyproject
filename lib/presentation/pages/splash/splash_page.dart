import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(
          AuthCheckRequested(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthUnauthenticated) {
          // Tetap berada di splash page
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: Stack(
            children: [
              /// Dekorasi lingkaran atas kanan
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),

              /// Dekorasi lingkaran bawah kiri
              Positioned(
                bottom: -120,
                left: -100,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),

                      /// Logo
                      const AppLogo(
                        size: 92,
                        light: true,
                      ),

                      const SizedBox(height: 24),

                      /// Judul
                      const Text(
                        'Dompet Kampus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// Sub Judul
                      const Text(
                        'GLOBAL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// Tagline
                      const Text(
                        'Bayar, transfer, dan kelola uang kuliah\n'
                        'dalam satu aplikasi yang aman.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),

                      const Spacer(),

                      /// Tombol Register
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Buat Akun Baru',
                          variant: AppButtonVariant.white,
                          onPressed: () {
                            context.push('/register');
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// Tombol Login
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Masuk ke Akun',
                          variant: AppButtonVariant.outlineWhite,
                          onPressed: () {
                            context.push('/login');
                          },
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
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
