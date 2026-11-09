import 'package:flutter/material.dart';

import 'formatters.dart';
import 'models.dart';

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({
    super.key,
    required this.month,
    required this.shifts,
    required this.orders,
    required this.onMonthChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime month;
  final List<WorkShift> shifts;
  final List<PickerOrder> orders;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onAdd;
  final ValueChanged<WorkShift> onEdit;
  final ValueChanged<WorkShift> onDelete;

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> {
  bool _allHistory = false;

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
    final monthKey =
        '${widget.month.year.toString().padLeft(4, '0')}-'
        '${widget.month.month.toString().padLeft(2, '0')}';
    final visible =
        widget.shifts
            .where((shift) => _allHistory || shift.day.startsWith(monthKey))
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
    final totalGenerated = visible.fold<int>(
      0,
      (sum, shift) =>
          sum +
          generatedForDay(
            day: shift.day,
            orders: widget.orders,
            shifts: [shift],
          ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Text(
          'Registra tus días trabajados y sus horarios.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Este mes')),
            ButtonSegment(value: true, label: Text('Todo el historial')),
          ],
          selected: {_allHistory},
          onSelectionChanged: (value) =>
              setState(() => _allHistory = value.first),
        ),
        if (!_allHistory) ...[
          const SizedBox(height: 8),
          _MonthPicker(
            month: widget.month,
            onPrevious: () => widget.onMonthChanged(
              DateTime(widget.month.year, widget.month.month - 1),
            ),
            onNext: () => widget.onMonthChanged(
              DateTime(widget.month.year, widget.month.month + 1),
            ),
            onPick: _pickMonth,
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF635087), Color(0xFF8872AC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x33FFFFFF),
                child: Icon(Icons.work_outline, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${visible.length} ${visible.length == 1 ? 'turno' : 'turnos'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _allHistory
                          ? 'En todo el historial'
                          : 'En ${capitalize(formatMonth(widget.month))}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Generado',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    formatMoney(totalGenerated),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historial de turnos',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('${visible.length}'),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _ShiftEmptyState(onAdd: widget.onAdd)
        else
          ...visible.map(
            (shift) => _ShiftHistoryCard(
              shift: shift,
              dayOrders: widget.orders
                  .where((order) => order.day == shift.day)
                  .toList(),
              onEdit: () => widget.onEdit(shift),
              onDelete: () => widget.onDelete(shift),
            ),
          ),
      ],
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
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
      IconButton.filledTonal(
        tooltip: 'Mes anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_outlined, size: 19),
          label: Text(
            capitalize(formatMonth(month)),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Mes siguiente',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _ShiftHistoryCard extends StatelessWidget {
  const _ShiftHistoryCard({
    required this.shift,
    required this.dayOrders,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkShift shift;
  final List<PickerOrder> dayOrders;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final orderTotal = dayOrders.fold<int>(
      0,
      (total, order) => total + order.total,
    );
    final generated = generatedForDay(
      day: shift.day,
      orders: dayOrders,
      shifts: [shift],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 5, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFF0EAF7),
                    child: Icon(Icons.work_outline, color: Color(0xFF635087)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capitalize(formatDay(shift.day)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${shift.startTime} – ${shift.endTime}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              if (dayOrders.isNotEmpty)
                _ShiftAmountRow(
                  label: '${dayOrders.length} pedidos del día',
                  amount: orderTotal,
                ),
              if (shift.bonus > 0)
                _ShiftAmountRow(label: 'Bono por turno', amount: shift.bonus),
              _ShiftAmountRow(
                label: 'Generado en el turno',
                amount: generated,
                isTotal: true,
              ),
              if (shift.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    shift.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftAmountRow extends StatelessWidget {
  const _ShiftAmountRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });

  final String label;
  final int amount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          formatMoney(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ShiftEmptyState extends StatelessWidget {
  const _ShiftEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFFF0EAF7),
          child: Icon(Icons.work_outline, color: Color(0xFF635087)),
        ),
        const SizedBox(height: 12),
        Text(
          'Todavía no hay turnos',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          'Registra tus horarios para recordar cada día que trabajaste.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        FilledButton.tonal(
          onPressed: onAdd,
          child: const Text('Registrar primer turno'),
        ),
      ],
    ),
  );
}
