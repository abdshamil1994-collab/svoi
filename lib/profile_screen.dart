import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'menu_screens.dart';
import 'post_grid.dart';
import 'profile_drawer.dart';

typedef ProfileStats = ({
  int posts,
  int likesGot,
  int commentsGot,
  int likesGiven,
  int following,
  int followers,
});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  ProfileStats _stats = (
    posts: 0,
    likesGot: 0,
    commentsGot: 0,
    likesGiven: 0,
    following: 0,
    followers: 0,
  );
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
    var following = 0, followers = 0;
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
    try {
      following = (await _client
              .from('friendships')
              .select('id')
              .eq('user_id', _uid)
              .eq('status', 'accepted')
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    try {
      followers = (await _client
              .from('friendships')
              .select('id')
              .eq('friend_id', _uid)
              .eq('status', 'accepted')
              .count(CountOption.exact))
          .count;
    } catch (_) {}
    if (mounted) {
      setState(() => _stats = (
            posts: posts,
            likesGot: likesGot,
            commentsGot: commentsGot,
            likesGiven: likesGiven,
            following: following,
            followers: followers,
          ));
    }
  }

  Future<void> _loadMyPosts() async {
    try {
      final data = await _client
          .from('posts')
          .select('id, user_id, text, image_url, video_url, created_at, likes(count)')
          .eq('user_id', _uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _myPosts = List<Map<String, dynamic>>.from(data));
      }
    } on PostgrestException {
      try {
        final data = await _client
            .from('posts')
            .select('id, user_id, text, image_url, video_url, created_at')
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
              'posts(id, user_id, text, image_url, video_url, created_at, likes(count), profiles!posts_user_id_fkey(username, avatar_url))')
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
                '${_stats.posts} Постов  |  ${_stats.likesGot} Лайков  |  ${_stats.following} Подписок  |  ${_stats.followers} Подписчиков',
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
                    PostsGrid(
                      posts: _myPosts,
                      emptyText: 'У вас пока нет постов',
                    ),
                    PostsGrid(
                      posts: _likedPosts,
                      emptyText: 'Вам пока ничего не понравилось',
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
}
