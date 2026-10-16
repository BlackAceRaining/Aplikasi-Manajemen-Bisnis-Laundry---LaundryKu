import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import 'data/models.dart';
import 'order_detail_screen.dart';
import 'orders_providers.dart';

class _DraftItem {
  final ServiceModel service;
  double quantity;

  _DraftItem({required this.service, double? quantity})
      : quantity = quantity ?? (service.unit == 'kg' ? service.minOrder : 1.0);

  int get unitPrice => service.price;
  int get subtotal => (unitPrice * quantity).round();
  String get unitLabel => switch (service.unit) {
        'kg' => 'kg',
        'pcs' => 'pcs',
        'pasang' => 'pasang',
        'm2' => 'm²',
        _ => service.unit,
      };
}

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final List<_DraftItem> _items = [];
  final _discountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CustomerModel? _customer;
  bool _saving = false;

  static const _conditionTags = ['Noda', 'Sobek', 'Kancing hilang', 'Tidak ada cacat'];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _subtotal => _items.fold(0, (sum, it) => sum + it.subtotal);
  int get _discount {
    final v = int.tryParse(_discountCtrl.text.trim()) ?? 0;
    return v.clamp(0, _subtotal);
  }

  int get _total => (_subtotal - _discount).clamp(0, _subtotal);

  double get _discountPercent => _subtotal == 0 ? 0 : _discount / _subtotal;

  bool get _discountNeedsOwner =>
      _discountPercent > 0.10 && !(ref.read(authProvider).user?.isOwner ?? false);

  Future<void> _pickCustomer() async {
    try {
      final customers = await ref.read(customersProvider.future);
      _showCustomerSheet(customers);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _showCustomerSheet(List<CustomerModel> customers) async {
    final selected = await showModalBottomSheet<CustomerModel>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Pelanggan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            if (customers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada pelanggan terdaftar.'),
              ),
            ...customers.map((c) => ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 18)),
                  title: Text(c.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${c.phone} · ${c.pointBalance} poin',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, c),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _customer = selected);
  }

  Future<void> _addService() async {
    List<ServiceModel> services;
    try {
      services = await ref.read(servicesProvider.future);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      return;
    }
    if (!mounted) return;
    if (services.isEmpty) {
      showSnack(context, 'Daftar layanan belum termuat.', isError: true);
      return;
    }
    final picked = await showModalBottomSheet<ServiceModel>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('+ Layanan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            ...services.map((s) => ListTile(
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                      '${Formatters.rupiah(s.price)} / ${s.unit == 'm2' ? 'm²' : s.unit} · estimasi ${s.estimateDurationHours} jam',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        final existing = _items.where((e) => e.service.id == picked.id);
        if (existing.isNotEmpty) {
          existing.first.quantity +=
              picked.unit == 'kg' ? 0.5 : 1.0;
        } else {
          _items.add(_DraftItem(service: picked));
        }
      });
    }
  }

  void _changeQty(_DraftItem item, double delta) {
    setState(() {
      final min = item.service.unit == 'kg'
          ? item.service.minOrder
          : 1.0;
      final step = item.service.unit == 'kg' ? 0.5 : 1.0;
      final next = (item.quantity + delta * step);
      // BR-03: pembulatan 0,1 kg dan tidak kurang dari minimum
      item.quantity = next < min ? min : (next * 10).roundToDouble() / 10;
    });
  }

  Future<void> _save() async {
    if (_customer == null) {
      showSnack(context, 'Pilih pelanggan terlebih dahulu.', isError: true);
      return;
    }
    if (_items.isEmpty) {
      showSnack(context, 'Tambahkan minimal satu layanan.', isError: true);
      return;
    }
    if (_discountNeedsOwner) {
      showSnack(
          context,
          'Diskon di atas 10% memerlukan otorisasi pemilik. Kurangi diskon atau minta pemilik.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final key =
          'ord-${DateTime.now().millisecondsSinceEpoch}-${_customer!.id}';
      final order = await ref.read(laundryRepositoryProvider).createOrder(
            customerId: _customer!.id,
            items: _items
                .map((e) => {
                      'service_id': e.service.id,
                      'quantity': e.quantity,
                    })
                .toList(),
            discountAmount: _discount,
            notes: [
              if (_selectedTags.isNotEmpty) _selectedTags.join(', '),
              if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
            ].join(' · '),
            idempotencyKey: key,
          );
      if (!mounted) return;
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardProvider);
      // Replace this screen with the freshly created nota (K2)
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id)));
      showSnack(context, 'Order ${order.orderNo} tersimpan.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    return Scaffold(
      appBar: AppBar(title: const Text('Order Baru')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          // Customer selector (K1: header pelanggan + Ganti)
          SectionCard(
            onTap: _pickCustomer,
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: customer == null
                      ? const Text('Pilih pelanggan',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${customer.phone} · ${customer.pointBalance} poin',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                ),
                Icon(customer == null
                    ? Icons.chevron_right_rounded
                    : Icons.refresh_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
          const SectionHeader(title: 'Item layanan'),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Belum ada layanan dipilih. Tekan "+ Layanan".',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ..._items.map((it) => SectionCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(it.service.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        Text(Formatters.rupiah(it.subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    Text(
                        '${Formatters.rupiah(it.unitPrice)} / ${it.unitLabel}${it.service.unit == 'kg' ? ' · bulat 0,1 kg' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _changeQty(it, -1),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Text(
                            it.service.unit == 'kg'
                                ? '${it.quantity.toStringAsFixed(1)} ${it.unitLabel}'
                                : '${it.quantity.toInt()} ${it.unitLabel}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        IconButton.filledTonal(
                          onPressed: () => _changeQty(it, 1),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: _addService,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Layanan'),
              ),
            ),
          ),
          // Kondisi awal (K1: foto wajib + tag kondisi)
          const SectionHeader(title: 'Kondisi awal pakaian'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _conditionTags
                  .map((t) => FilterChip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        selected: _selectedTags.contains(t),
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        onSelected: (on) => setState(
                            () => on ? _selectedTags.add(t) : _selectedTags.remove(t)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: pisahkan baju berwarna',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Summary
          SectionCard(
            child: Column(
              children: [
                _row('Subtotal', _subtotal),
                const SizedBox(height: 6),
                TextField(
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Diskon (Rp)',
                    isDense: true,
                    prefixIcon: const Icon(Icons.local_offer_rounded, size: 18),
                    helperText: _discountNeedsOwner
                        ? 'Diskon di atas 10% perlu otorisasi pemilik'
                        : 'Diskon di atas 10% memerlukan otorisasi pemilik.',
                    helperStyle: TextStyle(
                        color: _discountNeedsOwner
                            ? AppColors.danger
                            : AppColors.textMuted,
                        fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                _row('Total', _total, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan & buat nota'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, int amount, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(Formatters.rupiah(amount),
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}
