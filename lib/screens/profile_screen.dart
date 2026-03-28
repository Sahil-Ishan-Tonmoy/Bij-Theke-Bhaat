import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isEditing = false; // New state added for read-only vs edit mode

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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D5A27),
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Birth date cannot be empty')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cancel Edits',
              onPressed: () {
                setState(() => _isEditing = false);
              },
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF2D5A27),
                        child: Icon(Icons.person_rounded, size: 55, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  TextField(
                    controller: _nameController,
                    readOnly: !_isEditing,
                    // Inherits filled, color, and borderRadius from global Theme in main.dart
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF2D5A27)),
                    ),
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      color: _isEditing ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc_rounded, color: Color(0xFF2D5A27)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: _isEditing ? (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    } : null,
                  ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _isEditing ? _pickBirthDate : null,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Birth Date',
                        prefixIcon: Icon(Icons.cake_outlined, color: Color(0xFF2D5A27)),
                        suffixIcon: Icon(Icons.calendar_today_rounded, color: Color(0xFF2D5A27)),
                      ),
                      child: Text(
                        _selectedBirthDate == null
                            ? 'Select a date...'
                            : _selectedBirthDate!.toString().substring(0, 10),
                        style: TextStyle(
                          fontSize: 16, 
                          color: _isEditing ? Colors.black87 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email Address', 
                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF2D5A27)),
                      suffixIcon: Icon(Icons.lock_rounded, color: Colors.grey, size: 20),
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 48),

                  if (_isEditing)
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES'),
                    ),
                ],
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
