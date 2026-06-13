import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dkg_icons.dart';
import '../../bloc/otp/otp_bloc.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';

class TwofaTotpPage extends StatefulWidget {
  final String mode;

  const TwofaTotpPage({super.key, this.mode = 'login'});

  @override
  State<TwofaTotpPage> createState() => _TwofaTotpPageState();
}

class _TwofaTotpPageState extends State<TwofaTotpPage> {
  String _step = 'loading';
  String _code = '';
  bool _hasError = false;
  bool _copied = false;
  int _ttl = 30;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'setup') {
      context.read<OtpBloc>().add(OtpRegisterTotp()); // generate secret + QR
    } else {
      setState(() => _step = 'code');
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _ttl = _ttl <= 1 ? 30 : _ttl - 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onBack() {
    if (_step == 'code' && widget.mode == 'setup') {
      setState(() {
        _step = 'scan';
        _code = '';
        _hasError = false;
      });
    } else {
      context.go(widget.mode == 'setup' ? '/setup-2fa' : '/login');
    }
  }

  void _onCodeChanged(String v) {
    setState(() {
      _code = v;
      _hasError = false;
    });
    if (v.length == 6) context.read<OtpBloc>().add(OtpVerifyTotp(v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(DkgIcons.arrowLeft, color: AppColors.ink),
          onPressed: _onBack,
        ),
      ),
      body: SafeArea(
        child: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            if (state is OtpTotpSetup) {
              setState(() => _step = 'scan'); // tampilkan QR + secret
            } else if (state is OtpTotpEnabled || state is OtpVerified) {
              context.go('/home');
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
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 'scan':
        return _buildScan();
      case 'code':
        return _buildCode();
      case 'loading':
      default:
        return const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        );
    }
  }

  Widget _buildScan() {
    return BlocBuilder<OtpBloc, OtpState>(
      buildWhen: (prev, curr) => curr is OtpTotpSetup,
      builder: (context, state) {
        if (state is! OtpTotpSetup) {
          return const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final qrCode = state.entity.qrCode;
        final secret = state.entity.secret;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const FeatureIcon(icon: DkgIcons.smartphone, tone: 'violet'),
            const SizedBox(height: 16),
            const Text(
              'Pindai dengan Authenticator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pindai QR code di bawah dengan Google Authenticator atau Authy.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.ink.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ink.withOpacity(0.12)),
                ),
                child: Image.memory(
                  Uri.parse(qrCode).data!.contentAsBytes(),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ink.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ink.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunci manual',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          secret,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: secret));
                          setState(() => _copied = true);
                          Future.delayed(
                              const Duration(milliseconds: 1400), () {
                            if (mounted) setState(() => _copied = false);
                          });
                        },
                        icon: Icon(
                          _copied ? DkgIcons.check : DkgIcons.copy,
                          size: 18,
                          color: _copied
                              ? const Color(0xFF16A34A)
                              : AppColors.ink,
                        ),
                        label: Text(
                          _copied ? 'Tersalin' : 'Salin',
                          style: TextStyle(
                            color: _copied
                                ? const Color(0xFF16A34A)
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 'code'),
                child: const Text('Saya sudah memindai'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const FeatureIcon(icon: DkgIcons.smartphone, tone: 'violet'),
        const SizedBox(height: 16),
        const Text(
          'Masukkan kode Authenticator',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan kode 6 digit dari aplikasi Authenticator kamu.',
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
            'Kode tidak cocok',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: _ttl / 30,
                        strokeWidth: 4,
                        backgroundColor: AppColors.ink.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF7C3AED)),
                      ),
                    ),
                    Text(
                      '$_ttl',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Kode berganti dalam ${_ttl}s',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
