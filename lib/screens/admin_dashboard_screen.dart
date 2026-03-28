import 'package:flutter/material.dart';
import 'edit_market_price_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 24.0, top: 8.0),
              child: Text(
                "Database Management",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF2D5A27)
                ),
              ),
            ),
            
            _buildAdminCard(
              context,
              title: 'Manage Market Prices',
              subtitle: 'Add, Edit, or Remove live rice prices.',
              icon: Icons.price_change_rounded,
              iconColor: Colors.orangeAccent,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditMarketPriceScreen()));
              },
            ),
            const SizedBox(height: 16),
            
            _buildAdminCard(
              context,
              title: 'Manage Farming Calendar',
              subtitle: 'Modify harvesting timeline (Coming Soon)',
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF4CAF50),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calendar Editor coming soon...'))
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D5A27))
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
