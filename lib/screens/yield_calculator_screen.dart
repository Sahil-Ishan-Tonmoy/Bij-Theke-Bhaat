import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class YieldCalculatorScreen extends StatefulWidget {
  const YieldCalculatorScreen({super.key});

  @override
  State<YieldCalculatorScreen> createState() => _YieldCalculatorScreenState();
}

class _YieldCalculatorScreenState extends State<YieldCalculatorScreen> {
  final _fieldSizeCtrl = TextEditingController();
  String _unit = 'Bigha';
  bool _benchmarkInBigha = true; 

  String? _selectedVariety;
  double? _selectedPricePerKg;
  String? _selectedPriceRaw;

  static const Map<String, double> _yieldRates = {
    'aman': 540.0,
    'boro': 720.0,
    'miniket': 480.0,
    'kataribhog': 400.0,
    'irri': 650.0,
    'br-28': 680.0,
    'br28': 680.0,
    'br-29': 700.0,
    'br29': 700.0,
    'hybrid': 750.0,
    'balam': 460.0,
    'najirshail': 420.0,
  };

  double _yieldPerBighaFor(String name) {
    final lower = name.toLowerCase().replaceAll(' ', '');
    for (final key in _yieldRates.keys) {
      if (lower.contains(key.replaceAll('-', ''))) return _yieldRates[key]!;
    }
    return 500.0;
  }

  double? _totalYieldKg;
  double? _projectedRevenue;

  static const double _bighaToAcre = 0.3306; 
  static const double _acreToBigha = 3.025;
  static const double _hectareToBigha = 7.47;

  double? get _fieldSizeInBigha {
    final v = double.tryParse(_fieldSizeCtrl.text);
    if (v == null || v <= 0) return null;
    if (_unit == 'Bigha') return v;
    if (_unit == 'Acre') return v * _acreToBigha;
    if (_unit == 'Hectare') return v * _hectareToBigha;
    return v;
  }

  String _getTranslatedUnit(String unit) {
    final s = AppSettings.instance;
    switch (unit) {
      case 'Bigha': return s.translate('bigha');
      case 'Acre': return s.translate('acre');
      case 'Hectare': return s.translate('hectare');
      default: return unit;
    }
  }

  void _calculate() {
    final s = AppSettings.instance;
    final sizeInBigha = _fieldSizeInBigha;
    if (sizeInBigha == null || _selectedVariety == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isBengali ? 'দয়া করে সব ঘর পূরণ করুন' : 'Please fill all fields'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final totalKg = sizeInBigha * _yieldPerBighaFor(_selectedVariety!);
    setState(() {
      _totalYieldKg = totalKg;
      _projectedRevenue = _selectedPricePerKg != null ? totalKg * _selectedPricePerKg! : null;
    });
  }

  double? _parsePrice(dynamic raw) {
    final str = (raw ?? '').toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str);
  }

  @override
  void dispose() {
    _fieldSizeCtrl.dispose();
    super.dispose();
  }

  Widget _glass({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ]),
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
        title: Text(s.translate('yield_calc'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
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
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('market_prices').snapshots(),
              builder: (ctx, snap) {
                final priceDocs = snap.data?.docs ?? [];

                final varieties = priceDocs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name = d['variety'] ?? d['name'] ?? '?';
                  final priceKg = _parsePrice(d['price']);
                  return _VarietyEntry(
                    name: name.toString(),
                    priceRaw: d['price']?.toString() ?? '',
                    priceKg: priceKg,
                  );
                }).toList();

                final Map<String, double> livePriceMap = {};
                for (final v in varieties) {
                  if (v.priceKg != null) {
                    livePriceMap[v.name.toLowerCase().replaceAll(' ', '')] = v.priceKg!;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.translate('field_details'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                            const SizedBox(height: 16),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _fieldSizeCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(color: AppColors.primaryText),
                                    decoration: InputDecoration(
                                      labelText: s.translate('field_size'),
                                      labelStyle: TextStyle(color: AppColors.secondaryText),
                                      prefixIcon: Icon(Icons.landscape_rounded, color: AppColors.accent),
                                      filled: true,
                                      fillColor: AppColors.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 108,
                                  child: DropdownButtonFormField<String>(
                                    value: _unit,
                                    isExpanded: true,
                                    dropdownColor: AppColors.scaffoldBg,
                                    style: TextStyle(color: AppColors.primaryText),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppColors.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    ),
                                    items: ['Bigha', 'Acre', 'Hectare'].map((u) => DropdownMenuItem(value: u, child: Text(_getTranslatedUnit(u), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _unit = v!),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (varieties.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(s.isBengali ? '⚠️ কোনো বাজার দর পাওয়া যায়নি।' : '⚠️ No market prices found. Ask Admin to add rice prices first.', style: const TextStyle(color: Colors.orange, fontSize: 13)),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: _selectedVariety,
                                isExpanded: true,
                                dropdownColor: AppColors.scaffoldBg,
                                style: TextStyle(color: AppColors.primaryText),
                                hint: Text(s.translate('select_variety_hint'), style: TextStyle(color: AppColors.secondaryText)),
                                decoration: InputDecoration(
                                  labelText: s.isBengali ? 'ধানের জাত (লাইভ মূল্য থেকে)' : 'Rice Variety (from live prices)',
                                  labelStyle: TextStyle(color: AppColors.secondaryText),
                                  prefixIcon: Icon(Icons.grass_rounded, color: AppColors.accent),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                ),
                                items: varieties.map((v) => DropdownMenuItem<String>(
                                  value: v.name,
                                  child: Row(children: [
                                    Expanded(child: TranslateText(v.name, overflow: TextOverflow.ellipsis)),
                                    Text(s.translatePrice(v.priceRaw), style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.bold)),
                                  ]),
                                )).toList(),
                                onChanged: (v) {
                                  final entry = varieties.firstWhere((e) => e.name == v);
                                  setState(() {
                                    _selectedVariety = v;
                                    _selectedPricePerKg = entry.priceKg;
                                    _selectedPriceRaw = entry.priceRaw;
                                    _totalYieldKg = null;
                                    _projectedRevenue = null;
                                  });
                                },
                              ),
                            const SizedBox(height: 16),

                            ElevatedButton.icon(
                              icon: const Icon(Icons.calculate_rounded, color: Colors.white),
                              label: Text(s.translate('calculate_yield'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _calculate,
                            ),
                          ],
                        ),
                      ),

                      if (_totalYieldKg != null) ...[
                        const SizedBox(height: 16),
                        _glass(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Icon(Icons.bar_chart_rounded, color: AppColors.primaryText),
                                const SizedBox(width: 8),
                                Text(s.translate('results_for'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                const SizedBox(width: 4),
                                Expanded(child: TranslateText(_selectedVariety!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryText))),
                              ]),
                              const SizedBox(height: 14),
                              _resultRow(Icons.scale_rounded, Colors.indigoAccent, s.translate('expected_harvest'),
                                  '${s.translatePrice(_totalYieldKg!.toStringAsFixed(0))} কেজি  ≈  ${s.translatePrice((_totalYieldKg! / 40).toStringAsFixed(1))} ${s.translate('unit_mon')}'),
                              if (_projectedRevenue != null)
                                _resultRow(Icons.paid_rounded, Colors.green, s.translate('projected_revenue'),
                                    '৳ ${s.translatePrice(_projectedRevenue!.toStringAsFixed(0))}  (${s.translatePrice(_selectedPriceRaw ?? (s.isBengali ? "লাইভ রেট" : "live rate"))})'),
                              if (_projectedRevenue == null)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(s.isBengali ? '⚠️ এই জাতের জন্য কোনো মূল্য পাওয়া যায়নি।' : '⚠️ No parseable price for this variety.', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                ),
                              const Divider(height: 20),
                              Text(s.isBengali ? 'এটি BRRI-এর গড় ফলন তথ্যের ওপর ভিত্তি করে। প্রকৃত ফলাফল মাটি এবং আবহাওয়ার ওপর নির্ভর করে ভিন্ন হতে পারে।' : 'Based on BRRI average yield data. Actual results vary with soil, weather, and farming conditions.',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _glass(
                        padding: const EdgeInsets.all(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: AppColors.primaryText, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(s.translate('benchmarks'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryText.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _toggleChip(s.translate('bigha'), _benchmarkInBigha, 'Bigha'),
                                        _toggleChip(s.translate('acre'), !_benchmarkInBigha, 'Acre'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                              child: Text(
                                '${s.isBengali ? "প্রতি" : "Expected yield per"} ${_benchmarkInBigha ? s.translate('bigha') : s.translate('acre')} ${s.isBengali ? "এর প্রত্যাশিত ফলন" : "with live revenue estimate"}',
                                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                              ),
                            ),
                            const Divider(height: 1),
                            ..._buildBenchmarkRows(livePriceMap, priceDocs),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleChip(String label, bool active, String value) {
    return GestureDetector(
      onTap: () => setState(() => _benchmarkInBigha = value == 'Bigha'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.secondaryText)),
      ),
    );
  }

  List<Widget> _buildBenchmarkRows(Map<String, double> livePriceMap, List<QueryDocumentSnapshot> priceDocs) {
    final s = AppSettings.instance;
    if (priceDocs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(s.isBengali ? 'কোনো লাইভ মূল্য পাওয়া যায়নি।' : 'No live price entries found.\nAsk the Admin to add market prices.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
        ),
      ];
    }

    return priceDocs.asMap().entries.map((entry) {
      final i = entry.key;
      final doc = entry.value;
      final d = doc.data() as Map<String, dynamic>;
      final name = (d['variety'] ?? d['name'] ?? '?').toString();
      final livePrice = _parsePrice(d['price']);

      final double yieldPerBigha = _yieldPerBighaFor(name);
      final double displayYield = _benchmarkInBigha ? yieldPerBigha : yieldPerBigha * _bighaToAcre;
      final double? revenuePerUnit = livePrice != null ? displayYield * livePrice : null;
      final double pct = displayYield / (_benchmarkInBigha ? 750.0 : 750.0 * _bighaToAcre);
      final String unitLabel = _benchmarkInBigha ? s.translate('bigha') : s.translate('acre');
      final String priceRaw = d['price']?.toString() ?? '';

      return Container(
        color: i.isOdd ? AppColors.primaryText.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslateText(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                      if (priceRaw.isNotEmpty)
                        Text('${s.isBengali ? "লাইভ" : "Live"}: ${s.translatePrice(priceRaw)}', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${s.translatePrice(displayYield.toStringAsFixed(0))} কেজি/$unitLabel',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  if (revenuePerUnit != null)
                    Text('≈ ৳${s.translatePrice(revenuePerUnit.toStringAsFixed(0))}/$unitLabel',
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: AppColors.primaryText.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(const Color(0xFF81C784), const Color(0xFF2D5A27), pct.clamp(0.0, 1.0))!,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _VarietyEntry {
  final String name;
  final String priceRaw;
  final double? priceKg;
  const _VarietyEntry({required this.name, required this.priceRaw, required this.priceKg});
}
