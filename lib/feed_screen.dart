import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'comments_screen.dart';
import 'create_post_screen.dart';
import 'video_player_screen.dart';

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  final t = time.toLocal();
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>>? _posts;
  bool _loadFailed = false;
  Set<String> _myLikes = {};

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
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
          'id, text, image_url, video_url, created_at, '
          'profiles!posts_user_id_fkey(username, avatar_url), likes(count), comments(count)',
        )
        .order('created_at', ascending: false)
        .limit(50);

    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      final mine = await _client
          .from('likes')
          .select('post_id')
          .eq('user_id', uid);
      _myLikes = {
        for (final row in mine as List) row['post_id'] as String,
      };
    }
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> _loadPostsBasic() async {
    _myLikes = {};
    final data = await _client
        .from('posts')
        .select('id, text, image_url, video_url, created_at, '
            'profiles!posts_user_id_fkey(username, avatar_url)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _createPost() async {
    final newPost = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (newPost == null || !mounted) return;
    // Оптимистично добавляем пост в начало списка, затем тихо догружаем ленту.
    setState(() => _posts = [newPost, ...?_posts]);
    _refreshQuietly();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Лента'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loadFailed && _posts == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить ленту',
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

    final posts = _posts;
    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'Пока пусто. Нажмите + и создайте первый пост',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
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
  });

  final Map<String, dynamic> post;
  final int likesCount;
  final int commentsCount;
  final bool liked;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked = widget.liked;
  late int _likes = widget.likesCount;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _toggleLike() async {
    final uid = _client.auth.currentUser!.id;
    final postId = widget.post['id'] as String?;

    // Оптимистичное переключение, запрос уходит в фоне.
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });

    if (postId == null) return;
    try {
      if (_liked) {
        await _client.from('likes').insert({'post_id': postId, 'user_id': uid});
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommentsScreen(postId: postId)),
    );
  }

  void _openVideo(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url)),
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
          Row(
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
            ],
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
          Text(text),
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
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
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? AppColors.coral : mutedColor,
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
