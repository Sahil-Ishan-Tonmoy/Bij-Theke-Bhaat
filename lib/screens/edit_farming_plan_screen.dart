import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'plan_phases_screen.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class EditFarmingPlanScreen extends StatefulWidget {
  const EditFarmingPlanScreen({super.key});

  @override
  State<EditFarmingPlanScreen> createState() => _EditFarmingPlanScreenState();
}

class _EditFarmingPlanScreenState extends State<EditFarmingPlanScreen> {
  void _showRiceTypeDialog({DocumentSnapshot? existing}) {
    final s = AppSettings.instance;
    final nameCtrl = TextEditingController(text: existing?.get('name') ?? '');
    final descCtrl = TextEditingController(text: existing?.get('description') ?? '');
    final daysCtrl = TextEditingController(text: existing?.get('totalDays')?.toString() ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.scaffoldBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(existing == null ? s.translate('add_rice_type') : s.translate('edit_rice_type'),
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl, s.translate('rice_name_hint'), Icons.grass_rounded),
            const SizedBox(height: 12),
            _field(descCtrl, s.translate('short_desc_hint'), Icons.info_outline_rounded),
            const SizedBox(height: 12),
            _field(daysCtrl, s.translate('total_days_hint'), Icons.timer_outlined, isNum: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.isBengali ? 'বাতিল' : 'Cancel', style: TextStyle(color: AppColors.secondaryText))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final data = {
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'totalDays': int.tryParse(daysCtrl.text) ?? 140,
              };
              final col = FirebaseFirestore.instance.collection('farming_plans');
              if (existing == null) {
                await col.add(data);
              } else {
                await col.doc(existing.id).update(data);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.isBengali ? 'সংরক্ষণ করুন' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('farming_plans'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add',
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(s.translate('add_rice_type'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showRiceTypeDialog(),
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('farming_plans').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                final plans = snap.data!.docs;

                if (plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.agriculture_rounded, size: 64, color: AppColors.hintText),
                        const SizedBox(height: 16),
                        Text(s.translate('no_plans'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(s.translate('tap_plus_msg'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.hintText, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: plans.length,
                  itemBuilder: (ctx, i) {
                    final plan = plans[i];
                    final data = plan.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
                                  child: Icon(Icons.grass_rounded, color: AppColors.accent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TranslateText(
                                        name,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryText),
                                      ),
                                      Wrap(
                                        children: [
                                          Text(
                                            '${s.translatePrice((data['totalDays'] ?? '?').toString())} ${s.isBengali ? "দিন" : "days"}  •  ',
                                            style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                                          ),
                                          TranslateText(
                                            s.translatePlanDescription(data['description'] ?? ''),
                                            style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(height: 1, color: AppColors.primaryText.withOpacity(0.1)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.timeline_rounded, color: AppColors.accent, size: 18),
                                    label: Text(s.translate('manage_phases'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppColors.accent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlanPhasesScreen(planId: plan.id, planName: name),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                                  tooltip: s.isBengali ? 'পরিবর্তন করুন' : 'Edit',
                                  onPressed: () => _showRiceTypeDialog(existing: plan),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                  tooltip: s.isBengali ? 'মুছে ফেলুন' : 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: AppColors.scaffoldBg,
                                        title: Text(s.translate('delete_plan_q'), style: TextStyle(color: AppColors.primaryText)),
                                        content: Row(
                                          children: [
                                            Text(s.translate('delete_plan_msg'), style: TextStyle(color: AppColors.secondaryText)),
                                            const SizedBox(width: 4),
                                            Expanded(child: TranslateText(name, style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.isBengali ? 'না' : 'No', style: TextStyle(color: AppColors.secondaryText))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(s.isBengali ? 'মুছে ফেলুন' : 'Delete', style: const TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance.collection('farming_plans').doc(plan.id).delete();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
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
}
