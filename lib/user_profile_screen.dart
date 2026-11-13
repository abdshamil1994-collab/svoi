import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'post_grid.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>>? _posts;
  String _friendState = 'none'; // none | pending_out | pending_in | friends
  String? _friendshipId;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadProfile(), _loadPosts(), _loadFriendship()]);
  }

  Future<void> _loadProfile() async {
    try {
      final row = await _client
          .from('profiles')
          .select('username, avatar_url, bio')
          .eq('id', widget.userId)
          .maybeSingle();
      if (mounted) setState(() => _profile = row);
    } catch (_) {
      try {
        final row = await _client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', widget.userId)
            .maybeSingle();
        if (mounted) setState(() => _profile = row);
      } catch (_) {}
    }
  }

  Future<void> _loadPosts() async {
    try {
      final data = await _client
          .from('posts')
          .select('id, user_id, text, image_url, video_url, created_at, likes(count)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _posts = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
      try {
        final data = await _client
            .from('posts')
            .select('id, user_id, text, image_url, video_url, created_at')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() => _posts = List<Map<String, dynamic>>.from(data));
        }
      } catch (_) {}
    }
  }

  Future<void> _loadFriendship() async {
    try {
      final row = await _client
          .from('friendships')
          .select('id, status, user_id')
          .or('and(user_id.eq.$_uid,friend_id.eq.${widget.userId}),'
              'and(user_id.eq.${widget.userId},friend_id.eq.$_uid)')
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _friendshipId = row?['id'] as String?;
        if (row == null) {
          _friendState = 'none';
        } else if (row['status'] == 'accepted') {
          _friendState = 'friends';
        } else if (row['user_id'] == _uid) {
          _friendState = 'pending_out';
        } else {
          _friendState = 'pending_in';
        }
      });
    } catch (_) {}
  }

  Future<void> _friendAction() async {
    try {
      if (_friendState == 'none') {
        await _client.from('friendships').insert(
            {'user_id': _uid, 'friend_id': widget.userId});
      } else if (_friendState == 'pending_in' && _friendshipId != null) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', _friendshipId!);
      } else {
        return;
      }
      await _loadFriendship();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выполнить действие')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = _profile?['username'] as String? ?? '';
    final bio = _profile?['bio'] as String? ?? '';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5);

    final (buttonLabel, buttonEnabled) = switch (_friendState) {
      'friends' => ('В друзьях', false),
      'pending_out' => ('Заявка отправлена', false),
      'pending_in' => ('Принять заявку', true),
      _ => ('Добавить в друзья', true),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.coral, width: 2.5),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.coral.withValues(alpha: 0.12),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person_outline,
                      size: 32, color: AppColors.coral)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            username,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text('@$username', style: TextStyle(color: muted)),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(bio, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: buttonEnabled
                ? ElevatedButton(
                    onPressed: _friendAction,
                    child: Text(buttonLabel),
                  )
                : OutlinedButton(
                    onPressed: null,
                    child: Text(buttonLabel),
                  ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PostsGrid(
              posts: _posts,
              emptyText: 'Пока нет постов',
            ),
          ),
        ],
      ),
    );
  }
}
