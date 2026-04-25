import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/translate_text.dart';

class MarketPriceScreen extends StatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTranslatedUnit(String unit) {
    final s = AppSettings.instance;
    final lower = unit.toLowerCase();
    if (lower == 'mon') return s.translate('unit_mon');
    if (lower == 'kg') return s.translate('unit_kg');
    if (lower == 'ton') return s.translate('unit_ton');
    return unit;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('live_market_prices'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Live Search Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, spreadRadius: 1)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.primaryText),
                    decoration: InputDecoration(
                      hintText: s.translate('search_rice_hint'),
                      hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.5), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: AppColors.secondaryText),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Live Price Feed
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('market_prices').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppColors.primaryText)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: AppColors.accent));
                      }

                      var docs = snapshot.data?.docs ?? [];

                      // Apply search filter
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final variety = (data['variety'] ?? '').toString().toLowerCase();
                          return variety.contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: AppColors.secondaryText.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? '${s.isBengali ? "" : "No prices found for "}"$_searchQuery"${s.isBengali ? " এর জন্য কোনো দর পাওয়া যায়নি" : ""}'
                                    : (s.isBengali ? 'এই মুহূর্তে কোনো দর পাওয়া যাচ্ছে না।' : 'No prices available at the moment.'),
                                style: TextStyle(fontSize: 16, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final varietyRaw = (data['variety'] ?? data['name'] ?? 'Unknown').toString();
                          final price = data['price'] ?? '...';
                          final String? unitRaw = data['unit'];

                          final bool isMatch = _searchQuery.isNotEmpty && varietyRaw.toLowerCase().contains(_searchQuery);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isMatch
                                        ? AppColors.accent.withOpacity(0.15)
                                        : AppColors.glassFill,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isMatch
                                          ? AppColors.accent.withOpacity(0.6)
                                          : AppColors.glassBorder,
                                      width: isMatch ? 2 : 1.5,
                                    ),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 4), blurRadius: 10)],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isMatch ? AppColors.accent.withOpacity(0.2) : AppColors.accent.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.shopping_bag_rounded, color: AppColors.accent, size: 24),
                                    ),
                                    title: TranslateText(
                                      varietyRaw,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryText),
                                    ),
                                    subtitle: unitRaw != null
                                        ? Text('${s.translate('per_unit')} ${_getTranslatedUnit(unitRaw)}', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        s.translatePrice(price),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
