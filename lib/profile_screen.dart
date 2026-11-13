import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'menu_screens.dart';
import 'post_view_screen.dart';
import 'profile_drawer.dart';

typedef ProfileStats = ({int posts, int likesGot, int commentsGot, int likesGiven});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  ProfileStats _stats = (posts: 0, likesGot: 0, commentsGot: 0, likesGiven: 0);
  List<Map<String, dynamic>>? _myPosts;
  List<Map<String, dynamic>>? _likedPosts;
  bool _avatarUploading = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadProfile();
    _loadStats();
    _loadMyPosts();
    _loadLikedPosts();
  }

  Future<void> _loadProfile() async {
    try {
      final row = await _client
          .from('profiles')
          .select('username, avatar_url, bio')
          .eq('id', _uid)
          .maybeSingle();
      if (mounted) setState(() => _profile = row);
    } on PostgrestException {
      // Колонка bio ещё не создана (миграция 004 не применена).
      try {
        final row = await _client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', _uid)
            .maybeSingle();
        if (mounted) setState(() => _profile = row);
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    var posts = 0, likesGot = 0, commentsGot = 0, likesGiven = 0;
    try {
      posts = (await _client
              .from('posts')
              .select('id')
              .eq('user_id', _uid)
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    try {
      likesGot = (await _client
              .from('likes')
              .select('post_id, posts!inner(user_id)')
              .eq('posts.user_id', _uid)
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    try {
      commentsGot = (await _client
              .from('comments')
              .select('id, posts!inner(user_id)')
              .eq('posts.user_id', _uid)
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    try {
      likesGiven = (await _client
              .from('likes')
              .select('post_id')
              .eq('user_id', _uid)
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    if (mounted) {
      setState(() => _stats = (
            posts: posts,
            likesGot: likesGot,
            commentsGot: commentsGot,
            likesGiven: likesGiven,
          ));
    }
  }

  Future<void> _loadMyPosts() async {
    try {
      final data = await _client
          .from('posts')
          .select('id, text, image_url, video_url, created_at, likes(count)')
          .eq('user_id', _uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _myPosts = List<Map<String, dynamic>>.from(data));
      }
    } on PostgrestException {
      try {
        final data = await _client
            .from('posts')
            .select('id, text, image_url, video_url, created_at')
            .eq('user_id', _uid)
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() => _myPosts = List<Map<String, dynamic>>.from(data));
        }
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _loadLikedPosts() async {
    try {
      final data = await _client
          .from('likes')
          .select(
              'posts(id, text, image_url, video_url, created_at, likes(count), profiles!posts_user_id_fkey(username, avatar_url))')
          .eq('user_id', _uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _likedPosts = [
              for (final row in data as List)
                if (row['posts'] != null)
                  Map<String, dynamic>.from(row['posts'] as Map),
            ]);
      }
    } catch (_) {
      if (mounted) setState(() => _likedPosts = []);
    }
  }

  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final path =
          '$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      await _client.from('profiles').update({'avatar_url': url}).eq('id', _uid);
      await _loadProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить фото. Попробуйте ещё раз'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (saved == true) _loadProfile();
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          posts: _stats.posts,
          likesReceived: _stats.likesGot,
          commentsReceived: _stats.commentsGot,
          likesGiven: _stats.likesGiven,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = _profile?['username'] as String? ?? '';
    final bio = _profile?['bio'] as String? ?? '';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: ProfileDrawer(
          profile: _profile,
          onOpenStats: _openStats,
          onSignOut: _signOut,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _editProfile,
                      child: const Text('Изменить'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _avatarUploading ? null : _changeAvatar,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.coral, width: 2.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor:
                            AppColors.coral.withValues(alpha: 0.12),
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person_outline,
                                size: 36, color: AppColors.coral)
                            : null,
                      ),
                      if (_avatarUploading)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: AppColors.coral,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                username,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Text('@$username', style: TextStyle(color: muted)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '${_stats.posts} Постов  |  ${_stats.likesGot} Лайков  |  0 Подписок  |  0 Подписчиков',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 10),
              TabBar(
                labelColor: theme.textTheme.bodyLarge?.color,
                unselectedLabelColor: muted,
                indicatorColor: AppColors.coral,
                tabs: const [
                  Tab(text: 'Посты'),
                  Tab(text: 'Понравилось'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _PostsGrid(
                      posts: _myPosts,
                      emptyText: 'У вас пока нет постов',
                      onOpen: _openPost,
                    ),
                    _PostsGrid(
                      posts: _likedPosts,
                      emptyText: 'Вам пока ничего не понравилось',
                      onOpen: _openPost,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPost(Map<String, dynamic> post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostViewScreen(post: post)),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({
    required this.posts,
    required this.emptyText,
    required this.onOpen,
  });

  final List<Map<String, dynamic>>? posts;
  final String emptyText;
  final ValueChanged<Map<String, dynamic>> onOpen;

  int _likesCount(Map<String, dynamic> post) {
    final likes = post['likes'];
    if (likes is List && likes.isNotEmpty && likes.first is Map) {
      return (likes.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.5);

    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_on_outlined, size: 36, color: muted),
            const SizedBox(height: 10),
            Text(emptyText, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: posts!.length,
      itemBuilder: (context, i) {
        final post = posts![i];
        final imageUrl = post['image_url'] as String?;
        final videoUrl = post['video_url'] as String?;

        Widget cell;
        if (imageUrl != null) {
          cell = Image.network(imageUrl, fit: BoxFit.cover);
        } else if (videoUrl != null) {
          cell = Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  '▶ ${_likesCount(post)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        } else {
          cell = Container(
            color: AppColors.coral.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(10),
            child: Text(
              post['text'] as String? ?? '',
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }

        return GestureDetector(
          onTap: () => onOpen(post),
          child: ClipRect(child: cell),
        );
      },
    );
  }
}
