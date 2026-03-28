import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  
  @override
  void initState() {
    super.initState();
    _markAsSeen();
  }

  Future<void> _markAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _hideNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hiddenNotifications': FieldValue.arrayUnion([docId])
      }, SetOptions(merge: true));
    }
  }

  Future<void> _clearAll(List<String> visibleIds) async {
    if (visibleIds.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hiddenNotifications': FieldValue.arrayUnion(visibleIds)
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.'), backgroundColor: Colors.teal)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final hiddenList = List<String>.from(userData['hiddenNotifications'] ?? []);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(40)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final visibleDocs = allDocs.where((doc) => !hiddenList.contains(doc.id)).toList();
            
            return Scaffold(
              appBar: AppBar(
                title: const Text('Admin Updates'),
                actions: [
                  if (visibleDocs.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                      label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onPressed: () => _clearAll(visibleDocs.map((d) => d.id).toList()),
                    )
                ],
              ),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading notifications.', style: TextStyle(color: Colors.red)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF2D5A27)));
                    }

                    if (visibleDocs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_rounded, size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Text(
                              'You have no new updates.',
                              style: TextStyle(fontSize: 18, color: Color(0xFF2D5A27), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, index) {
                        final doc = visibleDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        final title = data['title'] ?? 'Notice';
                        final body = data['body'] ?? '';
                        final type = data['type'] ?? 'general';
                        
                        String timeAgo = 'Just now';
                        if (data['timestamp'] != null) {
                           DateTime time = (data['timestamp'] as Timestamp).toDate();
                           int hoursDiff = DateTime.now().difference(time).inHours;
                           if (hoursDiff == 0) {
                             int minDiff = DateTime.now().difference(time).inMinutes;
                             timeAgo = minDiff == 0 ? 'Just now' : '$minDiff min ago';
                           } else if (hoursDiff < 24) {
                             timeAgo = '$hoursDiff hours ago';
                           } else {
                             timeAgo = DateFormat.yMMMd().format(time);
                           }
                        }

                        IconData alertIcon = Icons.notifications_active_rounded;
                        Color alertColor = const Color(0xFF2D5A27); 
                        if (type == 'market') {
                          alertIcon = Icons.storefront_rounded;
                          alertColor = Colors.orangeAccent;
                        } else if (type == 'calendar') {
                          alertIcon = Icons.calendar_month_rounded;
                          alertColor = Colors.green;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: alertColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(alertIcon, color: alertColor, size: 26),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27), fontSize: 16),
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      body,
                                      style: const TextStyle(color: Colors.black87, fontSize: 13.5),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.black26),
                                    tooltip: 'Dismiss alert',
                                    onPressed: () => _hideNotification(doc.id),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            );
          },
        );
      }
    );
  }
}
