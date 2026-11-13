import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

enum _Mode { friend, ai }

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  static const _x = '❌';
  static const _o = '⭕';

  List<String> _board = List.filled(9, '');
  _Mode _mode = _Mode.friend;
  String _turn = _x;
  String? _winner; // '❌' | '⭕' | 'draw'

  void _reset([_Mode? mode]) {
    setState(() {
      _board = List.filled(9, '');
      _turn = _x;
      _winner = null;
      if (mode != null) _mode = mode;
    });
  }

  String? _checkWinner(List<String> b) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final v = b[line[0]];
      if (v != '' && v == b[line[1]] && v == b[line[2]]) return v;
    }
    return b.every((c) => c != '') ? 'draw' : null;
  }

  int _aiMove(List<String> b) {
    final rnd = Random();
    // Выиграть, если можно.
    for (var i = 0; i < 9; i++) {
      if (b[i] == '') {
        b[i] = _o;
        if (_checkWinner(b) == _o) return i;
        b[i] = '';
      }
    }
    // Блокировать выигрыш соперника.
    for (var i = 0; i < 9; i++) {
      if (b[i] == '') {
        b[i] = _x;
        if (_checkWinner(b) == _x) return i;
        b[i] = '';
      }
    }
    // Центр, затем случайная клетка.
    if (b[4] == '') return 4;
    final free = [for (var i = 0; i < 9; i++) if (b[i] == '') i];
    return free[rnd.nextInt(free.length)];
  }

  void _tap(int i) {
    if (_board[i] != '' || _winner != null) return;
    if (_mode == _Mode.ai && _turn == _o) return;

    setState(() {
      _board[i] = _turn;
      _winner = _checkWinner(_board);
      _turn = _turn == _x ? _o : _x;
    });

    if (_mode == _Mode.ai && _winner == null && _turn == _o) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || _winner != null) return;
        setState(() {
          _board[_aiMove(_board)] = _o;
          _winner = _checkWinner(_board);
          _turn = _x;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    final status = switch (_winner) {
      'draw' => 'Ничья!',
      _x || _o => 'Победил $_winner!',
      _ => 'Ход: $_turn',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Крестики-нолики'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                    value: _Mode.friend,
                    label: Text('С другом'),
                    icon: Icon(Icons.people_outline),
                  ),
                  ButtonSegment(
                    value: _Mode.ai,
                    label: Text('Против ИИ'),
                    icon: Icon(Icons.smart_toy_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _reset(s.first),
              ),
              const SizedBox(height: 20),
              Text(
                status,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkField
                            : AppColors.lightField,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _board[i],
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _reset(),
                icon: const Icon(Icons.refresh),
                label: const Text('Заново'),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _Mode.friend
                    ? 'Играйте по очереди на одном устройстве'
                    : 'Вы играете за ❌',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
