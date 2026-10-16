import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/orders_providers.dart';

/// A1 Cashflow — daily cash in/out plus owner expense recording (P-11).
class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashAsync = ref.watch(cashflowProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(context, ref),
        icon: const Icon(Icons.remove_circle_outline_rounded),
        label: const Text('Catat pengeluaran'),
        backgroundColor: AppColors.danger,
      ),
      body: cashAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(cashflowProvider),
        ),
        data: (flow) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                      child: StatTile(
                          label: 'Kas masuk',
                          value: Formatters.rupiah(flow.totalIn),
                          icon: Icons.arrow_downward_rounded,
                          color: AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: StatTile(
                          label: 'Kas keluar',
                          value: Formatters.rupiah(flow.totalOut),
                          icon: Icons.arrow_upward_rounded,
                          color: AppColors.danger)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: StatTile(
                          label: 'Saldo',
                          value: Formatters.rupiah(flow.net),
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.primary)),
                ],
              ),
            ),
            const SectionHeader(title: 'Transaksi terbaru'),
            Expanded(
              child: flow.transactions.isEmpty
                  ? const EmptyView(
                      icon: Icons.payments_rounded,
                      message: 'Belum ada transaksi kas pada periode ini.')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: flow.transactions.length,
                      itemBuilder: (context, i) {
                        final t = flow.transactions[i];
                        final isIn = t.transactionType == 'in';
                        return SectionCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isIn
                                    ? AppColors.successLight
                                    : AppColors.dangerLight,
                                child: Icon(
                                    isIn
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIn
                                        ? AppColors.success
                                        : AppColors.danger,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(t.description ?? t.category,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${t.category} · ${Formatters.dateTimeWita(t.createdAt)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Text(
                                  '${isIn ? '+' : '−'} ${Formatters.rupiah(t.amount)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isIn
                                          ? AppColors.success
                                          : AppColors.danger)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseForm(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'operasional';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Catat Pengeluaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(
                      value: 'operasional', child: Text('Biaya operasional')),
                  DropdownMenuItem(
                      value: 'bahan', child: Text('Bahan (deterjen dll.)')),
                  DropdownMenuItem(
                      value: 'gaji', child: Text('Gaji pegawai')),
                  DropdownMenuItem(
                      value: 'sewa', child: Text('Sewa / listrik')),
                  DropdownMenuItem(
                      value: 'lainnya', child: Text('Lainnya')),
                ],
                onChanged: (v) => setSheet(() => category = v ?? 'operasional'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Jumlah (Rp)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Keterangan'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan pengeluaran'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || descCtrl.text.trim().isEmpty) {
      showSnack(context, 'Jumlah dan keterangan wajib diisi dengan benar.',
          isError: true);
      return;
    }
    try {
      await ref.read(laundryRepositoryProvider).recordExpense(
            amount: amount,
            category: category,
            description: descCtrl.text.trim(),
          );
      ref.invalidate(cashflowProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        showSnack(context, 'Pengeluaran ${Formatters.rupiah(amount)} tercatat.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, isError: true);
    }
  }
}
