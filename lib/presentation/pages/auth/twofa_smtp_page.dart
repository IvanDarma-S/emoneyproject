import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/otp/otp_bloc.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';

class TwofaSmtpPage extends StatefulWidget {
  final String mode;

  const TwofaSmtpPage({super.key, this.mode = 'login'});

  @override
  State<TwofaSmtpPage> createState() => _TwofaSmtpPageState();
}

class _TwofaSmtpPageState extends State<TwofaSmtpPage> {
  String _code = '';
  bool _hasError = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    context.read<OtpBloc>().add(OtpSendEmail()); // POST /v1/otp/send-email
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onCodeChanged(String v) {
    setState(() {
      _code = v;
      _hasError = false;
    });
    if (v.length == 6) {
      context
          .read<OtpBloc>()
          .add(OtpConfirm(code: v, otpType: AppConstants.otpTypeEmail));
    }
  }

  void _resend() {
    context.read<OtpBloc>().add(OtpSendEmail());
    setState(() {
      _code = '';
      _hasError = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => context
              .go(widget.mode == 'setup' ? '/setup-2fa' : '/login'),
        ),
      ),
      body: SafeArea(
        child: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            if (state is OtpVerified) {
              if (widget.mode == 'setup') {
                context.go('/home');
              } else {
                context.read<AuthBloc>().add(AuthCheckRequested());
                context.go('/home');
              }
            } else if (state is OtpInvalid) {
              setState(() => _hasError = true);
              Future.delayed(const Duration(milliseconds: 650), () {
                if (mounted) {
                  setState(() {
                    _code = '';
                    _hasError = false;
                  });
                }
              });
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const FeatureIcon(
                  icon: Icons.mail_outline,
                  tone: 'blue',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Masukkan Email OTP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan kode 6 digit yang kami kirim ke email kamu.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.ink.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                CodeInput(
                  length: 6,
                  value: _code,
                  hasError: _hasError,
                  onChanged: _onCodeChanged,
                ),
                if (_hasError) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Kode salah',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFCA8A04), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cek email inbox atau spam kamu',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF854D0E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _secondsLeft > 0
                      ? Text(
                          'Kirim ulang kode dalam $_secondsLeft detik',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.ink.withOpacity(0.5),
                          ),
                        )
                      : TextButton(
                          onPressed: _resend,
                          child: const Text(
                            'Kirim ulang kode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
