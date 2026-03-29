import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/theme/app_theme.dart';
import 'package:loveell/utils/image_converter.dart';

class UserSearchResultCard extends StatefulWidget {
  final UserModel user;
  final UserModel currentUser;
  final VoidCallback onRequestSent;

  const UserSearchResultCard({
    super.key,
    required this.user,
    required this.currentUser,
    required this.onRequestSent,
  });

  @override
  State<UserSearchResultCard> createState() => _UserSearchResultCardState();
}

class _UserSearchResultCardState extends State<UserSearchResultCard>
    with SingleTickerProviderStateMixin {
  bool _isSendingRequest = false;
  String? _requestStatus;
  bool _isFriend = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyFriend();
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

  Future<void> _checkIfAlreadyFriend() async {
    try {
      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.uid)
          .collection('friends')
          .doc(widget.user.uid)
          .get();

      if (friendDoc.exists) {
        setState(() {
          _isFriend = true;
          _requestStatus = 'already_friends';
        });
      } else {
        final requestQuery = await FirebaseFirestore.instance
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: widget.currentUser.uid)
            .where('toUserId', isEqualTo: widget.user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (requestQuery.docs.isNotEmpty) {
          setState(() {
            _requestStatus = 'pending';
          });
        }
      }
    } catch (e) {
      print('Error checking friend status: $e');
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isSendingRequest) return;

    setState(() {
      _isSendingRequest = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final requestId = FirebaseFirestore.instance.collection('_').doc().id;

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .set({
        'fromUserId': widget.currentUser.uid,
        'toUserId': widget.user.uid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _requestStatus = 'pending';
      });

      widget.onRequestSent();
    } catch (e) {
      print('Error sending friend request: $e');

      String errorMessage = 'Failed to send request';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.createSnackBar(
          errorMessage,
          AppTheme.error,
          icon: Icons.error_outline_rounded,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: widget.user.userId));
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            boxShadow: [
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
                                base64Image: widget.user.profileImageBase64,
                                name: widget.user.name,
                                uid: widget.user.uid,
                                size: 56,
                                backgroundColor: const Color(0xFF2C2C2C),
                                textColor: const Color(0xFF7C7AFF),
                              ),
                            ),
                          ),
                          if (widget.user.isOnline)
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.user.name,
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
                          // Single ID Badge with copy
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
                                  color:
                                      const Color(0xFF7C7AFF).withOpacity(0.3),
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
                                    widget.user.userId,
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
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Button - Compact
                if (_isFriend)
                  _buildSuccessState()
                else if (_requestStatus == 'pending')
                  _buildPendingState()
                else
                  _buildActionButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 6),
          const Text(
            'Friends',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C7AFF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Pending',
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

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isSendingRequest ? null : _sendFriendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C7AFF),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSendingRequest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
