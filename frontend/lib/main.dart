import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'src/core/theme.dart';
import 'src/features/onboarding/presentation/onboarding_screen.dart';
import 'src/features/auth/presentation/auth_screen.dart';
import 'src/features/dream/presentation/dream_diary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('dreams');
  
  runApp(
    const ProviderScope(
      child: AionApp(),
    ),
  );
}

class AionApp extends StatelessWidget {
  const AionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aion',
      theme: AionTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const DreamDiaryScreen(),
      },
    );
  }
}
