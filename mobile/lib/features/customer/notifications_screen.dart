import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'ready':
        return Icons.check_circle_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'not_taken':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: notifAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: notifications.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                        icon: Icons.notifications_off_rounded,
                        message: 'Belum ada notifikasi.'),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: notifications.length,
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return SectionCard(
                      onTap: () async {
                        if (!n.isRead) {
                          try {
                            await ref
                                .read(laundryRepositoryProvider)
                                .markNotificationRead(n.id);
                            ref.invalidate(notificationsProvider);
                          } catch (_) {}
                        }
                        if (n.orderId != null && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailScreen(orderId: n.orderId!)));
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: n.isRead
                                ? AppColors.background
                                : AppColors.primaryLight,
                            child: Icon(_iconFor(n.type),
                                size: 18,
                                color: n.isRead
                                    ? AppColors.textMuted
                                    : AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title,
                                    style: TextStyle(
                                        fontWeight: n.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        fontSize: 13,
                                        color: n.isRead
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(n.message,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(Formatters.dateTimeWita(n.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
