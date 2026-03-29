import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry; // For failed messages
  final bool isSending; // For showing sending indicator

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.onRetry,
    this.isSending = false,
  });

  // Get message status icon
  Map<String, dynamic> _getMessageStatus() {
    if (!isMe) {
      return {'icon': null, 'color': null};
    }

    if (isSending) {
      return {
        'icon': Icons.access_time,
        'color': Colors.orange,
      };
    }

    if (message.isRead) {
      return {
        'icon': Icons.done_all,
        'color': Colors.blue, // Double blue check for read
      };
    } else if (message.isDelivered) {
      return {
        'icon': Icons.done_all,
        'color': Colors.grey, // Double grey check for delivered
      };
    } else {
      return {
        'icon': Icons.done,
        'color': Colors.grey, // Single gray check for sent
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getMessageStatus();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.pink.shade100,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.pink
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          color: Colors.pink.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(message.timestamp),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white70
                              : (isDark
                                  ? Colors.white70
                                  : Colors.grey.shade600),
                          fontSize: 10,
                        ),
                      ),
                      // Show status icon for my messages
                      if (isMe && status['icon'] != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          status['icon'],
                          size: 14,
                          color: status['color'],
                        ),
                      ],
                      // Show retry button for failed messages
                      if (isMe && onRetry != null && !isSending) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onRetry,
                          child: Icon(
                            Icons.refresh,
                            size: 14,
                            color: isMe ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                      // Show delete icon if provided
                      if (isMe && onDelete != null && !isSending) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: isMe ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
