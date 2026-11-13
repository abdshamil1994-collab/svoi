import 'package:flutter/foundation.dart' show Uint8List;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController =
      TextEditingController(text: widget.profile['username'] as String? ?? '');
  late final TextEditingController _bioController =
      TextEditingController(text: widget.profile['bio'] as String? ?? '');
  Uint8List? _newAvatarBytes;
  bool _loading = false;
  String? _errorText;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите никнейм';
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(v)) {
      return 'От 3 до 20 символов: латиница, цифры и подчёркивание';
    }
    return null;
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
    setState(() => _newAvatarBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });

    final uid = _client.auth.currentUser!.id;
    final username = _usernameController.text.trim();

    try {
      // Проверка уникальности ника.
      final taken = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', uid)
          .maybeSingle();
      if (taken != null) {
        setState(() {
          _loading = false;
          _errorText = 'Ник занят';
        });
        return;
      }

      String? avatarUrl;
      if (_newAvatarBytes != null) {
        final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from('avatars').uploadBinary(
              path,
              _newAvatarBytes!,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );
        avatarUrl = _client.storage.from('avatars').getPublicUrl(path);
      }

      await _client.from('profiles').update({
        'username': username,
        'bio': _bioController.text.trim(),
        'avatar_url': ?avatarUrl,
      }).eq('id', uid);

      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _errorText = e.code == '23505'
            ? 'Ник занят'
            : 'Не удалось сохранить. Выполните миграцию 004 (колонка bio)';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Не удалось сохранить профиль. Попробуйте ещё раз';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = widget.profile['avatar_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickAvatar,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                    backgroundImage: _newAvatarBytes != null
                        ? MemoryImage(_newAvatarBytes!)
                        : (avatarUrl != null ? NetworkImage(avatarUrl) : null)
                            as ImageProvider?,
                    child: _newAvatarBytes == null && avatarUrl == null
                        ? const Icon(Icons.add_a_photo_outlined,
                            size: 30, color: AppColors.coral)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Нажмите, чтобы сменить фото',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                enabled: !_loading,
                decoration: const InputDecoration(hintText: 'Никнейм'),
                validator: _validateUsername,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                enabled: !_loading,
                maxLength: 150,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'О себе',
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: 16),
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
    );
  }
}
