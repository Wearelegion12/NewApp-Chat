import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/user_model.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class NotificationsScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function({
    int? totalUnreadMessages,
    int? unreadNotificationsCount,
    int? unreadStoriesCount,
  }) onCountsUpdated;

  const NotificationsScreen({
    super.key,
    required this.currentUser,
    required this.onCountsUpdated,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late UserModel currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  static const Color _primary = Color(0xFF9C27B0); // Purple
  static const Color _primaryLight = Color(0xFFBA68C8); // Light purple

  // ZegoCloud credentials
  static const int _appID = 938333820;
  static const String _appSign =
      "6327dff6d8fc975e4409688c3aac8145bf0cdf30302f8e7223602637cd1a8c63";

  late AnimationController _notificationAnimationController;

  Color get _bgColor => const Color(0xFFF5F5F5);
  Color get _surfaceColor => const Color(0xFFFFFFFF);
  Color get _textColor => const Color(0xFF000000);
  Color get _secondaryTextColor => const Color(0xFF666666);

  LinearGradient get _primaryGradient => LinearGradient(
        colors: [_primary, _primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _notificationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _loadNotifications();
    _markAllAsRead();
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          notifications = notificationsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoading = false;
        });
      }

      int unreadCount = 0;
      for (var notification in notifications) {
        if (!(notification['isRead'] ?? false)) {
          unreadCount++;
        }
      }
      widget.onCountsUpdated(unreadNotificationsCount: unreadCount);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final unreadSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      widget.onCountsUpdated(unreadNotificationsCount: 0);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      if (mounted) {
        setState(() {
          final index =
              notifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            notifications[index]['isRead'] = true;
          }
        });
      }

      int unreadCount = 0;
      for (var notification in notifications) {
        if (!(notification['isRead'] ?? false)) {
          unreadCount++;
        }
      }
      widget.onCountsUpdated(unreadNotificationsCount: unreadCount);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        setState(() {
          notifications.removeWhere((n) => n['id'] == notificationId);
        });
      }

      int unreadCount = 0;
      for (var notification in notifications) {
        if (!(notification['isRead'] ?? false)) {
          unreadCount++;
        }
      }
      widget.onCountsUpdated(unreadNotificationsCount: unreadCount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    if (!(notification['isRead'] ?? false)) {
      await _markAsRead(notification['id']);
    }

    // Handle different notification types
    final type = notification['type'];

    if (type == 'friend_request') {
      await _handleFriendRequestNotification(notification);
    } else if (type == 'message') {
      await _handleMessageNotification(notification);
    } else if (type == 'like') {
      await _handleLikeNotification(notification);
    } else if (type == 'comment') {
      await _handleCommentNotification(notification);
    } else if (type == 'live_stream') {
      await _handleLiveStreamNotification(notification);
    }
  }

  Future<void> _handleFriendRequestNotification(
      Map<String, dynamic> notification) async {
    // Navigate to friend requests
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend requests feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleMessageNotification(
      Map<String, dynamic> notification) async {
    final chatId = notification['chatId'];
    if (chatId != null) {
      // Navigate to chat screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening chat...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLikeNotification(
      Map<String, dynamic> notification) async {
    final postId = notification['postId'];
    if (postId != null) {
      // Navigate to post
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening post...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCommentNotification(
      Map<String, dynamic> notification) async {
    final postId = notification['postId'];
    if (postId != null) {
      // Navigate to post
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening post...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLiveStreamNotification(
      Map<String, dynamic> notification) async {
    final roomId = notification['roomId'];
    if (roomId != null && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Check if the stream is still live
        final roomDoc = await FirebaseFirestore.instance
            .collection('live_rooms')
            .doc(roomId)
            .get();

        // Dismiss loading dialog
        if (mounted) {
          Navigator.pop(context);
        }

        if (roomDoc.exists && roomDoc.data()?['status'] == 'broadcasting') {
          // Stream is still live, navigate to it
          final safeUserID =
              currentUser.uid.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
          final safeRoomID = roomId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
          final safeUserName =
              currentUser.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                body: ZegoUIKitPrebuiltLiveStreaming(
                  appID: _appID,
                  appSign: _appSign,
                  userID: safeUserID,
                  userName: safeUserName,
                  liveID: safeRoomID,
                  config: ZegoUIKitPrebuiltLiveStreamingConfig.audience(),
                ),
              ),
            ),
          );
        } else {
          // Stream has ended
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This live stream has ended'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
            // Optionally delete the notification since the stream is ended
            await _deleteNotification(notification['id']);
          }
        }
      } catch (e) {
        // Dismiss loading dialog if showing
        if (mounted) {
          Navigator.pop(context);
        }

        debugPrint('Error checking live stream status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to join stream: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAll() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear All'),
        content:
            const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .get();

        for (var doc in notificationsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (mounted) {
          setState(() {
            notifications.clear();
          });
        }

        widget.onCountsUpdated(unreadNotificationsCount: 0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All notifications cleared'),
              backgroundColor: _primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error clearing notifications: $e');
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add_rounded;
      case 'friend_accept':
        return Icons.people_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'call':
        return Icons.call_rounded;
      case 'story':
        return Icons.auto_stories_rounded;
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.comment_rounded;
      case 'live_stream':
        return Icons.live_tv_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'friend_accept':
        return Colors.green;
      case 'message':
        return _primary;
      case 'call':
        return Colors.purple;
      case 'story':
        return Colors.orange;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.teal;
      case 'live_stream':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => _primaryGradient.createShader(bounds),
          child: const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              color: _primary,
              onPressed: _clearAll,
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
                    'Loading notifications...',
                    style: TextStyle(color: _secondaryTextColor),
                  ),
                ],
              ),
            )
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: _primary,
                  backgroundColor: _surfaceColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final timestamp =
                          (notification['timestamp'] as Timestamp).toDate();
                      final isRead = notification['isRead'] ?? false;
                      final type = notification['type'] ?? 'general';

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 30)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(20 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Dismissible(
                          key: Key(notification['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) {
                            _deleteNotification(notification['id']);
                          },
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: () => _handleNotificationTap(notification),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: _surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: !isRead
                                      ? Border.all(color: _primary, width: 1)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _getNotificationColor(type)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getNotificationIcon(type),
                                          color: _getNotificationColor(type),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notification['title'] ??
                                                  'Notification',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                                color: _textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notification['body'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _secondaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _getTimeAgo(timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _secondaryTextColor
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isRead)
                                        TweenAnimationBuilder<double>(
                                          tween:
                                              Tween<double>(begin: 0, end: 1),
                                          duration:
                                              const Duration(milliseconds: 300),
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: _primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
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
                Icons.notifications_rounded,
                size: 60,
                color: _primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When you get notifications,\nthey will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _secondaryTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: _secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationAnimationController.dispose();
    super.dispose();
  }
}
