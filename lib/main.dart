import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'services/auth_gate.dart';
import 'services/notification_service.dart';
import 'services/app_settings.dart';
import 'firebase_options.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.initialize();
    await AppSettings.instance.loadSettings();
    await initializeDateFormatting('bn', null);
  } catch (e) {
    debugPrint('App init failed: $e');
  }
  runApp(const BijThekeBhatApp());
}

class BijThekeBhatApp extends StatefulWidget {
  const BijThekeBhatApp({super.key});
  @override
  State<BijThekeBhatApp> createState() => _BijThekeBhatAppState();
}

class _BijThekeBhatAppState extends State<BijThekeBhatApp> {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.themeMode.addListener(_rebuild);
    _settings.language.addListener(_rebuild);
  }

  @override
  void dispose() {
    _settings.themeMode.removeListener(_rebuild);
    _settings.language.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  TextTheme _buildTextTheme(TextTheme base) => _settings.isBengali
      ? GoogleFonts.hindSiliguriTextTheme(base)
      : GoogleFonts.poppinsTextTheme(base);

  ThemeData _light(BuildContext ctx) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2D5A27),
        scaffoldBackgroundColor: const Color(0xFFE8F5E9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5A27),
          primary: const Color(0xFF2D5A27),
          secondary: const Color(0xFF4CAF50),
          surface: Colors.white,
        ),
        textTheme: _buildTextTheme(Theme.of(ctx).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2D5A27),
          centerTitle: true,
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2D5A27), width: 3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          labelStyle: const TextStyle(color: Colors.black54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5A27),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

  ThemeData _dark(BuildContext ctx) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFF1A2B1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF81C784),
          surface: const Color(0xFF243424),
        ),
        textTheme: _buildTextTheme(Theme.of(ctx).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A2B1A),
          foregroundColor: Color(0xFF81C784),
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A3D2A),
          border: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          labelStyle: const TextStyle(color: Colors.white54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF243424),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bij Theke Bhat',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode.value,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.unknown},
      ),
      theme: _light(context),
      darkTheme: _dark(context),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
      ],
      locale: Locale(_settings.language.value),
      home: const AuthGate(),
    );
  }
}
