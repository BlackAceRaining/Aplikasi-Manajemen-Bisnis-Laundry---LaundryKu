import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_providers.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _manualCtrl = TextEditingController();
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _processing = false;
  bool _cameraError = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_processing || code.trim().isEmpty) return;
    setState(() => _processing = true);
    try {
      final order =
          await ref.read(laundryRepositoryProvider).findByBarcode(code.trim());
      if (!mounted) return;
      if (order == null) {
        setState(() => _processing = false);
        showSnack(context, 'Order dengan kode "$code" tidak ditemukan.',
            isError: true);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id)));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Barcode'),
        actions: [
          if (!_cameraError)
            IconButton(
              icon: Icon(_scanner.value.torchState == TorchState.on
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded),
              onPressed: () => _scanner.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _cameraError
                  ? _manualOnly()
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: MobileScanner(
                            controller: _scanner,
                            errorBuilder: (context, error, child) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) {
                                if (mounted && !_cameraError) {
                                  setState(() => _cameraError = true);
                                }
                              });
                              return _manualOnly();
                            },
                            onDetect: (capture) {
                              final code =
                                  capture.barcodes.firstOrNull?.rawValue;
                              if (code != null && code.isNotEmpty) {
                                _handleCode(code);
                              }
                            },
                          ),
                        ),
                        // Framing guide
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.success, width: 3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        if (_processing)
                          const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 10),
                                    Text('Mengubah status...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Text(
                  'Arahkan ke barcode nota. Tidak ada kamera? Gunakan pencarian manual.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'LDRY-YYYYMMDD-NNNN',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onSubmitted: _handleCode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14)),
                      onPressed:
                          _processing ? null : () => _handleCode(_manualCtrl.text),
                      child: const Text('Cari'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualOnly() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded,
                size: 40, color: AppColors.primary),
            SizedBox(height: 10),
            Text(
              'Kamera tidak tersedia.\nGunakan pencarian manual di bawah.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
