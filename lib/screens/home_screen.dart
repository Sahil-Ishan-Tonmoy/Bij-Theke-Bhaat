import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_screen.dart';
import 'market_price_screen.dart';
import 'admin_dashboard_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  StreamSubscription<QuerySnapshot>? _notifSub;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _listenForNativeNotifications();
  }

  void _listenForNativeNotifications() {
    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>? ?? {};
          final Timestamp? timestamp = data['timestamp'];
          
          if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inSeconds < 15) {
             NotificationService.showNotification(
               id: change.doc.id.hashCode,
               title: data['title'] ?? 'New Admin Update',
               body: data['body'] ?? 'Check your notifications panel',
             );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _isAdmin = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking admin status: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
      }
    }
  }

  Widget _buildGlassCard(String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Icon(icon, size: 40, color: iconColor),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF2D5A27),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return _bellIcon(0);
        
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final hiddenList = List<String>.from(userData['hiddenNotifications'] ?? []);
        final Timestamp? lastSeen = userData['lastSeenNotifications'];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notifications').orderBy('timestamp', descending: true).limit(50).snapshots(),
          builder: (context, notifSnapshot) {
            if (!notifSnapshot.hasData) return _bellIcon(0);
            
            int unreadCount = 0;
            for (var doc in notifSnapshot.data!.docs) {
              if (hiddenList.contains(doc.id)) continue;
              
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? notifTime = data['timestamp'];
              
              if (notifTime != null && lastSeen != null) {
                if (notifTime.toDate().isAfter(lastSeen.toDate())) unreadCount++;
              } else if (lastSeen == null) {
                unreadCount++;
              }
            }
            
            return _bellIcon(unreadCount);
          }
        );
      }
    );
  }

  Widget _bellIcon(int count) {
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.notifications_active_rounded),
      ),
      tooltip: 'Updates & Alerts',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          _buildNotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'My Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
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
        child: _isLoadingRole 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome back,", 
                    style: TextStyle(fontSize: 18, color: Color(0xFF2D5A27), fontWeight: FontWeight.w500)
                  ),
                  const Text(
                    "Ready to farm?", 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))
                  ),
                  const SizedBox(height: 40),
                  
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.85,
                      children: [
                        if (_isAdmin)
                          _buildGlassCard(
                            'Management\nPanel', 
                            Icons.admin_panel_settings_rounded, 
                            Colors.redAccent, 
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))
                          ),
                        _buildGlassCard(
                          'Farming\nCalendar', 
                          Icons.calendar_month_rounded, 
                          const Color(0xFF4CAF50), 
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))
                        ),
                        _buildGlassCard(
                          'Live Market\nPrices', 
                          Icons.storefront_rounded, 
                          Colors.orangeAccent, 
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPriceScreen()))
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
