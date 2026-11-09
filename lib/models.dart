class AppThemeSettings {
  const AppThemeSettings({
    required this.darkMode,
    required this.accentColor,
    required this.withholdingPercent,
    required this.firstPayoutDay,
    required this.secondPayoutDay,
    required this.cardBillingDay,
  });

  static const defaults = AppThemeSettings(
    darkMode: false,
    accentColor: 0xFF176B5B,
    withholdingPercent: 15.25,
    firstPayoutDay: 6,
    secondPayoutDay: 21,
    cardBillingDay: 5,
  );

  final bool darkMode;
  final int accentColor;
  final double withholdingPercent;
  final int firstPayoutDay;
  final int secondPayoutDay;
  final int cardBillingDay;

  AppThemeSettings copyWith({
    bool? darkMode,
    int? accentColor,
    double? withholdingPercent,
    int? firstPayoutDay,
    int? secondPayoutDay,
    int? cardBillingDay,
  }) =>
      AppThemeSettings(
        darkMode: darkMode ?? this.darkMode,
        accentColor: accentColor ?? this.accentColor,
        withholdingPercent: withholdingPercent ?? this.withholdingPercent,
        firstPayoutDay: firstPayoutDay ?? this.firstPayoutDay,
        secondPayoutDay: secondPayoutDay ?? this.secondPayoutDay,
        cardBillingDay: cardBillingDay ?? this.cardBillingDay,
      );
}

class AccentColorOption {
  const AccentColorOption({required this.name, required this.value});

  final String name;
  final int value;
}

const accentColorOptions = [
  AccentColorOption(name: 'Verde', value: 0xFF176B5B),
  AccentColorOption(name: 'Rosa', value: 0xFFB34375),
  AccentColorOption(name: 'Azul', value: 0xFF3568A8),
];

class PickerOrder {
  const PickerOrder({
    this.id,
    required this.code,
    required this.day,
    required this.skuCount,
    required this.bonus,
    required this.notes,
    this.baseRate = 1300,
  });

  final int? id;
  final String code;
  final String day;
  final int skuCount;
  final int bonus;
  final String notes;
  final int baseRate;

  int get skuRate => skuRateForDay(DateTime.parse(day));

  int get total => calculateOrderTotal(
    skuCount: skuCount,
    skuRate: skuRate,
    bonus: bonus,
    baseRate: baseRate,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'code': code,
    'day': day,
    'sku_count': skuCount,
    'bonus': bonus,
    'notes': notes,
    'base_rate': baseRate,
  };

  factory PickerOrder.fromMap(Map<String, Object?> map) => PickerOrder(
    id: map['id'] as int,
    code: map['code'] as String,
    day: map['day'] as String,
    skuCount: map['sku_count'] as int,
    bonus: map['bonus'] as int,
    notes: map['notes'] as String,
    baseRate: map['base_rate'] as int,
  );
}

class WorkShift {
  const WorkShift({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.bonus,
    required this.notes,
  });

  final int? id;
  final String day;
  final String startTime;
  final String endTime;
  final int bonus;
  final String notes;

  Map<String, Object?> toMap() => {
    'id': id,
    'day': day,
    'start_time': startTime,
    'end_time': endTime,
    'bonus': bonus,
    'notes': notes,
  };

  factory WorkShift.fromMap(Map<String, Object?> map) => WorkShift(
    id: map['id'] as int,
    day: map['day'] as String,
    startTime: map['start_time'] as String,
    endTime: map['end_time'] as String,
    bonus: map['bonus'] as int,
    notes: map['notes'] as String,
  );
}

enum ExpensePaymentMethod { debit, credit }

class ExpenseEntry {
  const ExpenseEntry({
    this.id,
    required this.category,
    required this.title,
    required this.day,
    required this.amount,
    required this.notes,
    this.paymentMethod = ExpensePaymentMethod.debit,
    this.cardBilled = false,
    this.cardBilledMonth,
  });

  final int? id;
  final String category;
  final String title;
  final String day;
  final int amount;
  final String notes;
  final ExpensePaymentMethod paymentMethod;
  final bool cardBilled;
  final String? cardBilledMonth;

  Map<String, Object?> toMap() => {
    'id': id,
    'category': category,
    'title': title,
    'day': day,
    'amount': amount,
    'notes': notes,
    'payment_method': paymentMethod.name,
    'card_billed': cardBilled ? 1 : 0,
    'card_billed_month': cardBilledMonth,
  };

  factory ExpenseEntry.fromMap(Map<String, Object?> map) => ExpenseEntry(
    id: map['id'] as int,
    category: map['category'] as String,
    title: map['title'] as String,
    day: map['day'] as String,
    amount: map['amount'] as int,
    notes: map['notes'] as String,
    paymentMethod: ExpensePaymentMethod.values.firstWhere(
      (method) => method.name == map['payment_method'],
      orElse: () => ExpensePaymentMethod.debit,
    ),
    cardBilled: map['card_billed'] == 1 || map['card_billed_month'] != null,
    cardBilledMonth: map['card_billed_month'] as String?,
  );
}

class OtherIncomeEntry {
  const OtherIncomeEntry({
    this.id,
    required this.source,
    required this.day,
    required this.amount,
    required this.notes,
  });

  final int? id;
  final String source;
  final String day;
  final int amount;
  final String notes;

  Map<String, Object?> toMap() => {
    'id': id,
    'source': source,
    'day': day,
    'amount': amount,
    'notes': notes,
  };

  factory OtherIncomeEntry.fromMap(Map<String, Object?> map) =>
      OtherIncomeEntry(
        id: map['id'] as int,
        source: map['source'] as String,
        day: map['day'] as String,
        amount: map['amount'] as int,
        notes: map['notes'] as String,
      );
}

enum DebtType { monthly, installments }

class DebtEntry {
  const DebtEntry({
    this.id,
    required this.title,
    required this.notes,
    required this.type,
    required this.amount,
    required this.startDay,
    required this.installmentCount,
    required this.endMonth,
  });

  final int? id;
  final String title;
  final String notes;
  final DebtType type;
  // Monthly debts store their monthly amount; installment debts store the
  // total debt amount and split it into whole-peso installments.
  final int amount;
  final String startDay;
  final int? installmentCount;
  final String? endMonth;

  bool get isActive => endMonth == null;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'notes': notes,
    'type': type.name,
    'amount': amount,
    'start_day': startDay,
    'installment_count': installmentCount,
    'end_month': endMonth,
  };

  factory DebtEntry.fromMap(Map<String, Object?> map) => DebtEntry(
    id: map['id'] as int,
    title: map['title'] as String,
    notes: map['notes'] as String,
    type: DebtType.values.byName(map['type'] as String),
    amount: map['amount'] as int,
    startDay: map['start_day'] as String,
    installmentCount: map['installment_count'] as int?,
    endMonth: map['end_month'] as String?,
  );
}

class DebtOccurrence {
  const DebtOccurrence({
    required this.debt,
    required this.month,
    required this.dueDay,
    required this.amount,
    required this.paidAmount,
  });

  final DebtEntry debt;
  final String month;
  final String dueDay;
  final int amount;
  final int paidAmount;

  bool get isPaid => paidAmount >= amount;

  String get statusKey => '${debt.id}:$month';
}

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

int monthsBetween(String fromMonth, String toMonth) {
  final from = DateTime.parse('$fromMonth-01');
  final to = DateTime.parse('$toMonth-01');
  return (to.year - from.year) * 12 + to.month - from.month;
}

int installmentAmountForMonth({
  required int totalAmount,
  required int installmentCount,
  required int installmentNumber,
}) {
  if (installmentCount <= 0 ||
      installmentNumber < 1 ||
      installmentNumber > installmentCount) {
    throw ArgumentError('Installment number must be within its schedule.');
  }
  final regularAmount = totalAmount ~/ installmentCount;
  return installmentNumber == installmentCount
      ? totalAmount - regularAmount * (installmentCount - 1)
      : regularAmount;
}

DebtOccurrence? debtOccurrenceForMonth(
  DebtEntry debt,
  DateTime month, {
  int paidAmount = 0,
  String? dueDayOverride,
}) {
  final monthString = monthKey(month);
  final index = monthsBetween(
    monthKey(DateTime.parse(debt.startDay)),
    monthString,
  );
  if (index < 0 ||
      (debt.endMonth != null && monthString.compareTo(debt.endMonth!) > 0)) {
    return null;
  }

  final dueDate = DateTime.parse(debt.startDay);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final dueDay = dueDayOverride ?? dayKey(
    DateTime(month.year, month.month, dueDate.day.clamp(1, daysInMonth)),
  );
  if (debt.type == DebtType.installments &&
      (debt.installmentCount == null || index >= debt.installmentCount!)) {
    return null;
  }

  final occurrenceAmount = debt.type == DebtType.monthly
      ? debt.amount
      : installmentAmountForMonth(
          totalAmount: debt.amount,
          installmentCount: debt.installmentCount!,
          installmentNumber: index + 1,
        );
  return DebtOccurrence(
    debt: debt,
    month: monthString,
    dueDay: dueDay,
    amount: occurrenceAmount,
    paidAmount: paidAmount,
  );
}

List<DebtOccurrence> debtOccurrencesForMonth(
  List<DebtEntry> debts,
  DateTime month, {
  Map<String, int> paidAmountsByStatusKey = const {},
  Map<String, String> dueDaysByStatusKey = const {},
}) => debts
    .map(
      (debt) => debtOccurrenceForMonth(
        debt,
        month,
        paidAmount:
            paidAmountsByStatusKey['${debt.id}:${monthKey(month)}'] ?? 0,
        dueDayOverride:
            dueDaysByStatusKey['${debt.id}:${monthKey(month)}'],
      ),
    )
    .whereType<DebtOccurrence>()
    .toList();

class OrderPayout {
  const OrderPayout({
    required this.dueDay,
    required this.grossAmount,
    required this.netAmount,
    required this.receivedDay,
  });

  final String dueDay;
  final int grossAmount;
  final int netAmount;
  final String receivedDay;

  Map<String, Object?> toMap() => {
    'cycle_due_day': dueDay,
    'gross_amount': grossAmount,
    'net_amount': netAmount,
    'received_day': receivedDay,
  };

  factory OrderPayout.fromMap(Map<String, Object?> map) => OrderPayout(
    dueDay: map['cycle_due_day'] as String,
    grossAmount: map['gross_amount'] as int,
    netAmount: map['net_amount'] as int,
    receivedDay: map['received_day'] as String,
  );
}

class PendingPayout {
  const PendingPayout({required this.dueDay, required this.grossAmount});

  final String dueDay;
  final int grossAmount;

  int netAmount(double withholdingPercent) =>
      calculateNetAfterSii(grossAmount, withholdingPercent);
}

List<PendingPayout> pendingOrderPayouts({
  required List<PickerOrder> orders,
  required List<WorkShift> shifts,
  required List<OrderPayout> received,
  required DateTime throughDate,
  required int firstPayoutDay,
  required int secondPayoutDay,
}) {
  final receivedDates = received.map((payout) => payout.dueDay).toSet();
  final grossByDueDay = <String, int>{};
  void add(String day, int amount) {
    final dueDay = orderPayoutDueDay(
      day,
      firstPayoutDay: firstPayoutDay,
      secondPayoutDay: secondPayoutDay,
    );
    if (dueDay.compareTo(dayKey(throughDate)) > 0 ||
        receivedDates.contains(dueDay)) {
      return;
    }
    grossByDueDay.update(
      dueDay,
      (gross) => gross + amount,
      ifAbsent: () => amount,
    );
  }

  for (final order in orders) {
    add(order.day, order.total);
  }
  for (final shift in shifts) {
    add(shift.day, shift.bonus);
  }
  return grossByDueDay.entries
      .map((entry) => PendingPayout(
            dueDay: entry.key,
            grossAmount: entry.value,
          ))
      .where((payout) => payout.grossAmount > 0)
      .toList()
    ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
}

String orderPayoutDueDay(
  String day, {
  required int firstPayoutDay,
  required int secondPayoutDay,
}) {
  if (firstPayoutDay < 1 ||
      firstPayoutDay > 28 ||
      secondPayoutDay < 1 ||
      secondPayoutDay > 28 ||
      firstPayoutDay >= secondPayoutDay) {
    throw ArgumentError('Invoice days must be ordered days from 1 to 28.');
  }
  final date = DateTime.parse(day);
  if (date.day < firstPayoutDay) {
    return dayKey(DateTime(date.year, date.month, firstPayoutDay));
  }
  if (date.day < secondPayoutDay) {
    return dayKey(DateTime(date.year, date.month, secondPayoutDay));
  }
  return dayKey(DateTime(date.year, date.month + 1, firstPayoutDay));
}

int cardExpenseBillingMonth({
  required String day,
  required int billingDay,
}) {
  if (billingDay < 1 || billingDay > 28) {
    throw ArgumentError.value(billingDay, 'billingDay');
  }
  final purchaseDate = DateTime.parse(day);
  final statementDate = DateTime(
    purchaseDate.year,
    purchaseDate.month,
    billingDay,
  );
  final billingMonth = purchaseDate.isBefore(statementDate)
      ? statementDate
      : DateTime(statementDate.year, statementDate.month + 1, billingDay);
  return billingMonth.year * 100 + billingMonth.month;
}

int totalOutstandingDebtAmount({
  required List<DebtEntry> debts,
  required DateTime throughMonth,
  Map<String, int> paidAmountsByStatusKey = const {},
}) {
  var total = 0;
  final lastMonth = DateTime(throughMonth.year, throughMonth.month);
  for (final debt in debts) {
    if (!debt.isActive) continue;
    final start = DateTime.parse(debt.startDay);
    final firstMonth = DateTime(start.year, start.month);
    if (debt.type == DebtType.installments) {
      final count = debt.installmentCount;
      if (count == null) continue;
      for (var index = 0; index < count; index++) {
        final dueMonth = DateTime(firstMonth.year, firstMonth.month + index);
        final amount = installmentAmountForMonth(
          totalAmount: debt.amount,
          installmentCount: count,
          installmentNumber: index + 1,
        );
        final paid =
            paidAmountsByStatusKey['${debt.id}:${monthKey(dueMonth)}'] ?? 0;
        total += (amount - paid).clamp(0, amount);
      }
      continue;
    }

    final endMonth = debt.endMonth == null
        ? lastMonth
        : DateTime.parse('${debt.endMonth}-01');
    final lastAccruedMonth = endMonth.isBefore(lastMonth)
        ? endMonth
        : lastMonth;
    if (lastAccruedMonth.isBefore(firstMonth)) continue;
    final count =
        monthsBetween(monthKey(firstMonth), monthKey(lastAccruedMonth)) + 1;
    for (var index = 0; index < count; index++) {
      final dueMonth = DateTime(firstMonth.year, firstMonth.month + index);
      final paid =
          paidAmountsByStatusKey['${debt.id}:${monthKey(dueMonth)}'] ?? 0;
      total += (debt.amount - paid).clamp(0, debt.amount);
    }
  }
  return total;
}

const defaultSiiWithholdingPercent = 15.25;

int calculateSiiWithholding(int grossAmount, double percentage) {
  if (percentage < 0 || percentage > 100) {
    throw ArgumentError.value(percentage, 'percentage', 'Must be 0–100.');
  }
  final basisPoints = (percentage * 100).round();
  return (grossAmount * basisPoints + 5000) ~/ 10000;
}

int calculateNetAfterSii(int grossAmount, double percentage) =>
    grossAmount - calculateSiiWithholding(grossAmount, percentage);

int calculateSiiWithholding2026(int grossAmount) =>
    calculateSiiWithholding(grossAmount, defaultSiiWithholdingPercent);

int calculateNetAfterSii2026(int grossAmount) =>
    calculateNetAfterSii(grossAmount, defaultSiiWithholdingPercent);

int generatedForDay({
  required String day,
  required List<PickerOrder> orders,
  required List<WorkShift> shifts,
}) {
  final orderTotal = orders
      .where((order) => order.day == day)
      .fold<int>(0, (total, order) => total + order.total);
  final shiftBonus = shifts
      .where((shift) => shift.day == day)
      .fold<int>(0, (total, shift) => total + shift.bonus);
  return orderTotal + shiftBonus;
}

int calculateNetGeneratedAcrossMonths({
  required List<PickerOrder> orders,
  required List<WorkShift> shifts,
  double withholdingPercent = defaultSiiWithholdingPercent,
}) {
  final generatedByMonth = <String, int>{};
  for (final order in orders) {
    final key = monthKey(DateTime.parse(order.day));
    generatedByMonth.update(
      key,
      (total) => total + order.total,
      ifAbsent: () => order.total,
    );
  }
  for (final shift in shifts) {
    final key = monthKey(DateTime.parse(shift.day));
    generatedByMonth.update(
      key,
      (total) => total + shift.bonus,
      ifAbsent: () => shift.bonus,
    );
  }
  return generatedByMonth.values.fold<int>(
    0,
    (total, gross) => total + calculateNetAfterSii(gross, withholdingPercent),
  );
}

class CalendarNote {
  const CalendarNote({
    this.id,
    required this.day,
    required this.title,
    required this.notes,
  });

  final int? id;
  final String day;
  final String title;
  final String notes;

  Map<String, Object?> toMap() => {
    'id': id,
    'day': day,
    'title': title,
    'notes': notes,
  };

  factory CalendarNote.fromMap(Map<String, Object?> map) => CalendarNote(
    id: map['id'] as int,
    day: map['day'] as String,
    title: map['title'] as String,
    notes: map['notes'] as String,
  );
}

class CalendarEvent {
  const CalendarEvent({
    this.id,
    required this.day,
    required this.startTime,
    required this.title,
    required this.description,
    required this.notify,
    this.reminderMinutes = 0,
  });

  final int? id;
  final String day;
  final String startTime;
  final String title;
  final String description;
  final bool notify;
  final int reminderMinutes;

  DateTime get startsAt => DateTime.parse('$day $startTime:00');

  DateTime get notificationAt =>
      startsAt.subtract(Duration(minutes: reminderMinutes));

  CalendarEvent copyWith({int? id}) => CalendarEvent(
    id: id ?? this.id,
    day: day,
    startTime: startTime,
    title: title,
    description: description,
    notify: notify,
    reminderMinutes: reminderMinutes,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'day': day,
    'start_time': startTime,
    'title': title,
    'description': description,
    'notify': notify ? 1 : 0,
    'reminder_minutes': reminderMinutes,
  };

  factory CalendarEvent.fromMap(Map<String, Object?> map) => CalendarEvent(
    id: map['id'] as int,
    day: map['day'] as String,
    startTime: map['start_time'] as String,
    title: map['title'] as String,
    description: map['description'] as String,
    notify: map['notify'] == 1,
    reminderMinutes: map['reminder_minutes'] as int? ?? 0,
  );
}

String calendarReminderLabel(int minutes) => switch (minutes) {
  0 => 'Al inicio',
  10 => '10 minutos antes',
  30 => '30 minutos antes',
  60 => '1 hora antes',
  1440 => '1 día antes',
  _ => throw ArgumentError.value(minutes, 'minutes'),
};

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int skuRateForDay(DateTime date) => date.weekday == DateTime.sunday ? 90 : 75;

int calculateOrderTotal({
  required int skuCount,
  required int skuRate,
  required int bonus,
  int baseRate = 1300,
}) => baseRate + skuCount * skuRate + bonus;
