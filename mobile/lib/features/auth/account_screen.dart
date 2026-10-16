import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../dashboard/audit_log_screen.dart';
import '../dashboard/cashflow_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/services_screen.dart';
import 'auth_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final roleLabel = switch (user.role) {
      'pemilik' => 'Pemilik',
      'pegawai' => 'Pegawai / Kasir',
      _ => 'Pelanggan',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(user.name,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          Center(
            child: Text('${user.email} · $roleLabel',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 24),
          if (user.isOwner) ...[
            const SectionHeader(title: 'Menu pemilik'),
            _tile(context, Icons.dashboard_rounded, 'Dashboard', () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DashboardScreen()));
            }),
            _tile(context, Icons.sell_rounded, 'Layanan & Harga', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServicesScreen()));
            }),
            _tile(context, Icons.swap_vert_rounded, 'Cashflow', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CashflowScreen()));
            }),
            _tile(context, Icons.fact_check_rounded, 'Audit Log', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()));
            }),
          ],
          if (user.isStaff) ...[
            const SectionHeader(title: 'Eksplorasi'),
            _tile(context, Icons.dashboard_rounded,
                'Coba Dashboard Pemilik (403 ditolak server)', () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DashboardScreen()));
            }),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger)),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Keluar')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}
