import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_gate.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;

  Future<void> _resendVerification() async {
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _checkVerification() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) {
       Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s.translate('verify_email'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          actions: const [
            AppMenuButton(),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Icon(Icons.mark_email_unread_outlined, size: 100, color: AppColors.accent),
                          const SizedBox(height: 32),
                          Text(
                            s.translate('verify_msg'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.translate('verify_check'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 48),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(s.translate('verify_done'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _checkVerification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _isSending ? null : _resendVerification,
                            child: _isSending 
                              ? CircularProgressIndicator(color: AppColors.accent) 
                              : Text(s.translate('resend'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.logout, color: Colors.redAccent),
                            onPressed: () {
                              FirebaseAuth.instance.signOut();
                              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
                            },
                            label: Text(s.translate('cancel_logout'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 10),
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
}
