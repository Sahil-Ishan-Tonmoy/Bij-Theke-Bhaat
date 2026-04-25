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
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/translate_text.dart';

Color _getPhaseColor(int index) {
  const colors = [
    Colors.lightGreen,
    Colors.orange,
    Colors.purple,
    Colors.blue,
    Colors.amber,
    Colors.teal,
    Colors.pinkAccent,
    Colors.deepOrangeAccent,
  ];
  return colors[index % colors.length];
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _sowingDate;

  String? _selectedPlanId;
  String? _selectedPlanName;
  List<Map<String, dynamic>> _currentPhases = [];
  bool _loadingPhases = false;

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
    final s = AppSettings.instance;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _cityName = s.isBengali ? 'জিপিএস বন্ধ' : 'GPS Disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _cityName = s.isBengali ? 'অনুমতি নেই' : 'Permission Denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _cityName = s.isBengali ? 'অনুমতি স্থায়ীভাবে বন্ধ' : 'Permission Forever Denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      try {
        final geoRes = await http.get(Uri.parse(
            'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en'));
        if (geoRes.statusCode == 200) {
          final geoData = json.decode(geoRes.body);
          _cityName = geoData['city'] ?? geoData['locality'] ?? geoData['principalSubdivision'] ?? (s.isBengali ? 'অজানা এলাকা' : 'Unknown District');
        } else {
          _cityName = s.isBengali ? 'অজানা এলাকা' : 'Unknown District';
        }
      } catch (_) {
        _cityName = s.isBengali ? 'অবস্থান পাওয়া গেছে' : 'Location Found';
      }

      final res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,precipitation'));
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
      if (mounted) setState(() => _cityName = s.isBengali ? 'আবহাওয়ায় ত্রুটি' : 'Weather Error');
    }
  }

  String _getWeatherDesc() {
    final s = AppSettings.instance;
    if (_weatherCode == null) return s.isBengali ? 'আবহাওয়া আনা হচ্ছে...' : 'Fetching Weather...';
    if (_weatherCode == 0) return '${s.translate('clear_sky')} ☀️';
    if (_weatherCode! >= 1 && _weatherCode! <= 3) return '${s.translate('partly_cloudy')} ⛅';
    if (_weatherCode! >= 51 && _weatherCode! <= 67) return '${s.translate('light_rain')} 🌧️';
    if (_weatherCode! >= 95) return '${s.translate('thunderstorm_warning')} ⛈️';
    return '${s.translate('overcast')} ☁️';
  }

  Future<void> _loadUserCalendar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final d = doc.data()!;
          if (d.containsKey('sowingDate')) {
            _sowingDate = (d['sowingDate'] as Timestamp).toDate();
          }
          if (d.containsKey('selectedPlanId')) {
            _selectedPlanId = d['selectedPlanId'];
            _selectedPlanName = d['selectedPlanName'] ?? '';
            await _loadPhases(_selectedPlanId!);
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPhases(String planId) async {
    setState(() => _loadingPhases = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('farming_plans')
          .doc(planId)
          .collection('phases')
          .orderBy('startDay')
          .get();
      _currentPhases = snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      _currentPhases = [];
    } finally {
      if (mounted) setState(() => _loadingPhases = false);
    }
  }

  void _showPlanPicker() {
    final s = AppSettings.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 16),
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: AppColors.secondaryText.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(s.translate('select_plan'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('farming_plans').snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AppColors.accent));
                  final plans = snap.data!.docs;

                  if (plans.isEmpty) {
                    return Center(
                      child: Text(s.isBengali ? 'কোনো চাষের পরিকল্পনা নেই।\nএডমিনকে পরিকল্পনা যোগ করতে বলুন।' : 'No farming plans available.\nAsk your admin to add plans.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final plan = plans[i];
                      final data = plan.data() as Map<String, dynamic>;
                      final bool isSelected = _selectedPlanId == plan.id;
                      final name = data['name'] ?? 'Unknown';

                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          setState(() {
                            _selectedPlanId = plan.id;
                            _selectedPlanName = name;
                          });
                          await _loadPhases(plan.id);

                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                              'selectedPlanId': plan.id,
                              'selectedPlanName': name,
                            }, SetOptions(merge: true));
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : AppColors.glassFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppColors.accent : AppColors.glassBorder, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.grass_rounded, color: isSelected ? Colors.white : AppColors.accent, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TranslateText(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.white : AppColors.primaryText)),
                                    Wrap(
                                      children: [
                                        Text('${data['totalDays'] ?? '?'} ${s.isBengali ? 'দিন' : 'days'}  •  ', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : AppColors.secondaryText)),
                                        TranslateText(data['description'] ?? '', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : AppColors.secondaryText)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white),
                            ],
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
    );
  }

  Future<void> _pickSowingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
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
      }
    }
  }

  Widget _buildMarker(Color color) {
    return Positioned(
      bottom: 2,
      child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }

  Widget _buildWeatherWidget() {
    final s = AppSettings.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppColors.glassFill, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.location_on_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            TranslateText(_cityName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
          ]),
          Text(
            '${_temperature != null ? '${s.translatePrice(_temperature!.toStringAsFixed(1))}°C' : ''}  ${_getWeatherDesc()}',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    final s = AppSettings.instance;
    return GestureDetector(
      onTap: _showPlanPicker,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.agriculture_rounded, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.translate('select_plan'), style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
                  if (_selectedPlanName != null)
                    TranslateText(
                      _selectedPlanName!,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                    )
                  else
                    Text(
                      s.isBengali ? 'ধানের জাত নির্বাচন করুন' : 'Tap to select rice variety',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryText.withOpacity(0.5)),
                    ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final s = AppSettings.instance;
    if (_sowingDate == null || _selectedPlanId == null) return const SizedBox();
    if (_loadingPhases) return Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.accent)));
    if (_currentPhases.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.isBengali ? 'এই পরিকল্পনায় কোনো পর্যায় নেই।' : 'No phases in this plan yet.', style: TextStyle(color: AppColors.secondaryText))));

    final int todayDiff = DateTime.now().difference(_sowingDate!).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedPlanName != null)
                 TranslateText(_selectedPlanName!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
              Text(' ${s.isBengali ? "বৃদ্ধি টাইমলাইন" : "Growth Timeline"}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${s.translate('days_since')}: ${s.translatePrice(todayDiff.toString())} ${s.isBengali ? "দিন" : "days"}', style: TextStyle(fontSize: 14, color: AppColors.secondaryText)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentPhases.length,
            itemBuilder: (context, index) {
              final phase = _currentPhases[index];
              final int startDay = phase['startDay'] ?? 0;
              final int endDay = phase['endDay'] ?? 0;
              final bool isActive = todayDiff >= startDay && todayDiff <= endDay;
              final bool isPast = todayDiff > endDay;
              final Color nodeColor = _getPhaseColor(index);
              final Color activeNodeColor = isActive ? nodeColor : (isPast ? AppColors.accent : AppColors.secondaryText.withOpacity(0.3));

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.1,
                isFirst: index == 0,
                isLast: index == _currentPhases.length - 1,
                beforeLineStyle: LineStyle(color: isPast ? AppColors.accent : AppColors.glassBorder, thickness: 3),
                afterLineStyle: LineStyle(color: todayDiff >= startDay ? AppColors.accent : AppColors.glassBorder, thickness: 3),
                indicatorStyle: IndicatorStyle(
                  width: isActive ? 24 : 16,
                  color: activeNodeColor,
                  indicatorXY: 0.2,
                  indicator: isActive
                      ? AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: nodeColor,
                                boxShadow: [BoxShadow(color: nodeColor.withOpacity(0.6 * _pulseController.value), blurRadius: 15 * _pulseController.value, spreadRadius: 8 * _pulseController.value)],
                              ),
                            );
                          },
                        )
                      : Container(decoration: BoxDecoration(shape: BoxShape.circle, color: activeNodeColor)),
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
                          color: isActive ? AppColors.glassFill : AppColors.glassFill.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: isActive ? Border.all(color: nodeColor, width: 2) : Border.all(color: AppColors.glassBorder, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslateText(phase['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? nodeColor : AppColors.primaryText)),
                            const SizedBox(height: 4),
                            TranslateText(phase['subtitle'] ?? '', style: TextStyle(fontSize: 14, color: AppColors.secondaryText)),
                            const SizedBox(height: 8),
                            Text('${s.isBengali ? "দিন" : "Days"} ${s.translatePrice(startDay.toString())}–${s.translatePrice(endDay.toString())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryText.withOpacity(0.7))),
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
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('farming_calendar'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
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
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildWeatherWidget(),
                          _buildPlanSelector(),

                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.glassBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TableCalendar(
                                locale: s.isBengali ? 'bn' : 'en',
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
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false, 
                                  titleCentered: true,
                                  titleTextStyle: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(color: AppColors.primaryText),
                                  weekendStyle: TextStyle(color: AppColors.accent),
                                ),
                                calendarStyle: CalendarStyle(
                                  defaultTextStyle: TextStyle(color: AppColors.primaryText),
                                  weekendTextStyle: TextStyle(color: AppColors.accent),
                                  outsideTextStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.5)),
                                  todayDecoration: BoxDecoration(color: AppColors.accent.withOpacity(0.5), shape: BoxShape.circle),
                                  selectedDecoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) {
                                    if (_sowingDate == null || _currentPhases.isEmpty) return null;
                                    int diff = day.difference(_sowingDate!).inDays;
                                    if (diff == 0) return _buildMarker(Colors.blueAccent);
                                    for (int i = 0; i < _currentPhases.length; i++) {
                                      final phase = _currentPhases[i];
                                      if (diff >= (phase['startDay'] ?? 0) && diff <= (phase['endDay'] ?? 0)) {
                                        return _buildMarker(_getPhaseColor(i));
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
                              label: Text(s.translate('sowing_date'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _pickSowingDate,
                            ),

                          if (_sowingDate != null)
                            TextButton.icon(
                              icon: Icon(Icons.edit_calendar_rounded, color: AppColors.accent),
                              label: Text('${s.isBengali ? "রোপণের তারিখ পরিবর্তন" : "Change Sowing Date"} (${DateFormat.yMMMd().format(_sowingDate!)})', style: TextStyle(color: AppColors.primaryText)),
                              onPressed: _pickSowingDate,
                            ),

                          _buildTimeline(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
