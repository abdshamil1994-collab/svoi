import 'package:flutter/foundation.dart' show Uint8List;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  Uint8List? _imageBytes;
  bool _loading = false;
  String? _errorText;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Напишите текст поста');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final uid = _client.auth.currentUser!.id;
      String? imageUrl;

      if (_imageBytes != null) {
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from('post-images').uploadBinary(
              path,
              _imageBytes!,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );
        imageUrl = _client.storage.from('post-images').getPublicUrl(path);
      }

      await _client.from('posts').insert({
        'user_id': uid,
        'text': text,
        'image_url': imageUrl,
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorText = 'Не удалось опубликовать пост. Попробуйте ещё раз');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый пост'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              enabled: !_loading,
              maxLength: 1000,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Что нового?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!,
                        width: double.infinity, fit: BoxFit.cover),
                  ),
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _imageBytes = null),
                    icon: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Добавить фото'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                ),
              ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 13.5),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _publish,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Опубликовать'),
            ),
          ],
        ),
      ),
    );
  }
}
