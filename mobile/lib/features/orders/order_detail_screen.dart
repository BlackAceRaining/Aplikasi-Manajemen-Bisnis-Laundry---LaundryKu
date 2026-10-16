import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import 'orders_providers.dart';
import 'data/models.dart';

String _photoBaseUrl() =>
    ApiConstants.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final user = ref.watch(authProvider).user;
    final isStaff = user != null && !user.isCustomer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderDetailProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              _NotaCard(order: order),
              _ItemsCard(order: order),
              if (isStaff) _CustomerCard(order: order),
              _PhotosCard(order: order, canUpload: isStaff),
              _TimelineCard(logs: order.statusLogs),
              if (order.payments.isNotEmpty) _PaymentsCard(order: order),
              if (isStaff) _ActionsCard(order: order, isOwner: user.isOwner),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Nota + QR
class _NotaCard extends StatelessWidget {
  final OrderModel order;
  const _NotaCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NOTA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary)),
              StatusChip(status: order.status),
            ],
          ),
          const Divider(height: 24),
          Text(order.orderNo,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          QrImageView(
            data: order.barcode,
            size: 150,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 6),
          Text(order.barcode,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text('Dibuat: ${Formatters.dateTimeWita(order.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (order.completedAt != null)
            Text('Selesai dicuci: ${Formatters.dateTimeWita(order.completedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (order.dueAt != null)
            Text('Batas ambil: ${Formatters.dateTimeWita(order.dueAt)}',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Item list
class _ItemsCard extends StatelessWidget {
  final OrderModel order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian layanan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...order.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.serviceNameSnap,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                            '${it.quantityLabel} × ${Formatters.rupiah(it.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Text(Formatters.rupiah(it.subtotal),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          _sumRow('Subtotal', order.subtotal),
          if (order.discountAmount > 0)
            _sumRow('Diskon', -order.discountAmount,
                color: AppColors.success),
          _sumRow('Total', order.totalAmount, bold: true),
          if (order.totalPaid > 0) ...[
            const SizedBox(height: 6),
            _sumRow('Dibayar', order.totalPaid, color: AppColors.info),
            _sumRow('Sisa tagihan', order.remainingBalance,
                color: order.remainingBalance > 0 ? AppColors.danger : AppColors.success),
          ],
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${order.notes}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _sumRow(String label, int amount,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.textSecondary)),
          Text(Formatters.rupiah(amount),
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? AppColors.primary : (color ?? AppColors.textPrimary))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Customer
class _CustomerCard extends StatelessWidget {
  final OrderModel order;
  const _CustomerCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = order.customer;
    if (c == null) return const SizedBox.shrink();
    return SectionCard(
      child: Row(
        children: [
          const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_rounded, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${c.phone} · ${c.pointBalance} poin',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Photos
class _PhotosCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final bool canUpload;

  const _PhotosCard({required this.order, required this.canUpload});

  @override
  ConsumerState<_PhotosCard> createState() => _PhotosCardState();
}

class _PhotosCardState extends ConsumerState<_PhotosCard> {
  bool _uploading = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ref
          .read(laundryRepositoryProvider)
          .uploadPhoto(widget.order.id, dataUri);
      ref.invalidate(orderDetailProvider(widget.order.id));
      if (mounted) showSnack(context, 'Foto kondisi awal tersimpan.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Tidak dapat mengakses kamera. Gunakan input manual bila perlu.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.order.photos;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Foto kondisi awal',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (photos.isEmpty && widget.order.status == 'Diterima')
                const Text('Wajib sebelum Ditimbang',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            TextButton.icon(
              onPressed: widget.canUpload && !_uploading ? _takePhoto : null,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_rounded),
              label: const Text('Ambil foto'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...photos.map((p) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _photoBaseUrl() + p.photoPath,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 84,
                          height: 84,
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.primary),
                        ),
                      ),
                    )),
                if (widget.canUpload)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _uploading ? null : _takePhoto,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Timeline
class _TimelineCard extends StatelessWidget {
  final List<StatusLogModel> logs;
  const _TimelineCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Linimasa status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('Belum ada riwayat status.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            ...sorted.asMap().entries.map((e) {
              final log = e.value;
              final isLast = e.key == sorted.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.getStatusColor(log.toStatus),
                          ),
                        ),
                        if (!isLast)
                          const Expanded(
                            child: WidthBar(),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.fromStatus == null
                                  ? log.toStatus
                                  : '${log.fromStatus} → ${log.toStatus}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${Formatters.dateTimeWita(log.createdAt)}${log.changedByName != null ? ' · ${log.changedByName}' : ''}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                            if (log.reason != null &&
                                log.reason!.isNotEmpty)
                              Text(log.reason!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class WidthBar extends StatelessWidget {
  const WidthBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 2,
      child: ColoredBox(color: AppColors.border),
    );
  }
}

// ---------------------------------------------------------------- Payments
class _PaymentsCard extends StatelessWidget {
  final OrderModel order;
  const _PaymentsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pembayaran',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...order.payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.paymentMethod == 'cash' ? 'Tunai' : 'Transfer'} · ${Formatters.dateTimeWita(p.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text('+ ${Formatters.rupiah(p.amount)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Actions
class _ActionsCard extends ConsumerWidget {
  final OrderModel order;
  final bool isOwner;

  const _ActionsCard({required this.order, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = kAllowedTransitions[order.status] ?? [];
    final canPay = order.remainingBalance > 0 &&
        !order.isClosed &&
        order.status != 'Diterima' &&
        order.status != 'Ditimbang' &&
        order.status != 'Dicuci' &&
        order.status != 'Disetrika';
    final showDibatalkan = isOwner; // pegawai butuh persetujuan pemilik

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Aksi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          if (next.isEmpty && !canPay)
            const Text('Order sudah pada status akhir.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...next.where((s) => s != 'Dibatalkan' || showDibatalkan).map(
                      (s) => ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s == 'Dibatalkan'
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                        onPressed: () => _onTransition(context, ref, s),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text('→ $s'),
                      ),
                    ),
                if (canPay)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: () => showPaymentSheet(context, ref, order),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: Text(
                        'Catat pembayaran (${Formatters.rupiah(order.remainingBalance)})'),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          const Text(
            'Hanya transisi yang diizinkan yang ditampilkan. Pengembalian status khusus pemilik dengan alasan tertulis.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _onTransition(
      BuildContext context, WidgetRef ref, String target) async {
    String? reason;
    if (target == 'Siap') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tandai Siap?'),
          content: const Text(
              'Menandai Siap akan mengirim notifikasi ke pelanggan dan memulai batas pengambilan 7 hari.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tandai Siap')),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (target == 'Dibatalkan') {
      reason = await _askReason(context, 'Alasan pembatalan (wajib)');
      if (reason == null || reason.isEmpty) return;
    }

    try {
      await ref
          .read(laundryRepositoryProvider)
          .updateStatus(order.id, target, reason: reason);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersListProvider);
      if (context.mounted) showSnack(context, 'Status berubah menjadi $target.');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, isError: true);
    }
  }
}

Future<String?> _askReason(BuildContext context, String label) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Tulis alasan...'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kirim')),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Payment sheet
Future<void> showPaymentSheet(
    BuildContext context, WidgetRef ref, OrderModel order) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: _PaymentForm(order: order, sheetContext: ctx),
    ),
  );
}

class _PaymentForm extends ConsumerStatefulWidget {
  final OrderModel order;
  final BuildContext sheetContext;

  const _PaymentForm({required this.order, required this.sheetContext});

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  late final TextEditingController _amountCtrl;
  String _method = 'cash';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: '${widget.order.remainingBalance}');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (_amount <= 0) {
      showSnack(context, 'Jumlah pembayaran tidak valid.', isError: true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      // Idempotency key prevents double posting on retry
      final key =
          'pay-${widget.order.id}-${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(laundryRepositoryProvider).recordPayment(
            orderId: widget.order.id,
            amount: _amount,
            method: _method,
            idempotencyKey: key,
          );
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${Formatters.rupiah(_amount)} tercatat.'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final expectedPoints = order.totalAmount ~/ 10000;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Catat Pembayaran · ${order.orderNo}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(order.customer?.name ?? '',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total order', style: TextStyle(fontSize: 13)),
            Text(Formatters.rupiah(order.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (order.totalPaid > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dibayar', style: TextStyle(fontSize: 13)),
              Text('− ${Formatters.rupiah(order.totalPaid)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.info)),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sisa tagihan', style: TextStyle(fontSize: 13)),
            Text(Formatters.rupiah(order.remainingBalance),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'cash',
                label: Text('Tunai'),
                icon: Icon(Icons.payments_rounded)),
            ButtonSegment(
                value: 'transfer',
                label: Text('Transfer'),
                icon: Icon(Icons.account_balance_rounded)),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Jumlah dibayar (Rp)',
            prefixIcon: Icon(Icons.money_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final nominal in [50000, 100000, order.remainingBalance])
              if (nominal > 0)
                ActionChip(
                  label: Text(Formatters.rupiah(nominal)),
                  onPressed: () =>
                      setState(() => _amountCtrl.text = '$nominal'),
                ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Status setelah dicatat lunas: Lunas → Selesai. Poin pelanggan +$expectedPoints.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text('Catat pembayaran ${Formatters.rupiah(_amount)}'),
        ),
      ],
    );
  }
}
