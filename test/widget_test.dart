// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picker_control/forms.dart';
import 'package:picker_control/models.dart';
import 'package:picker_control/settings_dialog.dart';

void main() {
  testWidgets('appearance settings select dark mode and accent color', (
    tester,
  ) async {
    AppThemeSettings? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<AppThemeSettings>(
                  context: context,
                  builder: (context) =>
                      const SettingsDialog(settings: AppThemeSettings.defaults),
                );
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.tap(find.bySemanticsLabel('Rosa'));
    await tester.enterText(find.byType(TextFormField), '10,5');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result?.darkMode, isTrue);
    expect(result?.accentColor, 0xFFB34375);
    expect(result?.withholdingPercent, 10.5);
  });

  test('order earnings use the weekday and Sunday SKU rates', () {
    final firstSunday = DateTime(2026, 11, 8);

    for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
      final date = firstSunday.add(Duration(days: offset));
      expect(
        skuRateForDay(date),
        date.weekday == DateTime.sunday ? 90 : 75,
        reason: 'Unexpected SKU rate on ${dayKey(date)}',
      );
    }

    final monday = firstSunday.add(const Duration(days: 1));
    final sunday = firstSunday;
    expect(
      calculateOrderTotal(
        skuCount: 5,
        skuRate: skuRateForDay(monday),
        bonus: 500,
      ),
      2175,
    );
    expect(
      calculateOrderTotal(
        skuCount: 5,
        skuRate: skuRateForDay(sunday),
        bonus: 1000,
      ),
      2750,
    );
  });

  test('saved orders always use the SKU rate for their calendar date', () {
    final sundayOrder = PickerOrder.fromMap({
      'id': 1,
      'code': 'DOMINGO',
      'day': '2026-11-08',
      'sku_count': 5,
      'sku_rate': 75,
      'bonus': 0,
      'notes': '',
      'base_rate': 1300,
    });

    expect(sundayOrder.skuRate, 90);
    expect(sundayOrder.total, 1750);
    expect(sundayOrder.toMap().containsKey('sku_rate'), isFalse);
  });

  test('bonus options cover the requested ranges', () {
    expect(orderBonuses, [
      0,
      ...List.generate(10, (index) => (index + 1) * 100),
    ]);
    expect(shiftBonuses, [
      0,
      ...List.generate(12, (index) => (index + 1) * 1000),
    ]);
  });

  test('daily generated amount includes the shift bonus and linked orders', () {
    const orders = [
      PickerOrder(
        id: 1,
        code: 'A',
        day: '2026-11-09',
        skuCount: 1,
        bonus: 0,
        notes: '',
      ),
    ];
    const shifts = [
      WorkShift(
        id: 1,
        day: '2026-11-09',
        startTime: '09:00',
        endTime: '18:00',
        bonus: 5000,
        notes: '',
      ),
    ];

    expect(
      generatedForDay(day: '2026-11-09', orders: orders, shifts: shifts),
      6375,
    );
  });

  test('calendar date keys retain the full year and zero padding', () {
    expect(dayKey(DateTime(2026, 2, 3)), '2026-02-03');
  });

  test('installment amounts sum to the exact debt total', () {
    final amounts = List.generate(
      3,
      (index) => installmentAmountForMonth(
        totalAmount: 10000,
        installmentCount: 3,
        installmentNumber: index + 1,
      ),
    );

    expect(amounts, [3333, 3333, 3334]);
    expect(amounts.reduce((sum, amount) => sum + amount), 10000);
  });

  test(
    'monthly debt occurrence clamps its due day and honors its end month',
    () {
      final debt = DebtEntry(
        id: 8,
        title: 'Mamá',
        notes: '',
        type: DebtType.monthly,
        amount: 200000,
        startDay: '2026-01-31',
        installmentCount: null,
        endMonth: '2026-02',
      );

      final february = debtOccurrenceForMonth(debt, DateTime(2026, 2));
      final march = debtOccurrenceForMonth(debt, DateTime(2026, 3));

      expect(february?.dueDay, '2026-02-28');
      expect(february?.amount, 200000);
      expect(march, isNull);
    },
  );

  test('installment debt stops after its final scheduled month', () {
    final debt = DebtEntry(
      id: 9,
      title: 'Tarjeta',
      notes: '',
      type: DebtType.installments,
      amount: 50000,
      startDay: '2026-01-15',
      installmentCount: 2,
      endMonth: null,
    );

    expect(debtOccurrenceForMonth(debt, DateTime(2026, 2))?.amount, 25000);
    expect(debtOccurrenceForMonth(debt, DateTime(2026, 3)), isNull);
  });

  test('2026 SII retention estimate uses 15.25 percent', () {
    expect(calculateSiiWithholding2026(100000), 15250);
    expect(calculateNetAfterSii2026(100000), 84750);
    expect(calculateSiiWithholding(100000, 10.5), 10500);
    expect(calculateNetAfterSii(100000, 0), 100000);
    expect(() => calculateSiiWithholding(100000, 100.01), throwsArgumentError);
  });

  test('calendar events store their start date and time', () {
    final event = CalendarEvent(
      id: 4,
      day: '2026-11-09',
      startTime: '10:30',
      title: 'Sesión',
      description: 'Consulta',
      notify: true,
      reminderMinutes: 30,
    );

    expect(event.startsAt, DateTime(2026, 11, 9, 10, 30));
    expect(
      CalendarEvent.fromMap(event.toMap()).notify,
      isTrue,
    );
    final restored = CalendarEvent.fromMap(event.toMap());
    expect(restored.startTime, '10:30');
    expect(restored.reminderMinutes, 30);
    expect(
      restored.notificationAt,
      DateTime(2026, 11, 9, 10),
    );
    final legacyMap = event.toMap()..remove('reminder_minutes');
    expect(CalendarEvent.fromMap(legacyMap).reminderMinutes, 0);
  });

  test(
    'outstanding debts subtract recorded payments without double counting',
    () {
      final monthlyDebt = DebtEntry(
        id: 10,
        title: 'Papá',
        notes: '',
        type: DebtType.monthly,
        amount: 2000,
        startDay: '2026-01-10',
        installmentCount: null,
        endMonth: null,
      );
      final installmentDebt = DebtEntry(
        id: 11,
        title: 'Tarjeta',
        notes: '',
        type: DebtType.installments,
        amount: 10000,
        startDay: '2026-01-15',
        installmentCount: 3,
        endMonth: null,
      );

      expect(
        totalOutstandingDebtAmount(
          debts: [monthlyDebt, installmentDebt],
          throughMonth: DateTime(2026, 2),
          paidAmountsByStatusKey: {'10:2026-01': 2000, '11:2026-01': 3333},
        ),
        8667,
      );
    },
  );

  test('order payouts group work into the configured invoice dates', () {
    expect(
      orderPayoutDueDay(
        '2026-11-05',
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      ),
      '2026-11-06',
    );
    expect(
      orderPayoutDueDay(
        '2026-11-06',
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      ),
      '2026-11-21',
    );
    expect(
      orderPayoutDueDay(
        '2026-11-20',
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      ),
      '2026-11-21',
    );
    expect(
      orderPayoutDueDay(
        '2026-11-21',
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      ),
      '2026-12-06',
    );
  });

  test('pending payout contains order and shift bonus until received', () {
    const orders = [
      PickerOrder(
        id: 1,
        code: 'A',
        day: '2026-11-05',
        skuCount: 2,
        bonus: 100,
        notes: '',
      ),
    ];
    const shifts = [
      WorkShift(
        id: 1,
        day: '2026-11-05',
        startTime: '09:00',
        endTime: '18:00',
        bonus: 1000,
        notes: '',
      ),
    ];

    final pending = pendingOrderPayouts(
      orders: orders,
      shifts: shifts,
      received: const [],
      throughDate: DateTime(2026, 11, 6),
      firstPayoutDay: 6,
      secondPayoutDay: 21,
    );
    final received = pendingOrderPayouts(
      orders: orders,
      shifts: shifts,
      received: const [
        OrderPayout(
          dueDay: '2026-11-06',
          grossAmount: 0,
          netAmount: 0,
          receivedDay: '2026-11-06',
        ),
      ],
      throughDate: DateTime(2026, 11, 6),
      firstPayoutDay: 6,
      secondPayoutDay: 21,
    );

    expect(pending.single.dueDay, '2026-11-06');
    expect(pending.single.grossAmount, 2550);
    expect(received, isEmpty);
  });

  test('credit card billing day begins the next cycle on or after cutoff', () {
    expect(
      cardExpenseBillingMonth(day: '2026-11-04', billingDay: 5),
      202611,
    );
    expect(
      cardExpenseBillingMonth(day: '2026-11-05', billingDay: 5),
      202612,
    );
    expect(
      cardExpenseBillingMonth(day: '2026-12-01', billingDay: 5),
      202612,
    );
  });

  test('credit expense retains payment and billing-cycle details', () {
    const expense = ExpenseEntry(
      id: 21,
      category: 'Hogar',
      title: 'Compra',
      day: '2026-11-03',
      amount: 12500,
      notes: '',
      paymentMethod: ExpensePaymentMethod.credit,
      cardBilled: true,
      cardBilledMonth: '2026-11',
    );

    final restored = ExpenseEntry.fromMap(expense.toMap());

    expect(restored.paymentMethod, ExpensePaymentMethod.credit);
    expect(restored.cardBilled, isTrue);
    expect(restored.cardBilledMonth, '2026-11');
  });

  test('debt due date override applies only to its selected month', () {
    final debt = DebtEntry(
      id: 12,
      title: 'Mamá',
      notes: '',
      type: DebtType.monthly,
      amount: 200000,
      startDay: '2026-11-06',
      installmentCount: null,
      endMonth: null,
    );

    final november = debtOccurrenceForMonth(
      debt,
      DateTime(2026, 11),
      dueDayOverride: '2026-11-09',
    );
    final december = debtOccurrenceForMonth(debt, DateTime(2026, 12));

    expect(november?.dueDay, '2026-11-09');
    expect(december?.dueDay, '2026-12-06');
  });
}
