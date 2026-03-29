import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/models/message.dart';
import 'package:loveell/screens/messages/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel friend;
  final ChatService chatService;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.friend,
    required this.chatService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<Message> _messages = [];
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<bool>? _typingSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  bool _isTyping = false;
  bool _friendIsTyping = false;
  Timer? _typingTimer;
  bool _isLoadingMore = false;
  DateTime? _oldestMessageDate;
  bool _isSending = false;
  bool _isConnected = true;
  bool _hasScrolledToInitial = false;
  bool _shouldAutoScroll = true;
  bool _isKeyboardVisible = false;
  double _keyboardHeight = 0;

  Message? _replyToMessage;

  // Dark theme colors
  static const Color _primary = Color(0xFF7C7AFF);
  static const Color _success = Color(0xFF10B981);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _background = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2C);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB0B0B0);
  static const Color _borderColor = Color(0xFF2C2C2C);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupListeners();
    _markMessagesAsRead();
    _refreshMessages();
    _setupKeyboardListener();
    _scrollController.addListener(_onScrollThrottled);

    // Add a listener to detect when user scrolls manually
    _scrollController.addListener(_onUserScroll);
  }

  void _setupKeyboardListener() {
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients && _messages.isNotEmpty) {
            _scrollToBottomSmooth();
          }
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = bottomInset > 0;

    if (isKeyboardOpen != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardOpen;
        _keyboardHeight = bottomInset;
      });

      if (isKeyboardOpen && _shouldAutoScroll && _messages.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scrollController.hasClients) {
            _scrollToBottomSmooth();
          }
        });
      }
    }
  }

  Timer? _scrollThrottleTimer;
  void _onScrollThrottled() {
    if (_scrollThrottleTimer?.isActive ?? false) return;
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 16), () {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        final currentPixel = _scrollController.position.pixels;

        if (currentPixel < maxExtent - 100) {
          if (_shouldAutoScroll) _shouldAutoScroll = false;
        } else if (currentPixel >= maxExtent - 50) {
          if (!_shouldAutoScroll) _shouldAutoScroll = true;
        }
      }
    });
  }

  // Track user scroll to disable auto-scroll
  void _onUserScroll() {
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentPixel = _scrollController.position.pixels;

      // If user scrolls up more than 100 pixels from bottom, disable auto-scroll
      if (currentPixel < maxExtent - 100) {
        if (_shouldAutoScroll) {
          setState(() {
            _shouldAutoScroll = false;
          });
        }
      }
      // If user scrolls to bottom, re-enable auto-scroll
      else if (currentPixel >= maxExtent - 50) {
        if (!_shouldAutoScroll) {
          setState(() {
            _shouldAutoScroll = true;
          });
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshMessages();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshMessages();
      _markMessagesAsRead();
    }
  }

  Future<void> _refreshMessages() async {
    await widget.chatService.refreshChatRoom(widget.friend.uid);
  }

  void _setupListeners() {
    _messagesSubscription = widget.chatService
        .getMessagesStream(widget.friend.uid)
        .listen((messages) {
      if (!mounted) return;

      final bool wasEmpty = _messages.isEmpty;
      final int oldCount = _messages.length;

      setState(() {
        _messages = messages
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });

      _updateOldestMessageDate();

      if (wasEmpty && _messages.isNotEmpty) {
        _handleInitialScroll();
      }
      // Auto-scroll to bottom when new messages arrive AND auto-scroll is enabled
      else if (oldCount < _messages.length && _shouldAutoScroll) {
        _scrollToBottomSmooth();
      }
      // If new messages arrived but auto-scroll is disabled, show a "New messages" button
      else if (oldCount < _messages.length && !_shouldAutoScroll && mounted) {
        _showNewMessageButton();
      }
    }, onError: (error) {
      if (error.toString().contains('permission-denied') ||
          error.toString().contains('not-found')) {
        return;
      }
      print('Messages stream error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $error'),
            backgroundColor: _error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    _typingSubscription = widget.chatService
        .getTypingStream(widget.friend.uid)
        .listen((isTyping) {
      if (mounted) {
        setState(() {
          _friendIsTyping = isTyping;
        });
      }
    });

    _connectionSubscription =
        widget.chatService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });

        if (!isConnected) {
          _showOfflineSnackBar();
        } else {
          _refreshMessages();
          _retryPendingMessages();
        }
      }
    });
  }

  // Show a button to scroll to new messages
  void _showNewMessageButton() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New messages'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Scroll down',
          textColor: Colors.white,
          onPressed: () {
            _scrollToBottomSmooth();
            setState(() {
              _shouldAutoScroll = true;
            });
          },
        ),
      ),
    );
  }

  Future<void> _retryPendingMessages() async {
    await _refreshMessages();
  }

  void _showOfflineSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('You are offline. Messages will be sent when reconnected.'),
          ],
        ),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _markMessagesAsRead() {
    widget.chatService.markAllAsRead(widget.friend.uid);
  }

  void _handleInitialScroll() {
    if (_hasScrolledToInitial || _messages.isEmpty) return;

    _hasScrolledToInitial = true;
    _shouldAutoScroll = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      // Scroll to the latest message
      _scrollToBottomInstant();
    });
  }

  double _getEstimatedMessageHeight(Message message) {
    double baseHeight = 60.0;
    if (message.replyTo != null) baseHeight += 50.0;
    if (message.text.length > 50) baseHeight += (message.text.length / 40) * 20;
    return baseHeight.clamp(60.0, 120.0);
  }

  void _scrollToBottomSmooth() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _scrollToBottomInstant() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _updateOldestMessageDate() {
    if (_messages.isNotEmpty && _oldestMessageDate == null) {
      _oldestMessageDate = _messages.first.timestamp;
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || _oldestMessageDate == null || _messages.isEmpty)
      return;

    final currentScrollOffset =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    setState(() {
      _isLoadingMore = true;
    });

    final olderMessages = await widget.chatService.loadMoreMessages(
      widget.friend.uid,
      _oldestMessageDate!,
    );

    if (olderMessages.isNotEmpty && mounted) {
      setState(() {
        _messages = [...olderMessages, ..._messages];
        _oldestMessageDate = olderMessages.first.timestamp;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          double addedHeight = 0.0;
          for (var msg in olderMessages) {
            addedHeight += _getEstimatedMessageHeight(msg);
          }
          _scrollController.jumpTo(currentScrollOffset + addedHeight);
        }
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _handleTyping(String text) {
    if (!_isConnected) return;

    _typingTimer?.cancel();
    final isCurrentlyTyping = text.isNotEmpty;

    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;
      widget.chatService
          .sendTypingIndicator(widget.friend.uid, isCurrentlyTyping);
    }

    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          _isTyping = false;
          widget.chatService.sendTypingIndicator(widget.friend.uid, false);
        }
      });
    }
  }

  Future<void> _sendMessage({String? text}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    if (text == null) {
      _messageController.clear();
    }
    _handleTyping('');

    final result = await widget.chatService.sendMessage(
      text: messageText,
      receiver: widget.friend,
      type: MessageType.text,
      mediaUrl: null,
      replyTo: _replyToMessage != null
          ? MessageReply(
              messageId: _replyToMessage!.id,
              text: _replyToMessage!.text,
              senderId: _replyToMessage!.senderId,
              senderName: _replyToMessage!.senderName,
              type: _replyToMessage!.type ?? MessageType.text,
              mediaUrl: _replyToMessage!.mediaUrl,
            )
          : null,
    );

    setState(() {
      _isSending = false;
      _replyToMessage = null;
    });

    if (!result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to send message'),
          backgroundColor: _error,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _shouldAutoScroll = true;
      _refreshMessages();

      // Always scroll to bottom after sending a message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottomSmooth();
      });
    }
  }

  void _showMessageOptions(Message message) {
    final isMe = message.senderId == widget.currentUser.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF7C7AFF)),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyToMessage = message;
                });
              },
            ),
            if (isMe && message.type == MessageType.text && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF7C7AFF)),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  final newText = await _showEditDialog(message.text);
                  if (newText != null && newText.trim().isNotEmpty) {
                    final success = await widget.chatService.editMessage(
                      message.id,
                      widget.friend.uid,
                      newText.trim(),
                    );
                    if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to edit message'),
                          backgroundColor: Color(0xFFFF6B6B),
                        ),
                      );
                    } else {
                      _refreshMessages();
                    }
                  }
                },
              ),
            if (isMe && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFFF6B6B)),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _surface,
                      title: const Text('Delete Message'),
                      content: const Text(
                          'Are you sure you want to delete this message?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Color(0xFFFF6B6B))),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await widget.chatService.deleteMessage(
                      message.id,
                      widget.friend.uid,
                    );
                    _refreshMessages();
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<String?> _showEditDialog(String currentText) async {
    final controller = TextEditingController(text: currentText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary),
            ),
          ),
          style: const TextStyle(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == widget.currentUser.uid;

    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 12,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Message deleted',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 9,
                      color: _textSecondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview if exists
                  if (message.replyTo != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply, size: 10, color: _textSecondary),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.replyTo!.senderName,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                message.replyTo!.text,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Main message bubble
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? _primary : _surface,
                      borderRadius: BorderRadius.circular(18),
                      border: isMe ? null : Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : _textPrimary,
                            fontSize: 14,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(message.timestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe
                                    ? Colors.white.withOpacity(0.6)
                                    : _textSecondary,
                              ),
                            ),
                            if (message.isEdited) ...[
                              const SizedBox(width: 3),
                              Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.5)
                                      : _textSecondary.withOpacity(0.7),
                                ),
                              ),
                            ],
                            if (isMe &&
                                message.status != MessageStatus.sending) ...[
                              const SizedBox(width: 3),
                              Icon(
                                _getStatusIcon(message.status),
                                size: 10,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ],
                            if (isMe &&
                                message.status == MessageStatus.sending) ...[
                              const SizedBox(width: 3),
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(MessageStatus? status) {
    switch (status) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
      default:
        return Icons.check;
    }
  }

  Widget _buildReplyBar() {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceVariant,
        border: Border(
          top: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
              });
            },
            color: _textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: _primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Say hello to ${widget.friend.name}',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.send_rounded,
                  size: 14,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Type a message to start the conversation',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: _textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.friend.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_friendIsTyping)
              const Text(
                'typing...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7C7AFF),
                ),
              )
            else if (widget.friend.isOnline)
              const Text(
                'Online',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF10B981),
                ),
              )
            else
              Text(
                'Last seen ${DateFormat('MMM d, h:mm a').format(widget.friend.lastSeen ?? DateTime.now())}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFB0B0B0),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: _error.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 14, color: _error),
                  const SizedBox(width: 8),
                  const Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _error,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _focusNode.unfocus();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels <= 0 &&
                      notification.metrics.extentBefore == 0 &&
                      !_isLoadingMore &&
                      _messages.isNotEmpty) {
                    _loadMoreMessages();
                  }
                  return false;
                },
                child: _messages.isEmpty
                    ? _buildEmptyChatState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),
            ),
          ),
          _buildReplyBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(
                top: BorderSide(color: _borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    onChanged: _handleTyping,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: _textPrimary),
                    maxLines: null,
                    enabled: _isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending || !_isConnected
                        ? null
                        : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _connectionSubscription?.cancel();
    _typingTimer?.cancel();
    _scrollThrottleTimer?.cancel();
    super.dispose();
  }
}
