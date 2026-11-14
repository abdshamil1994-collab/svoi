import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

const _questions = [
  'Какое твоё самое смешное детское воспоминание?',
  'Если бы ты мог ужинать с любым человеком, кто бы это был?',
  'Какая песня всегда поднимает тебе настроение?',
  'Что бы ты делал, если бы выиграл миллион?',
  'Твоё самое неловкое свидание?',
  'Какой фильм ты можешь пересматривать бесконечно?',
  'Если бы у тебя была суперсила, какая?',
  'Что из еды ты не понимаешь, как едят другие?',
  'Твоё идеальное утро выходного?',
  'Какой самый странный подарок ты получал(а)?',
  'Куда бы ты отправился(ась) прямо сейчас?',
  'Какой у тебя скрытый талант?',
  'Что ты откладываешь уже год?',
  'Каким персонажем игры ты был(а) бы?',
  'Лучший совет, который тебе давали?',
  'Что ты делаешь, когда никто не видит?',
  'Твой самый большой страх в детстве?',
  'Какой предмет в школе ты любил(а) больше всех?',
  'Если бы день длился 30 часов, на что бы ушли лишние 6?',
  'Что бы ты сказал(а) себе 10 лет назад?',
  'Какой запах вызывает ностальгию?',
  'Твой самый запоминающийся отпуск?',
  'Чай или кофе? И почему?',
  'Какой мем лучше всего описывает твою неделю?',
];

class _GameScaffold extends StatelessWidget {
  const _GameScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

// --- Случайный вопрос ---

class RandomQuestionScreen extends StatefulWidget {
  const RandomQuestionScreen({super.key});

  @override
  State<RandomQuestionScreen> createState() => _RandomQuestionScreenState();
}

class _RandomQuestionScreenState extends State<RandomQuestionScreen> {
  final _rnd = Random();
  late String _question = _questions[_rnd.nextInt(_questions.length)];

  void _next() {
    setState(() {
      String next;
      do {
        next = _questions[_rnd.nextInt(_questions.length)];
      } while (next == _question);
      _question = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GameScaffold(
      title: 'Случайный вопрос',
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_question),
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkField : AppColors.lightField,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Text(
                _question,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _BigButton(label: 'Ещё вопрос', onPressed: _next),
        ],
      ),
    );
  }
}

// --- Кто первый? ---

class WhoFirstScreen extends StatefulWidget {
  const WhoFirstScreen({super.key});

  @override
  State<WhoFirstScreen> createState() => _WhoFirstScreenState();
}

class _WhoFirstScreenState extends State<WhoFirstScreen> {
  final _nameController = TextEditingController();
  final _names = <String>[];
  String? _current;
  String? _winner;
  bool _spinning = false;
  Timer? _timer;

  @override
  void dispose() {
    _nameController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _addName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _names.add(name);
      _nameController.clear();
      _winner = null;
      _current = null;
    });
  }

  void _spin() {
    if (_names.length < 2 || _spinning) return;
    setState(() {
      _spinning = true;
      _winner = null;
    });
    var ticks = 0;
    final rnd = Random();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      setState(() => _current = _names[rnd.nextInt(_names.length)]);
      ticks++;
      if (ticks >= 18) {
        timer.cancel();
        setState(() {
          _winner = _current;
          _spinning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.55);

    return _GameScaffold(
      title: 'Кто первый?',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Имя'),
                  onSubmitted: (_) => _addName(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addName,
                icon: const Icon(Icons.add_circle, color: AppColors.coral),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_names.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Добавьте минимум два имени',
                  style: TextStyle(color: muted)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _names)
                  Chip(
                    label: Text(name),
                    onDeleted: _spinning
                        ? null
                        : () => setState(() => _names.remove(name)),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            child: Text(
              _current ?? (_winner ?? '🎲'),
              key: ValueKey('$_current-$_spinning'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _winner != null ? AppColors.coral : null,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _BigButton(
            label: _spinning ? 'Выбираем...' : 'Кто первый?',
            onPressed: _spinning ? null : _spin,
          ),
        ],
      ),
    );
  }
}

// --- Бросить кубик ---

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> {
  static const _faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
  final _rnd = Random();
  String _face = '🎲';
  int? _value;
  bool _rolling = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _roll() {
    if (_rolling) return;
    setState(() => _rolling = true);
    var ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      setState(() {
        _face = _faces[_rnd.nextInt(6)];
        _value = null;
      });
      ticks++;
      if (ticks >= 14) {
        timer.cancel();
        final v = _rnd.nextInt(6);
        setState(() {
          _face = _faces[v];
          _value = v + 1;
          _rolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Бросить кубик',
      child: Column(
        children: [
          AnimatedScale(
            scale: _rolling ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Text(_face, style: const TextStyle(fontSize: 110)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 28,
            child: _value != null
                ? Text(
                    'Выпало: $_value',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          _BigButton(
            label: _rolling ? 'Катится...' : 'Бросить кубик',
            onPressed: _rolling ? null : _roll,
          ),
        ],
      ),
    );
  }
}
