import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (_) {}
  runApp(const MinerbaApp());
}

class MinerbaApp extends StatelessWidget {
  const MinerbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Konservasi Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFDF5),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF18181B), // Solid Black Accent
          onPrimary: Colors.white,
          secondary: Color(0xFFF59E0B), // Warm Minerba Amber Gold
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF18181B),
          error: Color(0xFFDC2626),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF18181B),
          scrolledUnderElevation: 1.5,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFDE68A), width: 1),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
