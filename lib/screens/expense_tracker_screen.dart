import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/translate_text.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Seeds';
  String _transactionType = 'expense'; // 'expense' | 'revenue'

  // ─── Categories ───
  static const Map<String, Color> _expenseCategories = {
    'Seeds': Colors.lightGreen,
    'Fertilizer': Colors.deepPurple,
    'Labor': Colors.orange,
    'Equipment': Colors.blue,
    'Irrigation': Colors.cyan,
    'Pesticide': Colors.redAccent,
    'Transport': Colors.teal,
    'Other': Colors.blueGrey,
  };

  static const Map<String, Color> _revenueCategories = {
    'Crop Sale': Colors.green,
    'Subsidy': Colors.amber,
    'Loan/Credit': Colors.indigo,
    'Other Income': Colors.teal,
  };

  String _getCategoryKey(String cat) {
    switch (cat) {
      case 'Seeds': return 'cat_seeds';
      case 'Fertilizer': return 'cat_fertilizer';
      case 'Labor': return 'cat_labor';
      case 'Equipment': return 'cat_equipment';
      case 'Irrigation': return 'cat_irrigation';
      case 'Pesticide': return 'cat_pesticide';
      case 'Transport': return 'cat_transport';
      case 'Other': return 'cat_other';
      case 'Crop Sale': return 'cat_sale';
      case 'Subsidy': return 'cat_subsidy';
      case 'Loan/Credit': return 'cat_loan';
      case 'Other Income': return 'cat_income';
      default: return 'cat_other';
    }
  }

  Map<String, Color> get _currentCategories =>
      _transactionType == 'expense' ? _expenseCategories : _revenueCategories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDialog({String type = 'expense'}) {
    final s = AppSettings.instance;
    _titleController.clear();
    _amountController.clear();
    _transactionType = type;
    _selectedCategory = type == 'expense' ? 'Seeds' : 'Crop Sale';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 28,
          ),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() {
                          _transactionType = 'expense';
                          _selectedCategory = 'Seeds';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _transactionType == 'expense' ? Colors.redAccent : AppColors.glassFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _transactionType == 'expense' ? Colors.redAccent : AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward_rounded, color: _transactionType == 'expense' ? Colors.white : AppColors.secondaryText, size: 18),
                              const SizedBox(width: 6),
                              Text(s.translate('expense'), style: TextStyle(fontWeight: FontWeight.bold, color: _transactionType == 'expense' ? Colors.white : AppColors.secondaryText)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() {
                          _transactionType = 'revenue';
                          _selectedCategory = 'Crop Sale';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _transactionType == 'revenue' ? AppColors.accent : AppColors.glassFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _transactionType == 'revenue' ? AppColors.accent : AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward_rounded, color: _transactionType == 'revenue' ? Colors.white : AppColors.secondaryText, size: 18),
                              const SizedBox(width: 6),
                              Text(s.translate('revenue'), style: TextStyle(fontWeight: FontWeight.bold, color: _transactionType == 'revenue' ? Colors.white : AppColors.secondaryText)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                Text(
                  '${s.isBengali ? "" : "Log "}${_transactionType == 'expense' ? s.translate('expense') : s.translate('revenue')}${s.isBengali ? " যোগ করুন" : ""}',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: _transactionType == 'expense' ? Colors.redAccent : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _titleController,
                  style: TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: _transactionType == 'expense' ? (s.isBengali ? 'খরচের বিবরণ' : 'Expense Description') : (s.isBengali ? 'আয়ের উৎস' : 'Revenue Source'),
                    labelStyle: TextStyle(color: AppColors.secondaryText),
                    filled: true, fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: s.isBengali ? 'টাকার পরিমাণ (৳)' : 'Amount (৳ Taka)',
                    labelStyle: TextStyle(color: AppColors.secondaryText),
                    prefixText: '৳ ',
                    prefixStyle: TextStyle(color: AppColors.primaryText),
                    filled: true, fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: AppColors.scaffoldBg,
                  style: TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: s.isBengali ? 'বিভাগ' : 'Category',
                    labelStyle: TextStyle(color: AppColors.secondaryText),
                    filled: true, fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: _currentCategories.keys.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Row(children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: _currentCategories[cat], shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(s.translate(_getCategoryKey(cat)), style: TextStyle(color: AppColors.primaryText)),
                    ]),
                  )).toList(),
                  onChanged: (v) { if (v != null) setModal(() => _selectedCategory = v); },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _transactionType == 'expense' ? Colors.redAccent : AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _save(ctx),
                  child: Text(
                    _transactionType == 'expense' ? (s.isBengali ? 'খরচ যোগ করুন' : 'Add Expense') : (s.isBengali ? 'আয় যোগ করুন' : 'Add Revenue'),
                    style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext ctx) async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || amount == null || amount <= 0 || user == null) return;
    Navigator.pop(ctx);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('expenses').add({
      'title': title,
      'amount': amount,
      'category': _selectedCategory,
      'type': _transactionType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _delete(String id) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('expenses').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    if (user == null) return const Scaffold(body: Center(child: Text('Unauthorized')));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('farm_ledger'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryText,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: [
            Tab(icon: const Icon(Icons.receipt_long_rounded), text: s.isBengali ? 'সব' : 'All'),
            Tab(icon: const Icon(Icons.arrow_upward_rounded), text: s.translate('expense')),
            Tab(icon: const Icon(Icons.arrow_downward_rounded), text: s.translate('revenue')),
            Tab(icon: const Icon(Icons.bar_chart_rounded), text: s.isBengali ? 'বিশ্লেষণ' : 'Analytics'),
          ],
        ),
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(user!.uid).collection('expenses')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                final allDocs = snap.data?.docs ?? [];

                double totalExpense = 0, totalRevenue = 0;
                for (final doc in allDocs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                  final type = d['type'] as String? ?? 'expense';
                  if (type == 'revenue') totalRevenue += amt;
                  else totalExpense += amt;
                }
                final double net = totalRevenue - totalExpense;
                final bool isProfit = net >= 0;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildSummaryCard(totalExpense, totalRevenue, net, isProfit),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(allDocs, null),
                          _buildList(allDocs, 'expense'),
                          _buildList(allDocs, 'revenue'),
                          _buildAnalytics(allDocs),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(s.translate('add_entry'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddDialog(),
      ),
    );
  }

  Widget _buildAnalytics(List<QueryDocumentSnapshot> allDocs) {
    final s = AppSettings.instance;
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

    if (allDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.secondaryText.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(s.isBengali ? 'এখনও কোনো তথ্য নেই।\nঅ্যানালিটিক্স দেখতে আয় এবং ব্যয়ের হিসাব যোগ করুন।' : 'No data yet.\nAdd expenses and revenue to see analytics.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 15)),
          ]),
        ),
      );
    }

    Color _getCatColor(String cat) {
      const colors = <String, Color>{
        'Seeds': Colors.lightGreen, 'Fertilizer': Colors.deepPurple, 'Labor': Colors.orange,
        'Equipment': Colors.blue, 'Irrigation': Colors.cyan, 'Pesticide': Colors.redAccent,
        'Transport': Colors.teal, 'Other': Colors.blueGrey,
        'Crop Sale': Colors.green, 'Subsidy': Colors.amber, 'Loan/Credit': Colors.indigo, 'Other Income': Colors.teal,
      };
      return colors[cat] ?? Colors.blueGrey;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isProfit ? [AppColors.accent, const Color(0xFF4CAF50)] : [Colors.redAccent, Colors.red.shade800]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isProfit ? (s.isBengali ? '📈 নীট লাভ' : '📈 Net Profit') : (s.isBengali ? '📉 নীট ক্ষতি' : '📉 Net Loss'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('৳ ${s.translatePrice(profit.abs().toStringAsFixed(0))}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                if (totalRevenue > 0)
                  Text('${s.isBengali ? "লাভের হার (ROI)" : "ROI"}: ${s.translatePrice(((profit / totalRevenue) * 100).toStringAsFixed(1))}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${s.translate('revenue')}  ৳${s.translatePrice(totalRevenue.toStringAsFixed(0))}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${s.translate('expense')} ৳${s.translatePrice(totalExpenses.toStringAsFixed(0))}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          if (expCatMap.isNotEmpty) _analyticsCard(
            title: s.isBengali ? 'ব্যয়ের বিবরণ' : 'Expense Breakdown',
            catMap: expCatMap,
            total: totalExpenses,
            catColor: _getCatColor,
          ),

          if (expCatMap.isNotEmpty) const SizedBox(height: 14),

          if (revCatMap.isNotEmpty) _analyticsCard(
            title: s.isBengali ? 'আয়ের বিবরণ' : 'Revenue Breakdown',
            catMap: revCatMap,
            total: totalRevenue,
            catColor: _getCatColor,
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard({
    required String title,
    required Map<String, double> catMap,
    required double total,
    required Color Function(String) catColor,
  }) {
    final s = AppSettings.instance;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
              const SizedBox(height: 14),
              ...catMap.entries.map((e) {
                final pct = total > 0 ? e.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: catColor(e.key), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(s.translate(_getCategoryKey(e.key)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
                      ]),
                      Text('৳${s.translatePrice(e.value.toStringAsFixed(0))}  (${s.translatePrice((pct * 100).toStringAsFixed(0))}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor(e.key))),
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.black.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(catColor(e.key)),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double expense, double revenue, double net, bool isProfit) {
    final s = AppSettings.instance;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _summaryTile(s.translate('revenue'), '৳ ${s.translatePrice(revenue.toStringAsFixed(0))}', Colors.green, Icons.arrow_downward_rounded),
                  const SizedBox(width: 12),
                  _summaryTile(s.translate('expense'), '৳ ${s.translatePrice(expense.toStringAsFixed(0))}', Colors.redAccent, Icons.arrow_upward_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isProfit
                        ? [AppColors.accent, const Color(0xFF4CAF50)]
                        : [Colors.redAccent, Colors.red.shade800],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isProfit ? (s.isBengali ? '📈 নীট লাভ' : '📈 Net Profit') : (s.isBengali ? '📉 নীট ক্ষতি' : '📉 Net Loss'),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    Text('৳ ${s.translatePrice(net.abs().toStringAsFixed(0))}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> allDocs, String? typeFilter) {
    final s = AppSettings.instance;
    final docs = typeFilter == null ? allDocs : allDocs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['type'] ?? 'expense') == typeFilter;
    }).toList();

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(typeFilter == 'revenue' ? Icons.savings_rounded : Icons.receipt_long_rounded, size: 56, color: AppColors.secondaryText.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              typeFilter == 'revenue' 
                ? (s.isBengali ? 'এখনও কোনো আয়ের হিসাব নেই।\nনিচে সবুজ ↓ বাটনে ক্লিক করে যোগ করুন।' : 'No revenue entries yet.\nTap the green ↓ button to add income.') 
                : (typeFilter == 'expense' ? (s.isBengali ? 'এখনও কোনো ব্যয়ের হিসাব নেই।\nনিচে + বাটনে ক্লিক করে যোগ করুন।' : 'No expenses yet.\nTap + to log your first expense.') : (s.isBengali ? 'এখনও কোনো লেনদেন নেই।\nশুরু করতে নিচের বাটনে ক্লিক করুন।' : 'No transactions yet.\nTap the buttons below to get started.')),
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final allExpCats = {..._expenseCategories, ..._revenueCategories};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final isRevenue = (data['type'] ?? 'expense') == 'revenue';
        final cat = data['category'] as String? ?? 'Other';
        final color = allExpCats[cat] ?? (isRevenue ? Colors.green : Colors.blueGrey);
        final ts = data['timestamp'] as Timestamp?;
        final dateStr = ts != null ? DateFormat('MMM dd, yyyy').format(ts.toDate()) : (s.isBengali ? 'অপেক্ষমাণ...' : 'Pending...');
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;

        return Dismissible(
          key: ValueKey(doc.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.scaffoldBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(s.isBengali ? 'তথ্যটি মুছে ফেলবেন?' : 'Delete Entry?'),
                content: Row(
                  children: [
                    Text(s.isBengali ? "" : "Delete "),
                    Flexible(child: TranslateText(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text(s.isBengali ? " মুছে ফেলতে চান?" : "?"),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.isBengali ? 'না' : 'No')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.isBengali ? 'মুছে ফেলুন' : 'Delete', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => _delete(doc.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isRevenue ? Colors.green.withOpacity(0.3) : AppColors.glassBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(isRevenue ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 20),
              ),
              title: TranslateText(data['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryText)),
              subtitle: Text('${s.translate(_getCategoryKey(cat))}  •  ${s.translatePrice(dateStr)}', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              trailing: Text(
                '${isRevenue ? '+' : '-'} ৳${s.translatePrice(amount.toStringAsFixed(0))}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isRevenue ? Colors.green : Colors.redAccent),
              ),
            ),
          ),
        );
      },
    );
  }
}
