import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';

class ProfitLossDashboardScreen extends StatefulWidget {
  const ProfitLossDashboardScreen({super.key});

  @override
  State<ProfitLossDashboardScreen> createState() => _ProfitLossDashboardScreenState();
}

class _ProfitLossDashboardScreenState extends State<ProfitLossDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;

  String _getTranslatedCategory(String cat) {
    final s = AppSettings.instance;
    final map = {
      'Seeds': s.translate('cat_seeds'),
      'Fertilizer': s.translate('cat_fertilizer'),
      'Labor': s.translate('cat_labor'),
      'Equipment': s.translate('cat_equipment'),
      'Irrigation': s.translate('cat_irrigation'),
      'Pesticide': s.translate('cat_pesticide'),
      'Transport': s.translate('cat_transport'),
      'Other': s.translate('cat_other'),
      'Crop Sale': s.translate('cat_sale'),
      'Subsidy': s.translate('cat_subsidy'),
      'Loan/Credit': s.translate('cat_loan'),
      'Other Income': s.translate('cat_income'),
    };
    return map[cat] ?? cat;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('profit_loss'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
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
            child: user == null
                ? Center(child: Text(s.isBengali ? 'লগইন করুন' : 'Please log in', style: TextStyle(color: AppColors.primaryText)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('expenses').snapshots(),
                    builder: (ctx, expSnap) {
                      if (expSnap.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: AppColors.accent));
                      }
                      final allDocs = expSnap.data?.docs ?? [];

                      double totalExpenses = 0, totalRevenue = 0;
                      final Map<String, double> expCatMap = {};
                      final Map<String, double> revCatMap = {};

                      for (final doc in allDocs) {
                        final d = doc.data() as Map<String, dynamic>;
                        final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                        final type = d['type'] as String? ?? 'expense';
                        final cat = d['category'] as String? ?? 'Other';
                        if (type == 'revenue') {
                          totalRevenue += amt;
                          revCatMap[cat] = (revCatMap[cat] ?? 0) + amt;
                        } else {
                          totalExpenses += amt;
                          expCatMap[cat] = (expCatMap[cat] ?? 0) + amt;
                        }
                      }

                      final double profit = totalRevenue - totalExpenses;
                      final bool isProfit = profit >= 0;

                      List<PieChartSectionData> _sections(Map<String, double> map, double total) {
                        return map.entries.map((e) => PieChartSectionData(
                          value: e.value,
                          title: total > 0 ? '${s.translatePrice(((e.value / total) * 100).toStringAsFixed(0))}%' : '',
                          color: _getCatColor(e.key),
                          radius: 55,
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        )).toList();
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s.translate('sync_msg'), style: TextStyle(fontSize: 12, color: AppColors.accent))),
                              ]),
                            ),

                            _buildGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(s.translate('season_summary'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                    Expanded(child: _statBox(s.translate('total_revenue'), '৳ ${s.translatePrice(totalRevenue.toStringAsFixed(0))}', Colors.green, Icons.arrow_downward_rounded)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _statBox(s.translate('total_expenses'), '৳ ${s.translatePrice(totalExpenses.toStringAsFixed(0))}', Colors.redAccent, Icons.arrow_upward_rounded)),
                                  ]),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isProfit
                                            ? [AppColors.accent, const Color(0xFF4CAF50)]
                                            : [Colors.redAccent, Colors.red.shade800],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(isProfit ? '📈 ${s.translate('net_profit_label')}' : '📉 ${s.translate('net_loss_label')}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text('৳ ${s.translatePrice(profit.abs().toStringAsFixed(0))}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                                        if (totalRevenue > 0)
                                          Text('${s.isBengali ? "লাভের হার (ROI)" : "ROI"}: ${s.translatePrice(((profit / totalRevenue) * 100).toStringAsFixed(1))}%', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            if (expCatMap.isNotEmpty)
                              _buildGlass(
                                child: Column(
                                  children: [
                                    Text(s.translate('expense_breakdown'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 190,
                                      child: PieChart(PieChartData(sections: _sections(expCatMap, totalExpenses), centerSpaceRadius: 40, sectionsSpace: 3)),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 14, runSpacing: 8,
                                      children: expCatMap.keys.map((cat) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getCatColor(cat), shape: BoxShape.circle)),
                                          const SizedBox(width: 5),
                                          Text('${_getTranslatedCategory(cat)} ৳${s.translatePrice(expCatMap[cat]!.toStringAsFixed(0))}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText)),
                                        ],
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),

                            if (expCatMap.isNotEmpty) const SizedBox(height: 16),

                            if (revCatMap.isNotEmpty)
                              _buildGlass(
                                child: Column(
                                  children: [
                                    Text(s.translate('revenue_breakdown'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 190,
                                      child: PieChart(PieChartData(sections: _sections(revCatMap, totalRevenue), centerSpaceRadius: 40, sectionsSpace: 3)),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 14, runSpacing: 8,
                                      children: revCatMap.keys.map((cat) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getCatColor(cat), shape: BoxShape.circle)),
                                          const SizedBox(width: 5),
                                          Text('${_getTranslatedCategory(cat)} ৳${s.translatePrice(revCatMap[cat]!.toStringAsFixed(0))}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText)),
                                        ],
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),

                            if (allDocs.isEmpty)
                              _buildGlass(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(s.translate('log_msg'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
                                  ),
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

  static Color _getCatColor(String cat) {
    const colors = {
      'Seeds': Colors.lightGreen,
      'Fertilizer': Colors.deepPurple,
      'Labor': Colors.orange,
      'Equipment': Colors.blue,
      'Irrigation': Colors.cyan,
      'Pesticide': Colors.redAccent,
      'Transport': Colors.teal,
      'Other': Colors.blueGrey,
      'Crop Sale': Colors.green,
      'Subsidy': Colors.amber,
      'Loan/Credit': Colors.indigo,
      'Other Income': Colors.teal,
    };
    return colors[cat] ?? Colors.blueGrey;
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
