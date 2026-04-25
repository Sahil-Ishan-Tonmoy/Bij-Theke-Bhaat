import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedGender = 'Male';
  DateTime? _selectedBirthDate;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false; 

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        
        if (data['gender'] != null) {
          _selectedGender = data['gender'];
        }
        
        if (data['birthDate'] != null) {
          _selectedBirthDate = DateTime.tryParse(data['birthDate']);
        }
      } else {
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickBirthDate() async {
    if (!_isEditing) return; 
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
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

  Future<void> _saveProfile() async {
    final s = AppSettings.instance;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.isBengali ? 'নাম খালি রাখা যাবে না' : 'Name cannot be empty')));
      return;
    }
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.isBengali ? 'জন্ম তারিখ নির্বাচন করুন' : 'Birth date cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final birthDateString = _selectedBirthDate!.toString().substring(0, 10);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'gender': _selectedGender,
          'birthDate': birthDateString,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          setState(() => _isEditing = false); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.isBengali ? 'প্রোফাইল সফলভাবে আপডেট করা হয়েছে!' : 'Profile updated successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('profile'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: s.translate('edit_profile'),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: s.isBengali ? 'বাতিল করুন' : 'Cancel Edits',
              onPressed: () {
                setState(() => _isEditing = false);
              },
            ),
          const AppMenuButton(),
        ],
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accent.withOpacity(0.2),
                                            blurRadius: 30,
                                            spreadRadius: 5,
                                          )
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: AppColors.accent,
                                        child: const Icon(Icons.person_rounded, size: 70, color: Colors.white),
                                      ),
                                    ),
                                    if (_isEditing)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppColors.accentLight, shape: BoxShape.circle),
                                          child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                              TextField(
                                controller: _nameController,
                                readOnly: !_isEditing,
                                style: TextStyle(
                                  color: _isEditing ? AppColors.primaryText : AppColors.secondaryText,
                                ),
                                decoration: InputDecoration(
                                  labelText: s.translate('full_name'),
                                  labelStyle: TextStyle(color: AppColors.secondaryText),
                                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.accent),
                                  filled: true, fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                              
                              DropdownButtonFormField<String>(
                                value: _selectedGender,
                                dropdownColor: AppColors.scaffoldBg,
                                style: TextStyle(color: _isEditing ? AppColors.primaryText : AppColors.secondaryText),
                                decoration: InputDecoration(
                                  labelText: s.translate('gender'),
                                  labelStyle: TextStyle(color: AppColors.secondaryText),
                                  prefixIcon: Icon(Icons.wc_rounded, color: AppColors.accent),
                                  filled: true, fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'Male', child: Text(s.isBengali ? 'পুরুষ' : 'Male')),
                                  DropdownMenuItem(value: 'Female', child: Text(s.isBengali ? 'মহিলা' : 'Female')),
                                  DropdownMenuItem(value: 'Other', child: Text(s.isBengali ? 'অন্যান্য' : 'Other')),
                                ],
                                onChanged: _isEditing ? (val) {
                                  if (val != null) setState(() => _selectedGender = val);
                                } : null,
                              ),
                              const SizedBox(height: 16),

                              InkWell(
                                onTap: _isEditing ? _pickBirthDate : null,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: s.translate('birth_date'),
                                    labelStyle: TextStyle(color: AppColors.secondaryText),
                                    prefixIcon: Icon(Icons.cake_outlined, color: AppColors.accent),
                                    suffixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.accent),
                                    filled: true, fillColor: AppColors.inputFill,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
                                  child: Text(
                                    _selectedBirthDate == null
                                        ? (s.isBengali ? 'তারিখ নির্বাচন করুন...' : 'Select a date...')
                                        : s.translatePrice(_selectedBirthDate!.toString().substring(0, 10)),
                                    style: TextStyle(
                                      fontSize: 16, 
                                      color: _isEditing ? AppColors.primaryText : AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              TextField(
                                controller: _emailController,
                                readOnly: true,
                                style: TextStyle(color: AppColors.secondaryText),
                                decoration: InputDecoration(
                                  labelText: s.translate('email'), 
                                  labelStyle: TextStyle(color: AppColors.secondaryText),
                                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.accent),
                                  suffixIcon: const Icon(Icons.lock_rounded, color: Colors.grey, size: 20),
                                  filled: true, fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                ),
                              ),
                              
                              const Spacer(),
                              const SizedBox(height: 32),

                              if (_isEditing)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 8,
                                    shadowColor: AppColors.accent.withOpacity(0.4),
                                  ),
                                  onPressed: _isSaving ? null : _saveProfile,
                                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(s.translate('save_changes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
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
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
