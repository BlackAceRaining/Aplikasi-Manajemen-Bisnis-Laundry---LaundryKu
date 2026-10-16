import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'data/laundry_repository.dart';
import 'data/models.dart';

final laundryRepositoryProvider = Provider<LaundryRepository>((ref) {
  return LaundryRepository(ref.watch(apiClientProvider));
});

// ---- Master data ----
final servicesProvider = FutureProvider<List<ServiceModel>>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchServices();
});

final customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchCustomers();
});

// ---- Order list with status filter + search ----
class OrdersFilter {
  final String status;
  final String search;

  const OrdersFilter({this.status = '', this.search = ''});

  OrdersFilter copyWith({String? status, String? search}) => OrdersFilter(
        status: status ?? this.status,
        search: search ?? this.search,
      );
}

class OrdersFilterNotifier extends StateNotifier<OrdersFilter> {
  OrdersFilterNotifier() : super(const OrdersFilter());

  void setStatus(String status) => state = state.copyWith(status: status);
  void setSearch(String search) => state = state.copyWith(search: search);
}

final ordersFilterProvider =
    StateNotifierProvider<OrdersFilterNotifier, OrdersFilter>((ref) {
  return OrdersFilterNotifier();
});

final ordersListProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) {
  final filter = ref.watch(ordersFilterProvider);
  return ref
      .watch(laundryRepositoryProvider)
      .fetchOrders(status: filter.status, search: filter.search);
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel, int>((ref, id) {
  return ref.watch(laundryRepositoryProvider).fetchOrderDetail(id);
});

// ---- Customer side ----
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchNotifications();
});

final pointsProvider =
    FutureProvider.autoDispose.family<PointsModel, int>((ref, customerId) {
  return ref.watch(laundryRepositoryProvider).fetchPoints(customerId);
});

// ---- Owner side ----
final dashboardProvider = FutureProvider.autoDispose<DashboardModel>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchDashboard();
});

final cashflowProvider = FutureProvider.autoDispose<CashflowModel>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchCashflow();
});

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLogModel>>((ref) {
  return ref.watch(laundryRepositoryProvider).fetchAuditLogs();
});

/// Valid forward transitions mirrored from backend OrderStatus enum so the UI
/// only offers allowed buttons; the server remains the source of truth.
const Map<String, List<String>> kAllowedTransitions = {
  'Diterima': ['Ditimbang', 'Dibatalkan'],
  'Ditimbang': ['Dicuci', 'Dibatalkan'],
  'Dicuci': ['Disetrika'],
  'Disetrika': ['Siap'],
  'Siap': ['Diambil', 'Tidak Diambil'],
  'Diambil': ['Lunas'],
  'Lunas': ['Selesai'],
  'Selesai': [],
  'Tidak Diambil': [],
  'Dibatalkan': [],
};

const List<String> kOrderStatusFlow = [
  'Diterima',
  'Ditimbang',
  'Dicuci',
  'Disetrika',
  'Siap',
  'Diambil',
  'Lunas',
  'Selesai',
];
