import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/user_model.dart';

class OnlineStatusIndicator extends StatelessWidget {
  final UserModel user;
  final bool showLastSeen;
  final double dotSize;
  final Color onlineColor;
  final Color offlineColor;

  const OnlineStatusIndicator({
    super.key,
    required this.user,
    this.showLastSeen = true,
    this.dotSize = 8,
    this.onlineColor = Colors.green,
    this.offlineColor = Colors.grey,
  });

  String _getLastSeenText() {
    if (user.isOnline) return 'Online';
    if (user.lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final lastSeen = user.lastSeen!;
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(lastSeen);
    }
  }

  Color _getStatusColor() {
    return user.isOnline ? onlineColor : offlineColor;
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;
    final effectiveDotSize = isSmallScreen ? dotSize * 0.75 : dotSize;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: effectiveDotSize,
          height: effectiveDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(),
            boxShadow: user.isOnline
                ? [
                    BoxShadow(
                      color: onlineColor.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        if (showLastSeen) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _getLastSeenText(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: user.isOnline ? onlineColor : Colors.white70,
                fontWeight: user.isOnline ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Optional: A compact version for app bars and list tiles
class CompactOnlineStatusIndicator extends StatelessWidget {
  final UserModel user;
  final double dotSize;

  const CompactOnlineStatusIndicator({
    super.key,
    required this.user,
    this.dotSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user.isOnline ? Colors.green : Colors.grey,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
    );
  }
}
