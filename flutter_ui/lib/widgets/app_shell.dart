import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layout chính: sidebar cố định bên trái + nội dung bên phải.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const double sidebarWidth = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sidebar(width: sidebarWidth),
        Expanded(child: child),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?['role']?['name'] ?? 'staff';

    return SizedBox(
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        child: SafeArea(
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
              _SidebarItem(icon: Icons.home, label: 'Trang chủ', route: '/'),
              if (role == 'admin' || role == 'manager')
                _SidebarItem(icon: Icons.grid_view, label: 'Sơ đồ quán', route: '/layout'),
              _SidebarItem(icon: Icons.restaurant_menu, label: 'Menu', route: '/menu'),
              _SidebarItem(icon: Icons.receipt_long, label: 'Đặt món', route: '/orders'),
              _SidebarItem(icon: Icons.list_alt, label: 'Đơn hàng', route: '/orders/list'),
              _SidebarItem(icon: Icons.history, label: 'Lịch sử', route: '/orders/history'),
              if (role == 'admin' || role == 'manager' || role == 'cashier')
                _SidebarItem(icon: Icons.analytics, label: 'Báo cáo', route: '/reports'),
              if (role == 'admin')
                _SidebarItem(icon: Icons.people, label: 'Quản lý users', route: '/users'),
              if (role == 'admin' || role == 'manager') ...[
                const Divider(),
                _SidebarItem(icon: Icons.badge, label: 'Nhân viên', route: '/staff'),
                _SidebarItem(icon: Icons.inventory, label: 'Kho hàng', route: '/inventory'),
                _SidebarItem(icon: Icons.loyalty, label: 'Khách hàng', route: '/customers'),
                _SidebarItem(icon: Icons.event_seat, label: 'Đặt bàn', route: '/reservations'),
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
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _SidebarItem({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final isActive = GoRouterState.of(context).matchedLocation == route ||
        (route != '/' && GoRouterState.of(context).matchedLocation.startsWith(route));
    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primaryColor : null),
      title: Text(
        label,
        style: isActive ? const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold) : null,
      ),
      selected: isActive,
      onTap: () => context.go(route),
    );
  }
}
