import 'package:flutter/material.dart';
import 'edit_market_price_screen.dart';
import 'edit_farming_plan_screen.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/theme_aware.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('admin_panel'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
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
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                  child: Text(
                    s.translate('db_mgmt'),
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primaryText
                    ),
                  ),
                ),
                
                _buildAdminCard(
                  context,
                  title: s.translate('manage_prices'),
                  subtitle: s.translate('manage_prices_sub'),
                  icon: Icons.price_change_rounded,
                  iconColor: Colors.orangeAccent,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditMarketPriceScreen()));
                  },
                ),
                const SizedBox(height: 16),
                
                _buildAdminCard(
                  context,
                  title: s.translate('manage_plans'),
                  subtitle: s.translate('manage_plans_sub'),
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditFarmingPlanScreen()));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              title: Text(
                title, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryText)
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(subtitle, style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
