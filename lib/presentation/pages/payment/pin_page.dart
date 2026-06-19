import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/deeplink_callback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/datasources/local/secure_storage_datasource.dart';
import '../../../injection/injection_container.dart';
import '../../blocs/auth/otp_bloc.dart';
import '../../blocs/payment/payment_bloc.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';
import '../../widgets/pin_pad.dart';

enum _Step { pin, otp }

class PinPage extends StatefulWidget {
  final Map<String, dynamic> flowData;
  const PinPage({super.key, required this.flowData});

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  _Step _step = _Step.pin;
  String _pin = '';
  String _otpCode = '';
  bool _busy = false;
  bool _otpError = false;

  // 2FA method aktif ('smtp' | 'totp' | 'notif'), default ke TOTP.
  String _twoFaMethod = AppConstants.twoFaTotp;

  int _resendTimer = AppConstants.otpResendSeconds;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  // Step 1: PIN selesai diketik → tentukan apakah perlu OTP/2FA atau langsung diproses.
  void _onPinComplete(String pin) {
    setState(() {
      _pin = pin;
      _busy = true;
    });

    final kind = widget.flowData['kind'] as String? ?? '';
    if (kind == AppConstants.txnTopup) {
      context.read<PaymentBloc>().add(PaymentTopupRequested(
        (widget.flowData['amount'] as num).toDouble(),
      ));
    } else {
      _prepareOtpStep();
    }
  }

  // Baca metode 2FA yang dikonfigurasi user, lalu kirim OTP (smtp/notif) atau
  // langsung tampilkan input kode (totp).
  Future<void> _prepareOtpStep() async {
    final method = await sl<SecureStorageDatasource>().get2faMethod();
    if (!mounted) return;

    setState(() {
      _twoFaMethod = method ?? AppConstants.twoFaTotp;
      _busy = false;
      _step = _Step.otp;
    });

    if (_twoFaMethod == AppConstants.twoFaSmtp) {
      context.read<OtpBloc>().add(OtpSendEmail());
      _startResendTimer();
    } else if (_twoFaMethod == AppConstants.twoFaNotif) {
      context.read<OtpBloc>().add(OtpSendFirebase());
      _startResendTimer();
    }
  }

  void _startResendTimer() {
    _countdown?.cancel();
    setState(() => _resendTimer = AppConstants.otpResendSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendTimer <= 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  void _resendOtp() {
    if (_twoFaMethod == AppConstants.twoFaSmtp) {
      context.read<OtpBloc>().add(OtpSendEmail());
    } else if (_twoFaMethod == AppConstants.twoFaNotif) {
      context.read<OtpBloc>().add(OtpSendFirebase());
    }
    _startResendTimer();
  }

  // Mapping metode 2FA → otp_type yang dipahami backend.
  String get _otpType {
    switch (_twoFaMethod) {
      case AppConstants.twoFaSmtp:
        return AppConstants.otpTypeEmail;
      case AppConstants.twoFaNotif:
        return AppConstants.otpTypeFirebase;
      default:
        return AppConstants.otpTypeTotp;
    }
  }

  String _descriptionFor(Map<String, dynamic> flow) {
    final kind = flow['kind'] as String? ?? '';
    if (kind == AppConstants.txnTransfer) {
      return flow['note'] as String? ?? 'Transfer';
    }
    return flow['description'] as String? ?? 'Pembayaran';
  }

  // Kembalikan callbackUrl jika ini flow deeplink merchant, null jika bukan.
  String? get _callbackUrl {
    final kind = widget.flowData['kind'] as String? ?? '';
    if (kind != 'deeplink') return null;
    final url = widget.flowData['callbackUrl'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  String? get _callbackReference => widget.flowData['reference'] as String?;

  void _onOtpChanged(String v) {
    setState(() {
      _otpCode = v;
      _otpError = false;
    });
    if (v.length == AppConstants.otpLength) {
      _submitPayment(v);
    }
  }

  // Step 2: kode OTP/TOTP lengkap → kirim ke endpoint transfer/pembayaran.
  void _submitPayment(String code) {
    setState(() => _busy = true);
    final flow = widget.flowData;
    context.read<PaymentBloc>().add(PaymentTransferRequested(
      amount: (flow['amount'] as num).toDouble(),
      description: _descriptionFor(flow),
      otpCode: code,
      otpType: _otpType,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PaymentBloc, PaymentState>(
          listener: (context, state) {
            if (state is PaymentTransferSuccess) {
              final result = state.result;
              // Kirim callback sukses ke app merchant (fire-and-forget, best-effort).
              final cb = _callbackUrl;
              if (cb != null) {
                DeeplinkCallbackService.notifySuccess(
                  callbackUrl: cb,
                  reference: _callbackReference,
                  transactionId: result.transactionId,
                );
              }
              context.go('/success', extra: {
                'title': 'Pembayaran berhasil',
                'subtitle': result.description,
                'amount': result.amount,
                'lines': [
                  ['Jumlah', CurrencyFormatter.format(result.amount)],
                  ['Saldo setelah', CurrencyFormatter.format(result.balanceAfter)],
                  ['Ref', 'DKG${result.transactionId}'],
                ],
              });
            } else if (state is PaymentTopupSuccess) {
              context.go('/success', extra: {
                'title': 'Top up berhasil',
                'subtitle': 'Saldo kamu bertambah',
                'amount': state.amount,
                'lines': [
                  ['Jumlah', CurrencyFormatter.format(state.amount)],
                  ['Saldo sekarang', CurrencyFormatter.format(state.balance)],
                ],
              });
            } else if (state is PaymentInvalidOtp) {
              setState(() {
                _busy = false;
                _otpError = true;
                _otpCode = '';
              });
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) setState(() => _otpError = false);
              });
            } else if (state is PaymentInsufficientBalance) {
              setState(() => _busy = false);
              // Callback gagal — saldo tidak cukup.
              final cb = _callbackUrl;
              if (cb != null) {
                DeeplinkCallbackService.notifyFailed(
                  callbackUrl: cb,
                  reference: _callbackReference,
                  errorMessage: 'insufficient_balance',
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Saldo tidak cukup. Saldo kamu saat ini ${CurrencyFormatter.format(state.balance)}.'),
                  backgroundColor: AppColors.red,
                ),
              );
            } else if (state is PaymentError) {
              setState(() => _busy = false);
              // Callback gagal — error server/jaringan.
              final cb = _callbackUrl;
              if (cb != null) {
                DeeplinkCallbackService.notifyFailed(
                  callbackUrl: cb,
                  reference: _callbackReference,
                  errorMessage: 'payment_error',
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
              );
            }
          },
        ),
        BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            if (state is OtpError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.red),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  onPressed: () {
                    if (_step == _Step.otp && !_busy) {
                      _countdown?.cancel();
                      setState(() {
                        _step = _Step.pin;
                        _pin = '';
                        _otpCode = '';
                      });
                    } else {
                      // Kirim callback cancelled jika user membatalkan dari flow deeplink.
                      final cb = _callbackUrl;
                      if (cb != null) {
                        DeeplinkCallbackService.notifyCancelled(
                          callbackUrl: cb,
                          reference: _callbackReference,
                        );
                      }
                      context.go('/home');
                    }
                  },
                ),
              ),
              if (_busy) ...[
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 18),
                      Text('Memproses transaksi…',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate600,
                          )),
                    ],
                  ),
                ),
              ] else if (_step == _Step.pin) ...[
                Expanded(child: _buildPinStep()),
              ] else ...[
                Expanded(child: _buildOtpStep()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Icon(Icons.lock_outline_rounded, size: 26, color: AppColors.primary)),
          ),
          const SizedBox(height: 16),
          const Text('Masukkan PIN',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              )),
          const SizedBox(height: 6),
          const Text('Masukkan 6 digit PIN keamanan kamu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.slate500)),
          const Spacer(),
          PinPad(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            onComplete: _onPinComplete,
          ),
          const SizedBox(height: 18),
          const Text.rich(TextSpan(
            text: 'Lupa PIN? ',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.slate400),
            children: [
              TextSpan(
                text: 'Reset',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final header = _otpHeader;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        children: [
          FeatureIcon(icon: header.icon, tone: header.tone, size: 74, iconSize: 36),
          const SizedBox(height: 18),
          Text(header.title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 8),
          Text(header.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: AppColors.slate500, height: 1.55)),
          const SizedBox(height: 28),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: _otpError ? (Matrix4.identity()..translateByDouble(8.0, 0, 0, 1)) : Matrix4.identity(),
            child: CodeInput(value: _otpCode, onChanged: _onOtpChanged, hasError: _otpError),
          ),
          if (_otpError) ...[
            const SizedBox(height: 12),
            const Text('Kode OTP salah, silakan coba lagi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: AppColors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(DkgIcons.shieldCheck, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total pembayaran ${CurrencyFormatter.format((widget.flowData['amount'] as num).toDouble())}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_twoFaMethod != AppConstants.twoFaTotp) ...[
            _resendTimer > 0
                ? Text(
                    'Kirim ulang dalam 00:${_resendTimer.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.slate400),
                  )
                : TextButton.icon(
                    onPressed: _resendOtp,
                    icon: const Icon(DkgIcons.refresh, size: 16, color: AppColors.primary),
                    label: const Text('Kirim ulang kode',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                  ),
          ],
        ],
      ),
    );
  }

  ({IconData icon, String tone, String title, String subtitle}) get _otpHeader {
    switch (_twoFaMethod) {
      case AppConstants.twoFaSmtp:
        return (
          icon: DkgIcons.mail,
          tone: 'blue',
          title: 'Masukkan Kode OTP Email',
          subtitle: 'Kode 6 digit dikirim ke email kamu via SMTP untuk konfirmasi pembayaran.',
        );
      case AppConstants.twoFaNotif:
        return (
          icon: Icons.notifications_outlined,
          tone: 'green',
          title: 'Masukkan Kode OTP',
          subtitle: 'Kami mengirim kode verifikasi ke notifikasi perangkat kamu.',
        );
      default:
        return (
          icon: DkgIcons.smartphone,
          tone: 'violet',
          title: 'Masukkan Kode Authenticator',
          subtitle: 'Buka aplikasi authenticator kamu dan masukkan kode yang sedang aktif.',
        );
    }
  }
}
