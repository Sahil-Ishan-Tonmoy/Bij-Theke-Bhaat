import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_gate.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, 
    );
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("App init failed: $e");
  }

  runApp(const BijThekeBhatApp());
}

class BijThekeBhatApp extends StatelessWidget {
  const BijThekeBhatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bij Theke Bhat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2D5A27),
        scaffoldBackgroundColor: const Color(0xFFE8F5E9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5A27),
          primary: const Color(0xFF2D5A27),
          secondary: const Color(0xFF4CAF50),
          surface: Colors.white,
        ),
        // Applying Poppins default sans-serif font
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        
        // Deep Green modern App bars
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D5A27),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black26,
        ),
        
        // Floating Text Fields (No thin black borders, rounded, pure white backgrounds)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF2D5A27), width: 3), // Subtle bottom focus indicator
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          labelStyle: const TextStyle(color: Colors.black54),
        ),
        
        // Premium large rounded buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5A27),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0xFF2D5A27),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600, 
              letterSpacing: 1.2
            ),
          ),
        ),
        
        // Smooth rounded cards with soft shadow elevation
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
