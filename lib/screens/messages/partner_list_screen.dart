import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loveell/services/auth_service.dart';
import 'package:loveell/services/call_service.dart';
import 'package:loveell/screens/messages/chat_service.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/models/message.dart';
import 'package:loveell/screens/audio_video_call/incoming_call_dialog.dart';
import 'package:loveell/screens/audio_video_call/active_call_screen.dart';
import 'package:loveell/screens/audio_video_call/active_video_call_screen.dart';
import 'package:loveell/screens/friends/friend_requests_screen.dart';
import 'package:loveell/screens/friends/search_users_screen.dart';
import 'package:loveell/screens/messages/chat_screen.dart';
import 'package:loveell/utils/image_converter.dart';
import 'package:loveell/services/image_preloader.dart';
import 'package:loveell/services/image_cache_service.dart';

class PartnerListScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function({
    int? totalUnreadMessages,
    int? unreadNotificationsCount,
    int? unreadStoriesCount,
  }) onCountsUpdated;

  const PartnerListScreen({
    super.key,
    required this.currentUser,
    required this.onCountsUpdated,
  });

  @override
  State<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends State<PartnerListScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final CallService _callService = CallService();
  late ChatService _chatService;

  late UserModel currentUser;
  List<UserModel> friends = [];
  Map<String, Message> lastMessages = {};
  Map<String, int> unreadCounts = {};

  int _pendingRequestCount = 0;
  String? _myUniqueId;

  bool isLoading = true;
  bool _isRefreshing = false;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;

  StreamSubscription? _currentUserSubscription;
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _friendRequestsSubscription;
  StreamSubscription? _connectionSubscription;
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  // Track image hashes for each friend
  Map<String, String?> _friendImageHashes = {};

  // Debounce timer for sorting
  Timer? _sortDebounceTimer;

  // Cache for formatted dates
  final Map<String, String> _cachedDateStrings = {};

  // Cache for message previews
  final Map<String, String> _cachedMessagePreviews = {};

  // Dark theme colors
  static const Color _primary = Color(0xFF7C7AFF);
  static const Color _secondary = Color(0xFFB46EFF);
  static const Color _success = Color(0xFF10B981);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _background = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _onSurface = Colors.white;
  static const Color _surfaceVariant = Color(0xFF2C2C2C);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB0B0B0);
  static const Color _borderColor = Color(0xFF2C2C2C);

  // Background gradient
  final List<Color> _backgroundGradient = const [
    Color(0xFF121212),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  List<UserModel> _filteredFriends = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _chatService = ChatService();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _initializeData();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionSubscription =
        _chatService.connectionStream.listen((isConnected) {
      if (mounted && !isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                    'You are offline. Messages will be sent when reconnected.'),
              ],
            ),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _initializeData() async {
    await _setUserOnline();
    _listenToCurrentUserChanges();
    await _loadData();
    await _initCallService();
    _setupCallListeners();
    await _getMyUniqueId();
    _listenForFriendRequests();
    _listenToFriendUpdates();
  }

  void _listenToCurrentUserChanges() {
    _currentUserSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;

      final updatedUser =
          UserModel.fromMap(snapshot.data() as Map<String, dynamic>);

      if (updatedUser.profileImageBase64 != currentUser.profileImageBase64) {
        debugPrint('Profile image changed for user ${currentUser.uid}');
        ImageCacheService().clearUserCache(currentUser.uid);

        setState(() {
          currentUser = updatedUser;
        });

        _loadFriends();
      } else {
        setState(() {
          currentUser = updatedUser;
        });
      }
    });
  }

  void _listenToFriendUpdates() {
    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.docs.length != friends.length) {
        debugPrint(
            'Friends count changed from ${friends.length} to ${snapshot.docs.length}, reloading...');
        _loadFriends();
      } else {
        final currentFriendIds = friends.map((f) => f.uid).toSet();
        final newFriendIds = snapshot.docs
            .map((doc) => doc.data()['friendId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet();

        if (!currentFriendIds.containsAll(newFriendIds) ||
            !newFriendIds.containsAll(currentFriendIds)) {
          debugPrint('Friend IDs changed, reloading...');
          _loadFriends();
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to friend updates: $error');
    });
  }

  void _listenToMessageUpdatesForFriend(String friendId) {
    if (_messageSubscriptions.containsKey(friendId)) return;

    final subscription =
        _chatService.getMessagesStream(friendId).listen((messages) {
      if (!mounted || messages.isEmpty) return;

      final lastMessage = messages.last;
      final unreadCount = messages
          .where((m) =>
              !m.isRead &&
              m.senderId == friendId &&
              m.receiverId == currentUser.uid)
          .length;

      // Clear cached data for this friend
      _cachedDateStrings.remove(friendId);
      _cachedMessagePreviews.remove(friendId);

      setState(() {
        lastMessages[friendId] = lastMessage;
        unreadCounts[friendId] = unreadCount;
      });

      // Debounce sorting to avoid multiple rapid rebuilds
      _sortDebounceTimer?.cancel();
      _sortDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          _reSortFriendsList();
        }
      });

      // Update total unread count
      _updateTotalUnreadCount();
    });

    _messageSubscriptions[friendId] = subscription;
  }

  void _updateTotalUnreadCount() {
    final totalUnread =
        unreadCounts.values.fold(0, (sum, count) => sum + count);
    widget.onCountsUpdated(totalUnreadMessages: totalUnread);
  }

  Future<void> _getMyUniqueId() async {
    String? userId = await _authService.getCurrentUserId();
    if (mounted) {
      setState(() {
        _myUniqueId = userId;
      });
    }
  }

  void _listenForFriendRequests() {
    _friendRequestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      int newCount = snapshot.docs.length;
      if (newCount > _pendingRequestCount) {
        _showFriendRequestNotification();
      }

      setState(() {
        _pendingRequestCount = newCount;
      });
    });
  }

  void _showFriendRequestNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.person_add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New friend request',
                style:
                    TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _openFriendRequests();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View'),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openFriendRequests() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendRequestsScreen(
          currentUser: currentUser,
        ),
      ),
    ).then((shouldRefresh) async {
      if (shouldRefresh == true && mounted) {
        setState(() => isLoading = true);
        await _loadFriends();
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  void _openSearchUsers() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchUsersScreen(
          currentUser: currentUser,
        ),
      ),
    ).then((_) => _loadFriends());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();
      _loadData();
      _getMyUniqueId();
    } else if (state == AppLifecycleState.paused) {
      _setUserOffline();
    }
  }

  Future<void> _initCallService() async => await _callService.init();

  void _setupCallListeners() {
    _callService.onIncomingCall = (callerName, roomId, callType) {
      if (!mounted) return;

      final partner = friends.firstWhere(
        (u) => u.name == callerName,
        orElse: () => UserModel(
          uid: '',
          userId: '',
          email: '',
          name: callerName,
          createdAt: DateTime.now(),
          isOnline: true,
        ),
      );

      if (partner.uid.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => IncomingCallDialog(
            callerName: callerName,
            roomId: roomId,
            callType: callType,
            callService: _callService,
            onAccept: () async {
              Navigator.pop(ctx);
              await _callService.acceptCall(roomId);
              if (mounted) {
                _navigateToCall(callType, partner);
              }
            },
            onReject: () {
              Navigator.pop(ctx);
              _callService.rejectCall(roomId);
            },
          ),
        );
      }
    };
  }

  void _navigateToCall(String callType, UserModel partner) {
    final screen = callType == 'video'
        ? ActiveVideoCallScreen(
            currentUser: currentUser,
            partner: partner,
            callService: _callService,
          )
        : ActiveCallScreen(
            currentUser: currentUser,
            partner: partner,
            callService: _callService,
          );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _setUserOnline() async {
    await _authService.updateOnlineStatus(true);
  }

  Future<void> _setUserOffline() async {
    await _authService.updateOnlineStatus(false);
  }

  void _reSortFriendsList() {
    if (friends.isEmpty) return;

    final sortedFriends = List<UserModel>.from(friends);
    sortedFriends.sort((a, b) {
      final aLastMsg = lastMessages[a.uid];
      final bLastMsg = lastMessages[b.uid];

      bool aThemInitiated = false;
      bool bThemInitiated = false;

      if (aLastMsg != null) {
        aThemInitiated = aLastMsg.senderId != currentUser.uid;
      }

      if (bLastMsg != null) {
        bThemInitiated = bLastMsg.senderId != currentUser.uid;
      }

      if (aLastMsg != null && bLastMsg != null) {
        if (aThemInitiated && !bThemInitiated) return -1;
        if (!aThemInitiated && bThemInitiated) return 1;
        return bLastMsg.timestamp.compareTo(aLastMsg.timestamp);
      }

      if (aLastMsg != null && bLastMsg == null) return -1;
      if (aLastMsg == null && bLastMsg != null) return 1;

      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;

      return a.name.compareTo(b.name);
    });

    if (mounted) {
      setState(() {
        friends = sortedFriends;
        _filteredFriends = sortedFriends;
      });
    }
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    try {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .get();

      List<UserModel> loadedFriends = [];
      Map<String, String?> newImageHashes = {};

      // Use Future.wait with limited concurrency
      const concurrency = 5;
      final List<Future<UserModel?>> friendFutures = [];

      for (var friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.data()['friendId'] as String? ?? '';
        if (friendId.isNotEmpty) {
          friendFutures.add(FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get()
              .then((userDoc) {
            if (userDoc.exists) {
              return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
            }
            return null;
          }));
        }
      }

      // Process in batches to avoid UI freeze
      final results = <UserModel?>[];
      for (var i = 0; i < friendFutures.length; i += concurrency) {
        final batch = friendFutures.sublist(
          i,
          i + concurrency > friendFutures.length
              ? friendFutures.length
              : i + concurrency,
        );
        final batchResults = await Future.wait(batch);
        results.addAll(batchResults);

        // Allow UI to breathe
        await Future.delayed(Duration.zero);
      }

      for (var friend in results) {
        if (friend != null) {
          loadedFriends.add(friend);
          newImageHashes[friend.uid] =
              friend.profileImageBase64?.hashCode.toString();
          _listenToMessageUpdatesForFriend(friend.uid);
        }
      }

      // Sort loaded friends
      loadedFriends.sort((a, b) {
        final aLastMsg = lastMessages[a.uid];
        final bLastMsg = lastMessages[b.uid];

        bool aThemInitiated = false;
        bool bThemInitiated = false;

        if (aLastMsg != null) {
          aThemInitiated = aLastMsg.senderId != currentUser.uid;
        }

        if (bLastMsg != null) {
          bThemInitiated = bLastMsg.senderId != currentUser.uid;
        }

        if (aLastMsg != null && bLastMsg != null) {
          if (aThemInitiated && !bThemInitiated) return -1;
          if (!aThemInitiated && bThemInitiated) return 1;
          return bLastMsg.timestamp.compareTo(aLastMsg.timestamp);
        }

        if (aLastMsg != null && bLastMsg == null) return -1;
        if (aLastMsg == null && bLastMsg != null) return 1;

        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;

        return a.name.compareTo(b.name);
      });

      // Clear image cache for changed avatars
      for (var friend in loadedFriends) {
        final oldHash = _friendImageHashes[friend.uid];
        final newHash = friend.profileImageBase64?.hashCode.toString();

        if (oldHash != newHash) {
          debugPrint('Friend ${friend.uid} image changed');
          ImageCacheService().clearUserCache(friend.uid);
        }
      }

      // Preload images in background
      Future.microtask(() => ImagePreloader.preloadUserImages(loadedFriends));

      if (mounted) {
        setState(() {
          friends = loadedFriends;
          _filteredFriends = loadedFriends;
          _friendImageHashes = newImageHashes;
          isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          _isRefreshing = false;
        });

        if (!isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading friends: ${e.toString()}'),
              backgroundColor: _error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadData() async => await _loadFriends();

  String _getLastMessageTime(DateTime timestamp, String friendId) {
    // Check cache first
    if (_cachedDateStrings.containsKey(friendId)) {
      return _cachedDateStrings[friendId]!;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String result;
    if (timestamp.isAfter(today)) {
      result = DateFormat('h:mm a').format(timestamp);
    } else if (timestamp.isAfter(yesterday)) {
      result = 'Yesterday';
    } else if (timestamp.year == now.year) {
      result = DateFormat('MMM d').format(timestamp);
    } else {
      result = DateFormat('MMM d, yyyy').format(timestamp);
    }

    _cachedDateStrings[friendId] = result;
    return result;
  }

  String _getLastMessagePreview(Message? message, String friendId) {
    if (message == null) return 'Tap to start chatting';

    // Check cache first
    if (_cachedMessagePreviews.containsKey(friendId)) {
      return _cachedMessagePreviews[friendId]!;
    }

    String preview = message.text;
    if (message.type != MessageType.text) {
      switch (message.type) {
        case MessageType.voiceNote:
          preview = '🎵 Voice message';
          break;
        case MessageType.location:
          preview = '📍 Location';
          break;
        default:
          preview = message.text;
      }
    }

    if (message.senderId == currentUser.uid) {
      preview = 'You: $preview';
    }

    _cachedMessagePreviews[friendId] = preview;
    return preview;
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _isRefreshing = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _loadFriends();

    if (mounted && !_isRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Friends list updated',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _navigateToChat(UserModel friend) {
    HapticFeedback.selectionClick();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUser: currentUser,
          friend: friend,
          chatService: _chatService,
        ),
      ),
    ).then((_) {
      // Reset unread count when returning from chat
      setState(() {
        unreadCounts[friend.uid] = 0;
      });
      _updateTotalUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _backgroundGradient,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipOval(
                  child: ImageConverter.getCachedAvatar(
                    base64Image: currentUser.profileImageBase64,
                    name: currentUser.name,
                    uid: currentUser.uid,
                    size: 40,
                    backgroundColor: _primary.withOpacity(0.1),
                    textColor: _primary,
                    highQuality: true,
                    key: ValueKey(
                        'appbar_avatar_${currentUser.profileImageBase64?.hashCode ?? 'null'}_${currentUser.uid}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentUser.isOnline
                                  ? _success
                                  : _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _myUniqueId != null ? 'ID: $_myUniqueId' : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                              fontFamily: 'monospace',
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
          actions: [
            // Friend Request Button with Custom Icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset(
                    'assets/icons-header/friend-request.png',
                    width: 24,
                    height: 24,
                    color: _textPrimary,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to default icon if image fails to load
                      return Icon(
                        Icons.person_add_outlined,
                        color: _textPrimary,
                        size: 24,
                      );
                    },
                  ),
                  onPressed: _openFriendRequests,
                ),
                if (_pendingRequestCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _error,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _pendingRequestCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

            // Search Button with Custom Icon
            IconButton(
              icon: Image.asset(
                'assets/icons-header/search-friends.png',
                width: 24,
                height: 24,
                color: _textPrimary,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to default icon if image fails to load
                  return Icon(
                    Icons.search,
                    color: _textPrimary,
                    size: 24,
                  );
                },
              ),
              onPressed: _openSearchUsers,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading conversations...',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : (_filteredFriends.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: _primary,
                    backgroundColor: _surface,
                    strokeWidth: 2,
                    displacement: 20,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: _filteredFriends.length,
                      cacheExtent: 500,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: true,
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        final lastMessage = lastMessages[friend.uid];
                        final unreadCount = unreadCounts[friend.uid] ?? 0;

                        return _buildChatTile(
                          friend,
                          index,
                          lastMessage,
                          unreadCount,
                        );
                      },
                    ),
                  )),
      ),
    );
  }

  Widget _buildChatTile(
    UserModel friend,
    int index,
    Message? lastMessage,
    int unreadCount,
  ) {
    final imageHash = friend.profileImageBase64?.hashCode.toString() ?? 'null';

    return Container(
      key: ValueKey('chat_tile_${friend.uid}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChat(friend),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar with online status
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: ImageConverter.getCachedAvatar(
                          base64Image: friend.profileImageBase64,
                          name: friend.name,
                          uid: friend.uid,
                          size: 52,
                          backgroundColor: _primary.withOpacity(0.1),
                          textColor: _primary,
                          highQuality: true,
                          key: ValueKey('avatar_${friend.uid}_$imageHash'),
                        ),
                      ),
                      if (friend.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _success,
                              border: Border.all(
                                color: _surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                friend.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (lastMessage != null)
                              Text(
                                _getLastMessageTime(
                                    lastMessage.timestamp, friend.uid),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getLastMessagePreview(lastMessage, friend.uid),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: unreadCount > 0
                                      ? _textPrimary
                                      : _textSecondary,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          ),
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
                color: _primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: _primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Find friends by their ID to start chatting',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openSearchUsers,
              icon: const Icon(Icons.search),
              label: const Text('Find Friends'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    _sortDebounceTimer?.cancel();
    _currentUserSubscription?.cancel();
    _friendsSubscription?.cancel();
    _friendRequestsSubscription?.cancel();
    _connectionSubscription?.cancel();
    for (var subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _chatService.dispose();
    _callService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _setUserOffline();
    super.dispose();
  }
}
