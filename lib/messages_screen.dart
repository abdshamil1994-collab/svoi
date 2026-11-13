import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'chat_screen.dart';
import 'feed_screen.dart' show timeAgo;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>>? _dialogs;
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
      final rows = await _client
          .from('messages')
          .select('id, sender_id, receiver_id, text, read, created_at')
          .or('sender_id.eq.$_uid,receiver_id.eq.$_uid')
          .order('created_at', ascending: false)
          .limit(200);

      // Группируем по собеседнику: последнее сообщение + непрочитанные.
      final byPeer = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final peer = map['sender_id'] == _uid
            ? map['receiver_id'] as String
            : map['sender_id'] as String;
        final existing = byPeer[peer];
        if (existing == null) {
          byPeer[peer] = {
            'peer_id': peer,
            'last_text': map['text'],
            'last_time': map['created_at'],
            'unread': 0,
          };
        }
        if (map['receiver_id'] == _uid && map['read'] == false) {
          byPeer[peer]!['unread'] = (byPeer[peer]!['unread'] as int) + 1;
        }
      }

      if (byPeer.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', byPeer.keys.toList());
        for (final p in profiles as List) {
          final entry = byPeer[p['id']];
          if (entry != null) {
            entry['username'] = p['username'];
            entry['avatar_url'] = p['avatar_url'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _dialogs = byPeer.values.toList()
            ..sort((a, b) => (b['last_time'] as String)
                .compareTo(a['last_time'] as String));
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _buildBody(muted),
    );
  }

  Widget _buildBody(Color? muted) {
    if (_failed && _dialogs == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Не удалось загрузить диалоги',
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
    final dialogs = _dialogs;
    if (dialogs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dialogs.isEmpty) {
      return Center(
        child: Text(
          'Диалогов пока нет.\nНапишите другу со страницы его профиля',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: dialogs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final d = dialogs[i];
          final avatarUrl = d['avatar_url'] as String?;
          final time = DateTime.tryParse(d['last_time'] as String? ?? '');
          final unread = d['unread'] as int;

          return ListTile(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    peerId: d['peer_id'] as String,
                    peerName: d['username'] as String? ?? 'без имени',
                    peerAvatar: avatarUrl,
                  ),
                ),
              );
              _load();
            },
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.coral.withValues(alpha: 0.12),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person_outline, color: AppColors.coral)
                  : null,
            ),
            title: Text(
              d['username'] as String? ?? 'без имени',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              d['last_text'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(timeAgo(time),
                      style: TextStyle(fontSize: 12, color: muted)),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.coral,
                    child: Text(
                      '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
