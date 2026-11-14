import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'notifications.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _friends = [];
  Set<String> _pendingOut = {};
  Set<String> _friendIds = {};
  bool _searching = false;
  bool _dataFailed = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final rows = await _client
          .from('friendships')
          .select(
              'id, status, user_id, friend_id, '
              'requester:profiles!friendships_user_id_fkey(username, avatar_url), '
              'target:profiles!friendships_friend_id_fkey(username, avatar_url)')
          .or('user_id.eq.$_uid,friend_id.eq.$_uid');

      final requests = <Map<String, dynamic>>[];
      final friends = <Map<String, dynamic>>[];
      final pendingOut = <String>{};

      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final isMine = map['user_id'] == _uid;
        final other = (isMine ? map['target'] : map['requester'])
            as Map<String, dynamic>?;
        if (other == null) continue;
        final entry = {
          'friendship_id': map['id'],
          'other_id': isMine ? map['friend_id'] : map['user_id'],
          'username': other['username'],
          'avatar_url': other['avatar_url'],
        };
        if (map['status'] == 'accepted') {
          friends.add(entry);
        } else if (!isMine) {
          requests.add(entry);
        } else {
          pendingOut.add(map['friend_id'] as String);
        }
      }

      if (mounted) {
        setState(() {
          _requests = requests;
          _friends = friends;
          _pendingOut = pendingOut;
          _friendIds = {
            for (final f in friends) f['other_id'] as String,
          };
          _dataFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataFailed = true);
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await _client
          .from('profiles')
          .select('id, username, avatar_url')
          .ilike('username', '%$q%')
          .neq('id', _uid)
          .limit(20);
      if (mounted) {
        setState(() =>
            _searchResults = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend(String friendId) async {
    // Оптимистично показываем «Заявка отправлена», запрос — в фоне.
    setState(() => _pendingOut.add(friendId));
    try {
      // Взаимная заявка? Тогда сразу принимаем.
      final reverse = await _client
          .from('friendships')
          .select('id')
          .eq('user_id', friendId)
          .eq('friend_id', _uid)
          .eq('status', 'pending')
          .maybeSingle();
      if (reverse != null) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', reverse['id']);
        sendNotification(userId: friendId, type: 'friend_accept');
      } else {
        await _client
            .from('friendships')
            .insert({'user_id': _uid, 'friend_id': friendId});
        sendNotification(userId: friendId, type: 'friend_request');
      }
      _loadData();
    } catch (_) {
      if (mounted) {
        setState(() => _pendingOut.remove(friendId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку')),
        );
      }
    }
  }

  Future<void> _respond(String friendshipId, bool accept) async {
    try {
      if (accept) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', friendshipId);
      } else {
        await _client.from('friendships').delete().eq('id', friendshipId);
      }
      _loadData();
    } catch (_) {}
  }

  void _openUser(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои друзья'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск людей по нику',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.coral),
                      ),
                    )
                  : null,
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          if (_searchResults.isNotEmpty) ...[
            for (final user in _searchResults)
              _UserTile(
                avatarUrl: user['avatar_url'] as String?,
                username: user['username'] as String? ?? '',
                onTap: () => _openUser(user['id'] as String),
                trailing: _friendIds.contains(user['id'])
                    ? Text('В друзьях',
                        style: TextStyle(fontSize: 12, color: muted))
                    : _pendingOut.contains(user['id'])
                        ? Text('Заявка отправлена',
                            style: TextStyle(fontSize: 12, color: muted))
                        : TextButton(
                            onPressed: () => _addFriend(user['id'] as String),
                            child: const Text('Добавить'),
                          ),
              ),
            const SizedBox(height: 16),
          ],
          if (_dataFailed) ...[
            Text('Не удалось загрузить друзей. Выполните миграцию 005.',
                style: TextStyle(color: muted)),
            const SizedBox(height: 16),
          ],
          if (_requests.isNotEmpty) ...[
            Text('Заявки',
                style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
            const SizedBox(height: 8),
            for (final req in _requests)
              _UserTile(
                avatarUrl: req['avatar_url'] as String?,
                username: req['username'] as String? ?? '',
                onTap: () => _openUser(req['other_id'] as String),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _respond(req['friendship_id'] as String, true),
                      child: const Text('Принять'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _respond(req['friendship_id'] as String, false),
                      child: Text('Отклонить',
                          style: TextStyle(color: muted)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
          Text('Мои друзья',
              style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Пока нет друзей. Найдите их через поиск выше',
                style: TextStyle(color: muted),
              ),
            )
          else
            for (final friend in _friends)
              _UserTile(
                avatarUrl: friend['avatar_url'] as String?,
                username: friend['username'] as String? ?? '',
                onTap: () => _openUser(friend['other_id'] as String),
              ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.avatarUrl,
    required this.username,
    required this.onTap,
    this.trailing,
  });

  final String? avatarUrl;
  final String username;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.coral.withValues(alpha: 0.12),
        backgroundImage: url != null ? NetworkImage(url) : null,
        child: url == null
            ? const Icon(Icons.person_outline, size: 22, color: AppColors.coral)
            : null,
      ),
      title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailing,
    );
  }
}
