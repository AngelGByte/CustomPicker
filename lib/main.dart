import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'app_database.dart';
import 'calendar_home_widget.dart';
import 'cloud_sync_service.dart';
import 'event_notifications.dart';
import 'firebase_options.dart';
import 'finance_tab.dart';
import 'formatters.dart';
import 'forms.dart';
import 'models.dart';
import 'settings_dialog.dart';
import 'shifts_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');
  await CalendarHomeWidget.configure();
  runApp(const PickerControlApp());
}

class PickerControlApp extends StatefulWidget {
  const PickerControlApp({super.key});

  @override
  State<PickerControlApp> createState() => _PickerControlAppState();
}

class _PickerControlAppState extends State<PickerControlApp> {
  AppThemeSettings _settings = AppThemeSettings.defaults;
  String? _settingsError;
  String? _profileName;
  User? _user;
  bool _guestSelected = false;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) setState(() => _user = user);
    });
    _loadSettings();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AppDatabase.instance.getAppSettings();
      final profileName = await AppDatabase.instance.getProfileName();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _profileName = profileName;
        _settingsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _settingsError = error.toString());
    }
  }

  Future<void> _saveSettings(AppThemeSettings settings) async {
    await AppDatabase.instance.saveAppSettings(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _showAccountDialog() async {
    final user = _user;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(user == null ? 'Vincular cuenta' : 'Cuenta vinculada'),
        content: Text(
          user == null
              ? 'Inicia sesión con Google para sincronizar MyPocket entre tus dispositivos.'
              : 'Los datos se sincronizan con ${user.email ?? 'tu cuenta de Google'} mientras la app está abierta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          if (user == null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _signInWithGoogle();
              },
              icon: const Icon(Icons.login),
              label: const Text('Continuar con Google'),
            )
          else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final credential = GoogleAuthProvider();
      final result = await FirebaseAuth.instance.signInWithProvider(credential);
      if (result.user?.emailVerified != true) {
        await FirebaseAuth.instance.signOut();
        _showAccountError(
          'Google no confirmó que el correo esté verificado. '
          'Prueba con una cuenta de Gmail existente.',
        );
      }
    } catch (error) {
      _showAccountError('No se pudo verificar e iniciar con Google: $error');
    }
  }

  Future<void> _saveName(String name) async {
    await AppDatabase.instance.saveProfileName(name);
    if (!mounted) return;
    setState(() {
      _profileName = name.trim();
      _guestSelected = true;
    });
  }

  void _showAccountError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_settings.accentColor);
    return MaterialApp(
      title: 'MyPocket',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(accent, Brightness.light),
      darkTheme: _buildTheme(accent, Brightness.dark),
      themeMode: _settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: _settingsError != null
          ? _SettingsLoadError(error: _settingsError!, onRetry: _loadSettings)
          : _profileName == null || _profileName!.trim().isEmpty
          ? _user != null || _guestSelected
                ? _NameSetupScreen(onSave: _saveName)
                : _WelcomeScreen(
                    onGuest: () => setState(() => _guestSelected = true),
                    onGoogle: _signInWithGoogle,
                  )
          : HomeShell(
              key: ValueKey(_user?.uid),
              settings: _settings,
              onSettingsChanged: _saveSettings,
              syncUserId: _user?.uid,
              onAccountPressed: _showAccountDialog,
              profileName: _profileName!,
            ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onGuest, required this.onGoogle});

  final VoidCallback onGuest;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/branding/mypocket_icon.png',
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bienvenida a MyPocket',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo quieres guardar tus finanzas.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onGoogle,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continuar con Gmail'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onGuest,
                  icon: const Icon(Icons.phone_android_outlined),
                  label: const Text('Continuar como invitado'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Google confirma que la cuenta existe. Como invitado, '
                  'tus datos permanecen solo en este dispositivo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NameSetupScreen extends StatefulWidget {
  const _NameSetupScreen({required this.onSave});

  final Future<void> Function(String) onSave;

  @override
  State<_NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<_NameSetupScreen> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(name);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el nombre. $error')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cómo te llamas?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Usaremos tu nombre para personalizar tu espacio.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Tu nombre',
                    hintText: 'Ej.: Angelica',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSaving ? null : _continue,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Empezar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

ThemeData _buildTheme(Color accent, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 76,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
  );
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            const Text('No se pudo cargar la configuración de MyPocket.'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.syncUserId,
    required this.onAccountPressed,
    required this.profileName,
  });

  final AppThemeSettings settings;
  final Future<void> Function(AppThemeSettings) onSettingsChanged;
  final String? syncUserId;
  final VoidCallback onAccountPressed;
  final String profileName;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  List<PickerOrder> _orders = [];
  List<WorkShift> _shifts = [];
  List<ExpenseEntry> _expenses = [];
  List<OtherIncomeEntry> _otherIncomes = [];
  List<DebtEntry> _debts = [];
  Map<String, int> _debtPaymentAmounts = {};
  Map<String, String> _debtDueDays = {};
  int _walletBalance = 0;
  List<OrderPayout> _orderPayouts = [];
  List<CalendarNote> _notes = [];
  List<CalendarEvent> _calendarEvents = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isSyncing = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _refresh(showLoading: true).then((refreshed) {
      if (refreshed && widget.syncUserId != null) {
        _syncCloud(scheduleEventNotifications: true)
            .then((_) => _listenForRemoteChanges());
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncUserId != widget.syncUserId &&
        widget.syncUserId != null) {
      _syncCloud();
    }
  }

  Future<bool> _refresh({bool showLoading = false}) async {
    if (mounted && showLoading) setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final orders = await db.getOrders();
      final shifts = await db.getShifts();
      final expenses = await db.getExpenses();
      final otherIncomes = await db.getOtherIncomes();
      final debts = await db.getDebts();
      final debtPaymentAmounts = await db.getDebtPaymentAmounts();
      final debtDueDays = await db.getDebtDueDays();
      final walletBalance = await db.getCurrentWalletBalance();
      final orderPayouts = await db.getOrderPayouts();
      final notes = await db.getNotes();
      final calendarEvents = await db.getCalendarEvents();
      if (!mounted) return false;
      setState(() {
        _orders = orders;
        _shifts = shifts;
        _expenses = expenses;
        _otherIncomes = otherIncomes;
        _debts = debts;
        _debtPaymentAmounts = debtPaymentAmounts;
        _debtDueDays = debtDueDays;
        _walletBalance = walletBalance;
        _orderPayouts = orderPayouts;
        _notes = notes;
        _calendarEvents = calendarEvents;
        _loadError = null;
        _isLoading = false;
      });
      try {
        await CalendarHomeWidget.update(calendarEvents);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Calendario guardado, pero no se pudo actualizar el widget. $error',
                ),
              ),
            );
        }
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
      return false;
    }
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      final refreshed = await _refresh();
      if (refreshed && widget.syncUserId != null) {
        try {
          await CloudSyncService.instance.sync(widget.syncUserId!);
          await _refresh();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Guardado en este dispositivo; sincronización pendiente. $error',
                  ),
                ),
              );
          }
        }
      }
      if (mounted && refreshed && successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar. $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  void _listenForRemoteChanges() {
    final userId = widget.syncUserId;
    if (userId == null || !mounted) return;
    _syncSubscription?.cancel();
    _syncSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('records')
        .snapshots()
        .listen(
          (snapshot) => _syncCloud(
            scheduleEventNotifications: snapshot.docChanges.any(
              (change) => change.doc.data()?['table'] == 'calendar_events',
            ),
          ),
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Se perdió la conexión de sincronización: $error',
                ),
              ),
            );
          },
        );
  }

  Future<void> _syncCloud({bool scheduleEventNotifications = false}) async {
    final userId = widget.syncUserId;
    if (userId == null || _isSyncing) return;
    _isSyncing = true;
    try {
      await CloudSyncService.instance.sync(userId);
      await _refresh();
      if (scheduleEventNotifications) {
        final events = await AppDatabase.instance.getCalendarEvents();
        for (final event in events.where((event) => event.notify)) {
          await EventNotificationService.instance.scheduleEvent(event);
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo sincronizar con la nube. $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _addOrEditOrder({PickerOrder? order, String? day}) async {
    final result = await showDialog<PickerOrder>(
      context: context,
      builder: (context) => OrderFormDialog(
        order: order,
        initialDay: day ?? dayKey(_selectedDay),
      ),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveOrder(result),
        successMessage: order == null
            ? 'Pedido guardado'
            : 'Pedido actualizado',
      );
    }
  }

  Future<void> _addOrEditShift({WorkShift? shift, String? day}) async {
    final initialDay = shift?.day ?? day ?? dayKey(_selectedDay);
    final existing =
        shift ??
        _shifts.cast<WorkShift?>().firstWhere(
          (item) => item?.day == initialDay,
          orElse: () => null,
        );
    final result = await showDialog<WorkShift>(
      context: context,
      builder: (context) =>
          ShiftFormDialog(shift: existing, initialDay: initialDay),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveShift(result),
        successMessage: existing == null
            ? 'Turno guardado'
            : 'Turno actualizado',
      );
    }
  }

  Future<void> _addOrEditExpense({
    ExpenseEntry? expense,
    String? day,
    ExpensePaymentMethod initialPaymentMethod = ExpensePaymentMethod.debit,
  }) async {
    final result = await showDialog<ExpenseEntry>(
      context: context,
      builder: (context) => ExpenseFormDialog(
        expense: expense,
        initialPaymentMethod: initialPaymentMethod,
        initialDay: day ?? dayKey(_selectedDay),
      ),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveExpense(result),
        successMessage: expense == null
            ? 'Gasto guardado'
            : 'Gasto actualizado',
      );
    }
  }

  Future<void> _addOrEditDebt({
    DebtEntry? debt,
    DebtType initialType = DebtType.monthly,
  }) async {
    final result = await showDialog<DebtEntry>(
      context: context,
      builder: (context) => DebtFormDialog(
        debt: debt,
        initialType: initialType,
        initialDay: dayKey(_selectedDay),
      ),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveDebt(result),
        successMessage: debt == null ? 'Deuda guardada' : 'Deuda actualizada',
      );
    }
  }

  Future<void> _addOrEditOtherIncome({OtherIncomeEntry? income}) async {
    final result = await showDialog<OtherIncomeEntry>(
      context: context,
      builder: (context) => OtherIncomeFormDialog(
        income: income,
        initialDay: dayKey(_selectedDay),
      ),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveOtherIncome(result),
        successMessage: income == null
            ? 'Ingreso agregado al saldo'
            : 'Ingreso actualizado',
      );
    }
  }

  Future<void> _toggleDebtPaid(DebtOccurrence occurrence) => _mutate(
    () => AppDatabase.instance.setDebtPaid(
      debtId: occurrence.debt.id!,
      month: occurrence.month,
      isPaid: !occurrence.isPaid,
      day: occurrence.dueDay,
      amount: occurrence.amount,
    ),
    successMessage: occurrence.isPaid
        ? 'Cuota marcada como pendiente'
        : 'Cuota marcada como pagada',
  );

  Future<void> _setDebtDueDay(DebtOccurrence occurrence) async {
    final year = int.parse(occurrence.month.substring(0, 4));
    final month = int.parse(occurrence.month.substring(5, 7));
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(occurrence.dueDay),
      firstDate: DateTime(year, month),
      lastDate: DateTime(year, month + 1, 0),
      locale: const Locale('es'),
      helpText: 'Elige el vencimiento de este mes',
    );
    if (selected == null) return;
    await _mutate(
      () => AppDatabase.instance.setDebtDueDay(
        debtId: occurrence.debt.id!,
        month: occurrence.month,
        dueDay: dayKey(selected),
      ),
      successMessage: 'Fecha de cobro actualizada para este mes',
    );
  }

  Future<void> _receivePayout(PendingPayout payout) => _mutate(
    () => AppDatabase.instance.recordOrderPayout(
      OrderPayout(
        dueDay: payout.dueDay,
        grossAmount: payout.grossAmount,
        netAmount: payout.netAmount(widget.settings.withholdingPercent),
        receivedDay: dayKey(DateTime.now()),
      ),
    ),
    successMessage: 'Pago recibido agregado a tu dinero actual',
  );

  Future<void> _billCardForMonth(DateTime month) async {
    await _mutate(() async {
      await AppDatabase.instance.billCardCycle(
        month: monthKey(month),
        billingDay: widget.settings.cardBillingDay,
      );
    }, successMessage: 'Facturación de tarjeta registrada');
  }

  Future<void> _toggleDebtClosed(DebtEntry debt) async {
    final updated = DebtEntry(
      id: debt.id,
      title: debt.title,
      notes: debt.notes,
      type: debt.type,
      amount: debt.amount,
      startDay: debt.startDay,
      installmentCount: debt.installmentCount,
      endMonth: debt.isActive ? monthKey(DateTime.now()) : null,
    );
    await _mutate(
      () => AppDatabase.instance.saveDebt(updated),
      successMessage: debt.isActive ? 'Deuda cerrada' : 'Deuda reactivada',
    );
  }

  Future<void> _addOrEditNote({CalendarNote? note, String? day}) async {
    final result = await showDialog<CalendarNote>(
      context: context,
      builder: (context) =>
          NoteFormDialog(note: note, initialDay: day ?? dayKey(_selectedDay)),
    );
    if (result != null) {
      await _mutate(
        () => AppDatabase.instance.saveNote(result),
        successMessage: note == null
            ? 'Recordatorio guardado'
            : 'Nota actualizada',
      );
    }
  }

  Future<void> _addOrEditCalendarEvent({
    CalendarEvent? event,
    String? day,
  }) async {
    final result = await showDialog<CalendarEvent>(
      context: context,
      builder: (context) => CalendarEventFormDialog(
        event: event,
        initialDay: day ?? dayKey(_selectedDay),
      ),
    );
    if (result == null) return;

    try {
      final saved = await AppDatabase.instance.saveCalendarEvent(result);
      var message = event == null ? 'Evento guardado' : 'Evento actualizado';
      try {
        final scheduled = await EventNotificationService.instance.scheduleEvent(
          saved,
        );
        if (!scheduled && saved.notify) {
          message =
              'Evento guardado, pero no se pudo activar el aviso. '
              'Revisa el permiso de notificaciones y la fecha.';
        }
      } catch (error) {
        message = 'Evento guardado, pero no se pudo programar el aviso: $error';
      }

      if (widget.syncUserId != null) {
        try {
          await CloudSyncService.instance.sync(widget.syncUserId!);
        } catch (error) {
          message = '$message. Sincronización pendiente: $error';
        }
      }
      final refreshed = await _refresh();
      if (mounted && refreshed) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el evento. $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  Future<void> _deleteItem({
    required String label,
    required Future<void> Function() delete,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text('Se eliminará $label. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _mutate(delete, successMessage: 'Registro eliminado');
    }
  }

  Future<void> _showAddMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.work_outline,
                title: 'Turno trabajado',
                subtitle: 'Horario de entrada, salida y bono',
                onTap: () => Navigator.pop(context, 'shift'),
              ),
              _ActionTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Gasto',
                subtitle: 'Registra una compra o gasto puntual',
                onTap: () => Navigator.pop(context, 'expense'),
              ),
              _ActionTile(
                icon: Icons.add_card_outlined,
                title: 'Dinero recibido',
                subtitle: 'Agrega un sueldo u otro ingreso',
                onTap: () => Navigator.pop(context, 'income'),
              ),
              _ActionTile(
                icon: Icons.event_note_outlined,
                title: 'Recordatorio',
                subtitle: 'Una fecha importante o una nota',
                onTap: () => Navigator.pop(context, 'note'),
              ),
              _ActionTile(
                icon: Icons.event_available_outlined,
                title: 'Evento con horario',
                subtitle: 'Citas, sesiones y aviso al inicio',
                onTap: () => Navigator.pop(context, 'event'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'shift':
        await _addOrEditShift();
        break;
      case 'expense':
        await _addOrEditExpense();
        break;
      case 'income':
        await _addOrEditOtherIncome();
        break;
      case 'note':
        await _addOrEditNote();
        break;
      case 'event':
        await _addOrEditCalendarEvent();
        break;
    }
  }

  Future<void> _showFinanceAddMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Gasto',
                subtitle: 'Una compra o gasto puntual',
                onTap: () => Navigator.pop(context, 'expense'),
              ),
              _ActionTile(
                icon: Icons.add_card_outlined,
                title: 'Dinero recibido',
                subtitle: 'Agrega un sueldo u otro ingreso',
                onTap: () => Navigator.pop(context, 'income'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'expense') await _addOrEditExpense();
    if (action == 'income') await _addOrEditOtherIncome();
  }

  Future<void> _openSettings() async {
    final settings = await showDialog<AppThemeSettings>(
      context: context,
      builder: (context) => SettingsDialog(settings: widget.settings),
    );
    if (settings == null) return;
    try {
      await widget.onSettingsChanged(settings);
      if (widget.syncUserId != null) await _syncCloud();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudieron guardar los ajustes. $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'MyPocket',
      'Mis pedidos',
      'Mis turnos',
      'Mi calendario',
      'Finanzas',
      'Mis deudas',
    ];
    final subtitles = [
      'Finanzas de ${widget.profileName}',
      'Tu historial de pedidos',
      'Tus días trabajados',
      'Fechas importantes',
      'Gastos e ingresos',
      'Pagos y compromisos',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_tabIndex],
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            Text(
              subtitles[_tabIndex],
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_tabIndex == 3)
            IconButton(
              tooltip: 'Ir a hoy',
              onPressed: () {
                final today = DateUtils.dateOnly(DateTime.now());
                setState(() => _selectedDay = today);
              },
              icon: const Icon(Icons.today_outlined),
            ),
          IconButton(
            tooltip: 'Cuenta y sincronización',
            onPressed: widget.onAccountPressed,
            icon: Icon(
              widget.syncUserId == null
                  ? Icons.account_circle_outlined
                  : Icons.cloud_done_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadErrorView(
              error: _loadError!,
              onRetry: () => _refresh(showLoading: true),
            )
          : IndexedStack(
              index: _tabIndex,
              children: [
                DashboardTab(
                  month: _selectedMonth,
                  orders: _orders,
                  shifts: _shifts,
                  withholdingPercent: widget.settings.withholdingPercent,
                  expenses: _expenses,
                  otherIncomes: _otherIncomes,
                  debts: _debts,
                  debtPaymentAmounts: _debtPaymentAmounts,
                  debtDueDays: _debtDueDays,
                  walletBalance: _walletBalance,
                  orderPayouts: _orderPayouts,
                  firstPayoutDay: widget.settings.firstPayoutDay,
                  secondPayoutDay: widget.settings.secondPayoutDay,
                  cardBillingDay: widget.settings.cardBillingDay,
                  onMonthChanged: (month) =>
                      setState(() => _selectedMonth = month),
                  onEditOrder: (order) => _addOrEditOrder(order: order),
                  onAddOtherIncome: () => _addOrEditOtherIncome(),
                  onViewOrders: () => setState(() => _tabIndex = 1),
                  onReceivePayout: _receivePayout,
                  onBillCard: _billCardForMonth,
                ),
                OrdersTab(
                  month: _selectedMonth,
                  orders: _orders,
                  onMonthChanged: (month) =>
                      setState(() => _selectedMonth = month),
                  onAdd: () => _addOrEditOrder(),
                  onEdit: (order) => _addOrEditOrder(order: order),
                  onDelete: (order) => _deleteItem(
                    label: 'el pedido ${order.code.isEmpty ? '' : order.code}',
                    delete: () => AppDatabase.instance.deleteOrder(order.id!),
                  ),
                ),
                ShiftsTab(
                  month: _selectedMonth,
                  shifts: _shifts,
                  orders: _orders,
                  onMonthChanged: (month) =>
                      setState(() => _selectedMonth = month),
                  onAdd: () => _addOrEditShift(),
                  onEdit: (shift) => _addOrEditShift(shift: shift),
                  onDelete: (shift) => _deleteItem(
                    label: 'el turno',
                    delete: () => AppDatabase.instance.deleteShift(shift.id!),
                  ),
                ),
                CalendarTab(
                  selectedDay: _selectedDay,
                  orders: _orders,
                  shifts: _shifts,
                  expenses: _expenses,
                  otherIncomes: _otherIncomes,
                  debts: _debts,
                  debtPaymentAmounts: _debtPaymentAmounts,
                  debtDueDays: _debtDueDays,
                  notes: _notes,
                  calendarEvents: _calendarEvents,
                  onDaySelected: (date) => setState(() => _selectedDay = date),
                  onAdd: _showAddMenu,
                  onEditOrder: (order) => _addOrEditOrder(order: order),
                  onDeleteOrder: (order) => _deleteItem(
                    label: 'el pedido ${order.code.isEmpty ? '' : order.code}',
                    delete: () => AppDatabase.instance.deleteOrder(order.id!),
                  ),
                  onEditShift: (shift) => _addOrEditShift(shift: shift),
                  onDeleteShift: (shift) => _deleteItem(
                    label: 'el turno',
                    delete: () => AppDatabase.instance.deleteShift(shift.id!),
                  ),
                  onEditExpense: (expense) =>
                      _addOrEditExpense(expense: expense),
                  onDeleteExpense: (expense) => _deleteItem(
                    label: 'el gasto ${expense.title}',
                    delete: () =>
                        AppDatabase.instance.deleteExpense(expense.id!),
                  ),
                  onEditOtherIncome: (income) =>
                      _addOrEditOtherIncome(income: income),
                  onDeleteOtherIncome: (income) => _deleteItem(
                    label: 'el ingreso ${income.source}',
                    delete: () =>
                        AppDatabase.instance.deleteOtherIncome(income.id!),
                  ),
                  onToggleDebtPaid: _toggleDebtPaid,
                  onEditNote: (note) => _addOrEditNote(note: note),
                  onDeleteNote: (note) => _deleteItem(
                    label: 'el recordatorio ${note.title}',
                    delete: () => AppDatabase.instance.deleteNote(note.id!),
                  ),
                  onAddCalendarEvent: () => _addOrEditCalendarEvent(),
                  onEditCalendarEvent: (event) =>
                      _addOrEditCalendarEvent(event: event),
                  onDeleteCalendarEvent: (event) => _deleteItem(
                    label: 'el evento ${event.title}',
                    delete: () async {
                      await EventNotificationService.instance.cancelEvent(
                        event.id!,
                      );
                      await AppDatabase.instance.deleteCalendarEvent(event.id!);
                    },
                  ),
                ),
                FinanceTab(
                  month: _selectedMonth,
                  expenses: _expenses,
                  otherIncomes: _otherIncomes,
                  onMonthChanged: (month) =>
                      setState(() => _selectedMonth = month),
                  onAddExpense: () => _addOrEditExpense(),
                  onEditExpense: (expense) =>
                      _addOrEditExpense(expense: expense),
                  onDeleteExpense: (expense) => _deleteItem(
                    label: 'el gasto ${expense.title}',
                    delete: () =>
                        AppDatabase.instance.deleteExpense(expense.id!),
                  ),
                  onAddOtherIncome: () => _addOrEditOtherIncome(),
                  onEditOtherIncome: (income) =>
                      _addOrEditOtherIncome(income: income),
                  onDeleteOtherIncome: (income) => _deleteItem(
                    label: 'el ingreso ${income.source}',
                    delete: () =>
                        AppDatabase.instance.deleteOtherIncome(income.id!),
                  ),
                ),
                DebtsTab(
                  month: _selectedMonth,
                  debts: _debts,
                  expenses: _expenses,
                  cardBillingDay: widget.settings.cardBillingDay,
                  debtPaymentAmounts: _debtPaymentAmounts,
                  debtDueDays: _debtDueDays,
                  onMonthChanged: (month) =>
                      setState(() => _selectedMonth = month),
                  onAddDebt: (type) => _addOrEditDebt(initialType: type),
                  onEditDebt: (debt) => _addOrEditDebt(debt: debt),
                  onDeleteDebt: (debt) => _deleteItem(
                    label: 'la deuda ${debt.title}',
                    delete: () => AppDatabase.instance.deleteDebt(debt.id!),
                  ),
                  onSetDebtPaid: _toggleDebtPaid,
                  onSetDebtDueDay: _setDebtDueDay,
                  onBillCard: _billCardForMonth,
                  onCloseDebt: _toggleDebtClosed,
                ),
              ],
            ),
      floatingActionButton: _isLoading || _loadError != null || _tabIndex == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: switch (_tabIndex) {
                1 => _addOrEditOrder,
                2 => _addOrEditShift,
                3 => _showAddMenu,
                4 => _showFinanceAddMenu,
                _ => _addOrEditDebt,
              },
              icon: Icon(switch (_tabIndex) {
                2 => Icons.work_outline,
                3 || 4 || 5 => Icons.add,
                _ => Icons.receipt_long_outlined,
              }),
              label: Text(switch (_tabIndex) {
                2 => 'Nuevo turno',
                3 || 4 || 5 => 'Agregar',
                _ => 'Nuevo pedido',
              }),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (_tabIndex) {
          3 => 5,
          4 => 3,
          5 => 4,
          _ => _tabIndex,
        },
        onDestinationSelected: (index) => setState(
          () => _tabIndex = switch (index) {
            3 => 4,
            4 => 5,
            5 => 3,
            _ => index,
          },
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Turnos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finanzas',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Deudas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.month,
    required this.orders,
    required this.shifts,
    required this.withholdingPercent,
    required this.expenses,
    required this.otherIncomes,
    required this.debts,
    required this.debtPaymentAmounts,
    required this.debtDueDays,
    required this.walletBalance,
    required this.orderPayouts,
    required this.firstPayoutDay,
    required this.secondPayoutDay,
    required this.cardBillingDay,
    required this.onMonthChanged,
    required this.onEditOrder,
    required this.onAddOtherIncome,
    required this.onViewOrders,
    required this.onReceivePayout,
    required this.onBillCard,
  });

  final DateTime month;
  final List<PickerOrder> orders;
  final List<WorkShift> shifts;
  final double withholdingPercent;
  final List<ExpenseEntry> expenses;
  final List<OtherIncomeEntry> otherIncomes;
  final List<DebtEntry> debts;
  final Map<String, int> debtPaymentAmounts;
  final Map<String, String> debtDueDays;
  final int walletBalance;
  final List<OrderPayout> orderPayouts;
  final int firstPayoutDay;
  final int secondPayoutDay;
  final int cardBillingDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<PickerOrder> onEditOrder;
  final VoidCallback onAddOtherIncome;
  final VoidCallback onViewOrders;
  final ValueChanged<PendingPayout> onReceivePayout;
  final ValueChanged<DateTime> onBillCard;

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
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    final monthOrders = orders.where((item) => item.day.startsWith(monthKey));
    final monthShifts = shifts.where((item) => item.day.startsWith(monthKey));
    final monthExpenses = expenses.where(
      (item) => item.day.startsWith(monthKey),
    );
    final monthOtherIncomes = otherIncomes.where(
      (item) => item.day.startsWith(monthKey),
    );
    final monthDebtOccurrences = debtOccurrencesForMonth(
      debts,
      month,
      paidAmountsByStatusKey: debtPaymentAmounts,
      dueDaysByStatusKey: debtDueDays,
    );
    final pendingPayouts = pendingOrderPayouts(
      orders: orders,
      shifts: shifts,
      received: orderPayouts,
      throughDate: DateTime.now(),
      firstPayoutDay: firstPayoutDay,
      secondPayoutDay: secondPayoutDay,
    );
    final orderEarnings = monthOrders.fold<int>(
      0,
      (total, item) => total + item.total,
    );
    final shiftEarnings = monthShifts.fold<int>(
      0,
      (total, item) => total + item.bonus,
    );
    final generated = orderEarnings + shiftEarnings;
    final withholding = calculateSiiWithholding(generated, withholdingPercent);
    final netGenerated = generated - withholding;
    final expenseTotal = monthExpenses.fold<int>(
      0,
      (total, item) => total + item.amount,
    );
    final otherIncomeTotal = monthOtherIncomes.fold<int>(
      0,
      (total, item) => total + item.amount,
    );
    final currentMoney = walletBalance;
    final pendingOccurrences = monthDebtOccurrences
        .where((occurrence) => !occurrence.isPaid)
        .toList();
    final monthlyPaymentsDue = pendingOccurrences
        .where((occurrence) => occurrence.debt.type == DebtType.monthly)
        .fold<int>(0, (total, occurrence) => total + occurrence.amount);
    final installmentsDue = pendingOccurrences
        .where((occurrence) => occurrence.debt.type == DebtType.installments)
        .fold<int>(0, (total, occurrence) => total + occurrence.amount);
    final creditExpensesDue = expenses
        .where(
          (expense) =>
              expense.paymentMethod == ExpensePaymentMethod.credit &&
              !expense.cardBilled &&
              cardExpenseBillingMonth(
                    day: expense.day,
                    billingDay: cardBillingDay,
                  ) <=
                  month.year * 100 + month.month,
        )
        .fold<int>(0, (total, expense) => total + expense.amount);
    final outstandingDebt =
        totalOutstandingDebtAmount(
          debts: debts,
          throughMonth: DateTime.now(),
          paidAmountsByStatusKey: debtPaymentAmounts,
        ) +
        expenses
            .where(
              (expense) =>
                  expense.paymentMethod == ExpensePaymentMethod.credit &&
                  !expense.cardBilled,
            )
            .fold<int>(0, (total, expense) => total + expense.amount);
    final recentOrders = monthOrders.toList()
      ..sort((a, b) => b.day.compareTo(a.day));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _MonthPicker(
          month: month,
          onPrevious: () =>
              onMonthChanged(DateTime(month.year, month.month - 1)),
          onNext: () => onMonthChanged(DateTime(month.year, month.month + 1)),
          onPick: () => _pickMonth(context),
        ),
        const SizedBox(height: 18),
        _EarningsCard(
          total: generated,
          withholding: withholding,
          netTotal: netGenerated,
          ordersCount: monthOrders.length,
          workDays: monthShifts.length,
          orderEarnings: orderEarnings,
          shiftEarnings: shiftEarnings,
        ),
        const SizedBox(height: 20),
        _WalletSummaryCard(
          balance: currentMoney,
          outstandingDebt: outstandingDebt,
          onAddIncome: onAddOtherIncome,
        ),
        if (pendingPayouts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Boletas por cobrar',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...pendingPayouts.map(
            (payout) => Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('Boleta del ${formatShortDay(payout.dueDay)}'),
                subtitle: Text(
                  'Bruto ${formatMoney(payout.grossAmount)} · '
                  'Neto estimado ${formatMoney(payout.netAmount(withholdingPercent))}',
                ),
                trailing: IconButton(
                  tooltip: 'Pago recibido',
                  onPressed: () => onReceivePayout(payout),
                  icon: const Icon(Icons.check_circle_outline),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => onBillCard(month),
          icon: const Icon(Icons.credit_score_outlined),
          label: const Text('Facturación realizada'),
        ),
        const SizedBox(height: 20),
        Text('Resumen del mes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Gastos del mes',
                    amount: expenseTotal,
                    tint: const Color(0xFFFFF1D9),
                    iconColor: const Color(0xFF956000),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.credit_card_outlined,
                    label: 'Tarjeta de crédito',
                    amount: installmentsDue + creditExpensesDue,
                    tint: Theme.of(context).colorScheme.primaryContainer,
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _MetricCard(
              icon: Icons.event_repeat_outlined,
              label: 'Pago del mes',
              amount: monthlyPaymentsDue,
              tint: const Color(0xFFEAF0FA),
              iconColor: const Color(0xFF5279B8),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cálculo del mes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _BreakdownRow(
          icon: Icons.receipt_long_outlined,
          label: 'Pedidos registrados',
          value: '${monthOrders.length}',
        ),
        _BreakdownRow(
          icon: Icons.shopping_basket_outlined,
          label: 'Ganancia por pedidos',
          value: formatMoney(orderEarnings),
        ),
        _BreakdownRow(
          icon: Icons.workspace_premium_outlined,
          label: 'Bonos por turno',
          value: formatMoney(shiftEarnings),
        ),
        _BreakdownRow(
          icon: Icons.percent,
          label:
              'Retención SII estimada '
              '(${withholdingPercent.toStringAsFixed(2).replaceAll('.', ',')}%)',
          value: '-${formatMoney(withholding)}',
        ),
        _BreakdownRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Generado después de retención',
          value: formatMoney(netGenerated),
        ),
        _BreakdownRow(
          icon: Icons.add_card_outlined,
          label: 'Otros ingresos del mes',
          value: formatMoney(otherIncomeTotal),
        ),
        if (recentOrders.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedidos recientes',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: onViewOrders,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recentOrders
              .take(3)
              .map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        order.code.isEmpty ? 'Pedido' : order.code,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${capitalize(formatShortDay(order.day))} · '
                        '${order.skuCount} productos',
                      ),
                      trailing: Text(
                        formatMoney(order.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => onEditOrder(order),
                    ),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 18),
        Text(
          'Tus datos se guardan en este dispositivo y el historial mensual se conserva.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({
    super.key,
    required this.month,
    required this.orders,
    required this.onMonthChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime month;
  final List<PickerOrder> orders;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onAdd;
  final ValueChanged<PickerOrder> onEdit;
  final ValueChanged<PickerOrder> onDelete;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _query = '';
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
    final filtered = widget.orders
        .where((order) => _allHistory || order.day.startsWith(monthKey))
        .where(
          (order) =>
              _query.isEmpty ||
              order.code.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final monthTotal = filtered.fold<int>(
      0,
      (total, order) => total + order.total,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Este mes')),
            ButtonSegment(value: true, label: Text('Todo el historial')),
          ],
          selected: {_allHistory},
          onSelectionChanged: (value) =>
              setState(() => _allHistory = value.first),
        ),
        if (!_allHistory) const SizedBox(height: 8),
        if (!_allHistory)
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${filtered.length} pedidos'),
                  const SizedBox(height: 4),
                  Text(
                    _allHistory ? 'Ganancia total' : 'Ganancia del mes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Text(
                formatMoney(monthTotal),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar por código de pedido',
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: _query.isNotEmpty
                ? 'No encontramos ese pedido'
                : 'Todavía no hay pedidos',
            message: _query.isNotEmpty ? 'Prueba con otro código.' : 'Agrega tu primer pedido para empezar a calcular tus ganancias.',
            actionLabel: _query.isEmpty ? 'Agregar pedido' : null,
            onAction: widget.onAdd,
          )
        else
          ...filtered.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OrderCard(
                order: order,
                onEdit: () => widget.onEdit(order),
                onDelete: () => widget.onDelete(order),
              ),
            ),
          ),
      ],
    );
  }
}

class CalendarTab extends StatelessWidget {
  const CalendarTab({
    super.key,
    required this.selectedDay,
    required this.orders,
    required this.shifts,
    required this.expenses,
    required this.otherIncomes,
    required this.debts,
    required this.debtPaymentAmounts,
    required this.debtDueDays,
    required this.notes,
    required this.calendarEvents,
    required this.onDaySelected,
    required this.onAdd,
    required this.onEditOrder,
    required this.onDeleteOrder,
    required this.onEditShift,
    required this.onDeleteShift,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onEditOtherIncome,
    required this.onDeleteOtherIncome,
    required this.onToggleDebtPaid,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onAddCalendarEvent,
    required this.onEditCalendarEvent,
    required this.onDeleteCalendarEvent,
  });

  final DateTime selectedDay;
  final List<PickerOrder> orders;
  final List<WorkShift> shifts;
  final List<ExpenseEntry> expenses;
  final List<OtherIncomeEntry> otherIncomes;
  final List<DebtEntry> debts;
  final Map<String, int> debtPaymentAmounts;
  final Map<String, String> debtDueDays;
  final List<CalendarNote> notes;
  final List<CalendarEvent> calendarEvents;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onAdd;
  final ValueChanged<PickerOrder> onEditOrder;
  final ValueChanged<PickerOrder> onDeleteOrder;
  final ValueChanged<WorkShift> onEditShift;
  final ValueChanged<WorkShift> onDeleteShift;
  final ValueChanged<ExpenseEntry> onEditExpense;
  final ValueChanged<ExpenseEntry> onDeleteExpense;
  final ValueChanged<OtherIncomeEntry> onEditOtherIncome;
  final ValueChanged<OtherIncomeEntry> onDeleteOtherIncome;
  final ValueChanged<DebtOccurrence> onToggleDebtPaid;
  final ValueChanged<CalendarNote> onEditNote;
  final ValueChanged<CalendarNote> onDeleteNote;
  final VoidCallback onAddCalendarEvent;
  final ValueChanged<CalendarEvent> onEditCalendarEvent;
  final ValueChanged<CalendarEvent> onDeleteCalendarEvent;

  List<CalendarMarker> _eventsForDay(DateTime date) {
    final key = dayKey(date);
    return [
      if (orders.any((item) => item.day == key)) CalendarMarker.order,
      if (shifts.any((item) => item.day == key)) CalendarMarker.shift,
      if (expenses.any((item) => item.day == key)) CalendarMarker.expense,
      if (otherIncomes.any((item) => item.day == key)) CalendarMarker.income,
      if (debtOccurrencesForMonth(
        debts,
        date,
        paidAmountsByStatusKey: debtPaymentAmounts,
        dueDaysByStatusKey: debtDueDays,
      ).any((item) => item.dueDay == key))
        CalendarMarker.debt,
      if (notes.any((item) => item.day == key)) CalendarMarker.note,
      if (calendarEvents.any((item) => item.day == key))
        CalendarMarker.appointment,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final key = dayKey(selectedDay);
    final dayOrders = orders.where((item) => item.day == key).toList();
    final dayShifts = shifts.where((item) => item.day == key).toList();
    final dayExpenses = expenses.where((item) => item.day == key).toList();
    final dayOtherIncomes = otherIncomes
        .where((item) => item.day == key)
        .toList();
    final dayDebtOccurrences = debtOccurrencesForMonth(
      debts,
      selectedDay,
      paidAmountsByStatusKey: debtPaymentAmounts,
      dueDaysByStatusKey: debtDueDays,
    ).where((item) => item.dueDay == key).toList();
    final dayNotes = notes.where((item) => item.day == key).toList();
    final dayCalendarEvents =
        calendarEvents.where((item) => item.day == key).toList()..sort(
          (first, second) => first.startTime.compareTo(second.startTime),
        );
    final dateLabel = capitalize(formatDay(key));
    final dayOrdersTotal = dayOrders.fold<int>(
      0,
      (total, order) => total + order.total,
    );
    final dayShiftBonus = dayShifts.fold<int>(
      0,
      (total, shift) => total + shift.bonus,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: TableCalendar<CalendarMarker>(
              locale: 'es_ES',
              firstDay: DateTime(2015),
              lastDay: DateTime(2100, 12, 31),
              focusedDay: selectedDay,
              selectedDayPredicate: (day) => isSameDay(day, selectedDay),
              eventLoader: _eventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left),
                rightChevronIcon: Icon(Icons.chevron_right),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: Theme.of(context).textTheme.labelSmall!,
                weekendStyle: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final markers = events.cast<CalendarMarker>().toList();
                  return Positioned(
                    bottom: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: markers
                          .map(
                            (marker) =>
                                _MarkerDot(color: marker.color(context)),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
              onDaySelected: (selected, focused) =>
                  onDaySelected(DateUtils.dateOnly(selected)),
              onPageChanged: (focused) =>
                  onDaySelected(DateUtils.dateOnly(focused)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Buscar fecha',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDay,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2100),
                  locale: const Locale('es'),
                  helpText: 'Busca cualquier fecha',
                );
                if (picked != null) {
                  onDaySelected(DateUtils.dateOnly(picked));
                }
              },
              icon: const Icon(Icons.manage_search),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dayOrders.isNotEmpty || dayShifts.isNotEmpty)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.savings_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                'Generado este día',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Pedidos ${formatMoney(dayOrdersTotal)} + '
                'bono de turno ${formatMoney(dayShiftBonus)}',
              ),
              trailing: Text(
                formatMoney(dayOrdersTotal + dayShiftBonus),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        if (dayOrders.isEmpty &&
            dayShifts.isEmpty &&
            dayExpenses.isEmpty &&
            dayOtherIncomes.isEmpty &&
            dayDebtOccurrences.isEmpty &&
            dayNotes.isEmpty &&
            dayCalendarEvents.isEmpty)
          _EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Un día despejado',
            message: 'Aún no tienes registros para esta fecha.',
            actionLabel: 'Agregar registro',
            onAction: onAdd,
          ),
        if (dayShifts.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.work_outline,
            label: 'Turno trabajado',
            count: dayShifts.length,
          ),
          ...dayShifts.map(
            (shift) => _ShiftCard(
              shift: shift,
              onEdit: () => onEditShift(shift),
              onDelete: () => onDeleteShift(shift),
            ),
          ),
        ],
        if (dayOrders.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.receipt_long_outlined,
            label: 'Pedidos',
            count: dayOrders.length,
          ),
          ...dayOrders.map(
            (order) => _OrderCard(
              order: order,
              onEdit: () => onEditOrder(order),
              onDelete: () => onDeleteOrder(order),
            ),
          ),
        ],
        if (dayExpenses.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.shopping_bag_outlined,
            label: 'Gastos',
            count: dayExpenses.length,
          ),
          ...dayExpenses.map(
            (expense) => _EventCard(
              icon: Icons.shopping_bag_outlined,
              tint: const Color(0xFFFFF1D9),
              iconColor: const Color(0xFF956000),
              title: expense.title,
              subtitle: '${expense.category} · ${formatMoney(expense.amount)}',
              details: expense.notes,
              onEdit: () => onEditExpense(expense),
              onDelete: () => onDeleteExpense(expense),
            ),
          ),
        ],
        if (dayOtherIncomes.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.add_card_outlined,
            label: 'Otros ingresos',
            count: dayOtherIncomes.length,
          ),
          ...dayOtherIncomes.map(
            (income) => _EventCard(
              icon: Icons.add_card_outlined,
              tint: Theme.of(context).colorScheme.primaryContainer,
              iconColor: Theme.of(context).colorScheme.primary,
              title: income.source,
              subtitle: formatMoney(income.amount),
              details: income.notes,
              onEdit: () => onEditOtherIncome(income),
              onDelete: () => onDeleteOtherIncome(income),
            ),
          ),
        ],
        if (dayDebtOccurrences.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.event_repeat_outlined,
            label: 'Vencimientos de deuda',
            count: dayDebtOccurrences.length,
          ),
          ...dayDebtOccurrences.map(
            (occurrence) => _DebtOccurrenceCard(
              occurrence: occurrence,
              onTogglePaid: () => onToggleDebtPaid(occurrence),
            ),
          ),
        ],
        if (dayNotes.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.event_note_outlined,
            label: 'Recordatorios',
            count: dayNotes.length,
          ),
          ...dayNotes.map(
            (note) => _NoteCard(
              note: note,
              onEdit: () => onEditNote(note),
              onDelete: () => onDeleteNote(note),
            ),
          ),
        ],
        if (dayCalendarEvents.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.event_available_outlined,
            label: 'Eventos y sesiones',
            count: dayCalendarEvents.length,
          ),
          ...dayCalendarEvents.map(
            (event) => _CalendarEventCard(
              event: event,
              onEdit: () => onEditCalendarEvent(event),
              onDelete: () => onDeleteCalendarEvent(event),
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddCalendarEvent,
          icon: const Icon(Icons.add),
          label: const Text('Agregar evento o sesión'),
        ),
      ],
    );
  }
}

enum CalendarMarker {
  order,
  shift,
  expense,
  debt,
  income,
  note,
  appointment;

  Color color(BuildContext context) => switch (this) {
    order || income => Theme.of(context).colorScheme.primary,
    shift => const Color(0xFF7B61A8),
    expense => const Color(0xFFE49A32),
    debt || note || appointment => const Color(0xFF5279B8),
  };
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

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.total,
    required this.withholding,
    required this.netTotal,
    required this.ordersCount,
    required this.workDays,
    required this.orderEarnings,
    required this.shiftEarnings,
  });

  final int total;
  final int withholding;
  final int netTotal;
  final int ordersCount;
  final int workDays;
  final int orderEarnings;
  final int shiftEarnings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? colorScheme.onPrimaryContainer : Colors.white;
    final firstColor = isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final secondColor = isDark
        ? colorScheme.tertiaryContainer
        : colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [firstColor, Color.lerp(firstColor, secondColor, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.savings_outlined,
                color: foreground.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 8),
              Text(
                'Generado este mes',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: foreground),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatMoney(total),
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Neto estimado después del SII: ${formatMoney(netTotal)}',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: foreground),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _EarningsDetail(
                label: '$ordersCount pedidos',
                value: orderEarnings,
                foreground: foreground,
              ),
              _EarningsDetail(
                label: '$workDays turnos',
                value: shiftEarnings,
                foreground: foreground,
              ),
              _EarningsDetail(
                label: 'Retención SII',
                value: -withholding,
                foreground: foreground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balance,
    required this.outstandingDebt,
    required this.onAddIncome,
  });

  final int balance;
  final int outstandingDebt;
  final VoidCallback onAddIncome;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mi dinero actual',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Agregar dinero recibido',
                onPressed: onAddIncome,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatMoney(balance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: balance < 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Deudas pendientes')),
              Text(
                formatMoney(outstandingDebt),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'El saldo resta gastos y pagos de deuda registrados. '
            'Las deudas pendientes no se descuentan hasta marcarlas pagadas.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EarningsDetail extends StatelessWidget {
  const _EarningsDetail({
    required this.label,
    required this.value,
    required this.foreground,
  });

  final String label;
  final int value;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 5, color: foreground.withValues(alpha: 0.75)),
      const SizedBox(width: 6),
      Text(
        '$label · ${formatMoney(value)}',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: foreground),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: tint,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amount),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onEdit,
    required this.onDelete,
  });

  final PickerOrder order;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.code.isEmpty ? 'Pedido' : order.code,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${capitalize(formatShortDay(order.day))} · '
                        '${order.skuCount} productos',
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
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Base ${formatMoney(order.baseRate)}  ·  '
                    'SKU ${formatMoney(order.skuCount * order.skuRate)}'
                    '${order.bonus > 0 ? '  ·  Bono ${formatMoney(order.bonus)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  formatMoney(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(order.notes, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkShift shift;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _EventCard(
    icon: Icons.work_outline,
    tint: const Color(0xFFF0EAF7),
    iconColor: const Color(0xFF7B61A8),
    title: 'Turno trabajado',
    subtitle:
        '${shift.startTime} – ${shift.endTime}'
        '${shift.bonus > 0 ? ' · Bono ${formatMoney(shift.bonus)}' : ''}',
    details: shift.notes,
    onEdit: onEdit,
    onDelete: onDelete,
  );
}

class _DebtOccurrenceCard extends StatelessWidget {
  const _DebtOccurrenceCard({
    required this.occurrence,
    required this.onTogglePaid,
  });

  final DebtOccurrence occurrence;
  final VoidCallback onTogglePaid;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF0FA),
        child: Icon(
          occurrence.isPaid ? Icons.check_circle_outline : Icons.event_repeat,
          color: const Color(0xFF5279B8),
        ),
      ),
      title: Text(
        occurrence.debt.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${occurrence.debt.type == DebtType.monthly ? 'Pago mensual' : 'Cuota'}'
        ' · ${occurrence.isPaid ? 'Pagada' : 'Pendiente'}'
        '${occurrence.debt.notes.isEmpty ? '' : '\n${occurrence.debt.notes}'}',
      ),
      isThreeLine: occurrence.debt.notes.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(occurrence.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Checkbox(value: occurrence.isPaid, onChanged: (_) => onTogglePaid()),
        ],
      ),
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _EventCard(
    icon: Icons.event_note_outlined,
    tint: const Color(0xFFEAF0FA),
    iconColor: const Color(0xFF5279B8),
    title: note.title,
    subtitle: 'Recordatorio',
    details: note.notes,
    onEdit: onEdit,
    onDelete: onDelete,
  );
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _EventCard(
    icon: Icons.event_available_outlined,
    tint: const Color(0xFFEAF0FA),
    iconColor: const Color(0xFF5279B8),
    title: event.title,
    subtitle:
        '${event.startTime} · ${event.notify ? 'Aviso activado' : 'Sin aviso'}',
    details: event.description,
    onEdit: onEdit,
    onDelete: onDelete,
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String details;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tint,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  if (details.isNotEmpty)
                    Text(details, style: Theme.of(context).textTheme.bodySmall),
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
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 44,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text('No se pudieron cargar tus registros'),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    ),
  );
}
