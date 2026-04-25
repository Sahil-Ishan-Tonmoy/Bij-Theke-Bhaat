import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';
import '../widgets/translate_text.dart';

class PlanPhasesScreen extends StatelessWidget {
  final String planId;
  final String planName;

  const PlanPhasesScreen({super.key, required this.planId, required this.planName});

  void _showPhaseDialog(BuildContext context, {DocumentSnapshot? existing}) {
    final s = AppSettings.instance;
    final titleCtrl = TextEditingController(text: existing?.get('title') ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.get('subtitle') ?? '');
    final startCtrl = TextEditingController(text: existing?.get('startDay')?.toString() ?? '');
    final endCtrl = TextEditingController(text: existing?.get('endDay')?.toString() ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.scaffoldBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(existing == null ? s.translate('add_phase') : s.translate('edit_phase'),
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(titleCtrl, s.translate('phase_title_hint'), Icons.label_rounded),
              const SizedBox(height: 12),
              _field(subtitleCtrl, s.translate('instr_hint'), Icons.description_rounded, multiline: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(startCtrl, s.translate('start_day_hint'), Icons.play_arrow_rounded, isNum: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(endCtrl, s.translate('end_day_hint'), Icons.stop_rounded, isNum: true)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.isBengali ? 'বাতিল' : 'Cancel', style: TextStyle(color: AppColors.secondaryText))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              final data = {
                'title': titleCtrl.text.trim(),
                'subtitle': subtitleCtrl.text.trim(),
                'startDay': int.tryParse(startCtrl.text) ?? 1,
                'endDay': int.tryParse(endCtrl.text) ?? 10,
              };
              final col = FirebaseFirestore.instance
                  .collection('farming_plans')
                  .doc(planId)
                  .collection('phases');
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

  static Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool isNum = false, bool multiline = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      maxLines: multiline ? 3 : 1,
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
        title: TranslateText(planName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: const [AppMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(s.translate('add_phase'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showPhaseDialog(context),
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('farming_plans')
                  .doc(planId)
                  .collection('phases')
                  .orderBy('startDay')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AppColors.accent));

                final phases = snap.data!.docs;

                if (phases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_clear_rounded, size: 64, color: AppColors.hintText),
                        const SizedBox(height: 16),
                        Text(s.translate('no_phases'), 
                          textAlign: TextAlign.center, 
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(s.translate('tap_plus_phase'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.hintText, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: phases.length,
                  itemBuilder: (ctx2, index) {
                    final ph = phases[index];
                    final pd = ph.data() as Map<String, dynamic>;
                    final title = pd['title'] ?? '';

                    return Container(
                      key: ValueKey(ph.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${s.isBengali ? "দিন" : "Day"} ${s.translatePrice(pd['startDay'].toString())} – ${s.translatePrice(pd['endDay'].toString())}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 22),
                                  tooltip: s.isBengali ? 'পরিবর্তন করুন' : 'Edit',
                                  onPressed: () => _showPhaseDialog(context, existing: ph),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 22),
                                  tooltip: s.isBengali ? 'মুছে ফেলুন' : 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: AppColors.scaffoldBg,
                                        title: Text(s.translate('delete_phase_q'), style: TextStyle(color: AppColors.primaryText)),
                                        content: Row(
                                          children: [
                                            Text(s.translate('delete_phase_msg'), style: TextStyle(color: AppColors.secondaryText)),
                                            const SizedBox(width: 4),
                                            Expanded(child: TranslateText(title, style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.bold))),
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
                                      await FirebaseFirestore.instance
                                          .collection('farming_plans').doc(planId)
                                          .collection('phases').doc(ph.id).delete();
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TranslateText(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryText)),
                            const SizedBox(height: 4),
                            TranslateText(pd['subtitle'] ?? '', style: TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4)),
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
