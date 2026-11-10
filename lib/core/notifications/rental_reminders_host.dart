import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../settings/app_prefs.dart';
import '../widgets/app_snackbar.dart';
import 'reminder_backend.dart';
import 'rental_reminder_plan.dart';

/// Ajustes de los recordatorios: son de cada aparato.
abstract final class RentalReminderPrefs {
  static const enabled = PrefKey<bool>('rentals.remindersOn', true);
  static const eveHour = PrefKey<int>('rentals.remindEveHour', 20);
  static const minutesBefore = PrefKey<int>('rentals.remindMinutes', 90);

  static RentalReminderSettings read() {
    final p = AppPrefs.instance;
    return RentalReminderSettings(
      enabled: p.get(enabled),
      eveHour: p.get(eveHour),
      minutesBefore: p.get(minutesBefore),
    );
  }
}

/// Mantiene al día los recordatorios de este aparato: al cambiar una reserva
/// (también si llega de otro aparato), al cambiar los ajustes y al volver a
/// la app. Donde no se pueden programar, avisa al abrir IRIS.
class RentalRemindersHost extends ConsumerStatefulWidget {
  final Widget child;

  const RentalRemindersHost({super.key, required this.child});

  @override
  ConsumerState<RentalRemindersHost> createState() => _HostState();
}

class _HostState extends ConsumerState<RentalRemindersHost>
    with WidgetsBindingObserver {
  final _backend = ReminderBackend.forPlatform();
  final _shown = <String>{};
  StreamSubscription<void>? _changes;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPrefs.instance.addListener(_schedule);
    final db = ref.read(databaseProvider);
    _changes = db
        .select(db.rentalReservations)
        .watch()
        .listen((_) => _schedule());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppPrefs.instance.removeListener(_schedule);
    _changes?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _reconcile);
  }

  Future<void> _reconcile() async {
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    final settings = RentalReminderPrefs.read();
    final now = DateTime.now();
    try {
      final reservations = await db.select(db.rentalReservations).get();
      final houses = await db.select(db.rentalHouses).get();
      final byUid = <String, RentalHouse>{for (final h in houses) h.uid: h};
      await _backend.replaceAll(
        RentalReminderPlan.upcoming(reservations, byUid, settings, now),
      );
      if (_backend.schedulesWhenClosed || !mounted) return;
      for (final r in RentalReminderPlan.dueNow(
        reservations,
        byUid,
        settings,
        now,
      )) {
        if (_shown.add(r.key) && mounted) {
          AppSnackBar.show(
            context,
            '${r.title}: ${r.body}',
            duration: const Duration(seconds: 8),
          );
        }
      }
    } catch (e) {
      debugPrint('Recordatorios de material: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
