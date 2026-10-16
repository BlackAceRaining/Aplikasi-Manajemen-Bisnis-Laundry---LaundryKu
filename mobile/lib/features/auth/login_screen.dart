import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok =
        await ref.read(authProvider.notifier).login(
            _emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) {
      final err = ref.read(authProvider).errorMessage;
      showSnack(context, err ?? 'Gagal masuk. Periksa kredensial Anda.',
          isError: true);
    }
  }

  void _fillDemo(String email) {
    _emailCtrl.text = email;
    _passCtrl.text = 'password';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero brand — mirrors wireframe "Masuk LaundryKu"
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF0E86A8)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_laundry_service_rounded,
                            color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text('LaundryKu',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Cucian beres,\ntanpa ribet.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                        'Lacak status, catat pembayaran, dan pindai nota dari satu aplikasi.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeatureTag(label: 'Nota berbarcode'),
                        _FeatureTag(label: 'Status real time'),
                        _FeatureTag(label: 'Poin member'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Masuk',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Masukkan email valid' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Kata sandi minimal 6 karakter'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Masuk'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Akun demo (kata sandi: password)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DemoChip(
                      label: 'Pemilik',
                      email: 'owner@laundryku.com',
                      onTap: _fillDemo),
                  _DemoChip(
                      label: 'Pegawai',
                      email: 'kasir1@laundryku.com',
                      onTap: _fillDemo),
                  _DemoChip(
                      label: 'Pelanggan',
                      email: 'budi@gmail.com',
                      onTap: _fillDemo),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Dengan masuk, Anda menyetujui pemrosesan data pribadi sesuai UU Pelindungan Data Pribadi.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final String label;
  const _FeatureTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white)),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final String email;
  final ValueChanged<String> onTap;

  const _DemoChip({
    required this.label,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.person_outline_rounded,
          size: 16, color: AppColors.primary),
      label: Text('$label · $email',
          style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.primaryLight,
      onPressed: () => onTap(email),
    );
  }
}
