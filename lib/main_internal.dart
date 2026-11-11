import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'viewmodels/motohub_viewmodel.dart';
import 'views/chat/chat_conversation_screen.dart';
import 'views/shared/cloud_sync_banner.dart';
import 'views/splash_screen.dart';

/// App A Entry Point: Internal ERP, POS & Bay Management System
/// Roles supported: Admin (`bossarman`), Cashier (`cashier01`), Mechanic (`mechanic01`)
/// Run command: `flutter run -t lib/main_internal.dart`
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('[Main] FCM background / notification init note: $e');
  }
  runApp(const BossArmanInternalApp());
}

class BossArmanInternalApp extends StatelessWidget {
  const BossArmanInternalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MotoHubViewModel>(
      create: (_) => MotoHubViewModel(isCustomerApp: false),
      child: MaterialApp(
        title: 'Boss Arman MotoHub • Internal ERP/POS',
        navigatorKey: NotificationService.navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name != null && settings.name!.startsWith('/chat/')) {
            final threadId = settings.name!.replaceFirst('/chat/', '');
            return MaterialPageRoute(
              builder: (_) => ChatConversationScreen(threadId: threadId),
            );
          }
          return null;
        },
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        builder: (context, child) => M3ETheme(
          data: AppTheme.expressiveTheme,
          // The inner Builder + Theme guarantee the slide transition
          // survives the M3ETheme wrapper.
          child: Builder(
            builder: (innerContext) => Theme(
              data: Theme.of(innerContext).copyWith(
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: SlidePageTransitionsBuilder(),
                    TargetPlatform.iOS: SlidePageTransitionsBuilder(),
                    TargetPlatform.windows: SlidePageTransitionsBuilder(),
                    TargetPlatform.macOS: SlidePageTransitionsBuilder(),
                    TargetPlatform.linux: SlidePageTransitionsBuilder(),
                    TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
                  },
                ),
              ),
              child: CloudSyncBanner(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
        home: const SplashScreen(isCustomerApp: false),
      ),
    );
  }
}
