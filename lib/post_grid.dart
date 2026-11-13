import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'post_view_screen.dart';

class PostsGrid extends StatelessWidget {
  const PostsGrid({
    super.key,
    required this.posts,
    required this.emptyText,
  });

  final List<Map<String, dynamic>>? posts;
  final String emptyText;

  static int likesCount(Map<String, dynamic> post) {
    final likes = post['likes'];
    if (likes is List && likes.isNotEmpty && likes.first is Map) {
      return (likes.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.5);

    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_on_outlined, size: 36, color: muted),
            const SizedBox(height: 10),
            Text(emptyText, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: posts!.length,
      itemBuilder: (context, i) {
        final post = posts![i];
        final imageUrl = post['image_url'] as String?;
        final videoUrl = post['video_url'] as String?;

        Widget cell;
        if (imageUrl != null) {
          cell = Image.network(imageUrl, fit: BoxFit.cover);
        } else if (videoUrl != null) {
          cell = Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  '▶ ${likesCount(post)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        } else {
          cell = Container(
            color: AppColors.coral.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(10),
            child: Text(
              post['text'] as String? ?? '',
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostViewScreen(post: post)),
          ),
          child: ClipRect(child: cell),
        );
      },
    );
  }
}
