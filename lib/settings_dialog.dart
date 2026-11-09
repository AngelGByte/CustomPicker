import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.settings});

  final AppThemeSettings settings;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _withholdingController;
  late bool _darkMode;
  late int _accentColor;
  late int _firstPayoutDay;
  late int _secondPayoutDay;
  late int _cardBillingDay;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.settings.darkMode;
    _accentColor = widget.settings.accentColor;
    _firstPayoutDay = widget.settings.firstPayoutDay;
    _secondPayoutDay = widget.settings.secondPayoutDay;
    _cardBillingDay = widget.settings.cardBillingDay;
    _withholdingController = TextEditingController(
      text: widget.settings.withholdingPercent.toString().replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _withholdingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajustes'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo oscuro'),
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
            ),
            const SizedBox(height: 8),
            Text(
              'Color principal',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: accentColorOptions.map((option) {
                final selected = _accentColor == option.value;
                return Tooltip(
                  message: option.name,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _accentColor = option.value),
                    child: Semantics(
                      label: option.name,
                      selected: selected,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(option.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _withholdingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Retención SII',
                hintText: '15,25',
                suffixText: '%',
                helperText: 'Porcentaje aplicado a tus ingresos generados',
              ),
              validator: (value) {
                final percentage = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                if (percentage == null) return 'Ingresa un porcentaje válido';
                if (percentage < 0 || percentage > 100) {
                  return 'Usa un valor entre 0 y 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Fechas de boleta y tarjeta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _firstPayoutDay,
                    decoration: const InputDecoration(labelText: 'Boleta 1'),
                    items: _dayOptions(),
                    onChanged: (day) => setState(() {
                      _firstPayoutDay = day ?? _firstPayoutDay;
                      _scheduleError = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _secondPayoutDay,
                    decoration: const InputDecoration(labelText: 'Boleta 2'),
                    items: _dayOptions(),
                    onChanged: (day) => setState(() {
                      _secondPayoutDay = day ?? _secondPayoutDay;
                      _scheduleError = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _cardBillingDay,
              decoration: const InputDecoration(
                labelText: 'Día de facturación de la tarjeta',
                helperText: 'Se cobra solo lo incluido en ese ciclo.',
              ),
              items: _dayOptions(),
              onChanged: (day) =>
                  setState(() => _cardBillingDay = day ?? _cardBillingDay),
            ),
            if (_scheduleError != null) ...[
              const SizedBox(height: 8),
              Text(
                _scheduleError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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
          if (_firstPayoutDay >= _secondPayoutDay) {
            setState(
              () => _scheduleError =
                  'La primera fecha de boleta debe ser anterior a la segunda.',
            );
            return;
          }
          Navigator.pop(
            context,
            AppThemeSettings(
              darkMode: _darkMode,
              accentColor: _accentColor,
              withholdingPercent: double.parse(
                _withholdingController.text.trim().replaceAll(',', '.'),
              ),
              firstPayoutDay: _firstPayoutDay,
              secondPayoutDay: _secondPayoutDay,
              cardBillingDay: _cardBillingDay,
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );

  List<DropdownMenuItem<int>> _dayOptions() => [
    for (var day = 1; day <= 28; day++)
      DropdownMenuItem(value: day, child: Text('$day')),
  ];
}
