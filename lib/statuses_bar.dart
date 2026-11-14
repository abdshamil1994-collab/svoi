import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';

class StatusesBar extends StatefulWidget {
  const StatusesBar({super.key});

  @override
  State<StatusesBar> createState() => StatusesBarState();
}

class StatusesBarState extends State<StatusesBar> {
  String _myStatus = '';
  String _myEmoji = '';
  String? _myAvatar;
  List<Map<String, dynamic>> _friendStatuses = [];

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final me = await _client
          .from('profiles')
          .select('status, status_emoji, avatar_url')
          .eq('id', _uid)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _myStatus = me?['status'] as String? ?? '';
          _myEmoji = me?['status_emoji'] as String? ?? '';
          _myAvatar = me?['avatar_url'] as String?;
        });
      }
    } catch (_) {}

    try {
      final friendships = await _client
          .from('friendships')
          .select('user_id, friend_id')
          .eq('status', 'accepted')
          .or('user_id.eq.$_uid,friend_id.eq.$_uid');
      final friendIds = {
        for (final row in friendships as List)
          (row['user_id'] == _uid ? row['friend_id'] : row['user_id'])
              as String,
      };
      if (friendIds.isEmpty) {
        if (mounted) setState(() => _friendStatuses = []);
        return;
      }
      final profiles = await _client
          .from('profiles')
          .select('id, username, avatar_url, status, status_emoji')
          .inFilter('id', friendIds.toList())
          .not('status', 'is', null);
      if (mounted) {
        setState(() => _friendStatuses = [
              for (final p in profiles as List)
                if ((p['status'] as String? ?? '').isNotEmpty)
                  Map<String, dynamic>.from(p as Map),
            ]);
      }
    } catch (_) {}
  }

  Future<void> _editStatus() async {
    final emojiController = ValueNotifier<String>(_myEmoji);
    final textController = TextEditingController(text: _myStatus);
    const emojis = ['😀', '😎', '🔥', '❤️', '🎉', '☕', '🚀', '🌙', '💪', '🎵'];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Мой статус',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: emojiController,
                  builder: (context, selected, _) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in emojis)
                        GestureDetector(
                          onTap: () => emojiController.value = e,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected == e
                                  ? AppColors.coral.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkField
                                      : AppColors.lightField),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected == e
                                    ? AppColors.coral
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                width: selected == e ? 1.6 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(e,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'Что у вас нового? (пусто — убрать статус)',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) return;
    final text = textController.text.trim();
    final emoji = text.isEmpty ? '' : emojiController.value;
    try {
      await _client.from('profiles').update({
        'status': text.isEmpty ? null : text,
        'status_emoji': text.isEmpty ? null : (emoji.isEmpty ? null : emoji),
      }).eq('id', _uid);
      setState(() {
        _myStatus = text;
        _myEmoji = emoji;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить статус')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _buildMyTile(muted),
          for (final f in _friendStatuses) _buildFriendTile(f, isDark, muted),
        ],
      ),
    );
  }

  Widget _buildMyTile(Color? muted) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: _editStatus,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                  backgroundImage:
                      _myAvatar != null ? NetworkImage(_myAvatar!) : null,
                  child: _myAvatar == null
                      ? const Icon(Icons.person_outline,
                          size: 22, color: AppColors.coral)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.coral,
                    child: Text(
                      _myStatus.isEmpty ? '+' : _myEmoji,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, height: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text('Мой статус', style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> f, bool isDark, Color? muted) {
    final avatarUrl = f['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkField : AppColors.lightField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${f['status_emoji'] ?? ''} ${f['username'] ?? ''}'
                        .trim(),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    f['status'] as String? ?? '',
                    style: TextStyle(fontSize: 11, color: muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
