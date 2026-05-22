import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'student_panel.dart';
import 'admin_panel.dart';
import 'teacher_dashboard.dart';

void main() {
  runApp(const ProctorSystemApp());
}

class ProctorSystemApp extends StatelessWidget {
  const ProctorSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: 'ProctorAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00E5FF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF080B12),
          cardTheme: CardThemeData(
            color: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        home: const _Gate(),
        routes: {
          '/login': (context) => const AuthScreen(),
          '/student_home': (context) => const StudentPanel(),
          '/admin_home': (context) => const AdminPanel(),
          '/teacher_home': (context) => const TeacherDashboard(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isAuthenticated) return const AuthScreen();
    if (state.isTeacher) return const TeacherDashboard();
    if (state.isProctor) return const AdminPanel();
    if (!state.isProfileComplete && state.isStudent) {
      // Redirect students to complete profile before accessing dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/profile');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const StudentPanel();
  }
}
