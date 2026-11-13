import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

class SimpleSubScreen extends StatelessWidget {
  const SimpleSubScreen({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: body,
    );
  }
}

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleSubScreen(
      title: 'Баланс',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              '0 монет',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Скоро расскажем, как заработать монеты'),
                    ),
                  );
                },
                child: const Text('Как заработать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.posts,
    required this.likesReceived,
    required this.commentsReceived,
    required this.likesGiven,
  });

  final int posts;
  final int likesReceived;
  final int commentsReceived;
  final int likesGiven;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      ('Посты', posts, Icons.dynamic_feed_outlined),
      ('Лайков получено', likesReceived, Icons.favorite_outline),
      ('Комментариев получено', commentsReceived, Icons.chat_bubble_outline),
      ('Лайков поставлено', likesGiven, Icons.thumb_up_outlined),
    ];

    return SimpleSubScreen(
      title: 'Статистика',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (label, value, icon) = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkField : AppColors.lightField,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.coral),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.onOpenSite});

  final VoidCallback onOpenSite;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.55);

    return SimpleSubScreen(
      title: 'О приложении',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('SVOI',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6)),
            const SizedBox(height: 8),
            Text('Версия 1.0.0', style: TextStyle(color: muted)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onOpenSite,
              child: const Text(
                'svoi.iibotnev.ru',
                style: TextStyle(
                  color: AppColors.coral,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.coral,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
