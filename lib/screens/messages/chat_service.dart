import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loveell/models/message.dart';
import 'package:loveell/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Local message queue for offline support
class LocalMessageQueue {
  static const String _queueKey = 'pending_messages';
  final SharedPreferences _prefs;

  LocalMessageQueue(this._prefs);

  Future<void> addMessage(Map<String, dynamic> message) async {
    final List<String> queue = _prefs.getStringList(_queueKey) ?? [];
    queue.add(jsonEncode(message));
    await _prefs.setStringList(_queueKey, queue);
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    final List<String> queue = _prefs.getStringList(_queueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> removeMessage(int index) async {
    final List<String> queue = _prefs.getStringList(_queueKey) ?? [];
    if (index < queue.length) {
      queue.removeAt(index);
      await _prefs.setStringList(_queueKey, queue);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_queueKey);
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late LocalMessageQueue _messageQueue;

  // Cache for chat room IDs
  final Map<String, String> _chatRoomIdCache = {};

  // Cache for friend status
  final Map<String, CacheEntry<bool>> _friendStatusCache = {};

  // Message cache for instant display
  final Map<String, List<Message>> _messageCache = {};

  // Pending messages tracking
  final Map<String, List<Message>> _pendingMessages = {};

  // Connection status
  bool _isConnected = true;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  // Retry mechanism
  Timer? _retryTimer;
  static const int _messageBatchSize = 30;
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 3);

  // Debouncing timers
  final Map<String, Timer> _readMarkTimers = {};
  final Map<String, Timer> _typingTimers = {};

  // Stream controllers
  final Map<String, StreamController<List<Message>>> _messageStreamControllers =
      {};
  final Map<String, StreamController<bool>> _typingStreamControllers = {};
  final Map<String, List<StreamSubscription>> _streamSubscriptions = {};

  ChatService() {
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _messageQueue = LocalMessageQueue(prefs);
    await _initConnectivity();
    await _retryPendingMessages();
  }

  Future<void> _initConnectivity() async {
    Connectivity().onConnectivityChanged.listen((result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      _connectionController.add(_isConnected);

      if (!wasConnected && _isConnected) {
        _retryPendingMessages();
        // Notify all listeners to refresh
        for (var chatRoomId in _messageStreamControllers.keys) {
          _notifyMessageListeners(chatRoomId);
        }
      }
    });

    final result = await Connectivity().checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    _connectionController.add(_isConnected);
  }

  String _getChatRoomId(String user1Id, String user2Id) {
    final cacheKey = user1Id.compareTo(user2Id) < 0
        ? '${user1Id}_$user2Id'
        : '${user2Id}_$user1Id';

    return _chatRoomIdCache.putIfAbsent(cacheKey, () {
      List<String> ids = [user1Id, user2Id];
      ids.sort();
      return ids.join('_');
    });
  }

  // Ensure chat room exists before operations
  Future<bool> _ensureChatRoomExists(
      String chatRoomId, String user1Id, String user2Id) async {
    try {
      final docRef = _firestore.collection('chats').doc(chatRoomId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Create the chat room document with complete structure
        await docRef.set({
          'participants': [user1Id, user2Id],
          'participantsMap': {
            user1Id: true,
            user2Id: true,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
          'lastMessageType': 'text',
          'isActive': true,
        });
        return true;
      }
      return true;
    } catch (e) {
      print('Error ensuring chat room exists: $e');
      return false;
    }
  }

  // Force refresh chat room messages
  Future<void> refreshChatRoom(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

    // Clear cache for this chat room to force refresh
    _messageCache.remove(chatRoomId);

    // Ensure chat room exists
    await _ensureChatRoomExists(chatRoomId, currentUser.uid, otherUserId);

    // Force fetch messages from Firestore
    await _fetchMessagesFromFirestore(chatRoomId);

    // Notify listeners to refresh
    _notifyMessageListeners(chatRoomId);
  }

  // Fetch messages directly from Firestore
  Future<void> _fetchMessagesFromFirestore(String chatRoomId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_messageBatchSize)
          .get();

      final messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _messageCache[chatRoomId] = messages;
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<bool> areFriends(String currentUserId, String otherUserId) async {
    final cacheKey = '${currentUserId}_$otherUserId';

    final cached = _friendStatusCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('friends')
            .doc(otherUserId)
            .get(),
        _firestore
            .collection('users')
            .doc(otherUserId)
            .collection('friends')
            .doc(currentUserId)
            .get()
      ]);

      final isFriend = results[0].exists && results[1].exists;

      _friendStatusCache[cacheKey] = CacheEntry(isFriend,
          expiry: DateTime.now().add(const Duration(minutes: 5)));

      return isFriend;
    } catch (e) {
      print('Error checking friends: $e');
      return false;
    }
  }

  // Send message with offline support
  Future<Map<String, dynamic>> sendMessage({
    required String text,
    required UserModel receiver,
    String? localId,
    MessageType? type,
    String? mediaUrl,
    MessageReply? replyTo,
    int? duration,
    String? fileSize,
    String? fileName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'No user logged in'};
      }

      final areFriends = await this.areFriends(user.uid, receiver.uid);
      if (!areFriends) {
        return {'success': false, 'error': 'You can only message your friends'};
      }

      final messageId = localId ?? _firestore.collection('_').doc().id;
      final chatRoomId = _getChatRoomId(user.uid, receiver.uid);
      final now = DateTime.now();

      // Ensure chat room exists before sending
      final roomExists =
          await _ensureChatRoomExists(chatRoomId, user.uid, receiver.uid);
      if (!roomExists) {
        return {'success': false, 'error': 'Failed to create chat room'};
      }

      String senderName = '';
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          senderName =
              (userDoc.data() as Map<String, dynamic>)['name'] ?? 'User';
        } else {
          senderName = 'User';
        }
      } catch (e) {
        senderName = 'User';
      }

      final message = Message(
        id: messageId,
        text: text,
        senderId: user.uid,
        senderName: senderName,
        receiverId: receiver.uid,
        timestamp: now,
        isDelivered: false,
        isRead: false,
        type: type ?? MessageType.text,
        mediaUrl: mediaUrl,
        status: MessageStatus.sending,
        replyTo: replyTo,
        duration: duration,
        fileSize: fileSize,
        fileName: fileName,
        deliveryInfo: MessageDeliveryInfo(
          sentAt: now,
          attempts: [
            DeliveryAttempt(
              timestamp: now,
              success: false,
            ),
          ],
        ),
      );

      // Add to pending messages
      _pendingMessages.putIfAbsent(chatRoomId, () => []);
      _pendingMessages[chatRoomId]!.add(message);

      // Update local cache
      final cachedMessages = _messageCache[chatRoomId] ?? [];
      _messageCache[chatRoomId] = [...cachedMessages, message];
      _messageCache[chatRoomId]!
          .sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _notifyMessageListeners(chatRoomId);

      if (_isConnected) {
        await _sendMessageToFirestore(
            message, chatRoomId, user.uid, receiver.uid);
      } else {
        await _queueMessageForLater(
            message, chatRoomId, user.uid, receiver.uid);
      }

      return {'success': true, 'message': message, 'pending': !_isConnected};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _sendMessageToFirestore(
      Message message, String chatRoomId, String senderId, String receiverId,
      {int retryCount = 0}) async {
    try {
      final batch = _firestore.batch();

      final chatRoomRef = _firestore.collection('chats').doc(chatRoomId);

      // Update last message
      Map<String, dynamic> lastMessageData = {
        'lastMessage': message.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        'lastMessageType': message.type.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (message.type != MessageType.text) {
        lastMessageData['lastMessageMedia'] = true;
      }

      batch.set(
        chatRoomRef,
        lastMessageData,
        SetOptions(merge: true),
      );

      // Update message with sent status
      final updatedMessage = message.copyWith(
        status: MessageStatus.sent,
        deliveryInfo: MessageDeliveryInfo(
          sentAt: message.timestamp,
          deliveredAt: null,
          readAt: null,
          attempts: [
            DeliveryAttempt(
              timestamp: DateTime.now(),
              success: true,
            ),
          ],
        ),
      );

      final messageRef = chatRoomRef.collection('messages').doc(message.id);
      batch.set(messageRef, updatedMessage.toMap());

      await batch.commit();

      // Update pending and cache
      _pendingMessages[chatRoomId]?.removeWhere((m) => m.id == message.id);

      final cachedIndex =
          _messageCache[chatRoomId]?.indexWhere((m) => m.id == message.id);
      if (cachedIndex != null &&
          cachedIndex != -1 &&
          _messageCache[chatRoomId] != null) {
        _messageCache[chatRoomId]![cachedIndex] = updatedMessage;
      }

      _notifyMessageListeners(chatRoomId);
    } catch (e) {
      if (retryCount < _maxRetries) {
        final delay = _retryDelay * (retryCount + 1);
        await Future.delayed(delay);
        await _sendMessageToFirestore(message, chatRoomId, senderId, receiverId,
            retryCount: retryCount + 1);
      } else {
        final failedMessage = message.copyWith(
          status: MessageStatus.failed,
        );
        await _queueMessageForLater(
            failedMessage, chatRoomId, senderId, receiverId);
      }
    }
  }

  Future<void> _queueMessageForLater(
    Message message,
    String chatRoomId,
    String senderId,
    String receiverId,
  ) async {
    final queuedMessage = {
      'message': message.toMap(),
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _messageQueue.addMessage(queuedMessage);
  }

  Future<void> _retryPendingMessages() async {
    try {
      final pendingMessages = await _messageQueue.getMessages();
      if (pendingMessages.isEmpty) return;

      for (int i = 0; i < pendingMessages.length; i++) {
        final msg = pendingMessages[i];
        try {
          final message =
              Message.fromMap(msg['message'] as Map<String, dynamic>);
          final chatRoomId = msg['chatRoomId'] as String;
          final senderId = msg['senderId'] as String;
          final receiverId = msg['receiverId'] as String;

          await _sendMessageToFirestore(
              message, chatRoomId, senderId, receiverId);
          await _messageQueue.removeMessage(i);

          _notifyMessageListeners(chatRoomId);
        } catch (e) {
          print('Failed to retry message: $e');
        }
      }
    } catch (e) {
      print('Error retrying pending messages: $e');
    }
  }

  // Get messages stream with persistence
  Stream<List<Message>> getMessagesStream(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

    // If controller already exists, still ensure we have fresh data
    if (_messageStreamControllers.containsKey(chatRoomId)) {
      // Refresh messages in background
      _fetchMessagesFromFirestore(chatRoomId).then((_) {
        _notifyMessageListeners(chatRoomId);
      });
      return _messageStreamControllers[chatRoomId]!.stream;
    }

    final controller = StreamController<List<Message>>.broadcast();
    _messageStreamControllers[chatRoomId] = controller;

    // First, load from cache if available
    if (_messageCache.containsKey(chatRoomId) &&
        _messageCache[chatRoomId]!.isNotEmpty) {
      controller.add(_messageCache[chatRoomId]!);
    }

    // Create subscription with proper error handling
    final subscription = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_messageBatchSize)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Update cache
      _messageCache[chatRoomId] = messages;

      // Add pending messages
      final pending = _pendingMessages[chatRoomId] ?? [];
      final allMessages = [...messages, ...pending];
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return allMessages;
    }).handleError((error) {
      print('Stream error for $chatRoomId: $error');
      // Return cached messages on error
      return _messageCache[chatRoomId] ?? [];
    }).listen((messages) {
      if (!controller.isClosed) {
        controller.add(messages);
      }
    }, onError: (error) {
      print('Subscription error: $error');
      if (!controller.isClosed) {
        controller.add(_messageCache[chatRoomId] ?? []);
      }
    });

    _streamSubscriptions.putIfAbsent(chatRoomId, () => []).add(subscription);

    return controller.stream;
  }

  void _notifyMessageListeners(String chatRoomId) {
    final controller = _messageStreamControllers[chatRoomId];
    if (controller != null && !controller.isClosed) {
      final cached = _messageCache[chatRoomId] ?? [];
      final pending = _pendingMessages[chatRoomId] ?? [];
      final allMessages = [...cached, ...pending];
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      controller.add(allMessages);
    }
  }

  // Typing indicators
  Stream<bool> getTypingStream(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(false);

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

    if (_typingStreamControllers.containsKey(chatRoomId)) {
      return _typingStreamControllers[chatRoomId]!.stream;
    }

    final controller = StreamController<bool>.broadcast();
    _typingStreamControllers[chatRoomId] = controller;

    final subscription = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('typing')
        .doc(otherUserId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        final isTyping = doc.data()?['isTyping'] ?? false;
        final timestamp = doc.data()?['timestamp'] as Timestamp?;

        if (timestamp != null && isTyping) {
          final expiryTime = timestamp.toDate().add(const Duration(seconds: 3));
          if (DateTime.now().isAfter(expiryTime)) {
            return false;
          }
        }
        return isTyping;
      }
      return false;
    }).listen((isTyping) {
      if (!controller.isClosed) {
        controller.add(isTyping);
      }
    });

    _streamSubscriptions.putIfAbsent(chatRoomId, () => []).add(subscription);

    return controller.stream;
  }

  Future<void> sendTypingIndicator(String otherUserId, bool isTyping) async {
    if (!_isConnected) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      final key = 'typing_$chatRoomId';
      _typingTimers[key]?.cancel();

      if (isTyping) {
        _typingTimers[key] = Timer(const Duration(seconds: 3), () async {
          await _firestore
              .collection('chats')
              .doc(chatRoomId)
              .collection('typing')
              .doc(currentUser.uid)
              .set({
            'isTyping': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        });
      }

      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('typing')
          .doc(currentUser.uid)
          .set({
        'isTyping': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Edit message
  Future<bool> editMessage(
    String messageId,
    String otherUserId,
    String newText,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      if (_isConnected) {
        await _firestore
            .collection('chats')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .update({
          'text': newText,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update cache
      final cachedMessages = _messageCache[chatRoomId] ?? [];
      final index = cachedMessages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final updatedMessage = cachedMessages[index].copyWith(
          text: newText,
          isEdited: true,
          editedAt: DateTime.now(),
        );
        _messageCache[chatRoomId]![index] = updatedMessage;
      }

      _notifyMessageListeners(chatRoomId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Add reaction to message
  Future<bool> addReaction(
    String messageId,
    String otherUserId,
    String reactionType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return false;

      MessageReactions? currentReactions;
      if (messageDoc.data()?['reactions'] != null) {
        currentReactions = MessageReactions.fromMap(
          messageDoc.data()!['reactions'] as Map<String, dynamic>,
        );
      }

      MessageReactions newReactions;
      if (currentReactions != null &&
          currentReactions.hasReacted(currentUser.uid, reactionType)) {
        newReactions = currentReactions.removeReaction(
          currentUser.uid,
          reactionType,
        );
      } else {
        newReactions = (currentReactions ??
                MessageReactions(
                  reactions: {},
                  totalCount: 0,
                ))
            .addReaction(currentUser.uid, reactionType);
      }

      if (_isConnected) {
        await _firestore
            .collection('chats')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .update({
          'reactions': newReactions.toMap(),
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  void markAsReadDebounced(String messageId, String otherUserId) {
    final key = '${messageId}_$otherUserId';

    _readMarkTimers[key]?.cancel();
    _readMarkTimers[key] = Timer(const Duration(milliseconds: 500), () {
      _markAsRead(messageId, otherUserId);
      _readMarkTimers.remove(key);
    });
  }

  Future<void> _markAsRead(String messageId, String otherUserId) async {
    if (!_isConnected) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isRead': true,
        'deliveryInfo.readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> markAllAsRead(String otherUserId) async {
    if (!_isConnected) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      final batch = _firestore.batch();
      final messages = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('isRead', isEqualTo: false)
          .limit(50)
          .get();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'deliveryInfo.readAt': FieldValue.serverTimestamp(),
        });
      }

      if (messages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<bool> deleteMessage(String messageId, String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      _pendingMessages[chatRoomId]?.removeWhere((m) => m.id == messageId);

      if (_isConnected) {
        await _firestore
            .collection('chats')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .update({
          'isDeleted': true,
          'text': 'This message was deleted',
        });
      }

      _notifyMessageListeners(chatRoomId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Message>> loadMoreMessages(
    String otherUserId,
    DateTime beforeTimestamp,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

      final chatRoomDoc = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .get()
          .catchError((e) {
        print('Chat room does not exist: $e');
        return null;
      });

      if (chatRoomDoc == null || !chatRoomDoc.exists) {
        return [];
      }

      final snapshot = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('timestamp', isLessThan: beforeTimestamp)
          .orderBy('timestamp', descending: true)
          .limit(_messageBatchSize)
          .get();

      final messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final existing = _messageCache[chatRoomId] ?? [];
      _messageCache[chatRoomId] = [...messages, ...existing];

      return messages;
    } catch (e) {
      print('Error loading more messages: $e');
      return [];
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _connectionController.close();

    for (var timer in _readMarkTimers.values) {
      timer.cancel();
    }
    _readMarkTimers.clear();

    for (var timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();

    for (var subscriptions in _streamSubscriptions.values) {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    }
    _streamSubscriptions.clear();

    for (var controller in _messageStreamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _messageStreamControllers.clear();

    for (var controller in _typingStreamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _typingStreamControllers.clear();

    _friendStatusCache.clear();
    _messageCache.clear();
    _pendingMessages.clear();
  }
}

class CacheEntry<T> {
  final T value;
  final DateTime expiry;

  CacheEntry(this.value, {required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
