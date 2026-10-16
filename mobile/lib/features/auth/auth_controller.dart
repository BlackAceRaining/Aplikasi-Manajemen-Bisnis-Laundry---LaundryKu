import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int? branchId;
  final int? customerId;
  final int pointBalance;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.branchId,
    this.customerId,
    this.pointBalance = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'pegawai',
      branchId: json['branch_id'],
      customerId: json['customer_id'],
      pointBalance: json['point_balance'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'branch_id': branchId,
    'customer_id': customerId,
    'point_balance': pointBalance,
  };

  bool get isOwner => role.toLowerCase() == 'pemilik';
  bool get isStaff => role.toLowerCase() == 'pegawai';
  bool get isCustomer => role.toLowerCase() == 'pelanggan';
}

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    final token = await TokenStorage.getToken();
    final userJson = await TokenStorage.getUserData();

    if (token != null && userJson != null) {
      try {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = state.copyWith(user: user, isLoading: false);
        // Refresh from server in background
        _refreshUser();
        return;
      } catch (_) {}
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> _refreshUser() async {
    try {
      final res = await _api.get('/auth/me');
      final user = UserModel.fromJson(res);
      await TokenStorage.saveUserData(jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = res['token'];
      final user = UserModel.fromJson(res['user']);

      await TokenStorage.saveToken(token);
      await TokenStorage.saveUserData(jsonEncode(user.toJson()));

      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal terhubung ke server');
      return false;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthNotifier(api);
});
