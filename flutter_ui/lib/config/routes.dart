import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/layout/layout_editor_screen.dart';
import '../screens/menu/menu_list_screen.dart';
import '../screens/menu/menu_form_screen.dart';
import '../screens/orders/order_screen.dart';
import '../screens/orders/order_list_screen.dart';
import '../screens/billing/invoice_screen.dart';
import '../screens/billing/payment_screen.dart';
import '../screens/reports/dashboard_screen.dart';
import '../screens/users/user_management_screen.dart';
import '../screens/staff/staff_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/customers/customer_screen.dart';
import '../screens/reservations/reservation_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(bool isLoggedIn) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: isLoggedIn ? '/' : '/login',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/layout', builder: (_, _) => const LayoutEditorScreen()),
      GoRoute(path: '/menu', builder: (_, _) => const MenuListScreen()),
      GoRoute(
        path: '/menu/form',
        builder: (_, state) => MenuFormScreen(item: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(path: '/orders', builder: (_, _) => const OrderScreen()),
      GoRoute(path: '/orders/list', builder: (_, _) => const OrderListScreen()),
      GoRoute(
        path: '/invoice/:orderId',
        builder: (_, state) => InvoiceScreen(orderId: int.parse(state.pathParameters['orderId']!)),
      ),
      GoRoute(
        path: '/payment/:invoiceId',
        builder: (_, state) => PaymentScreen(invoiceId: int.parse(state.pathParameters['invoiceId']!)),
      ),
      GoRoute(path: '/reports', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (_, _) => const UserManagementScreen()),
      GoRoute(path: '/staff', builder: (_, _) => const StaffScreen()),
      GoRoute(path: '/inventory', builder: (_, _) => const InventoryScreen()),
      GoRoute(path: '/customers', builder: (_, _) => const CustomerScreen()),
      GoRoute(path: '/reservations', builder: (_, _) => const ReservationScreen()),
    ],
  );
}
