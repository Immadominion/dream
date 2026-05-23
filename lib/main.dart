import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/logger_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/widgets/session_manager.dart';
import 'shared/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize storage service
  await StorageService.initialize();

  // Initialize local notifications (before ProviderScope so the service
  // is ready when providers first resolve)
  final logger = LoggerService();
  final notifications = NotificationService(logger: logger);
  await notifications.initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Provide the already-initialized NotificationService so Riverpod
        // consumers get the same instance without re-initializing.
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const DreamApp(),
    ),
  );
}

class DreamApp extends ConsumerWidget {
  const DreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone 13 Pro design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return SessionManager(
          child: MaterialApp.router(
            title: 'Dream',
            debugShowCheckedModeBanner: false,

            // Theme Configuration — always dark
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,

            // Router Configuration
            routerConfig: router,

            // Builder for responsive design
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
                  ),
                ),
                child: child!,
              );
            },
          ),
        );
      },
    );
  }
}
