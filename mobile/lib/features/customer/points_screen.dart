import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import '../orders/orders_providers.dart';

/// P4 Poin Member — saldo, aturan perolehan, dan riwayat poin.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null || user.customerId == null) {
      return const Scaffold(
          body: EmptyView(message: 'Data pelanggan tidak tersedia.'));
    }
    final pointsAsync = ref.watch(pointsProvider(user.customerId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Poin Member')),
      body: pointsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(pointsProvider(user.customerId!)),
        ),
        data: (points) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pointsProvider(user.customerId!)),
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 96),
            children: [
              // Balance hero
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF0E86A8)],
                  ),
                ),
                child: Column(
                  children: [
                    const Text('Saldo poin Anda',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('${points.pointBalance}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800)),
                    const Text('poin',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    const Text(
                      'Poin diberikan setelah order lunas: 1 poin untuk setiap Rp10.000 yang dibayar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Riwayat poin'),
              if (points.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Belum ada transaksi poin.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ...points.transactions.map((t) {
                final isEarn = t.type == 'earn';
                return SectionCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isEarn
                            ? AppColors.successLight
                            : AppColors.warningLight,
                        child: Icon(
                            isEarn
                                ? Icons.add_rounded
                                : Icons.remove_rounded,
                            color:
                                isEarn ? AppColors.success : AppColors.warning,
                            size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                t.description ??
                                    (isEarn ? 'Order lunas' : 'Tukar potongan'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${Formatters.dateWita(t.createdAt)} · saldo ${t.balanceAfter}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Text(
                          '${isEarn ? '+' : '−'}${t.points}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isEarn
                                  ? AppColors.success
                                  : AppColors.warning)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
