// screens/stories/stories_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/user_model.dart';

class StoriesScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function({
    int? totalUnreadMessages,
    int? unreadNotificationsCount,
    int? unreadStoriesCount,
  }) onCountsUpdated;

  const StoriesScreen({
    super.key,
    required this.currentUser,
    required this.onCountsUpdated,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen>
    with TickerProviderStateMixin {
  late UserModel currentUser;
  bool _isDarkMode = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> stories = [];
  List<UserModel> friends = [];

  // Modern color palette
  static const Color _primary = Color(0xFFE91E63); // LoveELL pink
  static const Color _primaryLight = Color(0xFFFF80AB);
  static const Color _onlineGreen = Color(0xFF31A24C);

  late AnimationController _storyAnimationController;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get _textColor =>
      _isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get _secondaryTextColor =>
      _isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF666666);

  LinearGradient get _primaryGradient => LinearGradient(
        colors: [_primary, _primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _storyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _loadData();
  }

  Future<void> _loadData() async {
    await _loadFriends();
    await _loadStories();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadFriends() async {
    try {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .get();

      List<UserModel> loadedFriends = [];

      for (var friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.data()['friendId'] as String? ?? '';
        if (friendId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();

          if (userDoc.exists) {
            loadedFriends.add(
              UserModel.fromMap(userDoc.data() as Map<String, dynamic>),
            );
          }
        }
      }

      setState(() {
        friends = loadedFriends;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> _loadStories() async {
    if (friends.isEmpty) return;

    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', whereIn: friends.map((f) => f.uid).toList())
          .where('timestamp', isGreaterThan: yesterday)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> loadedStories = [];

      for (var doc in storiesSnapshot.docs) {
        final storyData = doc.data();
        storyData['id'] = doc.id;

        // Get user info
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(storyData['userId'])
            .get();

        if (userDoc.exists) {
          storyData['user'] =
              UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
          loadedStories.add(storyData);
        }
      }

      setState(() {
        stories = loadedStories;
      });

      // Update unread stories count
      int unreadCount = 0;
      for (var story in loadedStories) {
        final viewedBy = List<String>.from(story['viewedBy'] ?? []);
        if (!viewedBy.contains(currentUser.uid)) {
          unreadCount++;
        }
      }
      widget.onCountsUpdated(unreadStoriesCount: unreadCount);
    } catch (e) {
      debugPrint('Error loading stories: $e');
    }
  }

  Future<void> _markStoryAsViewed(String storyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
        'viewedBy': FieldValue.arrayUnion([currentUser.uid])
      });

      // Update counts after marking as viewed
      _loadStories();
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  void _toggleDarkMode() {
    HapticFeedback.lightImpact();
    setState(() => _isDarkMode = !_isDarkMode);
  }

  void _createStory() {
    HapticFeedback.lightImpact();
    // TODO: Implement story creation (camera/gallery picker)
    _showComingSoon('Story Creation');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: ShaderMask(
          shaderCallback: (bounds) => _primaryGradient.createShader(bounds),
          child: const Text(
            'Stories',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: _primary,
            onPressed: _createStory,
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            color: _isDarkMode ? Colors.white : Colors.black87,
            onPressed: _toggleDarkMode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading stories...',
                    style: TextStyle(color: _secondaryTextColor),
                  ),
                ],
              ),
            )
          : stories.isEmpty
              ? _buildEmptyState()
              : _buildStoriesList(),
    );
  }

  Widget _buildStoriesList() {
    // Group stories by user
    Map<String, List<Map<String, dynamic>>> userStories = {};
    for (var story in stories) {
      final userId = story['userId'];
      if (!userStories.containsKey(userId)) {
        userStories[userId] = [];
      }
      userStories[userId]!.add(story);
    }

    return RefreshIndicator(
      onRefresh: _loadStories,
      color: _primary,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: userStories.length,
        itemBuilder: (context, index) {
          final userId = userStories.keys.elementAt(index);
          final userStoriesList = userStories[userId]!;
          final user = userStoriesList.first['user'] as UserModel;
          final hasUnviewed = userStoriesList
              .any((s) => !(s['viewedBy'] as List).contains(currentUser.uid));

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 30)),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  _showStoryViewer(user, userStoriesList);
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // User avatar with story ring
                      Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: hasUnviewed ? _primaryGradient : null,
                              color: hasUnviewed ? null : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                backgroundColor: _surfaceColor,
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: hasUnviewed ? _primary : Colors.grey,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (user.isOnline)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _onlineGreen,
                                  border: Border.all(
                                      color: _surfaceColor, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${userStoriesList.length} story${userStoriesList.length > 1 ? 's' : ''} • ${_getTimeAgo(userStoriesList.first['timestamp'].toDate())}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // View indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: hasUnviewed ? _primaryGradient : null,
                          color: hasUnviewed ? null : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasUnviewed ? 'New' : 'Viewed',
                          style: TextStyle(
                            color: hasUnviewed
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStoryViewer(UserModel user, List<Map<String, dynamic>> stories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoryViewer(
        user: user,
        stories: stories,
        currentUserId: currentUser.uid,
        onStoryViewed: _markStoryAsViewed,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 60,
                color: _primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Stories Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When your friends post stories,\nthey will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _secondaryTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createStory,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Your First Story'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _storyAnimationController.dispose();
    super.dispose();
  }
}

// Story Viewer Widget
class StoryViewer extends StatefulWidget {
  final UserModel user;
  final List<Map<String, dynamic>> stories;
  final String currentUserId;
  final Function(String) onStoryViewed;

  const StoryViewer({
    super.key,
    required this.user,
    required this.stories,
    required this.currentUserId,
    required this.onStoryViewed,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward().whenComplete(_nextStory);

    // Mark first story as viewed
    _markCurrentAsViewed();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _progressController.reset();
        _progressController.forward().whenComplete(_nextStory);
        _markCurrentAsViewed();
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progressController.reset();
        _progressController.forward().whenComplete(_nextStory);
        _markCurrentAsViewed();
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _markCurrentAsViewed() {
    final storyId = widget.stories[_currentIndex]['id'];
    final viewedBy =
        List<String>.from(widget.stories[_currentIndex]['viewedBy'] ?? []);

    if (!viewedBy.contains(widget.currentUserId)) {
      widget.onStoryViewed(storyId);
    }
  }

  void _pauseStory() {
    _progressController.stop();
  }

  void _resumeStory() {
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Story content
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.stories.length,
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              // TODO: Display actual story content (image/video)
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_rounded,
                        size: 100,
                        color: Colors.grey.shade800,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Story ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story['text'] ?? 'No caption',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Progress bars
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(widget.stories.length, (index) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 3,
                    child: index == _currentIndex
                        ? LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          )
                        : Container(
                            color: index < _currentIndex
                                ? Colors.white
                                : Colors.white24,
                          ),
                  ),
                );
              }),
            ),
          ),

          // Header
          Positioned(
            top: 50,
            left: 10,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade800,
                  child: Text(
                    widget.user.name.isNotEmpty
                        ? widget.user.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getTimeAgo(
                          widget.stories[_currentIndex]['timestamp'].toDate()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: 50,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Tap areas for navigation
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTapDown: (_) => _pauseStory(),
                    onTapUp: (_) => _resumeStory(),
                    onTapCancel: () => _resumeStory(),
                    onTap: _previousStory,
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: GestureDetector(
                    onTapDown: (_) => _pauseStory(),
                    onTapUp: (_) => _resumeStory(),
                    onTapCancel: () => _resumeStory(),
                    onTap: _nextStory,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTapDown: (_) => _pauseStory(),
                    onTapUp: (_) => _resumeStory(),
                    onTapCancel: () => _resumeStory(),
                    onTap: _nextStory,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }
}
