import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/otp_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';

class TwoFASmtpPage extends StatefulWidget {
  final String mode; // 'login' atau 'setup'

  const TwoFASmtpPage({super.key, required this.mode});

  @override
  State<TwoFASmtpPage> createState() => _TwoFASmtpPageState();
}

class _TwoFASmtpPageState extends State<TwoFASmtpPage> {
  String _code = '';
  bool _hasError = false;

  // Timer untuk Countdown Resend OTP
  Timer? _timer;
  int _start = AppConstants.otpResendSeconds;
  bool _isTimerActive = true;

  @override
  void initState() {
    super.initState();
    // Otomatis kirim email OTP saat halaman dibuka pertama kali
    context.read<OtpBloc>().add(OtpSendEmail());
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _start = AppConstants.otpResendSeconds;
    _isTimerActive = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_start == 0) {
        setState(() {
          _isTimerActive = false;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _onCodeChanged(String v) {
    setState(() {
      _code = v;
      _hasError = false;
    });
    if (v.length == 6) {
      context.read<OtpBloc>().add(
        OtpConfirm(code: v, otpType: AppConstants.otpTypeEmail),
      );
    }
  }

  Future<void> _resendOtp() async {
    context.read<OtpBloc>().add(OtpSendEmail());
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(DkgIcons.arrowLeft, color: AppColors.ink),
          onPressed: () {
            context.go(widget.mode == 'setup' ? '/setup-2fa' : '/login');
          },
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<OtpBloc, OtpState>(
            listener: (context, state) {
              if (state is OtpVerified) {
                if (widget.mode == 'setup') {
                  context.go('/home');
                } else {
                  // Panggil ulang AuthCheckRequested agar status auth_verified ter-refresh di local state/secure storage
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
          ),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // FeatureIcon amplop biru + judul
                const Center(
                  child: FeatureIcon(
                    icon: DkgIcons.mail,
                  ), // Menyesuaikan required argument icon Anda
                ),
                const SizedBox(height: 24),
                const Text(
                  'Masukkan Email OTP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // CodeInput kustom (Menerima parameter value sesuai hasil diagnosa sebelumnya)
                Center(
                  child: CodeInput(
                    value: _code,
                    onChanged: _onCodeChanged,
                    hasError: _hasError,
                  ),
                ),

                // Pesan Error Merah "Kode salah" saat OtpInvalid
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _hasError
                      ? const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: Text(
                            'Kode salah',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 32),

                // Info box kuning "Cek email inbox atau spam kamu"
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cek email inbox atau spam kamu',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Countdown -> Tombol Kirim Ulang
                Center(
                  child: BlocBuilder<OtpBloc, OtpState>(
                    builder: (context, state) {
                      final isOtpLoading = state is OtpLoading;

                      if (_isTimerActive) {
                        return Text(
                          'Kirim ulang kode dalam $_start detik',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        );
                      }

                      return TextButton(
                        onPressed: isOtpLoading ? null : _resendOtp,
                        child: Text(
                          isOtpLoading ? 'Mengirim...' : 'Kirim ulang kode',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
