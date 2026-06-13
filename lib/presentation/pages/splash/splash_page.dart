import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../../logic/auth/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<AuthBloc>().add(AuthCheckRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        }
      },
      builder: (context, state) {
        final isLoading =
            state is AuthInitial || state is AuthLoading;

        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogo(
                      size: 92,
                      light: true,
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Dompet Kampus',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'GLOBAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Bayar, transfer, dan kelola uang kuliah\n'
                      'dalam satu aplikasi yang aman.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    if (isLoading)
                      const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    else ...[
                      AppButton(
                        label: 'Buat Akun Baru',
                        variant: AppButtonVariant.white,
                        onPressed: () {
                          context.push('/register');
                        },
                      ),

                      const SizedBox(height: 16),

                      AppButton(
                        label: 'Masuk ke Akun',
                        variant: AppButtonVariant.outlineWhite,
                        onPressed: () {
                          context.push('/login');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
