import 'package:flutter/material.dart';

import 'formatters.dart';
import 'models.dart';

const orderBonuses = [0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
const shiftBonuses = [
  0,
  1000,
  2000,
  3000,
  4000,
  5000,
  6000,
  7000,
  8000,
  9000,
  10000,
  11000,
  12000,
];

Future<String?> pickDay(BuildContext context, String initialDay) async {
  final initial = DateTime.parse(initialDay);
  final selected = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2015),
    lastDate: DateTime(2100),
    locale: const Locale('es'),
    helpText: 'Selecciona una fecha',
  );
  return selected == null ? null : dayKey(selected);
}

class OrderFormDialog extends StatefulWidget {
  const OrderFormDialog({super.key, this.order, required this.initialDay});

  final PickerOrder? order;
  final String initialDay;

  @override
  State<OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends State<OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _skuController;
  late final TextEditingController _notesController;
  late String _day;
  late int _bonus;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _codeController = TextEditingController(text: order?.code ?? '');
    _skuController = TextEditingController(
      text: order == null ? '' : '${order.skuCount}',
    );
    _notesController = TextEditingController(text: order?.notes ?? '');
    _day = order?.day ?? widget.initialDay;
    _bonus = order?.bonus ?? 0;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _skuController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  @override
  Widget build(BuildContext context) {
    final skuCount = int.tryParse(_skuController.text) ?? 0;
    final total =
        1300 + skuCount * skuRateForDay(DateTime.parse(_day)) + _bonus;
    return AlertDialog(
      title: Text(widget.order == null ? 'Agregar pedido' : 'Editar pedido'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DatePickerField(day: _day, onTap: _selectDate),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código del pedido (opcional)',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _skuController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Productos / SKU',
                    hintText: 'Ej.: 10',
                    prefixIcon: const Icon(Icons.shopping_basket_outlined),
                    helperText:
                        ' \$${skuRateForDay(DateTime.parse(_day))} por producto este día',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    if (count == null || count < 0) {
                      return 'Ingresa una cantidad igual o mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _bonus,
                  decoration: const InputDecoration(
                    labelText: 'Bono por pedido',
                    prefixIcon: Icon(Icons.stars_outlined),
                  ),
                  items: orderBonuses
                      .map(
                        (amount) => DropdownMenuItem(
                          value: amount,
                          child: Text(
                            amount == 0 ? 'Sin bono' : formatMoney(amount),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _bonus = value ?? 0),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                _TotalPreview(amount: total),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              PickerOrder(
                id: widget.order?.id,
                code: _codeController.text.trim(),
                day: _day,
                skuCount: int.parse(_skuController.text),
                bonus: _bonus,
                notes: _notesController.text.trim(),
              ),
            );
          },
          child: const Text('Guardar pedido'),
        ),
      ],
    );
  }
}

class ShiftFormDialog extends StatefulWidget {
  const ShiftFormDialog({super.key, this.shift, required this.initialDay});

  final WorkShift? shift;
  final String initialDay;

  @override
  State<ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<ShiftFormDialog> {
  late final TextEditingController _notesController;
  late String _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _bonus;

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    _day = shift?.day ?? widget.initialDay;
    _start = _parseTime(shift?.startTime ?? '09:00');
    _end = _parseTime(shift?.endTime ?? '18:00');
    _bonus = shift?.bonus ?? 0;
    _notesController = TextEditingController(text: shift?.notes ?? '');
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  Future<void> _selectTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Hora de entrada' : 'Hora de salida',
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.shift == null ? 'Registrar turno' : 'Editar turno'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DatePickerField(day: _day, onTap: _selectDate),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimePickerField(
                    label: 'Entrada',
                    value: _start.format(context),
                    onTap: () => _selectTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerField(
                    label: 'Salida',
                    value: _end.format(context),
                    onTap: () => _selectTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _bonus,
              decoration: const InputDecoration(
                labelText: 'Bono por turno',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
              items: shiftBonuses
                  .map(
                    (amount) => DropdownMenuItem(
                      value: amount,
                      child: Text(
                        amount == 0 ? 'Sin bono' : formatMoney(amount),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _bonus = value ?? 0),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          WorkShift(
            id: widget.shift?.id,
            day: _day,
            startTime: _formatTime(_start),
            endTime: _formatTime(_end),
            bonus: _bonus,
            notes: _notesController.text.trim(),
          ),
        ),
        child: const Text('Guardar turno'),
      ),
    ],
  );
}

const expenseCategories = ['Hogar', 'Comida', 'Transporte', 'Salud', 'Otros'];

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    this.expense,
    this.initialPaymentMethod = ExpensePaymentMethod.debit,
    required this.initialDay,
  });

  final ExpenseEntry? expense;
  final ExpensePaymentMethod initialPaymentMethod;
  final String initialDay;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _day;
  late String _category;
  late ExpensePaymentMethod _paymentMethod;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController = TextEditingController(text: expense?.title ?? '');
    _amountController = TextEditingController(
      text: expense == null ? '' : '${expense.amount}',
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _day = expense?.day ?? widget.initialDay;
    _category = expense?.category ?? expenseCategories.last;
    _paymentMethod = expense?.paymentMethod ?? widget.initialPaymentMethod;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.expense == null ? 'Registrar gasto' : 'Editar gasto'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: expenseCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? expenseCategories.last),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ExpensePaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: ExpensePaymentMethod.debit,
                    label: Text('Débito'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: ExpensePaymentMethod.credit,
                    label: Text('Crédito'),
                    icon: Icon(Icons.credit_card_outlined),
                  ),
                ],
                selected: {_paymentMethod},
                onSelectionChanged: (selection) =>
                    setState(() => _paymentMethod = selection.first),
              ),
              if (_paymentMethod == ExpensePaymentMethod.credit) ...[
                const SizedBox(height: 8),
                Text(
                  'Se incluirá en la siguiente facturación de la tarjeta.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿En qué gastaste?',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Escribe un nombre para el gasto'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto en pesos chilenos',
                  hintText: 'Ej.: 5000',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DatePickerField(day: _day, onTap: _selectDate),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            ExpenseEntry(
              id: widget.expense?.id,
              category: _category,
              title: _titleController.text.trim(),
              day: _day,
              amount: int.parse(_amountController.text),
              notes: _notesController.text.trim(),
              paymentMethod: _paymentMethod,
              cardBilled:
                  _paymentMethod == ExpensePaymentMethod.credit &&
                  (widget.expense?.cardBilled ?? false),
              cardBilledMonth: widget.expense?.cardBilledMonth,
            ),
          );
        },
        child: const Text('Guardar gasto'),
      ),
    ],
  );
}

class OtherIncomeFormDialog extends StatefulWidget {
  const OtherIncomeFormDialog({
    super.key,
    this.income,
    required this.initialDay,
  });

  final OtherIncomeEntry? income;
  final String initialDay;

  @override
  State<OtherIncomeFormDialog> createState() => _OtherIncomeFormDialogState();
}

class _OtherIncomeFormDialogState extends State<OtherIncomeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sourceController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _day;

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    _sourceController = TextEditingController(text: income?.source ?? '');
    _amountController = TextEditingController(
      text: income == null ? '' : '${income.amount}',
    );
    _notesController = TextEditingController(text: income?.notes ?? '');
    _day = income?.day ?? widget.initialDay;
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.income == null ? 'Agregar dinero' : 'Editar ingreso'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _sourceController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'De dónde viene',
                  hintText: 'Ej.: Sueldo de otro trabajo',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Escribe el origen del dinero'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto recibido (CLP)',
                  hintText: 'Ej.: 50000',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DatePickerField(day: _day, onTap: _selectDate),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            OtherIncomeEntry(
              id: widget.income?.id,
              source: _sourceController.text.trim(),
              day: _day,
              amount: int.parse(_amountController.text),
              notes: _notesController.text.trim(),
            ),
          );
        },
        child: const Text('Guardar ingreso'),
      ),
    ],
  );
}

class DebtFormDialog extends StatefulWidget {
  const DebtFormDialog({
    super.key,
    this.debt,
    this.initialType = DebtType.monthly,
    required this.initialDay,
  });

  final DebtEntry? debt;
  final DebtType initialType;
  final String initialDay;

  @override
  State<DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<DebtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _startDay;
  late DebtType _type;
  late int? _installmentCount;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _titleController = TextEditingController(text: debt?.title ?? '');
    _amountController = TextEditingController(
      text: debt == null ? '' : '${debt.amount}',
    );
    _notesController = TextEditingController(text: debt?.notes ?? '');
    _startDay = debt?.startDay ?? widget.initialDay;
    _type = debt?.type ?? widget.initialType;
    _installmentCount = debt?.installmentCount ?? 3;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _startDay);
    if (date != null) setState(() => _startDay = date);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.debt == null ? 'Agregar deuda' : 'Editar deuda'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<DebtType>(
                segments: const [
                  ButtonSegment(
                    value: DebtType.monthly,
                    label: Text('Mensual'),
                    icon: Icon(Icons.autorenew),
                  ),
                  ButtonSegment(
                    value: DebtType.installments,
                    label: Text('En cuotas'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre o motivo',
                  hintText: 'Ej.: Mamá, papá, tarjeta',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Escribe el nombre de la deuda'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == DebtType.monthly
                      ? 'Monto mensual (CLP)'
                      : 'Monto total de la deuda (CLP)',
                  hintText: 'Ej.: 200000',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto mayor a 0';
                  }
                  return null;
                },
              ),
              if (_type == DebtType.installments) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _installmentCount,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de cuotas',
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  items: [
                    if (_installmentCount != null &&
                        (_installmentCount! < 3 || _installmentCount! > 24))
                      DropdownMenuItem(
                        value: _installmentCount,
                        child: Text('${_installmentCount!} cuotas (actual)'),
                      ),
                    for (var count = 3; count <= 24; count++)
                      DropdownMenuItem(
                        value: count,
                        child: Text('$count cuotas'),
                      ),
                  ],
                  onChanged: (count) =>
                      setState(() => _installmentCount = count),
                  validator: (count) => count == null
                      ? 'Selecciona la cantidad de cuotas'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              _DatePickerField(day: _startDay, onTap: _selectDate),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Detalle o nota (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _type == DebtType.monthly
                    ? 'Se repetirá cada mes hasta que la marques como cerrada.'
                    : 'El monto se dividirá en cuotas mensuales. El saldo de pesos se agrega a la última cuota.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            DebtEntry(
              id: widget.debt?.id,
              title: _titleController.text.trim(),
              notes: _notesController.text.trim(),
              type: _type,
              amount: int.parse(_amountController.text),
              startDay: _startDay,
              installmentCount: _type == DebtType.installments
                  ? _installmentCount
                  : null,
              endMonth: widget.debt?.endMonth,
            ),
          );
        },
        child: const Text('Guardar deuda'),
      ),
    ],
  );
}

class NoteFormDialog extends StatefulWidget {
  const NoteFormDialog({super.key, this.note, required this.initialDay});

  final CalendarNote? note;
  final String initialDay;

  @override
  State<NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends State<NoteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _day;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _notesController = TextEditingController(text: widget.note?.notes ?? '');
    _day = widget.note?.day ?? widget.initialDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.note == null ? 'Agregar recordatorio' : 'Editar nota'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DatePickerField(day: _day, onTap: _selectDate),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                prefixIcon: Icon(Icons.event_note_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Escribe un título'
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalles (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            CalendarNote(
              id: widget.note?.id,
              day: _day,
              title: _titleController.text.trim(),
              notes: _notesController.text.trim(),
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

class CalendarEventFormDialog extends StatefulWidget {
  const CalendarEventFormDialog({
    super.key,
    this.event,
    required this.initialDay,
  });

  final CalendarEvent? event;
  final String initialDay;

  @override
  State<CalendarEventFormDialog> createState() =>
      _CalendarEventFormDialogState();
}

class _CalendarEventFormDialogState extends State<CalendarEventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _day;
  late TimeOfDay _startTime;
  late bool _notify;
  late int _reminderMinutes;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _day = event?.day ?? widget.initialDay;
    _startTime = event == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(event.startTime.split(':')[0]),
            minute: int.parse(event.startTime.split(':')[1]),
          );
    _notify = event?.notify ?? true;
    _reminderMinutes = event?.reminderMinutes ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await pickDay(context, _day);
    if (date != null) setState(() => _day = date);
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora de inicio',
    );
    if (time != null) setState(() => _startTime = time);
  }

  String get _formattedStartTime =>
      '${_startTime.hour.toString().padLeft(2, '0')}:'
      '${_startTime.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.event == null ? 'Nuevo evento' : 'Editar evento'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DatePickerField(day: _day, onTap: _selectDate),
              const SizedBox(height: 8),
              _TimePickerField(
                label: 'Inicio',
                value: _formattedStartTime,
                onTap: _selectStartTime,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Sesión de psicología',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Escribe un título'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Detalles del evento (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notificarme'),
                subtitle: const Text('Recibirás un aviso antes del evento'),
                value: _notify,
                onChanged: (value) => setState(() => _notify = value),
              ),
              if (_notify)
                DropdownButtonFormField<int>(
                  initialValue: _reminderMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Avisarme',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                  items: const [0, 10, 30, 60, 1440]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text(calendarReminderLabel(minutes)),
                        ),
                      )
                      .toList(),
                  onChanged: (minutes) => setState(
                    () => _reminderMinutes = minutes ?? _reminderMinutes,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            CalendarEvent(
              id: widget.event?.id,
              day: _day,
              startTime: _formattedStartTime,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              notify: _notify,
              reminderMinutes: _reminderMinutes,
            ),
          );
        },
        child: const Text('Guardar evento'),
      ),
    ],
  );
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.day, required this.onTap});

  final String day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(capitalize(formatDay(day))),
    ),
  );
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Total del pedido'),
        Text(
          formatMoney(amount),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
