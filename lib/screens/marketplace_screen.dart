import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'add_listing_screen.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final user = FirebaseAuth.instance.currentUser;
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
    switch (unit) {
      case 'Mon': return s.translate('unit_mon');
      case 'Kg': return s.translate('unit_kg');
      case 'Ton': return s.translate('unit_ton');
      default: return unit;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final s = AppSettings.instance;
    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (cleanPhone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.isBengali ? 'ফোন নম্বর পাওয়া যায়নি।' : 'Phone number not available.')));
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      // Direct launch is more reliable for 'tel' links on Web/Chrome
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.isBengali ? 'ফোন ডায়ালার চালু করা যাচ্ছে না।' : 'Could not trigger Phone dialer.')));
      }
    }
  }

  Future<void> _deleteListing(String docId) async {
    await FirebaseFirestore.instance.collection('marketplace_listings').doc(docId).delete();
  }

  Widget _buildSearchBar() {
    final s = AppSettings.instance;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          hintText: s.isBengali ? 'ফসলের নাম বা কৃষকের নাম দিয়ে খুঁজুন...' : 'Search by crop type or farmer name...',
          hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.5), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.black38),
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
    );
  }

  Widget _buildListingCard(Map<String, dynamic> data, String docId) {
    final s = AppSettings.instance;
    bool isMyListing = user != null && user!.uid == data['sellerUid'];
    final createdAt = data['timestamp'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt.toDate())
        : (s.isBengali ? 'অজানা সময়' : 'Unknown Time');

    final cropName = data['cropType'] ?? '';
    final unitName = _getTranslatedUnit(data['unit'] ?? '');

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMyListing ? AppColors.accent.withOpacity(0.5) : AppColors.glassBorder,
              width: 1.5,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: TranslateText(cropName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText))),
                        Text(" ${s.isBengali ? 'উৎপাদন' : 'Yield'}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                    child: Text("৳ ${s.translatePrice(data['price'].toString())} / $unitName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text("${s.isBengali ? 'পরিমাণ' : 'Quantity'}: ${s.translatePrice(data['quantity'].toString())} $unitName", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.primaryText)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.person_outline, size: 18, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Text("${s.isBengali ? 'কৃষক' : 'Farmer'}: ${data['sellerName']}", style: TextStyle(fontSize: 15, color: AppColors.bodyText)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_outlined, size: 18, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Text("${s.isBengali ? 'পোস্ট করা হয়েছে' : 'Posted'}: ${s.translatePrice(dateStr)}", style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              ]),
              const SizedBox(height: 16),
              if (isMyListing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteListing(docId),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: Text(s.isBengali ? 'বিক্রয় হয়েছে / মুছে ফেলুন' : 'Mark as Sold / Delete', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.glassFill,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(data['phone'] ?? ''),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: Text("${s.isBengali ? 'কল করুন' : 'Call Seller'}: ${s.translatePrice(data['phone'] ?? '')}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamFeed({required bool myListingsOnly}) {
    final s = AppSettings.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('marketplace_listings').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              myListingsOnly 
                ? (s.isBengali ? 'আপনি এখনও কোনো বিজ্ঞাপন দেননি।' : 'You haven\'t posted any crops yet.') 
                : (s.isBengali ? 'বর্তমানে কোনো পণ্য নেই।\nপ্রথম বিজ্ঞাপনটি আপনিই দিন!' : 'No crops currently listed.\nBe the first to sell!'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        if (myListingsOnly && user != null) {
          docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['sellerUid'] == user!.uid).toList();
        }

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final crop = (data['cropType'] ?? '').toString().toLowerCase();
            final seller = (data['sellerName'] ?? '').toString().toLowerCase();
            return crop.contains(_searchQuery) || seller.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: AppColors.secondaryText.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty 
                    ? (s.isBengali ? '"$_searchQuery" এর জন্য কিছু পাওয়া যায়নি' : 'No results for "$_searchQuery"') 
                    : (s.translate('no_items')),
                  style: TextStyle(fontSize: 18, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildListingCard(data, doc.id);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    bool isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous == true;

    if (isAnonymous) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s.translate('marketplace'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.appBarText),
          actions: [
            const AppMenuButton(),
          ],
        ),
        body: ThemeAware(
          builder: (context) => Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildSearchBar(),
                  Expanded(child: _buildStreamFeed(myListingsOnly: false)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s.translate('marketplace'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.appBarText),
          actions: const [AppMenuButton()],
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelColor: AppColors.primaryText,
            unselectedLabelColor: AppColors.secondaryText,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: s.translate('all_items'), icon: const Icon(Icons.public)),
              Tab(text: s.translate('my_listings'), icon: const Icon(Icons.inventory)),
            ],
          ),
        ),
        body: ThemeAware(
          builder: (context) => Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildStreamFeed(myListingsOnly: false),
                        _buildStreamFeed(myListingsOnly: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
          label: Text(s.isBengali ? 'বিক্রয় করুন' : 'Sell Crop', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen())),
        ),
      ),
    );
  }
}
