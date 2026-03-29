import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loveell/models/user_model.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

enum VideoQuality {
  low,
  medium,
  high,
}

class LiveDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const LiveDashboardScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<String> _friendsList = [];
  bool _isLoadingFriends = true;

  // Stream data cache
  final Map<String, Map<String, dynamic>> _streamDataCache = {};

  // TikTok-style color palette
  static const Color _backgroundColor = Color(0xFF000000);
  static const Color _surfaceColor = Color(0xFF1A1A1A);
  static const Color _accentColor = Color(0xFFFE2C55); // TikTok red
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0B0B0);

  // ZegoCloud credentials
  static const int _appID = 938333820;
  static const String _appSign =
      "6327dff6d8fc975e4409688c3aac8145bf0cdf30302f8e7223602637cd1a8c63";

  @override
  void initState() {
    super.initState();
    _loadFriendsList();
  }

  Future<void> _loadFriendsList() async {
    try {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.uid)
          .collection('friends')
          .get();

      if (mounted) {
        setState(() {
          _friendsList = friendsSnapshot.docs.map((doc) => doc.id).toList();
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends list: $e');
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Stream<QuerySnapshot> _getFriendsLiveStreams() {
    if (_friendsList.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('live_rooms')
        .where('status', isEqualTo: 'broadcasting')
        .where('broadcasterId', whereIn: _friendsList)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoadingFriends
          ? _buildLoadingState()
          : _friendsList.isEmpty
              ? _buildNoFriendsState()
              : _buildStreamContent(),
      floatingActionButton: _buildGoLiveButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStreamContent() {
    return RefreshIndicator(
      onRefresh: _refreshStreams,
      color: _accentColor,
      backgroundColor: _surfaceColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: _getFriendsLiveStreams(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final liveStreams = snapshot.data!.docs;
          _updateStreamCache(liveStreams);

          return CustomScrollView(
            slivers: [
              // TikTok-style header
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: _backgroundColor.withOpacity(0.95),
                elevation: 0,
                title: const Row(
                  children: [
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: _textPrimary),
                    onPressed: _searchStreams,
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: _textPrimary),
                    onPressed: _openNotifications,
                  ),
                ],
              ),

              // Live streams count indicator
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${liveStreams.length} Live Now',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // Live streams grid (TikTok style - 2 columns)
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = liveStreams[index];
                      final data = _streamDataCache[doc.id] ??
                          (doc.data() as Map<String, dynamic>);
                      return _buildLiveStreamCard(doc.id, data);
                    },
                    childCount: liveStreams.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveStreamCard(String roomId, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => _navigateToLiveStream(roomId, data),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live thumbnail with overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[900],
                    child: _buildThumbnail(data),
                  ),
                ),

                // Live badge and viewer count
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Viewer count with TikTok format
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatViewerCount(data['viewerCount'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Stream info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['streamTitle'] ?? 'Live Stream',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[700],
                        backgroundImage: data['broadcasterProfileImage'] != null
                            ? MemoryImage(
                                base64Decode(data['broadcasterProfileImage']))
                            : null,
                        child: data['broadcasterProfileImage'] == null
                            ? Text(
                                data['broadcasterName']
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['broadcasterName'] ?? 'Anonymous',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Map<String, dynamic> data) {
    // Show live preview style thumbnail
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.live_tv,
              color: Colors.red,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.red.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Future<void> _refreshStreams() async {
    setState(() {});
  }

  void _searchStreams() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 300,
        child: Column(
          children: [
            const Text(
              'Search Live Streams',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accentColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Popular Live Streams',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('Streamer Name',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('1.2K viewers',
                      style: TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _accentColor,
      ),
    );
  }

  void _navigateToLiveStream(String roomId, Map<String, dynamic> data) {
    final safeUserID =
        widget.currentUser.uid.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final safeRoomID = roomId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final safeUserName =
        widget.currentUser.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

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
  }

  void _updateStreamCache(List<QueryDocumentSnapshot> newStreams) {
    for (final doc in newStreams) {
      if (!_streamDataCache.containsKey(doc.id)) {
        _streamDataCache[doc.id] = doc.data() as Map<String, dynamic>;
      }
    }

    final currentIds = newStreams.map((doc) => doc.id).toSet();
    _streamDataCache.removeWhere((key, _) => !currentIds.contains(key));
  }

  Widget _buildGoLiveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFE2C55), Color(0xFFF25F5C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFE2C55).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startLiveStream,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Go Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startLiveStream() async {
    final roomId = DateTime.now().millisecondsSinceEpoch.toString();
    final validRoomId = roomId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final streamTitle = '${widget.currentUser.name}\'s Stream';

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: _accentColor,
          ),
        ),
      );

      // Create the live room in Firestore
      await FirebaseFirestore.instance
          .collection('live_rooms')
          .doc(validRoomId)
          .set({
        'broadcasterId': widget.currentUser.uid,
        'broadcasterName': widget.currentUser.name,
        'broadcasterProfileImage': widget.currentUser.profileImageBase64,
        'streamTitle': streamTitle,
        'description': '',
        'status': 'broadcasting',
        'createdAt': FieldValue.serverTimestamp(),
        'viewerCount': 0,
        'videoQuality': 'medium',
        'resolution': '720p',
      });

      // Send notifications to all friends
      await _sendLiveNotifications(validRoomId, streamTitle);

      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Navigate to Zego live stream screen as host
      if (mounted) {
        final safeUserID =
            widget.currentUser.uid.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final safeRoomID =
            validRoomId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final safeUserName =
            widget.currentUser.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

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
                config: ZegoUIKitPrebuiltLiveStreamingConfig.host(),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if showing
      if (mounted) {
        Navigator.pop(context);
      }

      debugPrint('Error creating live stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start stream: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Method to send notifications to all friends
  Future<void> _sendLiveNotifications(String roomId, String streamTitle) async {
    try {
      // Get all friends
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.uid)
          .collection('friends')
          .get();

      if (friendsSnapshot.docs.isEmpty) {
        debugPrint('No friends to notify');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      // Create notification for each friend
      for (final friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.id;
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .collection('notifications')
            .doc(); // Auto-generate ID

        batch.set(notificationRef, {
          'type': 'live_stream',
          'title': 'Live Stream Started',
          'body': '${widget.currentUser.name} is now live: $streamTitle',
          'roomId': roomId,
          'broadcasterId': widget.currentUser.uid,
          'broadcasterName': widget.currentUser.name,
          'broadcasterProfileImage': widget.currentUser.profileImageBase64,
          'streamTitle': streamTitle,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
      debugPrint(
          'Sent live stream notifications to ${friendsSnapshot.docs.length} friends');
    } catch (e) {
      debugPrint('Error sending live notifications: $e');
      // Don't throw - we don't want to stop the stream if notifications fail
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: _accentColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Finding live streams...',
            style: TextStyle(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: _accentColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load streams',
            style: TextStyle(color: _textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: _textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshStreams,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFriendsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: _textSecondary,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Friends Yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Connect with friends to see their live streams',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Find Friends feature coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Find Friends'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: _textSecondary,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Live Streams',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When your friends go live, they\'ll appear here',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshStreams,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
