import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final bool isUpdate = doc != null;
    final varietyController = TextEditingController(text: isUpdate ? doc['variety'] : '');
    final priceController = TextEditingController(text: isUpdate ? doc['price'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            isUpdate ? 'Edit Price' : 'Add New Price',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: varietyController,
                decoration: const InputDecoration(
                  hintText: 'Rice Variety (e.g. Miniket)',
                  prefixIcon: Icon(Icons.grass_rounded, color: Color(0xFF2D5A27)),
                ),
                enabled: !isUpdate, // Cannot change document ID easily, so we prevent editing the variety name
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  hintText: 'Price (e.g. ৳ 68 / kg)',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF2D5A27)),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              onPressed: () async {
                final variety = varietyController.text.trim();
                final price = priceController.text.trim();
                if (variety.isEmpty || price.isEmpty) return;

                String finalPrice = price;
                if (!finalPrice.startsWith('৳')) finalPrice = '৳ ${finalPrice.trim()}';
                if (!finalPrice.endsWith('kg')) finalPrice = '${finalPrice.trim()} / kg';

                if (isUpdate) {
                  await _firestore.doc(doc.id).update({'price': finalPrice, 'updatedAt': FieldValue.serverTimestamp()});
                  _logNotification('Price Updated', 'The market price for $variety was updated to $finalPrice.', 'market');
                } else {
                  await _firestore.doc(variety).set({'variety': variety, 'price': finalPrice, 'updatedAt': FieldValue.serverTimestamp()});
                  _logNotification('New Price Listed', 'A new market entry for $variety was added at $finalPrice.', 'market');
                }
                
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  void _deletePrice(String docId, String varietyName) async {
    await _firestore.doc(docId).delete();
    _logNotification('Price Removed', 'The market listing for $varietyName was permanently deleted.', 'market');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Live Prices'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        backgroundColor: const Color(0xFF2D5A27),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2D5A27)));
            
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Text('No prices in database.', style: TextStyle(color: Color(0xFF2D5A27), fontSize: 16))
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sell_rounded, color: Color(0xFF2D5A27), size: 24),
                        ),
                        title: Text(
                          doc['variety'],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27)),
                        ),
                        subtitle: Text(
                          doc['price'],
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                              tooltip: 'Edit',
                              onPressed: () => _showEditDialog(doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                              tooltip: 'Delete',
                              onPressed: () => _deletePrice(doc.id, doc['variety']),
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
    );
  }
}
