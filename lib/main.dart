import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/router/app_router.dart';
import 'core/services/deeplink_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_bloc_observer.dart';
import 'injection/injection_container.dart' as di;

// Top-level variable — mencegah DeeplinkService di-garbage collect selama
// proses berjalan sehingga uriLinkStream tetap aktif untuk in-app deeplinks.
late final DeeplinkService _deeplinkService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = const AppBlocObserver();

  // Initialize Firebase — pastikan google-services.json/GoogleService-Info.plist sudah ada
  await Firebase.initializeApp();

  // Initialize dependency injection
  await di.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Simpan instance agar tidak di-GC — stream subscription harus tetap hidup
  // untuk menerima in-app deeplinks via onNewIntent (Android singleTop).
  _deeplinkService = DeeplinkService(AppRouter.router);
  await _deeplinkService.init();

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
