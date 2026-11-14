import 'package:material_ui/material_ui.dart';

import 'feed_screen.dart';

class PostViewScreen extends StatelessWidget {
  const PostViewScreen({super.key, required this.post});

  final Map<String, dynamic> post;

  int _countOf(String key) {
    final value = post[key];
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пост'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PostCard(
          post: post,
          likesCount: _countOf('likes'),
          commentsCount: _countOf('comments'),
          liked: false,
          inDetail: true,
        ),
      ),
    );
  }
}
