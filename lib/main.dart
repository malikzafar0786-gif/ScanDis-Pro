import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';
import 'services/db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.instance.init(); // local encrypted Isar store, ready before first frame
  runApp(const ProviderScope(child: ScanDisApp()));
}

class ScanDisApp extends StatelessWidget {
  const ScanDisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanDis',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const DashboardScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg = Color(0xFF0B131F);
    const accent = Color(0xFF00F2FE);

    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: bg,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: const Color(0xFF14202E),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
