import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'stories_bar.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialIndex,
  });

  final List<StoryGroup> groups;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _userIndex = widget.initialIndex;
  int _storyIndex = 0;
  late final AnimationController _progress;
  VideoPlayerController? _video;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  StoryGroup get _group => widget.groups[_userIndex];
  Map<String, dynamic> get _story => _group.stories[_storyIndex];
  bool get _isVideo => _story['media_type'] == 'video';
  bool get _isMine => _group.userId == _uid;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _startStory();
  }

  @override
  void dispose() {
    _progress.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _markViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final viewed = (prefs.getStringList('viewed_stories') ?? []).toSet()
      ..add(_story['id'] as String);
    await prefs.setStringList('viewed_stories', viewed.toList());
  }

  void _startStory() {
    _video?.dispose();
    _video = null;
    _markViewed();

    if (_isVideo) {
      _progress.duration = const Duration(seconds: 15);
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(_story['media_url']));
      _video = controller;
      controller.initialize().then((_) {
        if (!mounted || _video != controller) return;
        final duration = controller.value.duration;
        _progress.duration = duration < const Duration(seconds: 15)
            ? duration
            : const Duration(seconds: 15);
        setState(() {});
        controller.play();
        _progress.forward(from: 0);
      }).catchError((_) => _next());
    } else {
      _progress.duration = const Duration(seconds: 5);
      _progress.forward(from: 0);
    }
  }

  void _next() {
    if (_storyIndex < _group.stories.length - 1) {
      setState(() => _storyIndex++);
      _startStory();
    } else if (_userIndex < widget.groups.length - 1) {
      setState(() {
        _userIndex++;
        _storyIndex = 0;
      });
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startStory();
    } else if (_userIndex > 0) {
      setState(() {
        _userIndex--;
        _storyIndex = widget.groups[_userIndex].stories.length - 1;
      });
      _startStory();
    }
  }

  Future<void> _deleteStory() async {
    try {
      await _client.from('stories').delete().eq('id', _story['id']);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _group.stories.removeAt(_storyIndex));
    if (_group.stories.isEmpty) {
      Navigator.of(context).pop();
    } else {
      if (_storyIndex >= _group.stories.length) {
        _storyIndex = _group.stories.length - 1;
      }
      _startStory();
    }
  }

  void _onTap(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < width / 3) {
      _previous();
    } else {
      _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onTap,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: _buildMedia()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          for (var i = 0; i < _group.stories.length; i++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: i == _storyIndex
                                    ? AnimatedBuilder(
                                        animation: _progress,
                                        builder: (_, _) =>
                                            LinearProgressIndicator(
                                          value: _progress.value,
                                          minHeight: 2.5,
                                          backgroundColor: Colors.white24,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  Colors.white),
                                        ),
                                      )
                                    : Container(
                                        height: 2.5,
                                        color: i < _storyIndex
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            backgroundImage: _group.avatarUrl != null
                                ? NetworkImage(_group.avatarUrl!)
                                : null,
                            child: _group.avatarUrl == null
                                ? const Icon(Icons.person_outline,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _group.username,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isMine)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                              onPressed: _deleteStory,
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (_isVideo) {
      final video = _video;
      if (video != null && video.value.isInitialized) {
        return AspectRatio(
          aspectRatio: video.value.aspectRatio,
          child: VideoPlayer(video),
        );
      }
      return const CircularProgressIndicator(color: Colors.white);
    }
    return Image.network(
      _story['media_url'],
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const CircularProgressIndicator(color: Colors.white);
      },
    );
  }
}
