import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/translate_text.dart';

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
    final s = AppSettings.instance;
    if (visibleIds.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hiddenNotifications': FieldValue.arrayUnion(visibleIds)
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.translate('all_clear_msg')), backgroundColor: Colors.teal)
        );
      }
    }
  }

  String _translateTimeAgo(String timeAgo) {
    final s = AppSettings.instance;
    if (!s.isBengali) return timeAgo;
    if (timeAgo == 'Just now') return s.translate('just_now');
    if (timeAgo.contains('min ago')) {
      return '${s.translatePrice(timeAgo.split(' ')[0])} ${s.translate('min_ago')}';
    }
    if (timeAgo.contains('hours ago')) {
      return '${s.translatePrice(timeAgo.split(' ')[0])} ${s.translate('hours_ago')}';
    }
    return timeAgo;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s.translate('admin_updates'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          actions: const [AppMenuButton()],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (ctx1, userSnap) {
              if (!userSnap.hasData) return Center(child: CircularProgressIndicator(color: AppColors.accent));
              final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
              final hiddenList = List<String>.from(userData['hiddenNotifications'] ?? []);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notifications').orderBy('timestamp', descending: true).limit(30).snapshots(),
                builder: (ctx2, globalSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notifications').orderBy('timestamp', descending: true).limit(30).snapshots(),
                    builder: (ctx3, userNotifSnap) {
                      final List<QueryDocumentSnapshot> allDocs = [];
                      if (globalSnap.hasData) allDocs.addAll(globalSnap.data!.docs);
                      if (userNotifSnap.hasData) allDocs.addAll(userNotifSnap.data!.docs);
                      
                      // Sort by timestamp
                      allDocs.sort((a, b) {
                        final ta = (a.data() as Map)['timestamp'] as Timestamp?;
                        final tb = (b.data() as Map)['timestamp'] as Timestamp?;
                        if (ta == null) return 1;
                        if (tb == null) return -1;
                        return tb.compareTo(ta);
                      });

                      final visibleDocs = allDocs.where((doc) {
                        if (hiddenList.contains(doc.id)) return false;
                        final data = doc.data() as Map<String, dynamic>;
                        final targetUid = data['targetUid'] as String?;
                        return targetUid == null || targetUid == user.uid;
                      }).toList();

                      return SafeArea(
                        child: Column(
                          children: [
                            if (visibleDocs.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                                      label: Text(s.translate('clear_all'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      onPressed: () => _clearAll(visibleDocs.map((d) => d.id).toList()),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: Builder(
                                builder: (ctx4) {
                                  if (globalSnap.hasError || userNotifSnap.hasError) return Center(child: Text(s.isBengali ? 'ত্রুটি।' : 'Error.'));
                                  if (globalSnap.connectionState == ConnectionState.waiting && userNotifSnap.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator(color: AppColors.accent));
                                  }
                                  
                                  if (visibleDocs.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.notifications_off_rounded, size: 64, color: AppColors.secondaryText.withOpacity(0.3)),
                                          const SizedBox(height: 16),
                                          Text(s.translate('no_new_updates'), style: TextStyle(fontSize: 18, color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: visibleDocs.length,
                                    itemBuilder: (ctx5, index) {
                                      final doc = visibleDocs[index];
                                      final data = doc.data() as Map<String, dynamic>;
                                      final title = data['title'] ?? '';
                                      final body = data['body'] ?? '';
                                      final type = data['type'] ?? '';
                                      
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
                                      Color alertColor = AppColors.accent; 
                                      if (type == 'market') { alertIcon = Icons.storefront_rounded; alertColor = Colors.orangeAccent; }
                                      else if (type == 'calendar' || type == 'weather') { alertIcon = Icons.calendar_month_rounded; alertColor = Colors.green; }
                                      else if (type == 'health' || type == 'soil_health') { alertIcon = Icons.healing_rounded; alertColor = Colors.redAccent; }

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.glassFill,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: AppColors.glassBorder, width: 1.5),
                                              ),
                                              child: ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                leading: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(color: alertColor.withOpacity(0.15), shape: BoxShape.circle),
                                                  child: Icon(alertIcon, color: alertColor, size: 26),
                                                ),
                                                title: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: TranslateText(
                                                        title, 
                                                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText, fontSize: 16)
                                                      ),
                                                    ),
                                                    Text(_translateTimeAgo(timeAgo), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryText.withOpacity(0.6))),
                                                  ],
                                                ),
                                                subtitle: Padding(
                                                  padding: const EdgeInsets.only(top: 6),
                                                  child: TranslateText(
                                                    body, 
                                                    style: TextStyle(color: AppColors.primaryText, fontSize: 13.5)
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: Icon(Icons.close_rounded, color: AppColors.secondaryText.withOpacity(0.4)),
                                                  tooltip: s.translate('dismiss_alert'),
                                                  onPressed: () => _hideNotification(doc.id),
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
                      );
                    }
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
