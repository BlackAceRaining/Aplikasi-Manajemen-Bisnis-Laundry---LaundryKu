import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/orders_providers.dart';

/// O2 Audit — append-only trail of every sensitive change (P-10, FR-AUD).
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  static const _actionLabels = {
    'create_order': 'Membuat order',
    'update_status': 'Mengubah status order',
    'update_service_price': 'Mengubah harga layanan',
    'update_service': 'Memperbarui layanan',
    'create_service': 'Membuat layanan',
    'record_payment': 'Mencatat pembayaran',
    'record_expense': 'Mencatat pengeluaran',
    'apply_discount': 'Memberikan diskon',
    'reverse_status': 'Mengembalikan status',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: logsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(auditLogsProvider),
        ),
        data: (logs) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(auditLogsProvider),
          child: logs.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  EmptyView(
                      icon: Icons.fact_check_rounded,
                      message: 'Belum ada jejak audit.'),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: logs.length,
                  itemBuilder: (context, i) {
                    final log = logs[i];
                    final label =
                        _actionLabels[log.action] ?? log.action.replaceAll('_', ' ');
                    final detail = _detail(log.newValues);
                    return SectionCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.history_rounded,
                                size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$label · ${log.entityId ?? '-'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                if (detail.isNotEmpty)
                                  Text(detail,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                Text(
                                  '${log.userName ?? 'Sistem'} · ${Formatters.dateTimeWita(log.createdAt)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
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

  String _detail(Map<String, dynamic>? values) {
    if (values == null || values.isEmpty) return '';
    try {
      final interesting = values.entries
          .where((e) =>
              e.value != null &&
              e.value is! Map &&
              e.value is! List &&
              (e.key.contains('price') ||
                  e.key.contains('status') ||
                  e.key.contains('discount') ||
                  e.key.contains('reason')))
          .map((e) => e.value is num && e.key.contains('price')
              ? '${e.key}: ${Formatters.rupiah(e.value as int)}'
              : '${e.key}: ${e.value}')
          .take(3)
          .join(' · ');
      return interesting;
    } catch (_) {
      return jsonEncode(values).length > 80
          ? '${jsonEncode(values).substring(0, 80)}...'
          : jsonEncode(values);
    }
  }
}
