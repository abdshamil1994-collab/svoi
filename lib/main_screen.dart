import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'games_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  int _feedVisits = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _unread = messagesUnread.value;
    messagesUnread.addListener(_onUnreadChanged);
  }

  @override
  void dispose() {
    messagesUnread.removeListener(_onUnreadChanged);
    super.dispose();
  }

  void _onUnreadChanged() {
    if (mounted) setState(() => _unread = messagesUnread.value);
  }

  Future<void> _createPost() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created != null && mounted) {
      // Возвращаемся на ленту и пересоздаём её — новый пост подгрузится.
      setState(() {
        _tab = 0;
        _feedVisits++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ключ меняется при каждом входе на вкладку «Лента» — экран
    // пересоздаётся и заново подгружает посты.
    final tabs = [
      FeedScreen(key: ValueKey('feed-$_feedVisits')),
      const GamesScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkField : AppColors.lightField,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                _navItem(
                  0,
                  Icons.dynamic_feed_outlined,
                  Icons.dynamic_feed,
                  'Лента',
                ),
                _navItem(
                  1,
                  Icons.sports_esports_outlined,
                  Icons.sports_esports,
                  'Развлечения',
                ),
                const SizedBox(width: 64),
                _navItem(
                  2,
                  Icons.chat_bubble_outline,
                  Icons.chat_bubble,
                  'Сообщения',
                  badge: true,
                ),
                _navItem(3, Icons.person_outline, Icons.person, 'Профиль'),
              ],
            ),
          ),
          Positioned(
            top: -20,
            child: SizedBox(
              width: 58,
              height: 58,
              child: FloatingActionButton(
                onPressed: _createPost,
                backgroundColor: AppColors.coral,
                elevation: 0,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 30, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label, {
    bool badge = false,
  }) {
    final selected = _tab == index;
    final color = selected
        ? AppColors.coral
        : Theme.of(context)
            .textTheme
            .bodyMedium
            ?.color
            ?.withValues(alpha: 0.55);

    Widget iconWidget = Icon(selected ? selectedIcon : icon, color: color);
    if (badge) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: iconWidget,
          ),
          if (_unread > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          if (index == 0) _feedVisits++;
          _tab = index;
        }),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
