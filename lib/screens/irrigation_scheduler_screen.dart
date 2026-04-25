import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../services/app_colors.dart';
import '../widgets/theme_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IrrigationSchedulerScreen extends StatefulWidget {
  const IrrigationSchedulerScreen({super.key});

  @override
  State<IrrigationSchedulerScreen> createState() =>
      _IrrigationSchedulerScreenState();
}

class _IrrigationSchedulerScreenState extends State<IrrigationSchedulerScreen> {
  final user = FirebaseAuth.instance.currentUser;

  static const Map<String, _PhaseIrrigation> _phaseGuide = {
    'Seedbed Preparation': _PhaseIrrigation(
      'Keep soil moist but not flooded.',
      'মৃত্তিকা ভেজা রাখুন কিন্তু ডুবিয়ে দেবেন না।',
      'Light watering: ~200L/bigha/day',
      'হালকা সেচ: ~২০০লিটার/বিঘা/দিন',
      200,
      1,
    ),
    'Nursery Setup': _PhaseIrrigation(
      'Keep soil moist but not flooded.',
      'মৃত্তিকা ভেজা রাখুন কিন্তু ডুবিয়ে দেবেন না।',
      'Light watering: ~200L/bigha/day',
      'হালকা সেচ: ~২০০লিটার/বিঘা/দিন',
      200,
      1,
    ),
    'Transplanting': _PhaseIrrigation(
      'Flood field to 3–5cm depth right before transplanting.',
      'চারা রোপণের আগে জমি ৩-৫ সেমি পানিতে ডুবিয়ে দিন।',
      '500L/bigha on transplant day, then maintain 3cm flood.',
      'রোপণের দিন ৫০০লিটার/বিঘা, এরপর ৩ সেমি পানি বজায় রাখুন।',
      500,
      1,
    ),
    'First Fertilizer': _PhaseIrrigation(
      'Drain field to thin mud before applying fertilizer, then re-flood.',
      'সার দেওয়ার আগে জমি থেকে পানি বের করে কাদা করুন, এরপর আবার সেচ দিন।',
      'Drain and re-flood: cycle every 5 days.',
      'পানি বের করা এবং সেচ: প্রতি ৫ দিনের চক্র।',
      400,
      5,
    ),
    'Irrigation Phase': _PhaseIrrigation(
      'Critical phase — maintain 5cm standing water at all times.',
      'গুরুত্বপূর্ণ পর্যায় — সব সময় ৫ সেমি পানি জমিয়ে রাখুন।',
      'Continuous flood: ~600L/bigha/day',
      'টানা সেচ: ~৬০০লিটার/বিঘা/দিন',
      600,
      1,
    ),
    'Fertilizer Application': _PhaseIrrigation(
      'Drain to thin mud, apply fertilizer, re-flood after 3 days.',
      'জমি শুকিয়ে কাদা করুন, সার দিন, ৩ দিন পর আবার সেচ দিন।',
      '300L/bigha every 3 days',
      '৩০০লিটার/বিঘা প্রতি ৩ দিন পর পর',
      300,
      3,
    ),
    'Weed Management': _PhaseIrrigation(
      'Maintain 3cm water level to suppress weed growth.',
      'আগাছা দমনে ৩ সেমি পানির লেভেল বজায় রাখুন।',
      '350L/bigha every 2 days',
      '৩৫০লিটার/বিঘা প্রতি ২ দিন পর পর',
      350,
      2,
    ),
    'Panicle Initiation': _PhaseIrrigation(
      'Ensure 5cm flooding — critical for grain development.',
      '৫ সেমি পানি নিশ্চিত করুন — ধান পুষ্ট হওয়ার জন্য এটি জরুরি।',
      '550L/bigha/day',
      '৫৫০লিটার/বিঘা/দিন',
      550,
      1,
    ),
    'Flowering Stage': _PhaseIrrigation(
      'Maintain 3–5cm flood. Do NOT let field dry out during flowering.',
      '৩-৫ সেমি পানি রাখুন। ফুল আসার সময় জমি শুকাতে দেবেন না।',
      '500L/bigha/day',
      '৫০০লিটার/বিঘা/দিন',
      500,
      1,
    ),
    'Harvesting': _PhaseIrrigation(
      'Drain field completely 10 days before harvest for soil firmness.',
      'কাটার ১০ দিন আগে জমি থেকে সব পানি বের করে দিন।',
      'Stop irrigation. Drain completely.',
      'সেচ বন্ধ করুন। পানি বের করে দিন।',
      0,
      1,
    ),
  };

  String _weatherAdvice(int? weatherCode, double? temp) {
    final s = AppSettings.instance;
    if (weatherCode == null)
      return s.t('Weather data unavailable.', 'আবহাওয়ার তথ্য পাওয়া যায়নি।');
    if (weatherCode >= 51 && weatherCode <= 67)
      return s.t(
        '🌧️ Rain detected! Skip irrigation today.',
        '🌧️ বৃষ্টি হচ্ছে! আজ সেচ দেওয়ার প্রয়োজন নেই।',
      );
    if (weatherCode >= 95)
      return s.t(
        '⛈️ Thunderstorm! Avoid field operations.',
        '⛈️ বজ্রপাত! মাঠে কাজ করা থেকে বিরত থাকুন।',
      );
    if (temp != null && temp > 35)
      return s.t(
        '🌡️ Extreme heat! Increase water depth by +2cm.',
        '🌡️ অতিরিক্ত গরম! পানির গভীরতা আরও ২ সেমি বাড়ান।',
      );
    if (weatherCode == 0 || (weatherCode >= 1 && weatherCode <= 3))
      return s.t(
        '☀️ Clear sky. Normal irrigation schedule applies.',
        '☀️ পরিষ্কার আকাশ। স্বাভাবিক সেচ ব্যবস্থা চালু রাখুন।',
      );
    return s.t(
      '⛅ Partly cloudy. Normal schedule applies.',
      '⛅ আংশিক মেঘলা। স্বাভাবিক সেচ ব্যবস্থা চালু রাখুন।',
    );
  }

  Future<String> _fetchAiAdvice(
    String crop,
    String phase,
    int day,
    int? weatherCode,
    double? temp,
  ) async {
    final cacheKey =
        'irr_ai_${crop}_${phase}_${day}_${weatherCode}_${temp?.round()}_${AppSettings.instance.isBengali}';
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached;

    const String geminiKey = 'AIzaSyCGLvKvohePi86VRRCJgRHF9sIZGhnLTOg';
    final models = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.5-flash-lite',
    ];

    String weatherDesc = 'Unknown';
    if (weatherCode != null) {
      if (weatherCode == 0)
        weatherDesc = 'Clear Sky';
      else if (weatherCode < 50)
        weatherDesc = 'Cloudy';
      else if (weatherCode < 70)
        weatherDesc = 'Rainy';
      else
        weatherDesc = 'Stormy';
    }

    final prompt =
        'As an expert agronomist, provide a precise irrigation recommendation for $crop at growth phase "$phase" (Day $day). '
        'Current weather is $weatherDesc with temperature ${temp ?? 25}°C. '
        'Return a single professional sentence in ${AppSettings.instance.isBengali ? 'Bengali' : 'English'} '
        'stating the exact water volume (L/Bigha) and action for today.';

    for (var modelName in models) {
      try {
        final String url =
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$geminiKey';

        final Map<String, dynamic> requestBody = {
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        };

        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(requestBody),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final advice =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          if (advice.isNotEmpty) {
            await prefs.setString(cacheKey, advice);
            return advice;
          }
        } else {
          continue; // Try next model
        }
      } catch (e) {
        continue; // Error with this model, try next
      }
    }

    return AppSettings.instance.isBengali
        ? 'বর্তমানে এআই ব্যস্ত আছে। স্ট্যান্ডার্ড পরামর্শ: $phase পর্যায়ে স্বাভাবিক সেচ বজায় রাখুন।'
        : 'AI currently busy. Standard Advice: Maintain normal irrigation for $phase.';
  }

  int _displayLiters(int litersPerBigha) => AppSettings.instance.isBigha
      ? litersPerBigha
      : (litersPerBigha * 3.025).round();

  String _localizeSchedule(String text) {
    final s = AppSettings.instance;
    if (s.isBigha) return text;
    final result = text.replaceAllMapped(RegExp(r'(~?)(\d+)L/bigha'), (m) {
      final liters = int.tryParse(m.group(2) ?? '0') ?? 0;
      final converted = (liters * 3.025).round();
      return '${m.group(1)}${converted}L/acre';
    });
    return result.replaceAll('bigha', 'acre');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.translate('irrigation_scheduler'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.appBarText,
            ),
          ),
          backgroundColor: AppColors.appBarBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.appBarText),
          actions: const [AppMenuButton()],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: user == null
                ? Center(
                    child: Text(
                      s.isBengali ? 'লগইন করুন' : 'Please log in',
                      style: TextStyle(color: AppColors.primaryText),
                    ),
                  )
                : FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .get(),
                    builder: (ctx, userSnap) {
                      if (!userSnap.hasData)
                        return Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        );

                      final userData =
                          userSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final sowingTs = userData['sowingDate'] as Timestamp?;
                      final sowingDate = sowingTs?.toDate();
                      final planId = userData['selectedPlanId'] as String?;
                      final planName = s.translateCrop(
                        userData['selectedPlanName'] as String? ?? 'Unknown',
                      );
                      final int? weatherCode =
                          userData['lastWeatherCode'] as int?;
                      final double? temp = (userData['lastTemperature'] as num?)
                          ?.toDouble();

                      if (sowingDate == null || planId == null)
                        return _emptyState();

                      final int todayDiff = DateTime.now()
                          .difference(sowingDate)
                          .inDays;

                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('farming_plans')
                            .doc(planId)
                            .collection('phases')
                            .orderBy('startDay')
                            .get(),
                        builder: (ctx2, phaseSnap) {
                          if (!phaseSnap.hasData)
                            return Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                              ),
                            );

                          final phases = phaseSnap.data!.docs;
                          Map<String, dynamic>? currentPhase;
                          for (final ph in phases) {
                            final d = ph.data() as Map<String, dynamic>;
                            if (todayDiff >= (d['startDay'] ?? 0) &&
                                todayDiff <= (d['endDay'] ?? 0)) {
                              currentPhase = d;
                              break;
                            }
                          }

                          final guide = currentPhase != null
                              ? _phaseGuide[currentPhase['title']]
                              : null;
                          final unitLabel = s.isBigha
                              ? (s.isBengali ? 'বিঘা' : 'Bigha')
                              : (s.isBengali ? 'একর' : 'Acre');

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight - 32,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _glass(
                                          color: weatherCode != null
                                              ? Colors.blue.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.05),
                                          borderColor: weatherCode != null
                                              ? Colors.blue.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    weatherCode != null
                                                        ? Icons.wb_sunny_rounded
                                                        : Icons
                                                              .cloud_off_rounded,
                                                    color: weatherCode != null
                                                        ? Colors.blue
                                                        : Colors.orange,
                                                    size: 26,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      _weatherAdvice(
                                                        weatherCode,
                                                        temp,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (weatherCode == null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  s.isBengali
                                                      ? 'লাইভ আবহাওয়ার জন্য একবার ওয়েদার হাব ওপেন করুন।'
                                                      : 'Open Smart Weather Hub once to sync live weather.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ] else if (userData['lastWeatherCity'] !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '📍 ${userData['lastWeatherCity']}  •  ${temp != null ? '${temp.toStringAsFixed(0)}°C' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        _glass(
                                          color: AppColors.glassFill,
                                          borderColor: AppColors.glassBorder,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.agriculture_rounded,
                                                    color: AppColors.accent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    planName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                      color:
                                                          AppColors.primaryText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                todayDiff < 0
                                                    ? (s.isBengali
                                                          ? 'মৌসুম শুরু হতে আরও ${todayDiff.abs()} দিন বাকি'
                                                          : 'Season starts in ${todayDiff.abs()} days')
                                                    : (s.isBengali
                                                          ? 'চাষের মৌসুমের $todayDiff তম দিন'
                                                          : 'Day $todayDiff of growing season'),
                                                style: TextStyle(
                                                  color:
                                                      AppColors.secondaryText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              if (currentPhase == null)
                                                Text(
                                                  todayDiff < 0
                                                      ? (s.isBengali
                                                            ? 'আপনার চাষের পরিকল্পনা ভবিষ্যতের জন্য সেট করা হয়েছে। মৌসুম শুরু হলে সেচ গাইড দেখা যাবে।'
                                                            : 'Your farming plan is set for the future. Irrigation schedules will appear once the season begins.')
                                                      : (s.isBengali
                                                            ? 'আজকের জন্য কোনো পর্যায় পাওয়া যায়নি। আপনার রোপণের তারিখ পরীক্ষা করুন।'
                                                            : 'No active phase found for today. Check your sowing date or plan.'),
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                )
                                              else ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${s.isBengali ? 'বর্তমান পর্যায়' : 'Current Phase'}: ${s.translatePhase(currentPhase['title'])}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                if (guide != null) ...[
                                                  if (weatherCode != null &&
                                                      ((weatherCode >= 51 &&
                                                              weatherCode <=
                                                                  67) ||
                                                          weatherCode >= 95))
                                                    _infoCard(
                                                      Icons
                                                          .beach_access_rounded,
                                                      Colors.blueGrey,
                                                      s.isBengali
                                                          ? 'সেচ বন্ধ রাখুন'
                                                          : 'Skip Irrigation',
                                                      s.isBengali
                                                          ? 'বৃষ্টি বা ঝড়ের সম্ভাবনা রয়েছে। আজ সেচ দেওয়ার প্রয়োজন নেই।'
                                                          : 'Rain or storm detected. No irrigation needed today.',
                                                      isGradient: false,
                                                    )
                                                  else ...[
                                                    _infoCard(
                                                      Icons.water_drop_rounded,
                                                      Colors.blue,
                                                      s.isBengali
                                                          ? 'আজকের সেচ তালিকা'
                                                          : 'Today\'s Schedule',
                                                      _localizeSchedule(
                                                        s.isBengali
                                                            ? guide.scheduleBn
                                                            : guide.scheduleEn,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _infoCard(
                                                      Icons
                                                          .tips_and_updates_rounded,
                                                      Colors.orange,
                                                      s.isBengali
                                                          ? 'কৃষি পরামর্শ'
                                                          : 'Agronomic Tip',
                                                      s.isBengali
                                                          ? guide.tipBn
                                                          : guide.tipEn,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    if (guide.litersPerBigha >
                                                        0)
                                                      _infoCard(
                                                        Icons.calculate_rounded,
                                                        Colors.teal,
                                                        '${s.isBengali ? 'পানির পরিমাণ' : 'Water Volume'} ($unitLabel)',
                                                        '${_displayLiters(guide.litersPerBigha)}L ${guide.intervalDays == 1 ? (s.isBengali ? 'প্রতিদিন' : 'every day') : (s.isBengali ? 'প্রতি ${guide.intervalDays} দিন পর পর' : 'every ${guide.intervalDays} days')}',
                                                      ),
                                                    if (guide.litersPerBigha ==
                                                        0)
                                                      _infoCard(
                                                        Icons.block_rounded,
                                                        Colors.redAccent,
                                                        s.isBengali
                                                            ? 'প্রয়োজনীয় পদক্ষেপ'
                                                            : 'Action Required',
                                                        s.isBengali
                                                            ? 'মাঠ থেকে পানি বের করে দিন। কাটার আগে আর সেচ লাগবে না।'
                                                            : 'Drain the field now. No irrigation needed until harvest.',
                                                      ),
                                                  ],
                                                ] else ...[
                                                  _infoCard(
                                                    Icons.help_rounded,
                                                    Colors.grey,
                                                    s.isBengali
                                                        ? 'কোনো গাইড নেই'
                                                        : 'No specific guide',
                                                    s.isBengali
                                                        ? 'এই পর্যায়ের জন্য সাধারণ ৩-৫ সেমি পানির লেভেল বজায় রাখুন।'
                                                        : 'Maintain standard 3–5cm water level for this phase.',
                                                  ),
                                                ],

                                                const SizedBox(height: 20),
                                                const Divider(
                                                  height: 1,
                                                  color: Colors.black12,
                                                ),
                                                const SizedBox(height: 16),
                                                FutureBuilder<String>(
                                                  future: _fetchAiAdvice(
                                                    userData['selectedPlanName'] ??
                                                        'Rice',
                                                    currentPhase['title'],
                                                    todayDiff,
                                                    weatherCode,
                                                    temp,
                                                  ),
                                                  builder: (context, aiSnap) {
                                                    return _infoCard(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      Colors.deepPurpleAccent,
                                                      s.isBengali
                                                          ? 'স্মার্ট এআই পরামর্শ'
                                                          : 'Smart AI Advisor',
                                                      aiSnap.connectionState ==
                                                              ConnectionState
                                                                  .waiting
                                                          ? (s.isBengali
                                                                ? 'আপনার জন্য পরামর্শ তৈরি করা হচ্ছে...'
                                                                : 'Generating personalized advice...')
                                                          : aiSnap.data ??
                                                                'No specific AI advice available.',
                                                      isGradient: true,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        _glass(
                                          color: AppColors.glassFill
                                              .withOpacity(0.1),
                                          borderColor: AppColors.glassBorder,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.isBengali
                                                    ? 'সম্পূর্ণ মৌসুমের তালিকা'
                                                    : 'Full Season Schedule',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryText,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              ...phases.map((ph) {
                                                final d =
                                                    ph.data()
                                                        as Map<String, dynamic>;
                                                final bool isActive =
                                                    todayDiff >=
                                                        (d['startDay'] ?? 0) &&
                                                    todayDiff <=
                                                        (d['endDay'] ?? 0);
                                                final bool isPast =
                                                    todayDiff >
                                                    (d['endDay'] ?? 0);
                                                final g =
                                                    _phaseGuide[d['title']];
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isActive
                                                            ? Icons
                                                                  .play_circle_filled_rounded
                                                            : (isPast
                                                                  ? Icons
                                                                        .check_circle_rounded
                                                                  : Icons
                                                                        .circle_outlined),
                                                        color: isActive
                                                            ? AppColors.accent
                                                            : (isPast
                                                                  ? AppColors
                                                                        .secondaryText
                                                                  : AppColors
                                                                        .hintText),
                                                        size: 22,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'D${d['startDay']}–${d['endDay']}: ${s.translatePhase(d['title'])}',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    isActive
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                                fontSize: 13,
                                                                color: isActive
                                                                    ? AppColors
                                                                          .accent
                                                                    : AppColors
                                                                          .primaryText,
                                                              ),
                                                            ),
                                                            if (g != null)
                                                              Text(
                                                                g.litersPerBigha >
                                                                        0
                                                                    ? '${_displayLiters(g.litersPerBigha)}L/$unitLabel · ${_localizeSchedule(s.isBengali ? g.scheduleBn.split('।').first : g.scheduleEn.split('.').first)}'
                                                                    : _localizeSchedule(
                                                                        s.isBengali
                                                                            ? g.scheduleBn
                                                                            : g.scheduleEn,
                                                                      ),
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: AppColors
                                                                      .secondaryText,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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

  Widget _emptyState() {
    final s = AppSettings.instance;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 80,
              color: AppColors.hintText,
            ),
            const SizedBox(height: 24),
            Text(
              s.isBengali
                  ? 'কোনো সক্রিয় পরিকল্পনা নেই'
                  : 'No active plan found.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.isBengali
                  ? 'সেচ গাইড দেখতে আপনার ড্যাশবোর্ড থেকে একটি রোপণের তারিখ এবং ধানের জাত নির্বাচন করুন।'
                  : 'Please set your sowing date and select a rice variety in the Farming Calendar first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glass({
    required Widget child,
    required Color color,
    required Color borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    Color color,
    String title,
    String value, {
    bool isGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGradient ? null : color.withOpacity(0.08),
        gradient: isGradient
            ? LinearGradient(
                colors: [
                  Colors.deepPurpleAccent.withOpacity(0.1),
                  Colors.blueAccent.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGradient
              ? Colors.deepPurpleAccent.withOpacity(0.3)
              : color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseIrrigation {
  final String tipEn;
  final String tipBn;
  final String scheduleEn;
  final String scheduleBn;
  final int litersPerBigha;
  final int intervalDays;
  const _PhaseIrrigation(
    this.tipEn,
    this.tipBn,
    this.scheduleEn,
    this.scheduleBn,
    this.litersPerBigha,
    this.intervalDays,
  );
}
