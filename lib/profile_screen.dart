import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _profileFuture = _loadProfile();
  bool _avatarUploading = false;

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> _loadProfile() {
    final uid = _client.auth.currentUser!.id;
    return _client
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', uid)
        .maybeSingle();
  }

  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final uid = _client.auth.currentUser!.id;
      // Уникальное имя файла — чтобы не было проблем с кэшем CDN.
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      await _client
          .from('profiles')
          .update({'avatar_url': url}).eq('id', uid);
      if (mounted) {
        setState(() => _profileFuture = _loadProfile());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить фото. Попробуйте ещё раз'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _client.auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data;
            final username = profile?['username'] as String? ?? '';
            final avatarUrl = profile?['avatar_url'] as String?;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _avatarUploading ? null : _changeAvatar,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor:
                              AppColors.coral.withValues(alpha: 0.12),
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? const Icon(Icons.person_outline,
                                  size: 40, color: AppColors.coral)
                              : null,
                        ),
                        if (_avatarUploading)
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: AppColors.coral,
                            ),
                          ),
                        if (!_avatarUploading)
                          const Positioned(
                            right: 2,
                            bottom: 2,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: AppColors.coral,
                              child: Icon(Icons.photo_camera_outlined,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Нажмите, чтобы сменить фото',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: _signOut,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text('Выйти'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
