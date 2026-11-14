import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'party_games.dart';
import 'tictactoe_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Развлечения'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _GameCard(
            emoji: '❌⭕',
            title: 'Крестики-нолики',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TicTacToeScreen()),
            ),
          ),
          _GameCard(
            emoji: '❓',
            title: 'Случайный вопрос',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RandomQuestionScreen()),
            ),
          ),
          _GameCard(
            emoji: '🏁',
            title: 'Кто первый?',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WhoFirstScreen()),
            ),
          ),
          _GameCard(
            emoji: '🎲',
            title: 'Бросить кубик',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiceScreen()),
            ),
          ),
          const _GameCard(emoji: '🏙️', title: 'Города', soon: true),
          const _GameCard(emoji: '🧠', title: 'Викторина', soon: true),
          const _GameCard(emoji: '🎭', title: 'Правда или действие', soon: true),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.emoji,
    required this.title,
    this.soon = false,
    this.onTap,
  });

  final String emoji;
  final String title;
  final bool soon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: soon
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('«$title» появится скоро')),
              )
          : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkField : AppColors.lightField,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (soon) ...[
              const SizedBox(height: 4),
              Text('Скоро', style: TextStyle(fontSize: 12, color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}
