import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/marketplace_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          // CRITICAL SECURITY UPDATE: Check if email is verified
          if (!user.isAnonymous && !user.emailVerified) {
            return const VerifyEmailScreen();
          }
          
          if (user.isAnonymous) {
            return const MarketplaceScreen();
          }
          
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
