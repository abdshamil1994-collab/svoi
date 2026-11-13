import 'package:supabase_flutter/supabase_flutter.dart';

/// Отправка уведомления пользователю. Ошибки проглатываются —
/// уведомление не должно ломать основное действие.
Future<void> sendNotification({
  required String userId,
  required String type,
  String? postId,
}) async {
  try {
    final client = Supabase.instance.client;
    final actorId = client.auth.currentUser?.id;
    if (actorId == null || actorId == userId) return;
    await client.from('notifications').insert({
      'user_id': userId,
      'actor_id': actorId,
      'type': type,
      'post_id': postId,
    });
  } catch (_) {}
}
