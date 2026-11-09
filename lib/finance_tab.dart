import 'package:flutter/material.dart';

import 'formatters.dart';
import 'models.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({
    super.key,
    required this.month,
    required this.expenses,
    required this.otherIncomes,
    required this.onMonthChanged,
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onAddOtherIncome,
    required this.onEditOtherIncome,
    required this.onDeleteOtherIncome,
  });

  final DateTime month;
  final List<ExpenseEntry> expenses;
  final List<OtherIncomeEntry> otherIncomes;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onAddExpense;
  final ValueChanged<ExpenseEntry> onEditExpense;
  final ValueChanged<ExpenseEntry> onDeleteExpense;
  final VoidCallback onAddOtherIncome;
  final ValueChanged<OtherIncomeEntry> onEditOtherIncome;
  final ValueChanged<OtherIncomeEntry> onDeleteOtherIncome;

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  int _section = 0;

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: widget.month,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('es'),
      helpText: 'Busca un mes del historial',
    );
    if (selected != null) {
      widget.onMonthChanged(DateTime(selected.year, selected.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = monthKey(widget.month);
    final expenses = widget.expenses
        .where((expense) => expense.day.startsWith(month))
        .toList();
    final otherIncomes = widget.otherIncomes
        .where((income) => income.day.startsWith(month))
        .toList();
    final expenseTotal = expenses.fold<int>(
      0,
      (total, expense) => total + expense.amount,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _FinanceMonthPicker(
          month: widget.month,
          onPrevious: () => widget.onMonthChanged(
            DateTime(widget.month.year, widget.month.month - 1),
          ),
          onNext: () => widget.onMonthChanged(
            DateTime(widget.month.year, widget.month.month + 1),
          ),
          onPick: _pickMonth,
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Gastos', maxLines: 1),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Ingresos', maxLines: 1),
              icon: Icon(Icons.add_card_outlined),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (selection) =>
              setState(() => _section = selection.first),
        ),
        const SizedBox(height: 16),
        if (_section == 0) ...[
          _FinanceTotalCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Gastos registrados este mes',
            amount: expenseTotal,
            tint: const Color(0xFFFFF1D9),
            iconColor: const Color(0xFF956000),
          ),
          const SizedBox(height: 16),
          _SectionHeading(
            title: 'Compras y gastos',
            subtitle: 'Registra cada gasto puntual para llevar la cuenta.',
            buttonLabel: 'Agregar gasto',
            onAdd: widget.onAddExpense,
          ),
          if (expenses.isEmpty)
            const _FinanceEmpty(
              icon: Icons.savings_outlined,
              title: 'Todavía no hay gastos',
              message: 'Los gastos que agregues aparecerán aquí.',
            )
          else
            ...expenses.map(
              (expense) => _ExpenseCard(
                expense: expense,
                onEdit: () => widget.onEditExpense(expense),
                onDelete: () => widget.onDeleteExpense(expense),
              ),
            ),
        ] else ...[
          _FinanceTotalCard(
            icon: Icons.add_card_outlined,
            label: 'Otros ingresos este mes',
            amount: otherIncomes.fold<int>(
              0,
              (total, income) => total + income.amount,
            ),
            tint: Theme.of(context).colorScheme.primaryContainer,
            iconColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _SectionHeading(
            title: 'Dinero recibido',
            subtitle: 'Agrega sueldos u otros ingresos ya recibidos.',
            buttonLabel: 'Agregar ingreso',
            onAdd: widget.onAddOtherIncome,
          ),
          if (otherIncomes.isEmpty)
            const _FinanceEmpty(
              icon: Icons.add_card_outlined,
              title: 'Todavía no hay otros ingresos',
              message: 'Registra aquí dinero recibido de otros trabajos.',
            )
          else
            ...otherIncomes.map(
              (income) => _OtherIncomeCard(
                income: income,
                onEdit: () => widget.onEditOtherIncome(income),
                onDelete: () => widget.onDeleteOtherIncome(income),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Text(
          'Los montos se registran en pesos chilenos y el historial mensual se conserva.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class DebtsTab extends StatelessWidget {
  const DebtsTab({
    super.key,
    required this.month,
    required this.debts,
    required this.debtPaymentAmounts,
    required this.debtDueDays,
    required this.onMonthChanged,
    required this.onAddDebt,
    required this.onEditDebt,
    required this.onDeleteDebt,
    required this.onSetDebtPaid,
    required this.onSetDebtDueDay,
    required this.onBillCard,
    required this.onCloseDebt,
  });

  final DateTime month;
  final List<DebtEntry> debts;
  final Map<String, int> debtPaymentAmounts;
  final Map<String, String> debtDueDays;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onAddDebt;
  final ValueChanged<DebtEntry> onEditDebt;
  final ValueChanged<DebtEntry> onDeleteDebt;
  final ValueChanged<DebtOccurrence> onSetDebtPaid;
  final ValueChanged<DebtOccurrence> onSetDebtDueDay;
  final ValueChanged<DateTime> onBillCard;
  final ValueChanged<DebtEntry> onCloseDebt;

  Future<void> _pickMonth(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('es'),
      helpText: 'Busca un mes del historial',
    );
    if (selected != null) {
      onMonthChanged(DateTime(selected.year, selected.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = debtOccurrencesForMonth(
      debts,
      month,
      paidAmountsByStatusKey: debtPaymentAmounts,
      dueDaysByStatusKey: debtDueDays,
    )..sort((a, b) => a.dueDay.compareTo(b.dueDay));
    final debtTotal = occurrences.fold<int>(
      0,
      (total, occurrence) =>
          total + (occurrence.amount - occurrence.paidAmount).clamp(0, occurrence.amount),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _FinanceMonthPicker(
          month: month,
          onPrevious: () => onMonthChanged(
            DateTime(month.year, month.month - 1),
          ),
          onNext: () => onMonthChanged(DateTime(month.year, month.month + 1)),
          onPick: () => _pickMonth(context),
        ),
        const SizedBox(height: 16),
        _FinanceTotalCard(
          icon: Icons.event_repeat_outlined,
          label: 'Pagos y cuotas de este mes',
          amount: debtTotal,
          tint: Theme.of(context).colorScheme.primaryContainer,
          iconColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => onBillCard(month),
          icon: const Icon(Icons.credit_score_outlined),
          label: const Text('Facturación realizada'),
        ),
        const SizedBox(height: 16),
        _SectionHeading(
          title: 'Tarjeta de crédito',
          subtitle: 'Cuotas pendientes del ciclo seleccionado.',
          buttonLabel: 'Agregar deuda',
          onAdd: onAddDebt,
        ),
        ...debts
            .where((debt) => debt.type == DebtType.installments)
            .map(
              (debt) => _DebtSummaryCard(
                debt: debt,
                monthOccurrences: occurrences
                    .where((item) => item.debt.id == debt.id)
                    .toList(),
                onEdit: () => onEditDebt(debt),
                onDelete: () => onDeleteDebt(debt),
                onClose: () => onCloseDebt(debt),
                onSetPaid: onSetDebtPaid,
                onSetDueDay: onSetDebtDueDay,
              ),
            ),
        if (!debts.any((debt) => debt.type == DebtType.installments))
          const _FinanceEmpty(
            icon: Icons.credit_card_outlined,
            title: 'Sin cuotas registradas',
            message: 'Agrega aquí compras con tarjeta en varias cuotas.',
          )
        ,
        const SizedBox(height: 16),
        _SectionHeading(
          title: 'Pago del mes',
          subtitle: 'Compromisos mensuales como cuentas o pagos familiares.',
          buttonLabel: 'Agregar pago',
          onAdd: onAddDebt,
        ),
        ...debts
            .where((debt) => debt.type == DebtType.monthly)
            .map(
            (debt) => _DebtSummaryCard(
              debt: debt,
              monthOccurrences: occurrences
                  .where((item) => item.debt.id == debt.id)
                  .toList(),
              onEdit: () => onEditDebt(debt),
              onDelete: () => onDeleteDebt(debt),
              onClose: () => onCloseDebt(debt),
              onSetPaid: onSetDebtPaid,
              onSetDueDay: onSetDebtDueDay,
            ),
          ),
        if (!debts.any((debt) => debt.type == DebtType.monthly))
          const _FinanceEmpty(
            icon: Icons.event_repeat_outlined,
            title: 'Sin pagos mensuales',
            message: 'Agrega aquí tus compromisos mensuales.',
          ),
        const SizedBox(height: 18),
        Text(
          'Las deudas pendientes se muestran aquí y solo afectan tu saldo cuando registras su pago.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FinanceMonthPicker extends StatelessWidget {
  const _FinanceMonthPicker({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Mes anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            capitalize(formatMonth(month)),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Mes siguiente',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _FinanceTotalCard extends StatelessWidget {
  const _FinanceTotalCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final int amount;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: tint,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  formatMoney(amount),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(buttonLabel),
            ),
          ],
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseEntry expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFF1D9),
        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF956000)),
      ),
      title: Text(
        expense.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${expense.category} · ${capitalize(formatShortDay(expense.day))}'
        ' · ${expense.paymentMethod == ExpensePaymentMethod.debit ? 'Débito' : 'Crédito${expense.cardBilled ? ' facturado' : ''}'}'
        '${expense.notes.isEmpty ? '' : '\n${expense.notes}'}',
      ),
      isThreeLine: expense.notes.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    ),
  );
}

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({
    required this.debt,
    required this.monthOccurrences,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    required this.onSetPaid,
    required this.onSetDueDay,
  });

  final DebtEntry debt;
  final List<DebtOccurrence> monthOccurrences;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final ValueChanged<DebtOccurrence> onSetPaid;
  final ValueChanged<DebtOccurrence> onSetDueDay;

  @override
  Widget build(BuildContext context) {
    final occurrence = monthOccurrences.isEmpty ? null : monthOccurrences.first;
    final installmentIndex = occurrence == null
        ? null
        : monthsBetween(
                monthKey(DateTime.parse(debt.startDay)),
                occurrence.month,
              ) +
              1;
    final subtitle = switch (debt.type) {
      DebtType.monthly => 'Pago mensual · ${formatMoney(debt.amount)}',
      DebtType.installments =>
        '${debt.installmentCount} cuotas · Total ${formatMoney(debt.amount)}'
            '${installmentIndex == null ? '' : ' · Cuota $installmentIndex de ${debt.installmentCount}'}',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: debt.isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : const Color(0xFFF0F1EF),
                child: Icon(
                  debt.type == DebtType.monthly
                      ? Icons.autorenew
                      : Icons.calendar_month_outlined,
                  color: debt.isActive
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF777D79),
                ),
              ),
              title: Text(
                debt.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '$subtitle${debt.notes.isEmpty ? '' : '\n${debt.notes}'}'
                '${debt.isActive ? '' : '\nÚltimo mes activo: ${debt.endMonth}'}',
              ),
              isThreeLine: debt.notes.isNotEmpty || !debt.isActive,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'close':
                      onClose();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'close',
                    child: Text(
                      debt.isActive ? 'Marcar como cerrada' : 'Reactivar deuda',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
            if (occurrence != null)
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: occurrence.isPaid,
                title: Text(
                  'Vence ${capitalize(formatShortDay(occurrence.dueDay))}',
                ),
                subtitle: Text(formatMoney(occurrence.amount)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (_) => onSetPaid(occurrence),
              ),
            if (occurrence != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onSetDueDay(occurrence),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Cambiar vencimiento de este mes'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OtherIncomeCard extends StatelessWidget {
  const _OtherIncomeCard({
    required this.income,
    required this.onEdit,
    required this.onDelete,
  });

  final OtherIncomeEntry income;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.add_card_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        income.source,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${capitalize(formatShortDay(income.day))}'
        '${income.notes.isEmpty ? '' : '\n${income.notes}'}',
      ),
      isThreeLine: income.notes.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(income.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    ),
  );
}

class _FinanceEmpty extends StatelessWidget {
  const _FinanceEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
