import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'story_viewer_screen.dart';

class StoryGroup {
  StoryGroup({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
    required this.hasUnviewed,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final List<Map<String, dynamic>> stories;
  final bool hasUnviewed;
}

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => StoriesBarState();
}

class StoriesBarState extends State<StoriesBar> {
  List<StoryGroup>? _groups;
  Set<String> _viewed = {};
  bool _uploading = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _viewed = (prefs.getStringList('viewed_stories') ?? []).toSet();
    try {
      final data = await _client
          .from('stories')
          .select(
              'id, user_id, media_url, media_type, created_at, expires_at, '
              'profiles!stories_user_id_fkey(username, avatar_url)')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at');

      final byUser = <String, List<Map<String, dynamic>>>{};
      for (final row in data as List) {
        final map = Map<String, dynamic>.from(row as Map);
        byUser.putIfAbsent(map['user_id'] as String, () => []).add(map);
      }

      final groups = [
        for (final entry in byUser.entries)
          StoryGroup(
            userId: entry.key,
            username: (entry.value.first['profiles']
                as Map?)?['username'] as String? ?? 'без имени',
            avatarUrl: (entry.value.first['profiles']
                as Map?)?['avatar_url'] as String?,
            stories: entry.value,
            hasUnviewed: entry.value
                .any((s) => !_viewed.contains(s['id'] as String)),
          ),
      ];
      // Мои истории — первыми после кнопки создания.
      groups.sort((a, b) {
        if (a.userId == _uid) return -1;
        if (b.userId == _uid) return 1;
        return 0;
      });

      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _groups = []);
    }
  }

  Future<void> _createStory() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Фото'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Видео (до 15 сек)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final picker = ImagePicker();
    final picked = choice == 'image'
        ? await picker.pickImage(
            source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85)
        : await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 15));
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final isImage = choice == 'image';
      final ext = isImage ? 'jpg' : 'mp4';
      final path =
          '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('stories').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: isImage ? 'image/jpeg' : 'video/mp4',
            ),
          );
      final url = _client.storage.from('stories').getPublicUrl(path);
      await _client.from('stories').insert({
        'user_id': _uid,
        'media_url': url,
        'media_type': isImage ? 'image' : 'video',
      });
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Не удалось опубликовать историю')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openGroup(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(groups: _groups!, initialIndex: index),
      ),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.5);

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildCreateTile(muted),
          if (_groups != null)
            for (var i = 0; i < _groups!.length; i++) _buildGroupTile(i, muted),
        ],
      ),
    );
  }

  Widget _buildCreateTile(Color? muted) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: _uploading ? null : _createStory,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coral, width: 1.6),
              ),
              child: _uploading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.coral),
                    )
                  : const Icon(Icons.add, color: AppColors.coral),
            ),
            const SizedBox(height: 4),
            Text('Ваша история',
                style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(int index, Color? muted) {
    final group = _groups![index];
    final ringColor =
        group.hasUnviewed ? AppColors.coral : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _openGroup(index),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.2),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                backgroundImage: group.avatarUrl != null
                    ? NetworkImage(group.avatarUrl!)
                    : null,
                child: group.avatarUrl == null
                    ? const Icon(Icons.person_outline,
                        size: 24, color: AppColors.coral)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                group.userId == _uid ? 'Вы' : group.username,
                style: TextStyle(fontSize: 11, color: muted),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
