import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?['role']?['name'] ?? 'staff';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 24, color: AppTheme.primaryColor),
              ),
            ),
            accountName: Text(user?['name'] ?? 'User'),
            accountEmail: Text(user?['email'] ?? ''),
          ),
          if (role == 'admin' || role == 'manager')
            _DrawerItem(icon: Icons.grid_view, label: 'Sơ đồ quán', route: '/layout'),
          _DrawerItem(icon: Icons.restaurant_menu, label: 'Menu', route: '/menu'),
          _DrawerItem(icon: Icons.list_alt, label: 'Đơn hàng', route: '/orders/list'),
          _DrawerItem(icon: Icons.history, label: 'Lịch sử', route: '/orders/history'),
          if (role == 'admin' || role == 'manager' || role == 'cashier')
            _DrawerItem(icon: Icons.analytics, label: 'Báo cáo', route: '/reports'),
          if (role == 'admin')
            _DrawerItem(icon: Icons.people, label: 'Quản lý users', route: '/users'),
          if (role == 'admin' || role == 'manager') ...[
            const Divider(),
            _DrawerItem(icon: Icons.badge, label: 'Nhân viên', route: '/staff'),
            _DrawerItem(icon: Icons.inventory, label: 'Kho hàng', route: '/inventory'),
            _DrawerItem(icon: Icons.loyalty, label: 'Khách hàng', route: '/customers'),
            _DrawerItem(icon: Icons.event_seat, label: 'Đặt bàn', route: '/reservations'),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Đăng xuất', style: TextStyle(color: AppTheme.errorColor)),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final isActive = GoRouterState.of(context).matchedLocation == route;
    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primaryColor : null),
      title: Text(label, style: isActive ? const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold) : null),
      selected: isActive,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
