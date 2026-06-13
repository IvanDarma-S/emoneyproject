import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dkg_icons.dart';
import '../../widgets/app_button.dart';

class Setup2faPage extends StatefulWidget {
  const Setup2faPage({super.key});

  @override
  State<Setup2faPage> createState() => _Setup2faPageState();
}

class _TwoFaMethod {
  final String key;
  final IconData icon;
  final String tone;
  final String title;
  final String desc;
  final String route;
  final String? badge;

  const _TwoFaMethod({
    required this.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.desc,
    required this.route,
    this.badge,
  });
}

const _twoFaMethods = [
  _TwoFaMethod(
      key: 'smtp',
      icon: DkgIcons.mail,
      tone: 'blue',
      title: 'Email OTP (SMTP)',
      desc: 'Kode 6 digit dikirim ke email kamu setiap kali masuk.',
      route: '/2fa/smtp'),
  _TwoFaMethod(
      key: 'totp',
      icon: DkgIcons.smartphone,
      tone: 'violet',
      title: 'Authenticator (TOTP)',
      desc: 'Kode berubah tiap 30 detik di Google Authenticator / Authy.',
      route: '/2fa/totp',
      badge: 'Paling aman'),
  _TwoFaMethod(
      key: 'notif',
      icon: DkgIcons.bell,
      tone: 'green',
      title: 'Notifikasi OTP',
      desc: 'Setujui permintaan masuk lewat notifikasi di HP kamu.',
      route: '/2fa/notif'),
];

Color _toneColor(String tone) {
  switch (tone) {
    case 'blue':
      return const Color(0xFF2563EB);
    case 'violet':
      return const Color(0xFF7C3AED);
    case 'green':
      return const Color(0xFF16A34A);
    default:
      return AppColors.ink;
  }
}

class _Setup2faPageState extends State<Setup2faPage> {
  String _selected = 'smtp';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(DkgIcons.arrowLeft, color: AppColors.ink),
          onPressed: () => context.canPop() ? context.pop() : context.go('/akun'),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(DkgIcons.shieldCheck,
                          color: AppColors.ink, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Amankan akunmu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih metode verifikasi 2 langkah untuk melindungi akunmu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.ink.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._twoFaMethods.map((m) {
                      final selected = m.key == _selected;
                      final tone = _toneColor(m.tone);
                      return GestureDetector(
                        onTap: () => setState(() => _selected = m.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selected
                                ? tone.withOpacity(0.06)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? tone
                                  : AppColors.ink.withOpacity(0.12),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tone.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(m.icon, color: tone, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            m.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        if (m.badge != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tone.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              m.badge!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: tone,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.desc,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.ink.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _RadioIndicator(selected: selected, tone: tone),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AppButton(
                label: 'Lanjutkan',
                onPressed: () {
                  final m =
                      _twoFaMethods.firstWhere((m) => m.key == _selected);
                  context.go(m.route, extra: {'mode': 'setup'});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;
  final Color tone;

  const _RadioIndicator({required this.selected, required this.tone});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? tone : AppColors.ink.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone,
                ),
              ),
            )
          : null,
    );
  }
}
