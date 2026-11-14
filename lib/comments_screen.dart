import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'feed_screen.dart' show timeAgo;
import 'notifications.dart';
import 'user_profile_screen.dart';

/// Открывает комментарии выдвижной панелью снизу (как в Instagram).
Future<void> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(postId: postId),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _inputController = TextEditingController();
  List<Map<String, dynamic>>? _comments;
  bool _loadFailed = false;
  bool _sending = false;
  Map<String, dynamic>? _myProfile;
  String? _postOwnerId;
  Set<String> _myCommentLikes = {};

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
          .select('id, user_id, text, created_at, '
              'profiles!comments_user_id_fkey(username, avatar_url), '
              'comment_likes(count)')
          .eq('post_id', widget.postId)
          .order('created_at');
      if (mounted) {
        final comments = List<Map<String, dynamic>>.from(data);
        setState(() {
          _comments = comments;
          _loadFailed = false;
        });
        _loadMyCommentLikes(comments);
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadMyCommentLikes(List<Map<String, dynamic>> comments) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || comments.isEmpty) return;
    try {
      final rows = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', uid)
          .inFilter('comment_id',
              [for (final c in comments) c['id'] as String]);
      if (mounted) {
        setState(() => _myCommentLikes = {
              for (final r in rows as List) r['comment_id'] as String,
            });
      }
    } catch (_) {}
  }

  /// Тихое обновление: падение не считается ошибкой.
  Future<void> _refreshQuietly() async {
    try {
      final data = await _client
          .from('comments')
          .select('id, user_id, text, created_at, '
              'profiles!comments_user_id_fkey(username, avatar_url), '
              'comment_likes(count)')
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

  int _commentLikesCount(Map<String, dynamic> c) {
    final value = c['comment_likes'];
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> c) async {
    final uid = _client.auth.currentUser!.id;
    final commentId = c['id'] as String?;
    if (commentId == null) return;
    final liked = _myCommentLikes.contains(commentId);

    // Оптимистичное переключение.
    setState(() {
      if (liked) {
        _myCommentLikes.remove(commentId);
      } else {
        _myCommentLikes.add(commentId);
      }
      final likes = c['comment_likes'];
      final delta = liked ? -1 : 1;
      if (likes is List && likes.isNotEmpty && likes.first is Map) {
        likes.first['count'] =
            (((likes.first['count'] as num?)?.toInt() ?? 0) + delta)
                .clamp(0, 1 << 31);
      } else {
        c['comment_likes'] = [
          {'count': liked ? 0 : 1},
        ];
      }
    });

    try {
      if (liked) {
        await _client
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', uid);
      } else {
        await _client
            .from('comment_likes')
            .insert({'comment_id': commentId, 'user_id': uid});
        sendNotification(
          userId: c['user_id'] as String? ?? '',
          type: 'comment_like',
          postId: widget.postId,
        );
      }
    } catch (_) {
      // Откат при ошибке.
      if (mounted) {
        setState(() {
          if (liked) {
            _myCommentLikes.add(commentId);
          } else {
            _myCommentLikes.remove(commentId);
          }
        });
      }
    }
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
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 48),
                const Spacer(),
                Text(
                  'Комментарии',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody(theme, muted)),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + 12,
                ),
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
      ),
    );
  }

  Widget _buildBody(ThemeData theme, Color? muted) {
    if (_loadFailed && _comments == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Комментарии недоступны', style: TextStyle(color: muted)),
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
          style: TextStyle(color: muted),
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
        final liked = _myCommentLikes.contains(c['id']);
        final likesCount = _commentLikesCount(c);
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
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
              GestureDetector(
                onTap: () => _toggleCommentLike(c),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Column(
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: liked
                            ? AppColors.coral
                            : theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.45),
                      ),
                      if (likesCount > 0)
                        Text(
                          '$likesCount',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
