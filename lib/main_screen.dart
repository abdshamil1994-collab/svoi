import 'package:material_ui/material_ui.dart';

import 'feed_screen.dart';
import 'games_screen.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  int _feedVisits = 0;

  @override
  Widget build(BuildContext context) {
    // Ключ меняется при каждом входе на вкладку «Лента» — экран
    // пересоздаётся и заново подгружает посты.
    final tabs = [
      FeedScreen(key: ValueKey('feed-$_feedVisits')),
      const GamesScreen(),
      const PlaceholderScreen(title: 'Сообщения'),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          if (i == 0) _feedVisits++;
          _tab = i;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Развлечения',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Сообщения',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
