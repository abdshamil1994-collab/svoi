import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'comments_screen.dart';
import 'edit_post_screen.dart';
import 'notifications.dart';
import 'notifications_screen.dart';
import 'post_view_screen.dart';
import 'statuses_bar.dart';
import 'stories_bar.dart';
import 'user_profile_screen.dart';
import 'video_player_screen.dart';

String timeAgo(DateTime time) {
  final t = time.toLocal();
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24 && t.day == now.day) return '${diff.inHours} ч назад';
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final yesterday = now.subtract(const Duration(days: 1));
  if (t.day == yesterday.day &&
      t.month == yesterday.month &&
      t.year == yesterday.year) {
    return 'вчера в $hm';
  }
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>>? _posts;
  List<Map<String, dynamic>>? _friendPosts;
  bool _loadFailed = false;
  bool _friendsFailed = false;
  Set<String> _myLikes = {};
  int _unreadNotifications = 0;
  RealtimeChannel? _notificationsChannel;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFriendsFeed();
    _loadUnread();
    _subscribeNotifications();
  }

  @override
  void dispose() {
    if (_notificationsChannel != null) {
      _client.removeChannel(_notificationsChannel!);
    }
    super.dispose();
  }

  void _subscribeNotifications() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _notificationsChannel = _client
        .channel('notifications_bell_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _loadUnread(),
        )
        .subscribe();
  }

  Future<void> _loadUnread() async {
    try {
      final res = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', _client.auth.currentUser!.id)
          .eq('read', false)
          .count(CountOption.exact);
      if (mounted) setState(() => _unreadNotifications = res.count);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _loadUnread();
  }

  Future<void> _load() async {
    try {
      final posts = await _loadPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadFriendsFeed() async {
    try {
      final posts = await _loadFriendPosts();
      if (mounted) {
        setState(() {
          _friendPosts = posts;
          _friendsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _friendsFailed = true);
    }
  }

  /// Тихое обновление: падение не считается ошибкой, список остаётся как есть.
  Future<void> _refreshQuietly() async {
    try {
      final posts = await _loadPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loadFailed = false;
        });
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    try {
      return await _loadPostsFull();
    } on PostgrestException {
      // Таблицы likes/comments ещё не созданы (миграция 003 не применена) —
      // грузим ленту без счётчиков, они покажут нули.
      return _loadPostsBasic();
    }
  }

  Future<List<Map<String, dynamic>>> _loadPostsFull() async {
    final data = await _client
        .from('posts')
        .select(
          'id, user_id, text, image_url, video_url, created_at, '
          'profiles!posts_user_id_fkey(username, avatar_url), likes(count), comments(count)',
        )
        .order('created_at', ascending: false)
        .limit(50);
    await _loadMyLikes();
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> _loadPostsBasic() async {
    _myLikes = {};
    final data = await _client
        .from('posts')
        .select('id, user_id, text, image_url, video_url, created_at, '
            'profiles!posts_user_id_fkey(username, avatar_url)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _loadMyLikes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final mine =
          await _client.from('likes').select('post_id').eq('user_id', uid);
      _myLikes = {for (final row in mine as List) row['post_id'] as String};
    } catch (_) {
      _myLikes = {};
    }
  }

  Future<List<Map<String, dynamic>>> _loadFriendPosts() async {
    final uid = _client.auth.currentUser!.id;
    final friendships = await _client
        .from('friendships')
        .select('user_id, friend_id')
        .eq('status', 'accepted')
        .or('user_id.eq.$uid,friend_id.eq.$uid');
    final friendIds = {
      for (final row in friendships as List)
        (row['user_id'] == uid ? row['friend_id'] : row['user_id']) as String,
    };
    if (friendIds.isEmpty) return [];

    try {
      final data = await _client
          .from('posts')
          .select(
            'id, user_id, text, image_url, video_url, created_at, '
            'profiles!posts_user_id_fkey(username, avatar_url), likes(count), comments(count)',
          )
          .inFilter('user_id', friendIds.toList())
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException {
      final data = await _client
          .from('posts')
          .select('id, user_id, text, image_url, video_url, created_at, '
              'profiles!posts_user_id_fkey(username, avatar_url)')
          .inFilter('user_id', friendIds.toList())
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  int _countOf(Map<String, dynamic> post, String key) {
    final value = post[key];
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Лента'),
          centerTitle: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications'),
                backgroundColor: AppColors.coral,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const StoriesBar(),
            const StatusesBar(),
            TabBar(
              labelColor: theme.textTheme.bodyLarge?.color,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color
                  ?.withValues(alpha: 0.5),
              indicatorColor: AppColors.coral,
              tabs: const [
                Tab(text: 'Все'),
                Tab(text: 'Друзья'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPostsList(
                    posts: _posts,
                    failed: _loadFailed,
                    emptyText: 'Пока пусто. Нажмите + и создайте первый пост',
                    onRetry: () {
                      setState(() => _loadFailed = false);
                      _load();
                    },
                    onRefresh: _load,
                  ),
                  _buildPostsList(
                    posts: _friendPosts,
                    failed: _friendsFailed,
                    emptyText: 'Здесь появятся посты ваших друзей',
                    onRetry: () {
                      setState(() => _friendsFailed = false);
                      _loadFriendsFeed();
                    },
                    onRefresh: _loadFriendsFeed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList({
    required List<Map<String, dynamic>>? posts,
    required bool failed,
    required String emptyText,
    required VoidCallback onRetry,
    required Future<void> Function() onRefresh,
  }) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    if (failed && posts == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Не удалось загрузить ленту',
                style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return Center(child: Text(emptyText, style: TextStyle(color: muted)));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final post = posts[i];
          return PostCard(
            key: ValueKey(post['id'] ?? i),
            post: post,
            likesCount: _countOf(post, 'likes'),
            commentsCount: _countOf(post, 'comments'),
            liked: _myLikes.contains(post['id']),
            onChanged: _refreshQuietly,
            onDeleted: (deleted) {
              setState(() {
                _posts?.removeWhere((p) => p['id'] == deleted['id']);
                _friendPosts?.removeWhere((p) => p['id'] == deleted['id']);
              });
            },
          );
        },
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    this.onChanged,
    this.onDeleted,
    this.inDetail = false,
  });

  final Map<String, dynamic> post;
  final int likesCount;
  final int commentsCount;
  final bool liked;
  final VoidCallback? onChanged;
  final ValueChanged<Map<String, dynamic>>? onDeleted;

  /// true на экране полного просмотра — повторный переход не нужен.
  final bool inDetail;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late bool _liked = widget.liked;
  late int _likes = widget.likesCount;
  late final AnimationController _likeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _likeScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
  ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final uid = _client.auth.currentUser!.id;
    final postId = widget.post['id'] as String?;

    // Оптимистичное переключение + лёгкая анимация сердца.
    _likeCtrl.forward(from: 0);
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });

    if (postId == null) return;
    try {
      if (_liked) {
        await _client.from('likes').insert({'post_id': postId, 'user_id': uid});
        sendNotification(
          userId: widget.post['user_id'] as String? ?? '',
          type: 'like',
          postId: postId,
        );
      } else {
        await _client
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      }
    } catch (_) {
      // Откат при ошибке.
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось поставить лайк. Попробуйте позже'),
          ),
        );
      }
    }
  }

  Future<void> _openComments() async {
    final postId = widget.post['id'] as String?;
    if (postId == null) return;
    await showCommentsSheet(context, postId);
  }

  void _openDetail() {
    if (widget.inDetail) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostViewScreen(post: widget.post)),
    );
  }

  void _openVideo(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url)),
    );
  }

  Future<void> _editPost() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPostScreen(post: widget.post)),
    );
    if (saved == true) widget.onChanged?.call();
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _client
          .from('posts')
          .delete()
          .eq('id', widget.post['id'] as String);
      widget.onDeleted?.call(widget.post);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить пост')),
        );
      }
    }
  }

  void _openAuthor() {
    final authorId = widget.post['user_id'] as String?;
    if (authorId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: authorId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = widget.post['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? 'без имени';
    final avatarUrl = profile?['avatar_url'] as String?;
    final text = widget.post['text'] as String? ?? '';
    final imageUrl = widget.post['image_url'] as String?;
    final videoUrl = widget.post['video_url'] as String?;
    final createdAt = DateTime.tryParse(widget.post['created_at'] as String? ?? '');

    final (badgeIcon, badgeLabel) = videoUrl != null
        ? (Icons.videocam_outlined, 'Видео')
        : imageUrl != null
            ? (Icons.photo_outlined, 'Фото')
            : (Icons.notes, 'Текст');

    final mutedColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5);
    final isMyPost = widget.post['user_id'] ==
        Supabase.instance.client.auth.currentUser?.id;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkField : AppColors.lightField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openAuthor,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person_outline,
                          size: 20, color: AppColors.coral)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (createdAt != null)
                        Text(
                          timeAgo(createdAt),
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                    ],
                  ),
                ),
                if (isMyPost)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: mutedColor),
                    onSelected: (value) {
                      if (value == 'edit') _editPost();
                      if (value == 'delete') _deletePost();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'edit', child: Text('Редактировать')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: AppColors.coral),
                const SizedBox(width: 4),
                Text(
                  badgeLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.coral),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openDetail,
            behavior: HitTestBehavior.opaque,
            child: Text(text),
          ),
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _openDetail,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ],
          if (videoUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openVideo(videoUrl),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.play_arrow,
                        size: 36, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _toggleLike,
                icon: ScaleTransition(
                  scale: _likeScale,
                  child: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? AppColors.coral : mutedColor,
                  ),
                ),
              ),
              Text('$_likes', style: TextStyle(color: mutedColor)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _openComments,
                icon: Icon(Icons.chat_bubble_outline, color: mutedColor),
              ),
              Text('${widget.commentsCount}', style: TextStyle(color: mutedColor)),
            ],
          ),
        ],
      ),
    );
  }
}
