import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String rupiah(num amount) {
    return _currencyFormat.format(amount);
  }

  /// Convert UTC DateTime to WITA (UTC+8) and format
  static String dateTimeWita(dynamic dateTime) {
    if (dateTime == null) return '-';
    DateTime dt;
    if (dateTime is String) {
      dt = DateTime.parse(dateTime);
    } else if (dateTime is DateTime) {
      dt = dateTime;
    } else {
      return '-';
    }

    // Convert to WITA (UTC+8)
    final witaTime = dt.toUtc().add(const Duration(hours: 8));
    return '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(witaTime)} WITA';
  }

  static String dateWita(dynamic dateTime) {
    if (dateTime == null) return '-';
    DateTime dt;
    if (dateTime is String) {
      dt = DateTime.parse(dateTime);
    } else if (dateTime is DateTime) {
      dt = dateTime;
    } else {
      return '-';
    }

    final witaTime = dt.toUtc().add(const Duration(hours: 8));
    return DateFormat('dd MMM yyyy', 'id_ID').format(witaTime);
  }
}
