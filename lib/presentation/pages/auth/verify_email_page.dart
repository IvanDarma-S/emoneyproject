import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error/failures.dart';
import '../../../domain/usecases/auth/send_otp_usecase.dart';
import '../../../domain/usecases/auth/verify_email_otp_usecase.dart';
import '../../../injection/injection_container.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  late final TextEditingController _pinController;
  late final FocusNode _focusNode;
  late Timer _timer;

  final String _code = '';

  bool _loading = false;
  bool _hasError = false;
  bool _isTimerActive = true;
  bool _isVerifying = false;
  String? _errorMessage;
  int _start = 60;

  static const int _initialCountdown = 60;
  static const int _errorDisplayDuration = 650;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _focusNode = FocusNode();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _start = _initialCountdown;
    _isTimerActive = true;
    _timer.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    if (_start == 0) {
      setState(() => _isTimerActive = false);
      timer.cancel();
      return;
    }

    setState(() => _start--);
  }

  void _onCodeChanged(String value) {
    if (_hasError || _errorMessage != null) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }

    if (value.length == 6 && !_isVerifying) {
      _verify(value);
    }
  }

  Future<void> _verify(String code) async {
    if (_isVerifying) return;

    _isVerifying = true;
    setState(() => _loading = true);

    try {
      await sl<VerifyEmailOtpUsecase>()(code);
      if (mounted) context.go('/setup-2fa');
    } on ServerFailure catch (e) {
      _handleVerifyError(e);
    } catch (e) {
      _handleUnexpectedError();
    } finally {
      _isVerifying = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleVerifyError(ServerFailure error) {
    if (!mounted) return;

    final isInvalidOtp = error.errorCode == 'INVALID_OTP';
    setState(() {
      _hasError = true;
      _errorMessage = isInvalidOtp
          ? 'Kode salah atau sudah kadaluarsa'
          : error.message;
    });

    Future.delayed(Duration(milliseconds: _errorDisplayDuration), () {
      if (mounted) {
        setState(() => _hasError = false);
        _pinController.clear();
        _focusNode.requestFocus();
      }
    });
  }

  void _handleUnexpectedError() {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
    });
  }

  Future<void> _resend() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await sl<SendOtpEmailUsecase>()();
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengirim ulang kode OTP. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildErrorMessage() {
    if (!_hasError || _errorMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red, fontSize: 14),
      ),
    );
  }

  Widget _buildResendButton() {
    return _isTimerActive
        ? Text(
            'Kirim ulang dalam $_start detik',
            style: const TextStyle(fontSize: 14),
          )
        : ElevatedButton(
            onPressed: _loading ? null : _resend,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim Ulang Kode'),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Berikan argument icon yang required ke FeatureIcon
            const FeatureIcon(
              icon: Icons.mail_outline,
            ), // Sesuaikan dengan parameter icon Anda (bisa DkgIcons.mail jika tipenya IconData)
            const SizedBox(height: 24),
            const Text('Masukkan Kode OTP'),
            const SizedBox(height: 16),

            // 2. Sesuaikan parameter CodeInput dengan constructor aslinya
            CodeInput(
              value: _code, // Karena error bilang parameter 'value' required
              onChanged: _onCodeChanged,
              hasError: _hasError,
              // Hapus controller dan focusNode jika widget CodeInput Anda memang tidak mendukungnya
            ),
            _buildErrorMessage(),
            const SizedBox(height: 24),
            _buildResendButton(),
          ],
        ),
      ),
    );
  }
}
