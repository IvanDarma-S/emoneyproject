import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// TODO: Replace these placeholder imports with the actual package paths in your project.
// import 'package:go_router/go_router.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:your_app/core/di/service_locator.dart'; // exposes `sl`
// import 'package:your_app/core/theme/dkg_icons.dart'; // exposes `DkgIcons`
// import 'package:your_app/core/error/failures.dart'; // exposes `ServerFailure`
// import 'package:your_app/domain/usecases/auth/verify_email_otp_usecase.dart';
// import 'package:your_app/domain/usecases/otp/send_otp_email_usecase.dart';

/// Email OTP verification page.
///
/// Shows a 6-digit code input that auto-submits when filled, verifies the code
/// against [VerifyEmailOtpUsecase] and allows resending the code via
/// [SendOtpEmailUsecase] after a 60-second countdown.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  String _code = '';
  bool _hasError = false;
  String? _errorMessage;
  bool _loading = false;
  int _secondsLeft = 60;
  Timer? _timer;

  /// Key used to drive the [CodeInput] widget so we can clear it externally
  /// (e.g. after a failed verification attempt).
  final GlobalKey<_CodeInputState> _codeInputKey = GlobalKey<_CodeInputState>();

  /// Destination email address shown in the description text.
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Starts (or restarts) the 60-second resend countdown.
  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _onCodeChanged(String value) {
    setState(() {
      _code = value;
      _hasError = false;
      _errorMessage = null;
    });
    if (value.length == 6) _verify(value);
  }

  Future<void> _verify(String code) async {
    setState(() => _loading = true);
    try {
      await sl<VerifyEmailOtpUsecase>()(code);
      if (mounted) context.go('/setup-2fa');
    } on ServerFailure catch (e) {
      final isInvalidOtp = e.errorCode == 'INVALID_OTP';
      setState(() {
        _hasError = true;
        _errorMessage =
            isInvalidOtp ? 'Kode salah atau sudah kadaluarsa' : e.message;
      });
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          setState(() {
            _code = '';
            _hasError = false;
          });
          // Reflect the cleared value inside the CodeInput widget.
          _codeInputKey.currentState?.clear();
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    await sl<SendOtpEmailUsecase>()();
    _startTimer(); // reset countdown to 60
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/register'),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  const _EnvelopeWithCheck(),
                  const SizedBox(height: 32),
                  Text(
                    'Verifikasi email',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kami kirim kode 6 digit ke $_email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CodeInput(
                    key: _codeInputKey,
                    hasError: _hasError,
                    onChanged: _onCodeChanged,
                  ),
                  const SizedBox(height: 16),
                  if (_hasError && _errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  _buildResendSection(theme),
                ],
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.15),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResendSection(ThemeData theme) {
    if (_secondsLeft > 0) {
      return Text(
        'Kirim ulang kode dalam $_secondsLeft detik',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }
    return TextButton(
      onPressed: _resend,
      child: const Text('Kirim ulang kode'),
    );
  }
}

/// Envelope icon with a small green check badge in the corner.
class _EnvelopeWithCheck extends StatelessWidget {
  const _EnvelopeWithCheck();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              DkgIcons.mail,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 6-digit OTP input rendered as 6 separate boxes.
///
/// Uses a single hidden [TextField] to capture input while displaying the
/// digits in individual boxes. Auto-focuses on mount and fires [onChanged]
/// whenever the value changes. The value can be cleared externally via the
/// state's [clear] method (accessed through a [GlobalKey]).
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.onChanged,
    this.hasError = false,
    this.length = 6,
  });

  /// Fired whenever the entered code changes.
  final ValueChanged<String> onChanged;

  /// When true, the boxes render with a red border.
  final bool hasError;

  /// Number of digit boxes.
  final int length;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Clears the entered value (used after a failed verification).
  void clear() {
    _controller.clear();
    if (mounted) setState(() {});
    _focusNode.requestFocus();
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden text field that actually captures input.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              width: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: _handleChanged,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final text = _controller.text;
              final hasDigit = index < text.length;
              final isActive = index == text.length;

              final Color borderColor;
              if (widget.hasError) {
                borderColor = theme.colorScheme.error;
              } else if (isActive && _focusNode.hasFocus) {
                borderColor = theme.colorScheme.primary;
              } else {
                borderColor = theme.colorScheme.outline;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: 44,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: widget.hasError || isActive ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    hasDigit ? text[index] : '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
