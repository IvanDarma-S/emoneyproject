import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_bloc_observer.dart';
// 1. IMPORT FILE INI (Pastikan Anda sudah menjalankan 'flutterfire configure')
import 'firebase_options.dart';
import 'injection/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = const AppBlocObserver();

  // 2. PERBAIKAN: Tambahkan options agar support Flutter Web & Mobile sekaligus
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize dependency injection
  await di.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DompetKampusApp());
}

class DompetKampusApp extends StatelessWidget {
  const DompetKampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dompet Kampus Global',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
