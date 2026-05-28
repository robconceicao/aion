import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/core/theme.dart';
import 'src/features/onboarding/presentation/onboarding_screen.dart';
import 'src/features/auth/presentation/auth_screen.dart';
import 'src/features/dream/presentation/dream_diary_screen.dart';
import 'src/features/dream/presentation/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AionNotificationService.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://gfpicpmopbmvlyslnrrr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmcGljcG1vcGJtdmx5c2xucnJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5OTM5NzEsImV4cCI6MjA5NTU2OTk3MX0.exLLr6vYBG7E2LCMSOLV_Nc6y-pBuBxskXJTKM9iYCk',
  );

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
