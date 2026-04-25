import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/notification_service.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../services/app_colors.dart';
import '../widgets/theme_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoilHealthScreen extends StatefulWidget {
  const SoilHealthScreen({super.key});

  @override
  State<SoilHealthScreen> createState() => _SoilHealthScreenState();
}

class _SoilHealthScreenState extends State<SoilHealthScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _phCtrl = TextEditingController();
  final _nitrogenCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  bool _saving = false;

  Future<String> _fetchSoilAiAdvice(
    double ph,
    double n,
    double m,
    String crop,
  ) async {
    final cacheKey =
        'soil_ai_${ph}_${n}_${m}_${crop}_${AppSettings.instance.isBengali}';
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached;

    final String geminiKey = AppSettings.instance.geminiApiKey;
    final models = [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.5-flash-lite'
    ];

    final prompt =
        'As an expert soil scientist, analyze these soil parameters for growing $crop: '
        'pH: $ph, Nitrogen: $n ppm, Moisture: $m%. '
        'Return a single professional and actionable recommendation in ${AppSettings.instance.isBengali ? 'Bengali' : 'English'} '
        'stating exactly how to improve the soil for maximum yield. Keep it under 60 words.';

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
        }
      } catch (e) {
        continue; 
      }
    }

    // FINAL FALLBACK: Local Expert Logic if AI is exhausted
    final analysis = _analyzeSoil(ph, n, m);
    final topAdvice = analysis.suggestions.isNotEmpty ? analysis.suggestions.first.advice : '';
    
    return AppSettings.instance.isBengali
        ? 'বর্তমানে এআই কোটা পূর্ণ হয়েছে। আপনার জন্য স্ট্যান্ডার্ড পরামর্শ: $topAdvice'
        : 'AI Quota reached for today. Standard Expert Advice: $topAdvice';
  }

  @override
  void dispose() {
    _phCtrl.dispose();
    _nitrogenCtrl.dispose();
    _moistureCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    final s = AppSettings.instance;
    if (user == null) return;
    final ph = double.tryParse(_phCtrl.text);
    final n = double.tryParse(_nitrogenCtrl.text);
    final m = double.tryParse(_moistureCtrl.text);
    if (ph == null || n == null || m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isBengali
                ? 'সবগুলো ঘর সঠিক সংখ্যা দিয়ে পূরণ করুন'
                : 'Please fill all fields with valid numbers',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('soil_logs')
        .add({
          'ph': ph,
          'nitrogen': n,
          'moisture': m,
          'timestamp': FieldValue.serverTimestamp(),
        });
    _phCtrl.clear();
    _nitrogenCtrl.clear();
    _moistureCtrl.clear();

    final analysis = _analyzeSoil(ph, n, m);
    final notifBody = analysis.suggestions.take(2).join(' | ');

    final alertPrefix = s.isBengali ? 'মাটির এলার্ট: ' : 'Soil Alert: ';
    await NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🌱 $alertPrefix ${analysis.overallStatus}',
      body: notifBody,
      payload: 'soil_health',
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('notifications')
        .add({
          'title': '🌱 $alertPrefix ${analysis.overallStatus}',
          'body': notifBody,
          'ph': ph,
          'nitrogen': n,
          'moisture': m,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'soil_health',
          'read': false,
        });

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isBengali
                ? '✅ মাটির তথ্য সংরক্ষিত হয়েছে!'
                : '✅ Soil reading logged!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  _SoilAnalysis _analyzeSoil(double ph, double nitrogen, double moisture) {
    final s = AppSettings.instance;
    final suggestions = <_Suggestion>[];
    String status = s.isBengali ? 'ভালো' : 'Good';
    Color color = Colors.green;
    final inBigha = s.isBigha;
    final unit = inBigha
        ? (s.isBengali ? 'বিঘা' : 'bigha')
        : (s.isBengali ? 'একর' : 'acre');
    final bagsScale = inBigha ? 1.0 : 3.025;
    final kgScale = inBigha ? 0.13 : 0.405;

    if (ph < 4.5) {
      final bags = (3.5 * bagsScale).toStringAsFixed(1);
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🔴 অতিরিক্ত অম্লীয় (pH ${ph.toStringAsFixed(1)})'
              : '🔴 Critically Acidic (pH ${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'প্রচুর চুন প্রয়োগ করুন (~$bags বস্তা/$unit)। ২-৩ সপ্তাহ চাষ বন্ধ রাখুন।'
              : 'Apply heavy lime (~$bags bags/$unit). Avoid planting 2–3 weeks.',
          Colors.red,
        ),
      );
      status = s.isBengali ? 'জরুরী' : 'Critical';
      color = Colors.red;
    } else if (ph < 5.5) {
      final bags = (1.5 * bagsScale).toStringAsFixed(1);
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟠 অম্লীয় মাটি (pH ${ph.toStringAsFixed(1)})'
              : '🟠 Acidic Soil (pH ${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'চুন প্রয়োগ করুন (~$bags বস্তা/$unit)। ২ সপ্তাহ পর আবার পরীক্ষা করুন।'
              : 'Apply lime (~$bags bags/$unit). Re-test in 2 weeks.',
          Colors.orange,
        ),
      );
      if (color != Colors.red) {
        status = s.isBengali ? 'মনোযোগ প্রয়োজন' : 'Needs Attention';
        color = Colors.orange;
      }
    } else if (ph < 6.0) {
      final bags = (0.7 * bagsScale).toStringAsFixed(1);
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟡 সামান্য অম্লীয় (pH ${ph.toStringAsFixed(1)})'
              : '🟡 Slightly Acidic (pH ${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'অল্প চুন দিন (~$bags বস্তা/$unit)। প্রতি সপ্তাহে পর্যবেক্ষণ করুন।'
              : 'Light lime (~$bags bags/$unit). Monitor weekly.',
          Colors.amber,
        ),
      );
      if (color == Colors.green) {
        status = s.isBengali ? 'পর্যবেক্ষণ করুন' : 'Monitor';
        color = Colors.amber;
      }
    } else if (ph <= 7.0) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '✅ আদর্শ pH (${ph.toStringAsFixed(1)})'
              : '✅ Optimal pH (${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'ধান চাষের জন্য আদর্শ pH। বর্তমান ব্যবস্থাপনা বজায় রাখুন।'
              : 'pH is ideal for rice. Maintain current management.',
          Colors.green,
        ),
      );
    } else if (ph <= 7.5) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟡 সামান্য ক্ষারীয় (pH ${ph.toStringAsFixed(1)})'
              : '🟡 Slightly Alkaline (pH ${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'pH কমাতে সালফার বা অ্যামোনিয়াম সালফেট প্রয়োগ করুন।'
              : 'Apply sulphur or ammonium sulphate to lower pH.',
          Colors.amber,
        ),
      );
      if (color == Colors.green) {
        status = s.isBengali ? 'পর্যবেক্ষণ করুন' : 'Monitor';
        color = Colors.amber;
      }
    } else {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🔴 ক্ষারীয় মাটি (pH ${ph.toStringAsFixed(1)})'
              : '🔴 Alkaline Soil (pH ${ph.toStringAsFixed(1)})',
          s.isBengali
              ? 'জিপসাম এবং সালফার প্রয়োগ করুন। জলাবদ্ধতা এড়িয়ে চলুন।'
              : 'Apply gypsum + sulphur. Avoid waterlogging.',
          Colors.red,
        ),
      );
      status = s.isBengali ? 'জরুরী' : 'Critical';
      color = Colors.red;
    }

    if (nitrogen < 10) {
      final kg = (90 * kgScale).round();
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🔴 নাইট্রোজেন খুব কম ($nitrogen ppm)'
              : '🔴 Very Low Nitrogen ($nitrogen ppm)',
          s.isBengali
              ? 'দ্রুত ইউরিয়া (~$kg কেজি/$unit) প্রয়োগ করুন। কম্পোস্ট সার ব্যবহারের কথা ভাবুন।'
              : 'Apply Urea (~$kg kg/$unit) immediately. Consider compost.',
          Colors.red,
        ),
      );
      status = s.isBengali ? 'জরুরী' : 'Critical';
      color = Colors.red;
    } else if (nitrogen < 20) {
      final kg = (50 * kgScale).round();
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟠 নাইট্রোজেন কম ($nitrogen ppm)'
              : '🟠 Low Nitrogen ($nitrogen ppm)',
          s.isBengali
              ? 'ইউরিয়া (~$kg কেজি/$unit) প্রয়োগ করুন। কিস্তিতে সার প্রয়োগ করা ভালো।'
              : 'Apply Urea (~$kg kg/$unit). Split application recommended.',
          Colors.orange,
        ),
      );
      if (color != Colors.red) {
        status = s.isBengali ? 'মনোযোগ প্রয়োজন' : 'Needs Attention';
        color = Colors.orange;
      }
    } else if (nitrogen <= 40) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '✅ নাইট্রোজেন আদর্শ ($nitrogen ppm)'
              : '✅ Good Nitrogen ($nitrogen ppm)',
          s.isBengali
              ? 'নাইট্রোজেন লেভেল ঠিক আছে। সুষম সার প্রয়োগ বজায় রাখুন।'
              : 'Nitrogen is ideal. Maintain balanced fertilization.',
          Colors.green,
        ),
      );
    } else {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟠 নাইট্রোজেন বেশি ($nitrogen ppm)'
              : '🟠 High Nitrogen ($nitrogen ppm)',
          s.isBengali
              ? 'ইউরিয়া কমান। অতিরিক্ত ইউরিয়া ধানের গোছ এবং ব্লাস্ট রোগের কারণ হয়।'
              : 'Reduce urea. Excess causes lodging and blast disease.',
          Colors.orange,
        ),
      );
      if (color != Colors.red) {
        status = s.isBengali ? 'মনোযোগ প্রয়োজন' : 'Needs Attention';
        color = Colors.orange;
      }
    }

    if (moisture < 30) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🔴 অতিরিক্ত শুকনো ($moisture%)'
              : '🔴 Critically Dry ($moisture%)',
          s.isBengali
              ? 'দ্রুত সেচ দিন। অন্তত ৩ সেমি পানি জমিয়ে রাখুন।'
              : 'Irrigate immediately. Maintain ≥3cm standing water.',
          Colors.red,
        ),
      );
      status = s.isBengali ? 'জরুরী' : 'Critical';
      color = Colors.red;
    } else if (moisture < 60) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟠 আর্দ্রতা কম ($moisture%)'
              : '🟠 Low Moisture ($moisture%)',
          s.isBengali
              ? 'সেচ দিন। শিকড়ের বৃদ্ধির জন্য ৬০-৮০% আর্দ্রতা প্রয়োজন।'
              : 'Irrigate field. Target 60–80% for optimal root growth.',
          Colors.orange,
        ),
      );
      if (color != Colors.red) {
        status = s.isBengali ? 'মনোযোগ প্রয়োজন' : 'Needs Attention';
        color = Colors.orange;
      }
    } else if (moisture <= 80) {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '✅ আর্দ্রতা আদর্শ ($moisture%)'
              : '✅ Good Moisture ($moisture%)',
          s.isBengali
              ? 'আর্দ্রতা ঠিক আছে। বর্তমান সেচ ব্যবস্থা বজায় রাখুন।'
              : 'Optimal moisture level. Continue current irrigation.',
          Colors.green,
        ),
      );
    } else {
      suggestions.add(
        _Suggestion(
          s.isBengali
              ? '🟡 আর্দ্রতা বেশি ($moisture%)'
              : '🟡 High Moisture ($moisture%)',
          s.isBengali
              ? 'অতিরিক্ত পানি বের করে দিন যাতে শিকড় পচে না যায়।'
              : 'Drain excess water to prevent root rot.',
          Colors.amber,
        ),
      );
      if (color == Colors.green) {
        status = s.isBengali ? 'পর্যবেক্ষণ করুন' : 'Monitor';
        color = Colors.amber;
      }
    }

    return _SoilAnalysis(
      overallStatus: status,
      overallColor: color,
      suggestions: suggestions,
    );
  }

  String _phStatus(double ph) {
    final s = AppSettings.instance;
    if (ph < 5.5) return s.isBengali ? 'অত্যধিক অম্লীয়' : 'Too Acidic';
    if (ph < 6.0) return s.isBengali ? 'সামান্য অম্লীয়' : 'Slightly Acidic';
    if (ph <= 7.0)
      return s.isBengali ? 'ধানের জন্য আদর্শ ✅' : 'Optimal for Rice ✅';
    if (ph <= 7.5)
      return s.isBengali ? 'সামান্য ক্ষারীয়' : 'Slightly Alkaline';
    return s.isBengali ? 'অত্যধিক ক্ষারীয়' : 'Too Alkaline';
  }

  Color _phColor(double ph) {
    if (ph >= 6.0 && ph <= 7.0) return Colors.green;
    if ((ph >= 5.5 && ph < 6.0) || (ph > 7.0 && ph <= 7.5))
      return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ThemeAware(
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.translate('soil_health'),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: user == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('soil_logs')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];

                final List<FlSpot> phSpots = [];
                for (int i = 0; i < docs.length; i++) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  phSpots.add(
                    FlSpot(i.toDouble(), (d['ph'] as num?)?.toDouble() ?? 7.0),
                  );
                }

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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _glass(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.edit_note_rounded,
                                          color: AppColors.accent,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          s.translate('log_reading'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _numField(
                                      _phCtrl,
                                      s.translate('soil_ph'),
                                      s.isBengali
                                          ? 'আদর্শ: ৬.০ – ৭.০'
                                          : 'Optimal: 6.0 – 7.0',
                                      Icons.science_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _numField(
                                            _nitrogenCtrl,
                                            s.translate('nitrogen'),
                                            '20 – 40',
                                            Icons.grain_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _numField(
                                            _moistureCtrl,
                                            s.translate('moisture'),
                                            '60 – 80',
                                            Icons.water_drop_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_rounded,
                                              color: Colors.white,
                                            ),
                                      label: Text(
                                        _saving
                                            ? '...'
                                            : s.translate('save_changes'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 4,
                                        shadowColor: AppColors.accent
                                            .withOpacity(0.3),
                                      ),
                                      onPressed: _saving ? null : _saveLog,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              if (docs.length >= 2) ...[
                                _glass(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.translate('trend'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 160,
                                        child: LineChart(
                                          LineChartData(
                                            minY: 4,
                                            maxY: 9,
                                            gridData: const FlGridData(
                                              show: true,
                                            ),
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 30,
                                                  getTitlesWidget: (v, _) =>
                                                      Text(
                                                        v.toStringAsFixed(1),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .secondaryText,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              rightTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: phSpots,
                                                isCurved: true,
                                                color: AppColors.accent,
                                                barWidth: 3,
                                                dotData: const FlDotData(
                                                  show: true,
                                                ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  color: AppColors.accent
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              LineChartBarData(
                                                spots: [
                                                  FlSpot(0, 6.0),
                                                  FlSpot(
                                                    (docs.length - 1)
                                                        .toDouble(),
                                                    6.0,
                                                  ),
                                                ],
                                                color: Colors.green.withOpacity(
                                                  0.4,
                                                ),
                                                barWidth: 1,
                                                dashArray: [5, 5],
                                                dotData: const FlDotData(
                                                  show: false,
                                                ),
                                              ),
                                              LineChartBarData(
                                                spots: [
                                                  FlSpot(0, 7.0),
                                                  FlSpot(
                                                    (docs.length - 1)
                                                        .toDouble(),
                                                    7.0,
                                                  ),
                                                ],
                                                color: Colors.green.withOpacity(
                                                  0.4,
                                                ),
                                                barWidth: 1,
                                                dashArray: [5, 5],
                                                dotData: const FlDotData(
                                                  show: false,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s.isBengali
                                            ? 'ড্যাশ লাইন = ধানের জন্য আদর্শ pH (৬.০–৭.০)'
                                            : 'Dashed lines = optimal rice pH range (6.0–7.0)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (docs.isNotEmpty) ...[
                                ValueListenableBuilder<String>(
                                  valueListenable: s.landUnit,
                                  builder: (_, __, ___) =>
                                      _buildSuggestionCard(docs.last),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (docs.isEmpty)
                                _glass(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        s.isBengali
                                            ? 'এখনও কোনো তথ্য যোগ করা হয়নি।\nউপরে আপনার প্রথম তথ্য যোগ করুন।'
                                            : 'No soil readings yet.\nLog your first reading above.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...docs.reversed.map((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  final ts = d['timestamp'] as Timestamp?;
                                  final date = ts != null
                                      ? DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(ts.toDate())
                                      : (s.isBengali ? 'অপেক্ষমাণ' : 'Pending');
                                  final ph =
                                      (d['ph'] as num?)?.toDouble() ?? 0.0;
                                  return Dismissible(
                                    key: ValueKey(doc.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    confirmDismiss: (_) async => await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: AppColors.scaffoldBg,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: Text(
                                          s.isBengali
                                              ? 'তথ্যটি মুছে ফেলবেন?'
                                              : 'Delete Reading?',
                                          style: TextStyle(
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                        content: Text(
                                          s.isBengali
                                              ? 'pH ${ph.toStringAsFixed(1)} এর এই তথ্যটি মুছে ফেলতে চান?'
                                              : 'Remove pH ${ph.toStringAsFixed(1)} entry?',
                                          style: TextStyle(
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(
                                              s.isBengali ? 'বাতিল' : 'Cancel',
                                              style: TextStyle(
                                                color: AppColors.secondaryText,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(
                                              s.isBengali
                                                  ? 'মুছে ফেলুন'
                                                  : 'Delete',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onDismissed: (_) async {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user!.uid)
                                          .collection('soil_logs')
                                          .doc(doc.id)
                                          .delete();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.glassFill,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _phColor(ph).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: _phColor(
                                                ph,
                                              ).withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.science_rounded,
                                              color: _phColor(ph),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'pH ${ph.toStringAsFixed(1)}  —  ${_phStatus(ph)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: _phColor(ph),
                                                  ),
                                                ),
                                                Text(
                                                  '${s.isBengali ? 'নাইট্রোজেন' : 'N'}: ${d['nitrogen']} ppm  •  ${s.isBengali ? 'আর্দ্রতা' : 'Moisture'}: ${d['moisture']}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.hintText,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                s.isBengali
                                                    ? '← মুছতে স্লাইড করুন'
                                                    : '← swipe to delete',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.hintText
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              const Spacer(),
                            ],
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

  Widget _buildSuggestionCard(QueryDocumentSnapshot doc) {
    final s = AppSettings.instance;
    final d = doc.data() as Map<String, dynamic>;
    final ph = (d['ph'] as num?)?.toDouble() ?? 7.0;
    final n = (d['nitrogen'] as num?)?.toDouble() ?? 20.0;
    final m = (d['moisture'] as num?)?.toDouble() ?? 70.0;
    final analysis = _analyzeSoil(ph, n, m);
    final unitLabel = s.isBigha
        ? (s.isBengali ? 'প্রতি বিঘা' : 'per Bigha')
        : (s.isBengali ? 'প্রতি একর' : 'per Acre');

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      analysis.overallColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_rounded,
                      color: analysis.overallColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.isBengali
                            ? 'মাটি পরীক্ষার রিপোর্ট'
                            : 'Smart Soil Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: analysis.overallColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${analysis.overallStatus} • $unitLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: analysis.overallColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Section 1: At a Glance (3 mini cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.isBengali ? 'এক নজরে অবস্থা' : 'At a Glance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: analysis.suggestions.map((sug) {
                          return Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sug.color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sug.color.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: sug.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sug.title.split('(')[0].trim(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: sug.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sug.advice,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryText,
                                    height: 1.3,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.black12,
              ),

              // Section 2: AI Advisor
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .get(),
                builder: (context, userSnap) {
                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final crop = userData['selectedPlanName'] ?? 'Rice';

                  return FutureBuilder<String>(
                    future: _fetchSoilAiAdvice(ph, n, m, crop),
                    builder: (context, aiSnap) {
                      String cleanAdvice = aiSnap.data ?? '';
                      // Strip Markdown bold asterisks
                      cleanAdvice = cleanAdvice
                          .replaceAll('**', '')
                          .replaceAll('*', '');

                      return Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurpleAccent.withOpacity(0.08),
                              Colors.blueAccent.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.deepPurpleAccent.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.deepPurpleAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.isBengali
                                      ? 'বিশেষজ্ঞ কৃষি কৌশল'
                                      : 'Expert Agronomic Strategy',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.deepPurpleAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (aiSnap.connectionState ==
                                ConnectionState.waiting)
                              Center(
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.transparent,
                                  color: Colors.deepPurpleAccent.withOpacity(
                                    0.3,
                                  ),
                                ),
                              )
                            else
                              Text(
                                cleanAdvice.isEmpty
                                    ? (s.isBengali
                                          ? 'পরামর্শ পাওয়া যাচ্ছে না।'
                                          : 'No custom strategy available.')
                                    : cleanAdvice,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryText,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        hintStyle: TextStyle(fontSize: 10, color: AppColors.hintText),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 18),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SoilAnalysis {
  final String overallStatus;
  final Color overallColor;
  final List<_Suggestion> suggestions;
  const _SoilAnalysis({
    required this.overallStatus,
    required this.overallColor,
    required this.suggestions,
  });
}

class _Suggestion {
  final String title;
  final String advice;
  final Color color;
  const _Suggestion(this.title, this.advice, this.color);

  @override
  String toString() => '$title — $advice';
}
