import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/orders_providers.dart';

/// O5 Layanan & Harga — owner manages master services and prices.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Layanan & Harga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Tambah layanan',
            onPressed: () => _showServiceForm(context, ref, null),
          ),
        ],
      ),
      body: servicesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(servicesProvider),
        ),
        data: (services) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Perubahan harga hanya berlaku untuk order baru. Order yang sudah dibuat tetap memakai harga lama.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            ...services.map((s) => SectionCard(
                  onTap: () => _showServiceForm(context, ref, s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                                '${Formatters.rupiah(s.price)} / ${s.unit == 'm2' ? 'm²' : s.unit} · estimasi ${s.estimateDurationHours} jam${s.unit == 'kg' ? ' · min ${s.minOrder.toStringAsFixed(1)} kg' : ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showServiceForm(
      BuildContext context, WidgetRef ref, dynamic existing) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final priceCtrl =
        TextEditingController(text: '${existing?.price ?? ''}');
    final hoursCtrl =
        TextEditingController(text: '${existing?.estimate_duration_hours ?? ''}');
    final minCtrl =
        TextEditingController(text: '${existing?.min_order ?? '1'}');
    final reasonCtrl = TextEditingController();
    String unit = existing?.unit ?? 'kg';

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
              Text(existing == null ? 'Tambah Layanan' : 'Ubah Harga',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama layanan'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Satuan'),
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('Kilogram (kg)')),
                  DropdownMenuItem(value: 'pcs', child: Text('Satuan (pcs)')),
                  DropdownMenuItem(
                      value: 'pasang', child: Text('Pasang (sepatu)')),
                  DropdownMenuItem(
                      value: 'm2', child: Text('Per meter persegi (m²)')),
                ],
                onChanged: (v) => setSheet(() => unit = v ?? 'kg'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Harga per satuan (Rp)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Estimasi selesai (jam)'),
              ),
              if (unit == 'kg') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: minCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Minimum order (kg) · pembulatan 0,1 kg'),
                ),
              ],
              if (existing != null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Alasan perubahan harga (opsional)'),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Simpan layanan' : 'Simpan perubahan'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    final payload = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'unit': unit,
      'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
      'estimate_duration_hours': int.tryParse(hoursCtrl.text.trim()) ?? 1,
      if (unit == 'kg')
        'min_order': double.tryParse(minCtrl.text.trim()) ?? 1.0,
      if (existing != null && reasonCtrl.text.trim().isNotEmpty)
        'reason': reasonCtrl.text.trim(),
    };

    try {
      final repo = ref.read(laundryRepositoryProvider);
      if (existing == null) {
        await repo.createService(payload);
      } else {
        await repo.updateService(existing.id, payload);
      }
      ref.invalidate(servicesProvider);
      if (context.mounted) {
        showSnack(context, existing == null
            ? 'Layanan ditambahkan.'
            : 'Harga diperbarui · tercatat di riwayat harga & audit.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, isError: true);
    }
  }
}
