import 'package:flutter/foundation.dart' show Uint8List;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'main_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  Uint8List? _avatarBytes;
  bool _loading = false;
  String? _errorText;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Придумайте никнейм';
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(v)) {
      return 'От 3 до 20 символов: латиница, цифры и подчёркивание';
    }
    return null;
  }

  String _mapError(Object error) {
    if (error is PostgrestException && error.code == '23505') {
      return 'Этот никнейм уже занят';
    }
    if (error is StorageException) {
      return 'Не удалось загрузить аватар. Попробуйте другое изображение';
    }
    return 'Не удалось сохранить профиль. Проверьте интернет и повторите';
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final uid = _client.auth.currentUser!.id;
      String? avatarUrl;

      if (_avatarBytes != null) {
        final path = '$uid/avatar.jpg';
        await _client.storage.from('avatars').uploadBinary(
              path,
              _avatarBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        avatarUrl = _client.storage.from('avatars').getPublicUrl(path);
      }

      await _client.from('profiles').insert({
        'id': uid,
        'username': _usernameController.text.trim(),
        'avatar_url': avatarUrl,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _errorText = _mapError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Создайте профиль',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: GestureDetector(
                        onTap: _loading ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor:
                              AppColors.coral.withValues(alpha: 0.12),
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : null,
                          child: _avatarBytes == null
                              ? const Icon(Icons.add_a_photo_outlined,
                                  size: 32, color: AppColors.coral)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Фото профиля',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_loading,
                      decoration: const InputDecoration(hintText: 'Никнейм'),
                      validator: _validateUsername,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
