import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/theme/app_theme.dart';
import 'package:loveell/utils/image_converter.dart';

class FriendRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final UserModel fromUser;
  final DateTime timestamp;
  final bool isProcessing;
  final Future<void> Function() onAccepted;
  final Future<void> Function() onRejected;

  const FriendRequestCard({
    super.key,
    required this.request,
    required this.fromUser,
    required this.timestamp,
    this.isProcessing = false,
    required this.onAccepted,
    required this.onRejected,
  });

  @override
  State<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<FriendRequestCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isAcceptHovered = false;
  bool _isRejectHovered = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(date);
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 5) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _handleReject() async {
    if (widget.isProcessing) return;
    await widget.onRejected();
  }

  Future<void> _handleAccept() async {
    if (widget.isProcessing) return;
    await widget.onAccepted();
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: widget.fromUser.userId));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.createSnackBar(
        'ID copied!',
        AppTheme.primary,
        icon: Icons.copy_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.02))
                : Matrix4.identity(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF1A1A1A),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C7AFF).withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ],
                border: Border.all(
                  color: const Color(0xFF2A2A2A),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header with avatar and name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C7AFF).withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C7AFF),
                                      Color(0xFFA5A3FF),
                                    ],
                                  ),
                                ),
                                child: ClipOval(
                                  child: ImageConverter.getCachedAvatar(
                                    base64Image:
                                        widget.fromUser.profileImageBase64,
                                    name: widget.fromUser.name,
                                    uid: widget.fromUser.uid,
                                    size: 56,
                                    backgroundColor: const Color(0xFF2C2C2C),
                                    textColor: const Color(0xFF7C7AFF),
                                  ),
                                ),
                              ),
                              if (widget.fromUser.isOnline)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981),
                                      border: Border.all(
                                        color: const Color(0xFF1E1E1E),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fromUser.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              // ID Badge with copy
                              GestureDetector(
                                onTap: _copyUserId,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF7C7AFF)
                                          .withOpacity(0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_rounded,
                                        size: 12,
                                        color: Color(0xFF7C7AFF),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.fromUser.userId,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFB0B0B0),
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 10,
                                        color: Color(0xFF7C7AFF),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Time indicator
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: const Color(0xFF6B6B6B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(widget.timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B6B6B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (widget.isProcessing)
                      _buildProcessingState()
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              onPressed: _handleAccept,
                              label: 'Accept',
                              icon: Icons.check_rounded,
                              backgroundColor: const Color(0xFF10B981),
                              isHovered: _isAcceptHovered,
                              onHoverEnter: () =>
                                  setState(() => _isAcceptHovered = true),
                              onHoverExit: () =>
                                  setState(() => _isAcceptHovered = false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              onPressed: _handleReject,
                              label: 'Decline',
                              icon: Icons.close_rounded,
                              backgroundColor: const Color(0xFFEF4444),
                              isHovered: _isRejectHovered,
                              onHoverEnter: () =>
                                  setState(() => _isRejectHovered = true),
                              onHoverExit: () =>
                                  setState(() => _isRejectHovered = false),
                            ),
                          ),
                        ],
                      ),

                    // Mutual friends indicator (optional)
                    if (_isHovered)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF7C7AFF).withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 12,
                                color: const Color(0xFF7C7AFF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '2 mutual friends',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFFB0B0B0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C7AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7C7AFF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C7AFF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Processing...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C7AFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required bool isHovered,
    required VoidCallback onHoverEnter,
    required VoidCallback onHoverExit,
  }) {
    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      child: SizedBox(
        height: 42,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isHovered ? backgroundColor.withOpacity(0.9) : backgroundColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: isHovered ? 2 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
