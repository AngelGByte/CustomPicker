// Thi
//s is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:picker_control/finance_tab.dart';
import 'package:picker_control/formatters.dart';
import 'package:picker_control/forms.dart';
import 'package:picker_control/models.dart';
import 'package:picker_control/settings_dialog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets(
    'credit expenses are included in billing total but not listed as debts',
    (tester) async {
      final debt = DebtEntry(
        id: 91,
        title: 'Notebook',
        notes: '',
        type: DebtType.installments,
        amount: 30000,
        startDay: '2026-11-01',
        installmentCount: 3,
        endMonth: null,
      );
      const expense = ExpenseEntry(
        id: 92,
        category: 'Comida',
        title: 'Compra con crédito',
        day: '2026-11-03',
        amount: 12500,
        notes: '',
        paymentMethod: ExpensePaymentMethod.credit,
      );
      const billedExpense = ExpenseEntry(
        id: 93,
        category: 'Transporte',
        title: 'Compra ya facturada',
        day: '2026-10-28',
        amount: 5000,
        notes: '',
        paymentMethod: ExpensePaymentMethod.credit,
        cardBilled: true,
        cardBilledMonth: '2026-11',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebtsTab(
              month: DateTime(2026, 11),
              debts: [debt],
              expenses: const [expense, billedExpense],
              cardBillingDay: 5,
              debtPaymentAmounts: const {'91:2026-11': 10000},
              debtDueDays: const {},
              onMonthChanged: (_) {},
              onAddDebt: (_) {},
              onEditDebt: (_) {},
              onDeleteDebt: (_) {},
              onSetDebtPaid: (_) {},
              onSetDebtDueDay: (_) {},
              onBillCard: (_) {},
              onCloseDebt: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Tarjeta'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compra con crédito'), findsNothing);
      expect(find.text('Notebook'), findsOneWidget);
      expect(find.text(formatMoney(27500)), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Facturación realizada'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'finance history shows only expenses and income for the chosen month',
    (tester) async {
      var month = DateTime(2026, 11);
      const expenses = [
        ExpenseEntry(
          id: 101,
          category: 'Comida',
          title: 'Gasto noviembre',
          day: '2026-11-12',
          amount: 1000,
          notes: '',
        ),
        ExpenseEntry(
          id: 102,
          category: 'Comida',
          title: 'Gasto diciembre',
          day: '2026-12-12',
          amount: 2000,
          notes: '',
        ),
      ];
      const incomes = [
        OtherIncomeEntry(
          id: 103,
          source: 'Ingreso noviembre',
          day: '2026-11-13',
          amount: 3000,
          notes: '',
        ),
        OtherIncomeEntry(
          id: 104,
          source: 'Ingreso diciembre',
          day: '2026-12-13',
          amount: 4000,
          notes: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: FinanceTab(
                month: month,
                expenses: expenses,
                otherIncomes: incomes,
                onMonthChanged: (value) => setState(() => month = value),
                onAddExpense: () {},
                onEditExpense: (_) {},
                onDeleteExpense: (_) {},
                onAddOtherIncome: () {},
                onEditOtherIncome: (_) {},
                onDeleteOtherIncome: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Gasto noviembre'), findsOneWidget);
      expect(find.text('Gasto diciembre'), findsNothing);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Gasto noviembre'), findsNothing);
      expect(find.text('Gasto diciembre'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Ingresos'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ingreso diciembre'), findsOneWidget);
      expect(find.text('Ingreso noviembre'), findsNothing);
    },
  );

  testWidgets('installment count can be selected from 3 to 24', (tester) async {
    DebtEntry? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<DebtEntry>(
                  context: context,
                  builder: (context) => DebtFormDialog(
                    initialType: DebtType.installments,
                    initialDay: '2026-11-09',
                  ),
                );
              },
              child: const Text('Agregar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);

    final installmentSelector = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    expect(
      installmentSelector.items!.map((item) => item.value),
      List.generate(22, (index) => index + 3),
    );
    installmentSelector.onChanged!(24);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Compra');
    await tester.enterText(find.byType(TextFormField).at(1), '24000');
    await tester.tap(find.text('Guardar deuda'));
    await tester.pumpAndSettle();

    expect(result?.installmentCount, 24);
  });

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
      amount: 30000,
      startDay: '2026-01-15',
      installmentCount: 3,
      endMonth: null,
    );

    final february = debtOccurrenceForMonth(debt, DateTime(2026, 2));
    final paidFinalMonth = debtOccurrencesForMonth(
      [debt],
      DateTime(2026, 3),
      paidAmountsByStatusKey: const {'9:2026-03': 10000},
    );
    final monthAfterFinalPayment = debtOccurrencesForMonth(
      [debt],
      DateTime(2026, 4),
      paidAmountsByStatusKey: const {'9:2026-03': 10000},
    );

    expect(february?.amount, 10000);
    expect(paidFinalMonth.single.isPaid, isTrue);
    expect(monthAfterFinalPayment, isEmpty);
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
    expect(CalendarEvent.fromMap(event.toMap()).notify, isTrue);
    final restored = CalendarEvent.fromMap(event.toMap());
    expect(restored.startTime, '10:30');
    expect(restored.reminderMinutes, 30);
    expect(restored.notificationAt, DateTime(2026, 11, 9, 10));
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
      orderPayoutDueDay('2026-11-05', firstPayoutDay: 6, secondPayoutDay: 21),
      '2026-11-06',
    );
    expect(
      orderPayoutDueDay('2026-11-06', firstPayoutDay: 6, secondPayoutDay: 21),
      '2026-11-21',
    );
    expect(
      orderPayoutDueDay('2026-11-20', firstPayoutDay: 6, secondPayoutDay: 21),
      '2026-11-21',
    );
    expect(
      orderPayoutDueDay('2026-11-21', firstPayoutDay: 6, secondPayoutDay: 21),
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
    expect(cardExpenseBillingMonth(day: '2026-11-04', billingDay: 5), 202611);
    expect(cardExpenseBillingMonth(day: '2026-11-05', billingDay: 5), 202612);
    expect(cardExpenseBillingMonth(day: '2026-12-01', billingDay: 5), 202612);
  });

  test(
    'single-payment credit expenses are grouped into their billing cycle',
    () {
      final expenses = [
        const ExpenseEntry(
          id: 31,
          category: 'Comida',
          title: 'Compra antes del cierre',
          day: '2026-11-04',
          amount: 12500,
          notes: '',
          paymentMethod: ExpensePaymentMethod.credit,
        ),
        const ExpenseEntry(
          id: 32,
          category: 'Comida',
          title: 'Compra después del cierre',
          day: '2026-11-05',
          amount: 8000,
          notes: '',
          paymentMethod: ExpensePaymentMethod.credit,
        ),
        const ExpenseEntry(
          id: 33,
          category: 'Hogar',
          title: 'Débito',
          day: '2026-11-04',
          amount: 1000,
          notes: '',
          paymentMethod: ExpensePaymentMethod.debit,
        ),
        const ExpenseEntry(
          id: 34,
          category: 'Salud',
          title: 'Compra facturada',
          day: '2026-10-30',
          amount: 5000,
          notes: '',
          paymentMethod: ExpensePaymentMethod.credit,
          cardBilled: true,
          cardBilledMonth: '2026-11',
        ),
      ];

      final novemberCycle = cardExpensesForBillingMonth(
        expenses: expenses,
        month: DateTime(2026, 11),
        billingDay: 5,
      );
      final decemberCycle = cardExpensesForBillingMonth(
        expenses: expenses,
        month: DateTime(2026, 12),
        billingDay: 5,
      );

      expect(novemberCycle.map((expense) => expense.id), [31, 34]);
      expect(decemberCycle.map((expense) => expense.id), [32]);
    },
  );

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
