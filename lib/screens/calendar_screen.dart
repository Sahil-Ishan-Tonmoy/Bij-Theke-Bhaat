import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class Phase {
  final String id;
  final String title;
  final String subtitle;
  final int startDay;
  final int endDay;
  final Color color;

  Phase(this.id, this.title, this.subtitle, this.startDay, this.endDay, this.color);
}

final List<Phase> farmingPhases = [
  Phase('seedbed', 'Seedbed Preparation', 'Sow seeds in nursing beds', 1, 15, Colors.lightGreen),
  Phase('transplant', 'Transplanting', 'Move seedlings to main field', 20, 30, Colors.orange),
  Phase('fertilizer1', 'First Fertilizer', 'Apply Nitrogen/Urea', 35, 50, Colors.purple),
  Phase('flowering', 'Flowering Stage', 'Ensure adequate flooding', 65, 80, Colors.blue),
  Phase('harvest', 'Harvesting', 'Drain water, reap crops', 120, 140, Colors.amber),
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _sowingDate;

  bool _isLoading = true;
  int? _weatherCode;
  double? _temperature;
  String _cityName = 'Locating...';
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _loadUserCalendar();
    _fetchLiveWeather();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _cityName = 'GPS Disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _cityName = 'Permission Denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _cityName = 'Permission Forever Denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      try {
        final geoRes = await http.get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en'));
        if (geoRes.statusCode == 200) {
           final geoData = json.decode(geoRes.body);
           // Fallback priority: city -> locality -> subdivision
           _cityName = geoData['city'] ?? geoData['locality'] ?? geoData['principalSubdivision'] ?? 'Unknown District';
        } else {
           _cityName = 'Unknown District';
        }
      } catch (e) {
        _cityName = 'Location Found'; 
      }

      final res = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,precipitation'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _temperature = data['current']['temperature_2m'];
            _weatherCode = data['current']['weather_code'];
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _cityName = 'Weather Error');
    }
  }

  String _getWeatherDesc() {
    if (_weatherCode == null) return 'Fetching Weather...';
    if (_weatherCode == 0) return 'Clear ☀️';
    if (_weatherCode! >= 1 && _weatherCode! <= 3) return 'Cloudy ⛅';
    if (_weatherCode! >= 51 && _weatherCode! <= 67) return 'Rain 🌧️';
    if (_weatherCode! >= 95) return 'Thunderstorm ⛈️';
    return 'Overcast ☁️';
  }

  Future<void> _loadUserCalendar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('sowingDate')) {
          _sowingDate = (doc.data()!['sowingDate'] as Timestamp).toDate();
          _checkPhaseNotifications();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _checkPhaseNotifications() {
    if (_sowingDate == null) return;
    
    final int todayDiff = DateTime.now().difference(_sowingDate!).inDays;
    
    // Simulate push notification trigger for critical days
    if (todayDiff >= 20 && todayDiff <= 30) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔔 Reminder: You are in the Transplanting Phase! Ensure soil is tilled.'),
            backgroundColor: const Color(0xFF2D5A27),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'DISMISS', textColor: Colors.white, onPressed: (){}),
          )
        );
      });
    }
  }

  Future<void> _pickSowingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _sowingDate = picked;
        _focusedDay = picked;
      });
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'sowingDate': Timestamp.fromDate(picked),
        }, SetOptions(merge: true));
        _checkPhaseNotifications();
      }
    }
  }

  Widget _buildMarker(Color color) {
    return Positioned(
      bottom: 2,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF2D5A27), size: 20),
              const SizedBox(width: 8),
              Text(
                _cityName, 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)
              ),
            ],
          ),
          Text(
            '${_temperature != null ? '${_temperature!.toStringAsFixed(1)}°C' : ''}  ${_getWeatherDesc()}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_sowingDate == null) return const SizedBox();
    
    final int todayDiff = DateTime.now().difference(_sowingDate!).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Growth Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
          const SizedBox(height: 8),
          Text('Day $todayDiff since sowing', style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: farmingPhases.length,
            itemBuilder: (context, index) {
              final phase = farmingPhases[index];
              final bool isActive = todayDiff >= phase.startDay && todayDiff <= phase.endDay;
              final bool isPast = todayDiff > phase.endDay;
              
              final Color nodeColor = isActive ? phase.color : (isPast ? const Color(0xFF2D5A27) : Colors.grey.shade400);

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.1,
                isFirst: index == 0,
                isLast: index == farmingPhases.length - 1,
                beforeLineStyle: LineStyle(color: isPast ? const Color(0xFF2D5A27) : Colors.grey.shade400, thickness: 3),
                afterLineStyle: LineStyle(color: todayDiff >= phase.startDay ? const Color(0xFF2D5A27) : Colors.grey.shade400, thickness: 3),
                indicatorStyle: IndicatorStyle(
                  width: isActive ? 24 : 16,
                  color: nodeColor,
                  indicatorXY: 0.2,
                  indicator: isActive 
                    ? AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: nodeColor,
                              boxShadow: [
                                BoxShadow(
                                  color: nodeColor.withOpacity(0.6 * _pulseController.value),
                                  blurRadius: 15 * _pulseController.value,
                                  spreadRadius: 8 * _pulseController.value,
                                )
                              ]
                            ),
                          );
                        }
                      )
                    : Container(decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor)),
                ),
                endChild: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8, bottom: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isActive ? 0.9 : 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: isActive ? Border.all(color: nodeColor, width: 2) : Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(phase.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? nodeColor : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(phase.subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                            const SizedBox(height: 8),
                            Text('Days ${phase.startDay}-${phase.endDay}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Farming Calendar'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildWeatherWidget(),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarFormat: CalendarFormat.month,
                          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: Color(0xFF2D5A27), shape: BoxShape.circle),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (_sowingDate == null) return null;
                              
                              int diff = day.difference(_sowingDate!).inDays;
                              if (diff == 0) return _buildMarker(Colors.blueAccent);
                              
                              for (var phase in farmingPhases) {
                                if (diff >= phase.startDay && diff <= phase.endDay) {
                                  return _buildMarker(phase.color);
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (_sowingDate == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.psychology_alt_rounded),
                        label: const Text('Set Sowing Start Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: _pickSowingDate,
                      ),
                      
                    if (_sowingDate != null)
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2D5A27)),
                        label: Text('Change Sowing Date (${DateFormat.yMMMd().format(_sowingDate!)})', style: const TextStyle(color: Color(0xFF2D5A27))),
                        onPressed: _pickSowingDate,
                      ),
                      
                    _buildTimeline(),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
