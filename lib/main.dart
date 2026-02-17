import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/features/home/presentation/pages/main_navigation.dart';
import 'package:spark/firebase_options.dart';

import 'push_notifications.dart';
import 'features/auth/presentation/pages/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await PushNotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');

  Widget initialScreen = (token != null)
      ? const MainNavigation()
      : const OnboardingScreen();

  runApp(
    ProviderScope(
      child: MyApp(startScreen: initialScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spark App',

      // ⚠️ IMPORTANT: FCM navigation ke liye navigatorKey connect kar di
      navigatorKey: PushNotificationService.navigatorKey,

      // Purana Dark Theme logic
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10),
      ),

      // Auth logic ke hisab se screen
      home: startScreen,

      // Saare Routes jo pehle the + naye wale
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const MainNavigation(),
        // Notification click navigation ke liye ye bhi daal do
        '/chat': (context) => const MainNavigation(), // Ya jo bhi tera chat page hai
      },
    );
  }
}