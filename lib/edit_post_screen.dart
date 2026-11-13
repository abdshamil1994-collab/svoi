import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.post['text'] as String? ?? '');
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Текст поста не может быть пустым');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await Supabase.instance.client
          .from('posts')
          .update({'text': text}).eq('id', widget.post['id'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException {
      setState(() {
        _loading = false;
        _errorText = 'Не удалось сохранить. Выполните миграцию 006 '
            '(политика UPDATE для posts)';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Не удалось сохранить. Попробуйте ещё раз';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать пост'),
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
              decoration: const InputDecoration(alignLabelWithHint: true),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 13.5),
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
    );
  }
}
