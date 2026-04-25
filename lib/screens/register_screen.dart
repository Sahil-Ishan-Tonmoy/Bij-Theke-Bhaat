import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedGender = 'Male';
  DateTime? _selectedBirthDate;
  
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (_selectedBirthDate == null) {
      setState(() => _errorMessage = 'Please select your birth date');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final uid = userCred.user!.uid;
      final birthDateString = _selectedBirthDate!.toString().substring(0, 10);
      
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'gender': _selectedGender,
        'birthDate': birthDateString,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenNotifications': FieldValue.serverTimestamp(),
        'hiddenNotifications': [],
        'role': 'Farmer', // Default role
      });
      
      await userCred.user!.sendEmailVerification();
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

  Widget _buildIllustrativeIcon() {
    return Center(
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 8,
              offset: const Offset(0, 8),
            )
          ]
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
            width: 110,
            height: 110,
          ),
        ),
      ),
    );
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          _buildIllustrativeIcon(),
                          const SizedBox(height: 32),
                          
                          Text(
                            s.translate('create_account'), 
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.translate('join_msg'),
                            style: TextStyle(
                              color: AppColors.secondaryText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          TextField(
                            controller: _nameController,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('full_name'), 
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.person_outline, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: AppColors.scaffoldBg,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('gender'), 
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.wc_outlined, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: [
                              DropdownMenuItem(value: 'Male', child: Text(s.isBengali ? 'পুরুষ' : 'Male')),
                              DropdownMenuItem(value: 'Female', child: Text(s.isBengali ? 'মহিলা' : 'Female')),
                              DropdownMenuItem(value: 'Other', child: Text(s.isBengali ? 'অন্যান্য' : 'Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGender = val);
                            },
                          ),
                          const SizedBox(height: 16),
    
                          InkWell(
                            onTap: _pickBirthDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: s.translate('birth_date'),
                                labelStyle: TextStyle(color: AppColors.secondaryText),
                                prefixIcon: Icon(Icons.cake_outlined, color: AppColors.accent),
                                suffixIcon: Icon(Icons.calendar_today, color: AppColors.accent),
                                filled: true, fillColor: AppColors.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                              child: Text(
                                _selectedBirthDate == null
                                    ? (s.isBengali ? 'তারিখ নির্বাচন করুন...' : 'Select a date...')
                                    : _selectedBirthDate!.toString().substring(0, 10),
                                style: TextStyle(
                                  fontSize: 16, 
                                  color: _selectedBirthDate == null ? AppColors.secondaryText.withOpacity(0.5) : AppColors.primaryText
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
    
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
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _passwordController,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('password_hint'),
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _confirmPasswordController,
                            style: TextStyle(color: AppColors.primaryText),
                            decoration: InputDecoration(
                              labelText: s.translate('confirm_password'),
                              labelStyle: TextStyle(color: AppColors.secondaryText),
                              prefixIcon: Icon(Icons.lock_reset_outlined, color: AppColors.accent),
                              filled: true, fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                            ),
                          
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            onPressed: _isLoading ? null : _register,
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(s.translate('register'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
                          ),
                          
                          const Spacer(),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: Text(
                              s.translate('have_account'),
                              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                            ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
