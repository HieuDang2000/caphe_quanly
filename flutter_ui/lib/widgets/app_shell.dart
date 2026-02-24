import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Các chế độ hiển thị sidebar.
enum SidebarMode { expanded, compact, hidden }

/// Trạng thái sidebar dùng chung cho toàn app.
final sidebarModeProvider = StateProvider<SidebarMode>((ref) => SidebarMode.expanded);

/// Layout chính: sidebar cố định bên trái + nội dung bên phải.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const double _expandedWidth = 260;
  static const double _compactWidth = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(sidebarModeProvider);
    final sidebarWidth = switch (mode) {
      SidebarMode.expanded => _expandedWidth,
      SidebarMode.compact => _compactWidth,
      SidebarMode.hidden => 0.0,
    };

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mode != SidebarMode.hidden) _Sidebar(width: sidebarWidth, mode: mode),
            Expanded(child: child),
          ],
        ),
        if (mode == SidebarMode.hidden)
          Positioned(
            top: 16,
            left: 16,
            child: Material(
              elevation: 4,
              shape: const CircleBorder(),
              color: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                tooltip: 'Mở sidebar',
                onPressed: () {
                  ref.read(sidebarModeProvider.notifier).state = SidebarMode.expanded;
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.width, required this.mode});

  final double width;
  final SidebarMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?['role']?['name'] ?? 'staff';
    final showLabels = mode == SidebarMode.expanded;

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
                accountName: showLabels ? Text(user?['name'] ?? 'User') : const SizedBox.shrink(),
                accountEmail: showLabels ? Text(user?['email'] ?? '') : const SizedBox.shrink(),
              ),
              ListTile(
                leading: Icon(
                  switch (mode) {
                    SidebarMode.expanded => Icons.chevron_left,
                    SidebarMode.compact => Icons.chevron_right,
                    SidebarMode.hidden => Icons.menu,
                  },
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: showLabels
                    ? Text(
                        switch (mode) {
                          SidebarMode.expanded => 'Thu gọn',
                          SidebarMode.compact => 'Ẩn sidebar',
                          SidebarMode.hidden => 'Hiện sidebar',
                        },
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      )
                    : null,
                onTap: () {
                  final notifier = ref.read(sidebarModeProvider.notifier);
                  switch (mode) {
                    case SidebarMode.expanded:
                      notifier.state = SidebarMode.compact;
                      break;
                    case SidebarMode.compact:
                      notifier.state = SidebarMode.hidden;
                      break;
                    case SidebarMode.hidden:
                      notifier.state = SidebarMode.expanded;
                      break;
                  }
                },
              ),
              const Divider(height: 1),
              _SidebarItem(icon: Icons.receipt_long, label: 'Đặt món', route: '/', showLabel: showLabels),
              if (role == 'admin' || role == 'manager')
                _SidebarItem(icon: Icons.grid_view, label: 'Sơ đồ quán', route: '/layout', showLabel: showLabels),
              _SidebarItem(icon: Icons.restaurant_menu, label: 'Menu', route: '/menu', showLabel: showLabels),
              _SidebarItem(icon: Icons.list_alt, label: 'Đơn hàng', route: '/orders/list', showLabel: showLabels),
              _SidebarItem(icon: Icons.history, label: 'Lịch sử', route: '/orders/history', showLabel: showLabels),
              if (role == 'admin' || role == 'manager' || role == 'cashier')
                _SidebarItem(icon: Icons.analytics, label: 'Báo cáo', route: '/reports', showLabel: showLabels),
              if (role == 'admin')
                _SidebarItem(icon: Icons.people, label: 'Quản lý users', route: '/users', showLabel: showLabels),
              if (role == 'admin' || role == 'manager') ...[
                const Divider(),
                _SidebarItem(icon: Icons.badge, label: 'Nhân viên', route: '/staff', showLabel: showLabels),
                _SidebarItem(icon: Icons.inventory, label: 'Kho hàng', route: '/inventory', showLabel: showLabels),
                _SidebarItem(icon: Icons.loyalty, label: 'Khách hàng', route: '/customers', showLabel: showLabels),
                _SidebarItem(icon: Icons.event_seat, label: 'Đặt bàn', route: '/reservations', showLabel: showLabels),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                title: showLabels
                    ? const Text('Đăng xuất', style: TextStyle(color: AppTheme.errorColor))
                    : null,
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
  final bool showLabel;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == route || (route != '/' && location.startsWith(route));

    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primaryColor : null),
      title: showLabel
          ? Text(
              label,
              style: isActive ? const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold) : null,
            )
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: showLabel ? 16 : 12),
      horizontalTitleGap: showLabel ? 16 : 0,
      selected: isActive,
      onTap: () => context.go(route),
    );
  }
}
