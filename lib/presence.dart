import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_screen.dart' show timeAgo;

/// Обновляет last_seen в профиле: при старте, каждые 30 секунд
/// и при возврате приложения из фона.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();
  // ignore: unused_field — таймер живёт всё время работы приложения.
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _ping();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ping();
  }

  Future<void> _ping() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      await client
          .from('profiles')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
    } catch (_) {}
  }
}

bool isOnline(DateTime? lastSeen) {
  if (lastSeen == null) return false;
  return DateTime.now().toUtc().difference(lastSeen.toUtc()).inMinutes < 2;
}

/// «в сети» или «был(а) в сети …»
String presenceText(DateTime? lastSeen) {
  if (lastSeen == null) return 'был(а) давно';
  if (isOnline(lastSeen)) return 'в сети';
  return 'был(а) в сети ${timeAgo(lastSeen)}';
}
