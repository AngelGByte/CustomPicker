import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.decimalPattern('es_CL');

String formatMoney(int amount) => '\$${_currencyFormat.format(amount)}';

String formatDay(String key) =>
    DateFormat('EEEE d MMMM y', 'es').format(DateTime.parse(key));

String formatShortDay(String key) =>
    DateFormat('d MMM yyyy', 'es').format(DateTime.parse(key));

String formatMonth(DateTime month) =>
    DateFormat('MMMM y', 'es').format(month);

String capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
