import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?['role']?['name'] ?? 'staff';

    final maxContentWidth = 800.0;
    const maxTileExtent = 220.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Coffee Shop Manager')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
              color: AppTheme.primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        (user?['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${user?['name'] ?? 'User'}!',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?['role']?['display_name'] ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Chức năng', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = (constraints.maxWidth / maxTileExtent).floor().clamp(2, 4);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                  _MenuCard(icon: Icons.receipt_long, label: 'Đặt món', color: AppTheme.primaryColor, onTap: () => context.go('/orders')),
                  _MenuCard(icon: Icons.list_alt, label: 'Đơn hàng', color: AppTheme.secondaryColor, onTap: () => context.go('/orders/list')),
                  _MenuCard(icon: Icons.restaurant_menu, label: 'Menu', color: AppTheme.accentColor, onTap: () => context.go('/menu')),
                  if (role == 'admin' || role == 'manager')
                    _MenuCard(icon: Icons.grid_view, label: 'Sơ đồ quán', color: Colors.teal, onTap: () => context.go('/layout')),
                  if (role == 'admin' || role == 'manager' || role == 'cashier')
                    _MenuCard(icon: Icons.analytics, label: 'Báo cáo', color: Colors.indigo, onTap: () => context.go('/reports')),
                  if (role == 'admin')
                    _MenuCard(icon: Icons.people, label: 'Users', color: Colors.deepPurple, onTap: () => context.go('/users')),
                  if (role == 'admin' || role == 'manager') ...[
                    _MenuCard(icon: Icons.badge, label: 'Nhân viên', color: Colors.blue, onTap: () => context.go('/staff')),
                    _MenuCard(icon: Icons.inventory, label: 'Kho hàng', color: Colors.orange, onTap: () => context.go('/inventory')),
                    _MenuCard(icon: Icons.loyalty, label: 'Khách hàng', color: Colors.pink, onTap: () => context.go('/customers')),
                    _MenuCard(icon: Icons.event_seat, label: 'Đặt bàn', color: Colors.green, onTap: () => context.go('/reservations')),
                  ],
                  ],
                );
              },
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
