import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'feed_screen.dart' show timeAgo;
import 'post_view_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _items;
  bool _failed = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('notifications')
          .select(
              'id, type, post_id, read, created_at, actor_id, '
              'actor:profiles!notifications_actor_id_fkey(username, avatar_url)')
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _text(Map<String, dynamic> n) {
    final actor =
        (n['actor'] as Map<String, dynamic>?)?['username'] as String? ??
            'Кто-то';
    return switch (n['type']) {
      'friend_request' => '$actor подал(а) заявку в друзья',
      'friend_accept' => '$actor принял(а) вашу заявку в друзья',
      'like' => '$actor лайкнул(а) ваш пост',
      'comment' => '$actor прокомментировал(а) ваш пост',
      _ => 'Новое уведомление',
    };
  }

  Future<void> _open(Map<String, dynamic> n) async {
    // Помечаем прочитанным.
    if (n['read'] != true) {
      setState(() => n['read'] = true);
      try {
        await _client
            .from('notifications')
            .update({'read': true}).eq('id', n['id'] as String);
      } catch (_) {}
    }
    if (!mounted) return;

    final type = n['type'] as String?;
    if (type == 'friend_request' || type == 'friend_accept') {
      final actorId = n['actor_id'] as String?;
      // actor_id нет в select — берём из связанного профиля через запрос.
      if (actorId == null) {
        _openActorByUsername(n);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: actorId)),
      );
      return;
    }

    final postId = n['post_id'] as String?;
    if (postId != null) {
      try {
        final post = await _client
            .from('posts')
            .select(
                'id, user_id, text, image_url, video_url, created_at, likes(count), comments(count), '
                'profiles!posts_user_id_fkey(username, avatar_url)')
            .eq('id', postId)
            .maybeSingle();
        if (!mounted) return;
        if (post != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    PostViewScreen(post: Map<String, dynamic>.from(post))),
          );
          return;
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пост недоступен')),
        );
      }
    }
  }

  Future<void> _openActorByUsername(Map<String, dynamic> n) async {
    final username =
        (n['actor'] as Map<String, dynamic>?)?['username'] as String?;
    if (username == null) return;
    try {
      final profile = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (!mounted || profile == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: profile['id'] as String),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _buildBody(isDark, muted),
    );
  }

  Widget _buildBody(bool isDark, Color? muted) {
    if (_failed && _items == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Не удалось загрузить уведомления',
                style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text('Уведомлений пока нет', style: TextStyle(color: muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = items[i];
          final actor = n['actor'] as Map<String, dynamic>?;
          final avatarUrl = actor?['avatar_url'] as String?;
          final unread = n['read'] != true;
          final createdAt =
              DateTime.tryParse(n['created_at'] as String? ?? '');

          return Container(
            color: unread
                ? AppColors.coral.withValues(alpha: isDark ? 0.12 : 0.06)
                : null,
            child: ListTile(
              onTap: () => _open(n),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person_outline,
                        size: 20, color: AppColors.coral)
                    : null,
              ),
              title: Text(
                _text(n),
                style: TextStyle(
                    fontWeight: unread ? FontWeight.w600 : FontWeight.normal),
              ),
              subtitle:
                  createdAt != null ? Text(timeAgo(createdAt)) : null,
              trailing: unread
                  ? const CircleAvatar(radius: 4, backgroundColor: AppColors.coral)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
