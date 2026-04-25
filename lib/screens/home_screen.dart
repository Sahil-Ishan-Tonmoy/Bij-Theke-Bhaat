import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_screen.dart';
import 'market_price_screen.dart';
import 'admin_dashboard_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'marketplace_screen.dart';
import 'weather_screen.dart';
import 'expense_tracker_screen.dart';
import 'disease_scanner_screen.dart';
import 'yield_calculator_screen.dart';
import 'soil_health_screen.dart';
import 'irrigation_scheduler_screen.dart';

import '../services/notification_service.dart';
import '../widgets/app_menu_button.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  int _currentFeaturePage = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<QuerySnapshot>? _userNotifSub;
  Timer? _simulatedWeatherTimer;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _listenForNativeNotifications();
    
    // Set to 1 hour interval as per user request
    _simulatedWeatherTimer = Timer.periodic(const Duration(hours: 1), (_) => _dropPeriodicWeather());
    // Initial drop
    Future.delayed(const Duration(seconds: 10), () => _dropPeriodicWeather());
  }

  Future<void> _dropPeriodicWeather() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // 1. Get Location with Permission Check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      
      // 2. Fetch Weather
      final res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code'
      ));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final current = data['current'];
        final double temp = (current['temperature_2m'] as num).toDouble();
        final int code = (current['weather_code'] as num).toInt();
        
        String title = '🌤 Weather Update';
        String body = 'Current temperature is ${temp.toStringAsFixed(1)}°C.';
        
        if (code == 0) {
          title = '☀️ Clear Skies Detected';
          body = 'Perfect weather for field work! Temperature is ${temp.toStringAsFixed(1)}°C. Ideal for spraying or harvesting.';
        } else if (code >= 1 && code <= 3) {
          title = '⛅ Partly Cloudy';
          body = 'Conditions are stable at ${temp.toStringAsFixed(1)}°C. Good time for general maintenance.';
        } else if (code >= 51 && code <= 67) {
          title = '🌧 Rain Alert';
          body = 'Expect light rain. Humidity might increase. Current temp: ${temp.toStringAsFixed(1)}°C. Adjust irrigation accordingly.';
        } else if (code >= 95) {
          title = '⛈ Thunderstorm Warning';
          body = 'Severe weather detected (${temp.toStringAsFixed(1)}°C). Please stay indoors and protect your equipment.';
        }

        // SAVE TO USER-SPECIFIC COLLECTION
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
           'title': title,
           'body': body,
           'type': 'calendar',
           'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Dynamic weather notification failed: $e');
    }
  }

  void _listenForNativeNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    
    // Global listener
    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      _processSnapshot(snapshot);
    });

    // User-specific listener
    if (user != null) {
      _userNotifSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        _processSnapshot(snapshot);
      });
    }
  }

  Future<void> _processSnapshot(QuerySnapshot snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>? ?? {};
        final Timestamp? timestamp = data['timestamp'];
        
        if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inSeconds < 15) {
           final s = AppSettings.instance;
           final String tTitle = await s.translateAsync(data['title'] ?? 'New Admin Update');
           final String tBody = await s.translateAsync(data['body'] ?? 'Check your notifications panel');

           NotificationService.showNotification(
             id: change.doc.id.hashCode,
             title: tTitle,
             body: tBody,
           );
        }
      }
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _userNotifSub?.cancel();
    _simulatedWeatherTimer?.cancel();
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
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardFill,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.primaryText,
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
          builder: (context, globalSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notifications').orderBy('timestamp', descending: true).limit(50).snapshots(),
              builder: (context, userNotifSnapshot) {
                int unreadCount = 0;
                
                // Count Global
                if (globalSnapshot.hasData) {
                  for (var doc in globalSnapshot.data!.docs) {
                    if (hiddenList.contains(doc.id)) continue;
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? notifTime = data['timestamp'];
                    if (notifTime != null && lastSeen != null) {
                      if (notifTime.toDate().isAfter(lastSeen.toDate())) unreadCount++;
                    } else if (lastSeen == null) {
                      unreadCount++;
                    }
                  }
                }

                // Count User-Specific
                if (userNotifSnapshot.hasData) {
                  for (var doc in userNotifSnapshot.data!.docs) {
                    if (hiddenList.contains(doc.id)) continue;
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? notifTime = data['timestamp'];
                    if (notifTime != null && lastSeen != null) {
                      if (notifTime.toDate().isAfter(lastSeen.toDate())) unreadCount++;
                    } else if (lastSeen == null) {
                      unreadCount++;
                    }
                  }
                }
                
                return _bellIcon(unreadCount);
              }
            );
          }
        );
      }
    );
  }

  Widget _bellIcon(int count) {
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.notifications_active_rounded, color: AppColors.appBarText),
      ),
      tooltip: 'Updates & Alerts',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(AppSettings.instance.translate('dashboard'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          actions: [
            _buildNotificationBell(),
            if (FirebaseAuth.instance.currentUser?.isAnonymous != true)
              IconButton(
                icon: Icon(Icons.person_rounded, color: AppColors.appBarText),
                tooltip: 'My Profile',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            const AppMenuButton(),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: _isLoadingRole 
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppSettings.instance.translate('welcome_back'), 
                        style: TextStyle(fontSize: 16, color: AppColors.primaryText, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        FirebaseAuth.instance.currentUser?.isAnonymous == true ? AppSettings.instance.translate('ready_to_buy') : AppSettings.instance.translate('ready_to_farm'), 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryText)
                      ),
                      const SizedBox(height: 40),
                      
                      Builder(
                        builder: (context) {
                          List<Widget> activeCards = [];
                          if (_isAdmin) {
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('management_panel'), Icons.admin_panel_settings_rounded, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))));
                          }
                          
                          if (FirebaseAuth.instance.currentUser?.isAnonymous != true) {
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('farming_calendar'), Icons.calendar_month_rounded, const Color(0xFF4CAF50), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('market_prices'), Icons.storefront_rounded, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPriceScreen()))));
                          }
                          
                          activeCards.add(_buildGlassCard(AppSettings.instance.translate('marketplace'), Icons.shopping_bag_rounded, Colors.indigoAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen()))));
                          
                          if (FirebaseAuth.instance.currentUser?.isAnonymous != true) {
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('weather'), Icons.cloud_circle_rounded, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('disease_scanner'), Icons.document_scanner_rounded, Colors.deepPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiseaseScannerScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('farm_ledger'), Icons.account_balance_wallet_rounded, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseTrackerScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('yield_calculator'), Icons.calculate_rounded, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YieldCalculatorScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('soil_health'), Icons.science_rounded, Colors.brown, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoilHealthScreen()))));
                            activeCards.add(_buildGlassCard(AppSettings.instance.translate('irrigation_scheduler'), Icons.water_drop_rounded, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IrrigationSchedulerScreen()))));
                          }
    
                          List<Widget> gridPages = [];
                          for (var i = 0; i < activeCards.length; i += 4) {
                            var chunkLength = (i + 4 > activeCards.length) ? activeCards.length : i + 4;
                            gridPages.add(
                              GridView.count(
                                padding: const EdgeInsets.only(bottom: 12),
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.05, 
                                physics: const NeverScrollableScrollPhysics(),
                                children: activeCards.sublist(i, chunkLength),
                              )
                            );
                          }
    
                          return Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: PageView(
                                    onPageChanged: (index) => setState(() => _currentFeaturePage = index),
                                    children: gridPages,
                                  ),
                                ),
                                if (gridPages.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(gridPages.length, (index) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: _currentFeaturePage == index ? 24 : 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _currentFeaturePage == index ? AppColors.accent : AppColors.hintText,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      )),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
