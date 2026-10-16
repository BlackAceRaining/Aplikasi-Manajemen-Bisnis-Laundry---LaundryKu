import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../auth/account_screen.dart';
import '../auth/auth_controller.dart';
import '../customer/notifications_screen.dart';
import '../customer/points_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/create_order_screen.dart';
import '../orders/order_list_screen.dart';
import '../scan/scan_screen.dart';

/// Root navigation shell; tab set depends on the logged-in role.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final isCustomer = user.isCustomer;

    final List<Widget> pages;
    final List<NavigationDestination> nav;

    if (isCustomer) {
      pages = [
        const _CustomerOrdersTab(),
        const NotificationsScreen(),
        const PointsScreen(),
        const AccountScreen(),
      ];
      nav = const [
        NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Pesanan'),
        NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Notifikasi'),
        NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Poin'),
        NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Akun'),
      ];
    } else {
      final isOwner = user.isOwner;
      pages = [
        if (isOwner) const DashboardScreen(),
        const OrderListScreen(),
        const ScanScreen(),
        const CreateOrderScreen(),
        const AccountScreen(),
      ];
      nav = [
        if (isOwner)
            const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard'),
        const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Order'),
        const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Pindai'),
        const NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Buat'),
        const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Akun'),
      ];
    }

    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.primaryLight,
        destinations: nav,
      ),
    );
  }
}

/// Customer home: greeting + own order list (RBAC filters server-side).
class _CustomerOrdersTab extends ConsumerWidget {
  const _CustomerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).user?.name ?? '';
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, $name',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const Text('Pantau cucian Anda di sini.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const Expanded(child: OrderListScreen()),
      ],
    );
  }
}
