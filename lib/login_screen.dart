import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorText;

  SupabaseClient get _auth => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите email';
    final emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(v);
    if (!emailOk) return 'Некорректный email';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Введите пароль';
    if (v.length < 8) return 'Пароль должен содержать минимум 8 символов';
    return null;
  }

  String _mapAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Неверный email или пароль';
      }
      if (msg.contains('email not confirmed')) {
        return 'Email не подтверждён. Проверьте почту и перейдите по ссылке из письма';
      }
      if (msg.contains('user already registered')) {
        return 'Пользователь с таким email уже зарегистрирован';
      }
      if (msg.contains('password')) {
        return 'Пароль слишком простой — придумайте надёжнее';
      }
      if (msg.contains('rate limit')) {
        return 'Слишком много попыток. Подождите немного и повторите';
      }
      return 'Ошибка авторизации: ${error.message}';
    }
    return 'Нет соединения с сервером. Проверьте интернет и повторите';
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _errorText = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await _runAuth(() async {
      await _auth.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) _goNext();
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    await _runAuth(() async {
      final response = await _auth.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session != null) {
        _goNext();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аккаунт создан. Подтвердите email по ссылке из письма'),
          ),
        );
      }
    });
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
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_loading,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !_loading,
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
                          if (_errorText != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _loading ? null : _signIn,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Войти'),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : () {},
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
                            onPressed: _loading ? null : _signUp,
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
