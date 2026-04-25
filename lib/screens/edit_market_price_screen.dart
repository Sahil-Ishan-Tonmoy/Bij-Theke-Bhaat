import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class EditMarketPriceScreen extends StatefulWidget {
  const EditMarketPriceScreen({super.key});

  @override
  State<EditMarketPriceScreen> createState() => _EditMarketPriceScreenState();
}

class _EditMarketPriceScreenState extends State<EditMarketPriceScreen> {
  final _firestore = FirebaseFirestore.instance.collection('market_prices');

  void _logNotification(String title, String body, String type) {
    FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showEditDialog([DocumentSnapshot? doc]) {
    final s = AppSettings.instance;
    final bool isUpdate = doc != null;
    final varietyController = TextEditingController(text: isUpdate ? doc['variety'] : '');
    final priceController = TextEditingController(text: isUpdate ? doc['price'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            isUpdate ? s.translate('edit_price') : s.translate('add_new_price'),
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: varietyController,
                style: TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: s.translate('variety_hint'),
                  hintStyle: TextStyle(color: AppColors.hintText),
                  prefixIcon: Icon(Icons.grass_rounded, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                enabled: !isUpdate,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                style: TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: s.translate('price_hint'),
                  hintStyle: TextStyle(color: AppColors.hintText),
                  prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.isBengali ? 'বাতিল' : 'Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () async {
                final variety = varietyController.text.trim();
                final price = priceController.text.trim();
                if (variety.isEmpty || price.isEmpty) return;

                String finalPrice = price;
                if (!finalPrice.startsWith('৳')) finalPrice = '৳ ${finalPrice.trim()}';
                if (!finalPrice.toLowerCase().contains('kg') && !finalPrice.toLowerCase().contains('mon')) {
                  finalPrice = '${finalPrice.trim()} / kg';
                }

                if (isUpdate) {
                  await _firestore.doc(doc.id).update({'price': finalPrice, 'updatedAt': FieldValue.serverTimestamp()});
                  _logNotification(s.translate('notif_price_updated'), 'The market price for $variety was updated to $finalPrice.', 'market');
                } else {
                  await _firestore.doc(variety).set({'variety': variety, 'price': finalPrice, 'updatedAt': FieldValue.serverTimestamp()});
                  _logNotification(s.translate('notif_price_added'), 'A new market entry for $variety was added at $finalPrice.', 'market');
                }
                
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.isBengali ? 'সংরক্ষণ করুন' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _deletePrice(String docId, String varietyName) async {
    final s = AppSettings.instance;
    await _firestore.doc(docId).delete();
    _logNotification(s.translate('notif_price_removed'), 'The market listing for $varietyName was permanently deleted.', 'market');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('edit_live_prices'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(s.translate('add_price'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.accent));
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(s.translate('no_prices'), style: TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.bold))
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final variety = doc['variety'] as String;
                    final price = doc['price'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassFill,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.glassBorder, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.sell_rounded, color: AppColors.accent, size: 24),
                            ),
                            title: TranslateText(
                              variety,
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText, fontSize: 16),
                            ),
                            subtitle: Text(
                              s.translatePrice(price),
                              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.secondaryText),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                                  tooltip: s.isBengali ? 'পরিবর্তন করুন' : 'Edit',
                                  onPressed: () => _showEditDialog(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                  tooltip: s.isBengali ? 'মুছে ফেলুন' : 'Delete',
                                  onPressed: () => _deletePrice(doc.id, variety),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
