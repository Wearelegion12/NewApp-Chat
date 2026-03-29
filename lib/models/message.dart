// message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String receiverId;
  final DateTime timestamp;
  final bool isDelivered;
  final bool isRead;

  // NEW FEATURES
  final MessageType? type; // Text, audio, location, etc.
  final String? mediaUrl; // For audio files only
  final MessageStatus? status; // Sending, sent, delivered, read, failed
  final MessageReactions? reactions; // Reactions (like, love, etc.)
  final MessageReply? replyTo; // Reply to a specific message
  final bool isEdited; // Track if message was edited
  final DateTime? editedAt; // When message was last edited
  final bool isDeleted; // Soft delete flag
  final String? metadata; // Additional metadata (JSON string)
  final String? localId; // Temporary ID for offline messages
  final int? duration; // For voice notes/audio duration
  final String? fileSize; // File size for audio
  final String? fileName; // Original file name for audio
  final MessageDeliveryInfo? deliveryInfo; // Detailed delivery info

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.timestamp,
    required this.isDelivered,
    required this.isRead,
    this.type = MessageType.text,
    this.mediaUrl,
    this.status,
    this.reactions,
    this.replyTo,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.metadata,
    this.localId,
    this.duration,
    this.fileSize,
    this.fileName,
    this.deliveryInfo,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      receiverId: map['receiverId'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isDelivered: map['isDelivered'] ?? false,
      isRead: map['isRead'] ?? false,
      type: map['type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.toString() == 'MessageType.${map['type']}',
              orElse: () => MessageType.text,
            )
          : MessageType.text,
      mediaUrl: map['mediaUrl'] as String?,
      status: map['status'] != null
          ? MessageStatus.values.firstWhere(
              (e) => e.toString() == 'MessageStatus.${map['status']}',
              orElse: () => MessageStatus.sent,
            )
          : null,
      reactions: map['reactions'] != null
          ? MessageReactions.fromMap(map['reactions'] as Map<String, dynamic>)
          : null,
      replyTo: map['replyTo'] != null
          ? MessageReply.fromMap(map['replyTo'] as Map<String, dynamic>)
          : null,
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] as Timestamp).toDate()
          : null,
      isDeleted: map['isDeleted'] ?? false,
      metadata: map['metadata'] as String?,
      localId: map['localId'] as String?,
      duration: map['duration'] as int?,
      fileSize: map['fileSize'] as String?,
      fileName: map['fileName'] as String?,
      deliveryInfo: map['deliveryInfo'] != null
          ? MessageDeliveryInfo.fromMap(
              map['deliveryInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDelivered': isDelivered,
      'isRead': isRead,
      'type': type.toString().split('.').last,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (status != null) 'status': status.toString().split('.').last,
      if (reactions != null) 'reactions': reactions!.toMap(),
      if (replyTo != null) 'replyTo': replyTo!.toMap(),
      'isEdited': isEdited,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      'isDeleted': isDeleted,
      if (metadata != null) 'metadata': metadata,
      if (localId != null) 'localId': localId,
      if (duration != null) 'duration': duration,
      if (fileSize != null) 'fileSize': fileSize,
      if (fileName != null) 'fileName': fileName,
      if (deliveryInfo != null) 'deliveryInfo': deliveryInfo!.toMap(),
    };
  }

  // Helper methods
  bool get isMedia => type != MessageType.text;
  bool get isAudio => type == MessageType.audio;
  bool get isVoiceNote => type == MessageType.voiceNote;
  bool get isLocation => type == MessageType.location;
  bool get isSystem => type == MessageType.system;
  bool get isPending => status == MessageStatus.sending;
  bool get isFailed => status == MessageStatus.failed;
  bool get isSent => status == MessageStatus.sent;
  bool get isDeliveredStatus => status == MessageStatus.delivered;

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    final size = int.tryParse(fileSize!);
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Message copyWith({
    String? id,
    String? text,
    String? senderId,
    String? senderName,
    String? receiverId,
    DateTime? timestamp,
    bool? isDelivered,
    bool? isRead,
    MessageType? type,
    String? mediaUrl,
    MessageStatus? status,
    MessageReactions? reactions,
    MessageReply? replyTo,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    String? metadata,
    String? localId,
    int? duration,
    String? fileSize,
    String? fileName,
    MessageDeliveryInfo? deliveryInfo,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      timestamp: timestamp ?? this.timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
      localId: localId ?? this.localId,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
    );
  }

  @override
  String toString() {
    return 'Message{id: $id, text: $text, senderId: $senderId, type: $type, status: $status}';
  }
}

enum MessageType {
  text,
  audio,
  voiceNote,
  location,
  system,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageReactions {
  final Map<String, List<String>> reactions; // reactionType -> list of userIds
  final int totalCount;

  MessageReactions({
    required this.reactions,
    required this.totalCount,
  });

  factory MessageReactions.fromMap(Map<String, dynamic> map) {
    return MessageReactions(
      reactions: Map<String, List<String>>.from(map['reactions'] ?? {}),
      totalCount: map['totalCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reactions': reactions,
      'totalCount': totalCount,
    };
  }

  bool hasReacted(String userId, String reactionType) {
    return reactions[reactionType]?.contains(userId) ?? false;
  }

  String? getUserReaction(String userId) {
    for (var entry in reactions.entries) {
      if (entry.value.contains(userId)) {
        return entry.key;
      }
    }
    return null;
  }

  List<String> getReactionTypes() {
    return reactions.keys.toList();
  }

  int getReactionCount(String reactionType) {
    return reactions[reactionType]?.length ?? 0;
  }

  MessageReactions addReaction(String userId, String reactionType) {
    // Remove existing reaction from any type
    MessageReactions temp = this;
    final existingReaction = getUserReaction(userId);
    if (existingReaction != null) {
      temp = temp.removeReaction(userId, existingReaction);
    }

    // Add new reaction
    final newReactions = Map<String, List<String>>.from(temp.reactions);
    newReactions.putIfAbsent(reactionType, () => []).add(userId);
    return MessageReactions(
      reactions: newReactions,
      totalCount: temp.totalCount + 1,
    );
  }

  MessageReactions removeReaction(String userId, String reactionType) {
    final newReactions = Map<String, List<String>>.from(reactions);
    if (newReactions[reactionType]?.contains(userId) ?? false) {
      newReactions[reactionType]!.remove(userId);
      if (newReactions[reactionType]!.isEmpty) {
        newReactions.remove(reactionType);
      }
      return MessageReactions(
        reactions: newReactions,
        totalCount: totalCount - 1,
      );
    }
    return this;
  }

  MessageReactions toggleReaction(String userId, String reactionType) {
    if (hasReacted(userId, reactionType)) {
      return removeReaction(userId, reactionType);
    } else {
      return addReaction(userId, reactionType);
    }
  }
}

class MessageReply {
  final String messageId;
  final String text;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String? mediaUrl;

  MessageReply({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.mediaUrl,
  });

  factory MessageReply.fromMap(Map<String, dynamic> map) {
    return MessageReply(
      messageId: map['messageId'] as String,
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.toString().split('.').last,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    };
  }

  bool get hasMedia => mediaUrl != null && type != MessageType.text;

  String get previewText {
    if (type == MessageType.audio) return '🎵 Audio message';
    if (type == MessageType.voiceNote) return '🎤 Voice message';
    if (type == MessageType.location) return '📍 Location';
    if (type == MessageType.system) return 'ℹ️ System message';
    return text.length > 50 ? '${text.substring(0, 50)}...' : text;
  }
}

class MessageDeliveryInfo {
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final List<DeliveryAttempt> attempts;

  MessageDeliveryInfo({
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.attempts = const [],
  });

  factory MessageDeliveryInfo.fromMap(Map<String, dynamic> map) {
    return MessageDeliveryInfo(
      sentAt:
          map['sentAt'] != null ? (map['sentAt'] as Timestamp).toDate() : null,
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      readAt:
          map['readAt'] != null ? (map['readAt'] as Timestamp).toDate() : null,
      attempts: (map['attempts'] as List?)
              ?.map((e) => DeliveryAttempt.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      'attempts': attempts.map((e) => e.toMap()).toList(),
    };
  }

  Duration? get timeToDeliver {
    if (sentAt == null || deliveredAt == null) return null;
    return deliveredAt!.difference(sentAt!);
  }

  Duration? get timeToRead {
    if (sentAt == null || readAt == null) return null;
    return readAt!.difference(sentAt!);
  }

  bool get isDelivered => deliveredAt != null;
  bool get isRead => readAt != null;

  MessageDeliveryInfo markAsDelivered() {
    return MessageDeliveryInfo(
      sentAt: sentAt,
      deliveredAt: DateTime.now(),
      readAt: readAt,
      attempts: attempts,
    );
  }

  MessageDeliveryInfo markAsRead() {
    return MessageDeliveryInfo(
      sentAt: sentAt,
      deliveredAt: deliveredAt ?? DateTime.now(),
      readAt: DateTime.now(),
      attempts: attempts,
    );
  }

  MessageDeliveryInfo addAttempt({required bool success, String? error}) {
    final newAttempts = List<DeliveryAttempt>.from(attempts);
    newAttempts.add(DeliveryAttempt(
      timestamp: DateTime.now(),
      success: success,
      error: error,
    ));
    return MessageDeliveryInfo(
      sentAt: sentAt,
      deliveredAt: deliveredAt,
      readAt: readAt,
      attempts: newAttempts,
    );
  }
}

class DeliveryAttempt {
  final DateTime timestamp;
  final String? error;
  final bool success;

  DeliveryAttempt({
    required this.timestamp,
    this.error,
    required this.success,
  });

  factory DeliveryAttempt.fromMap(Map<String, dynamic> map) {
    return DeliveryAttempt(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      error: map['error'] as String?,
      success: map['success'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      if (error != null) 'error': error,
      'success': success,
    };
  }
}

// Extension for message formatting
extension MessageExtension on Message {
  String getDisplayText() {
    if (isDeleted) return 'This message was deleted';
    if (type == MessageType.audio) return '🎵 Audio message';
    if (type == MessageType.voiceNote) return '🎤 Voice message';
    if (type == MessageType.location) return '📍 Location';
    if (type == MessageType.system) return text;
    return text;
  }

  String getStatusText() {
    if (status == MessageStatus.sending) return 'Sending...';
    if (status == MessageStatus.failed) return 'Failed to send';
    if (status == MessageStatus.sent && !isDelivered) return 'Sent';
    if (isDelivered && !isRead) return 'Delivered';
    if (isRead) return 'Read';
    return '';
  }
}
