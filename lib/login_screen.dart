import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateLogin(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите email или телефон';
    if (v.contains('@')) {
      final emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(v);
      if (!emailOk) return 'Некорректный email';
    } else {
      final digits = v.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Некорректный номер телефона';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Введите пароль';
    if (v.length < 8) return 'Пароль должен содержать минимум 8 символов';
    return null;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вход выполнен (демо)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                (constraints.maxWidth * 0.08).clamp(20.0, 48.0);
            final topGap = (constraints.maxHeight * 0.08).clamp(24.0, 96.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topGap),
                          const Center(child: RingsLogo(size: 96)),
                          const SizedBox(height: 12),
                          Text(
                            'SVOI',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 28,
                              letterSpacing: 6,
                            ),
                          ),
                          SizedBox(height: topGap * 0.7),
                          TextFormField(
                            controller: _loginController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email или телефон',
                            ),
                            validator: _validateLogin,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Пароль',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.5),
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _submit,
                            child: const Text('Войти'),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Забыли пароль?'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'или',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Создать аккаунт'),
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: GestureDetector(
                              onTap: () {},
                              child: Text(
                                'Политика конфиденциальности',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkText.withValues(alpha: 0.55)
                                      : AppColors.lightText.withValues(alpha: 0.55),
                                  decoration: TextDecoration.underline,
                                  decorationColor: isDark
                                      ? AppColors.darkText.withValues(alpha: 0.55)
                                      : AppColors.lightText.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class RingsLogo extends StatelessWidget {
  const RingsLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RingsPainter(color: AppColors.coral),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final radius = size.width * 0.27;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final c1 = Offset(size.width * 0.37, size.height * 0.5);
    final c2 = Offset(size.width * 0.63, size.height * 0.5);

    // Первое кольцо целиком.
    canvas.drawCircle(c1, radius, paint);
    // Второе кольцо целиком — поверх первого.
    canvas.drawCircle(c2, radius, paint);

    // Перерисовываем дугу первого кольца в нижней точке пересечения,
    // чтобы кольца выглядели переплетёнными.
    final d = (c2 - c1).distance;
    final angle = math.acos((d / 2) / radius);
    canvas.drawArc(
      Rect.fromCircle(center: c1, radius: radius),
      angle - 0.28,
      0.56,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.color != color;
}
