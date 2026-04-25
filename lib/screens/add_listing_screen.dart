import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _cropType = 'Aman Rice';
  String _unit = 'Mon';
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  final List<String> _cropTypes = [
    'Aman Rice',
    'Boro Rice',
    'Aus Rice',
    'Miniket',
    'Basmati',
    'Nazirshail',
    'Kataribhog'
  ];
  final List<String> _units = ['Mon', 'Kg', 'Ton'];

  String _getTranslatedUnit(String unit) {
    final s = AppSettings.instance;
    switch (unit) {
      case 'Mon': return s.translate('unit_mon');
      case 'Kg': return s.translate('unit_kg');
      case 'Ton': return s.translate('unit_ton');
      default: return unit;
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    final s = AppSettings.instance;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final sellerName = userDoc.data()?['name'] ?? 'Unknown Farmer';

      await FirebaseFirestore.instance.collection('marketplace_listings').add({
        'sellerUid': user.uid,
        'sellerName': sellerName,
        'cropType': _cropType,
        'quantity': double.parse(_quantityController.text),
        'unit': _unit,
        'price': double.parse(_priceController.text),
        'phone': _phoneController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      try {
        await FirebaseFirestore.instance.collection('notifications').add({
           'title': 'New $_cropType Available! 🚜',
           'body': '$sellerName just listed ${double.parse(_quantityController.text)} $_unit of $_cropType for ৳${_priceController.text}/$_unit.',
           'type': 'market',
           'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.isBengali ? '✅ বিজ্ঞাপনটি সফলভাবে পোস্ট করা হয়েছে!' : 'Rice Listing posted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.isBengali ? 'পণ্য বিক্রি করুন' : 'Sell Your Crop', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.translate('yield_details'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _cropType,
                        style: TextStyle(color: AppColors.primaryText),
                        dropdownColor: AppColors.scaffoldBg,
                        decoration: InputDecoration(
                          labelText: s.translate('crop_variety'),
                          labelStyle: TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: _cropTypes.map((type) => DropdownMenuItem(value: type, child: TranslateText(type))).toList(),
                        onChanged: (val) => setState(() => _cropType = val!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: AppColors.primaryText),
                              decoration: InputDecoration(
                                labelText: s.translate('quantity'),
                                labelStyle: TextStyle(color: AppColors.secondaryText),
                                filled: true,
                                fillColor: AppColors.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                              validator: (val) => val == null || val.isEmpty ? (s.isBengali ? 'প্রয়োজনীয়' : 'Required') : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _unit,
                              style: TextStyle(color: AppColors.primaryText),
                              dropdownColor: AppColors.scaffoldBg,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                              items: _units.map((unit) => DropdownMenuItem(value: unit, child: Text(_getTranslatedUnit(unit)))).toList(),
                              onChanged: (val) => setState(() => _unit = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: '${s.translate('price_per_unit')} (৳/${_getTranslatedUnit(_unit)})',
                          labelStyle: TextStyle(color: AppColors.secondaryText),
                          prefixText: '৳ ',
                          prefixStyle: TextStyle(color: AppColors.primaryText),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (val) => val == null || val.isEmpty ? (s.isBengali ? 'প্রয়োজনীয়' : 'Required') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: s.translate('contact_phone'),
                          labelStyle: TextStyle(color: AppColors.secondaryText),
                          prefixIcon: Icon(Icons.phone, color: AppColors.accent),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return s.isBengali ? 'ক্রেতার যোগাযোগের জন্য ফোন নম্বর প্রয়োজন' : 'Phone required for buyers to call you';
                          if (val.length < 10) return s.isBengali ? 'সঠিক ফোন নম্বর দিন' : 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _submitListing,
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(s.translate('post_listing'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
