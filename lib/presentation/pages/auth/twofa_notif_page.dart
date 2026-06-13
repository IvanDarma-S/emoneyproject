import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../bloc/otp/otp_bloc.dart';
import '../../widgets/feature_icon.dart';

class TwofaNotifPage extends StatefulWidget {
  final String mode;

  const TwofaNotifPage({super.key, this.mode = 'login'});

  @override
  State<TwofaNotifPage> createState() => _TwofaNotifPageState();
}

class _TwofaNotifPageState extends State<TwofaNotifPage> {
  String _phase = 'waiting';

  @override
  void initState() {
    super.initState();
    context.read<OtpBloc>().add(OtpSendFirebase());
  }

  void _onBack() {
    context.go(widget.mode == 'setup' ? '/setup-2fa' : '/login');
  }

  void _onResend() {
    context.read<OtpBloc>().add(OtpSendFirebase());
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _phase == 'approved';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: _onBack,
        ),
      ),
      body: SafeArea(
        child: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            if (state is OtpVerified) {
              setState(() => _phase = 'approved');
              Future.delayed(const Duration(milliseconds: 900), () {
                if (mounted) context.go('/home');
              });
            } else if (state is OtpError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.red,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                FeatureIcon(
                  icon: isApproved
                      ? Icons.verified_user_outlined
                      : Icons.notifications_outlined,
                  tone: 'green',
                ),
                const SizedBox(height: 16),
                Text(
                  isApproved ? 'Disetujui!' : 'Cek notifikasi kamu',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isApproved
                      ? 'Verifikasi berhasil. Mengalihkan kamu...'
                      : 'Kami telah mengirim notifikasi ke perangkat kamu. '
                          'Buka notifikasi dan setujui untuk melanjutkan.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.ink.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                if (!isApproved) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Menunggu persetujuan…',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _onResend,
                    child: const Text(
                      'Tidak menerima notifikasi? Kirim ulang',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
