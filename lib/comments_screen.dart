import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'feed_screen.dart' show timeAgo;
import 'notifications.dart';
import 'user_profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key, required this.postId});

  final String postId;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _inputController = TextEditingController();
  List<Map<String, dynamic>>? _comments;
  bool _loadFailed = false;
  bool _sending = false;
  Map<String, dynamic>? _myProfile;
  String? _postOwnerId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyProfile();
    _loadPostOwner();
  }

  Future<void> _loadPostOwner() async {
    try {
      final row = await _client
          .from('posts')
          .select('user_id')
          .eq('id', widget.postId)
          .maybeSingle();
      if (mounted) setState(() => _postOwnerId = row?['user_id'] as String?);
    } catch (_) {}
  }

  Future<void> _loadMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) setState(() => _myProfile = row);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('comments')
          .select('id, user_id, text, created_at, profiles(username, avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at');
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data);
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Тихое обновление: падение не считается ошибкой.
  Future<void> _refreshQuietly() async {
    try {
      final data = await _client
          .from('comments')
          .select('id, user_id, text, created_at, profiles(username, avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at');
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data);
          _loadFailed = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    // Шаг 1: вставка. Только её падение считается ошибкой отправки.
    try {
      await _client.from('comments').insert({
        'post_id': widget.postId,
        'user_id': _client.auth.currentUser!.id,
        'text': text,
      });
      final owner = _postOwnerId;
      if (owner != null) {
        sendNotification(userId: owner, type: 'comment', postId: widget.postId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить комментарий')),
        );
      }
      return;
    }

    // Шаг 2: локальное обновление + тихая догрузка списка.
    if (!mounted) return;
    _inputController.clear();
    setState(() {
      _sending = false;
      _comments = [
        ...?_comments,
        {
          'text': text,
          'created_at': DateTime.now().toIso8601String(),
          'profiles': _myProfile,
        },
      ];
    });
    _refreshQuietly();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Комментарии'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(theme)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Написать комментарий...',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.coral,
                            ),
                          )
                        : const Icon(Icons.send, color: AppColors.coral),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loadFailed && _comments == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Комментарии недоступны',
              style: TextStyle(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _loadFailed = false);
                _load();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final comments = _comments;
    if (comments == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (comments.isEmpty) {
      return Center(
        child: Text(
          'Комментариев пока нет',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final c = comments[i];
        final profile = c['profiles'] as Map<String, dynamic>?;
        final avatarUrl = profile?['avatar_url'] as String?;
        final authorId = c['user_id'] as String?;
        final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
        return GestureDetector(
          onTap: authorId == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: authorId),
                    ),
                  ),
          behavior: HitTestBehavior.opaque,
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.coral.withValues(alpha: 0.12),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person_outline,
                      size: 18, color: AppColors.coral)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile?['username'] as String? ?? 'без имени',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c['text'] as String? ?? ''),
                ],
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}
