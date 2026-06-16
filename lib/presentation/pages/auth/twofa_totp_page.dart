import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/auth/otp_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';

class TwoFATotpPage extends StatefulWidget {
  final String mode; // 'login' atau 'setup'

  const TwoFATotpPage({super.key, required this.mode});

  @override
  State<TwoFATotpPage> createState() => _TwoFATotpPageState();
}

class _TwoFATotpPageState extends State<TwoFATotpPage> {
  // State machine _step: "loading" -> "scan" (hanya setup) -> "code"
  String _step = "loading";

  String _code = '';
  bool _hasError = false;
  bool _copied = false;

  // Data dari state OtpTotpSetup untuk keperluan scan
  String? _qrCodeBase64;
  String? _secretKey;

  // Timer untuk TOTP TTL (Time-To-Live) 30 detik
  Timer? _ticker;
  int _ttl = 30;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'setup') {
      context.read<OtpBloc>().add(
        OtpRegisterTotp(),
      ); // Generate secret + QR dari server
    } else {
      setState(() => _step = 'code'); // Jika login, langsung minta kode input
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _ttl = _ttl <= 1 ? 30 : _ttl - 1);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onCodeChanged(String v) {
    setState(() {
      _code = v;
      _hasError = false;
    });
    if (v.length == 6) {
      context.read<OtpBloc>().add(OtpVerifyTotp(v));
    }
  }

  void _handleBackNavigation() {
    if (_step == 'code' && widget.mode == 'setup') {
      setState(() => _step = 'scan');
    } else {
      context.go(widget.mode == 'setup' ? '/setup-2fa' : '/login');
    }
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
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          widget.mode == 'setup' ? 'Setup Authenticator' : 'Verifikasi 2FA',
          style: const TextStyle(color: AppColors.ink),
        ),
      ),
      body: BlocListener<OtpBloc, OtpState>(
        listener: (context, state) {
          if (state is OtpTotpSetup) {
            setState(() {
              _step = 'scan';
              _qrCodeBase64 = state
                  .entity
                  .qrCode; // Asumsi entitas membawa string base64 / data URI
              _secretKey = state.entity.secret;
            });
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
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  // Router internal berdasarkan state machine _step
  Widget _buildCurrentStep() {
    switch (_step) {
      case 'scan':
        return _buildScanStep();
      case 'code':
        return _buildCodeStep();
      case 'loading':
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  // STEP 1: SCAN QR CODE (Khusus mode Setup)
  Widget _buildScanStep() {
    Uint8List? qrBytes;
    if (_qrCodeBase64 != null) {
      try {
        // Mendukung format pure base64 atau data URI scheme
        final cleanBase64 = _qrCodeBase64!.contains(',')
            ? _qrCodeBase64!.split(',')[1]
            : _qrCodeBase64!;
        qrBytes = base64Decode(cleanBase64.trim());
      } catch (_) {
        // Fallback jika format Uri.parse contentAsBytes diperlukan
        qrBytes = Uri.parse(_qrCodeBase64!).data?.contentAsBytes();
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('scan_step'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pindai QR Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Buka aplikasi authenticator Anda (Google Authenticator / Authy) lalu pindai kode QR di bawah.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Render QR Code dari memory bytes
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: qrBytes != null
                  ? Image.memory(qrBytes, width: 200, height: 200)
                  : const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: Text('Gagal memuat QR Code')),
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // Kotak Kunci Manual (Jika QR Code tidak bisa discan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Key / Kunci Manual',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _secretKey ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Tombol Salin dengan feedback visual 1.4 detik
                TextButton.icon(
                  onPressed: () async {
                    if (_secretKey == null) return;
                    await Clipboard.setData(ClipboardData(text: _secretKey!));
                    setState(() => _copied = true);
                    Future.delayed(const Duration(milliseconds: 1400), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _copied ? Colors.green : Colors.blue,
                  ),
                  icon: Icon(
                    _copied ? DkgIcons.check : DkgIcons.copy,
                    size: 18,
                  ),
                  label: Text(_copied ? 'Tersalin' : 'Salin'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Tombol Progres ke Step Input Kode
          ElevatedButton(
            onPressed: () => setState(() => _step = 'code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Saya sudah memindai',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: INPUT VERIFIKASI KODE TOTP
  Widget _buildCodeStep() {
    return SingleChildScrollView(
      key: const ValueKey('code_step'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Masukkan Kode Authenticator',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan 6 digit angka yang muncul di aplikasi authenticator milikmu.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Input field 6-digit kustom Anda
          Center(
            child: CodeInput(
              value: _code,
              onChanged: _onCodeChanged,
              hasError: _hasError,
            ),
          ),

          // Pesan error jika OtpInvalid
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _hasError
                ? const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Kode tidak cocok',
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
          const SizedBox(height: 48),

          // Circular countdown indicator visual untuk siklus 30 detik TOTP
          Center(
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  width: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _ttl / 30,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _ttl <= 5 ? Colors.red : Colors.purple,
                        ),
                        strokeWidth: 4,
                      ),
                      Text(
                        '$_ttl',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kode berganti dalam ${_ttl}s',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
