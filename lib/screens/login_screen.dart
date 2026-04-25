import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginAsBuyer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCredential.user!.uid;
      
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': 'Anonymous Buyer',
        'name': 'Guest Buyer',
        'gender': 'Not Specified',
        'birthDate': DateTime.now().toIso8601String(),
        'sowingDate': DateTime.now(),
        'role': 'Buyer',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenNotifications': FieldValue.serverTimestamp(),
        'hiddenNotifications': [],
      }, SetOptions(merge: true));

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: const [AppMenuButton()],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),
                          Center(
                            child: Hero(
                              tag: 'logo',
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(Icons.eco_rounded, size: 80, color: AppColors.accent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(s.translate('welcome_back_msg'), textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryText, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(s.translate('signin_msg'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                          const SizedBox(height: 48),
                          
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                            ),

                          TextField(
                            controller: _emailController,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('email'),
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('password_hint'),
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: AppColors.accent.withOpacity(0.4),
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(s.translate('login'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: Text(s.translate('no_account'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(flex: 2),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text(s.translate('guest_buyer')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondaryText,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isLoading ? null : _loginAsBuyer,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
