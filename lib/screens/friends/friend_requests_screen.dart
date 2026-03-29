import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/screens/friends/friend_requests_card.dart';
import 'package:loveell/theme/app_theme.dart';

class FriendRequestsScreen extends StatefulWidget {
  final UserModel currentUser;

  const FriendRequestsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRequestsListener();
    _checkAuthAndPermissions();
  }

  void _checkAuthAndPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    print('=== AUTH CHECK ===');
    print('Current user UID: ${user?.uid}');
    print('Current user email: ${user?.email}');

    if (user == null) {
      print('❌ ERROR: No user logged in!');
      if (mounted) {
        setState(() {
          _errorMessage = 'Please log in again';
        });
      }
    } else {
      print('✅ User authenticated successfully');
      await _testPermissions(user.uid);
    }
  }

  Future<void> _testPermissions(String userId) async {
    print('\n=== TESTING PERMISSIONS ===');

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      print('✅ Can read own user document');
    } catch (e) {
      print('❌ Cannot read own user document: $e');
    }

    final testId = FirebaseFirestore.instance.collection('_').doc().id;
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(testId)
          .set({
        'fromUserId': userId,
        'toUserId': 'test_user_123',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Can create friend request');

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(testId)
          .update({'status': 'accepted'});
      print('✅ Can update friend request');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc('test_friend')
          .set({
        'friendId': 'test_friend',
        'addedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Can write to friends subcollection');

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(testId)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc('test_friend')
          .delete();

      print('✅ All permissions working correctly!\n');
    } catch (e) {
      print('❌ Permission test failed: $e');
    }
  }

  void _setupRequestsListener() {
    _requestsSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: widget.currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fromUserId = data['fromUserId'] as String;

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fromUserId)
              .get();

          if (userDoc.exists) {
            requests.add({
              'requestId': doc.id,
              'fromUser':
                  UserModel.fromMap(userDoc.data() as Map<String, dynamic>),
              'timestamp':
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'isProcessing': false,
            });
          }
        } catch (e) {
          print('Error loading user: $e');
        }
      }

      requests.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Error in requests listener: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load requests';
        });
      }
    });
  }

  @override
  void dispose() {
    _requestsSubscription.cancel();
    super.dispose();
  }

  // FIXED: Use transaction for atomic operations
  Future<void> _acceptRequest(String requestId, UserModel sender) async {
    HapticFeedback.mediumImpact();

    // Show loading indicator
    setState(() {
      final index = _requests.indexWhere((r) => r['requestId'] == requestId);
      if (index != -1) {
        _requests[index]['isProcessing'] = true;
      }
    });

    try {
      final currentFirebaseUser = FirebaseAuth.instance.currentUser;
      if (currentFirebaseUser == null) {
        throw Exception('User not authenticated');
      }

      if (currentFirebaseUser.uid != widget.currentUser.uid) {
        throw Exception('User ID mismatch');
      }

      print('\n=== ACCEPTING FRIEND REQUEST ===');
      print('Request ID: $requestId');
      print(
          'Current user: ${widget.currentUser.uid} (${widget.currentUser.name})');
      print('Sender: ${sender.uid} (${sender.name})');

      final requestRef = FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId);

      final requestDoc = await requestRef.get();
      if (!requestDoc.exists) {
        throw Exception('Friend request no longer exists');
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      print('Request status: ${requestData['status']}');

      if (requestData['status'] != 'pending') {
        throw Exception('Request already processed');
      }

      // Use TRANSACTION for atomic operations
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Update request status to accepted
        transaction.update(requestRef, {'status': 'accepted'});
        print('✓ Added request update to transaction');

        // 2. Add to current user's friends
        final currentUserFriendRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUser.uid)
            .collection('friends')
            .doc(sender.uid);

        transaction.set(currentUserFriendRef, {
          'friendId': sender.uid,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('✓ Added current user friend to transaction');

        // 3. Add to sender's friends
        final senderFriendRef = FirebaseFirestore.instance
            .collection('users')
            .doc(sender.uid)
            .collection('friends')
            .doc(widget.currentUser.uid);

        transaction.set(senderFriendRef, {
          'friendId': widget.currentUser.uid,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('✓ Added sender friend to transaction');

        // 4. Create notification for sender
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(sender.uid)
            .collection('notifications')
            .doc();

        transaction.set(notificationRef, {
          'type': 'friend_request_accepted',
          'message': '${widget.currentUser.name} accepted your friend request',
          'userId': widget.currentUser.uid,
          'userName': widget.currentUser.name,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        print('✓ Added notification to transaction');
      });

      print('✅ Transaction completed successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.createSnackBar(
            'Friend request accepted!',
            AppTheme.success,
            icon: Icons.check_rounded,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error accepting request: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');

      String errorMessage = 'Failed to accept request';
      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Permission denied. Please check your internet connection and try again.';
        print('⚠️ This is a Firestore security rules issue');
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'Request not found. It may have been already processed.';
      } else if (e.toString().contains('already-exists')) {
        errorMessage = 'You are already friends with this user.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.createSnackBar(
            errorMessage,
            AppTheme.error,
            icon: Icons.error_outline_rounded,
          ),
        );
      }

      // Reset processing state
      setState(() {
        final index = _requests.indexWhere((r) => r['requestId'] == requestId);
        if (index != -1) {
          _requests[index]['isProcessing'] = false;
        }
      });
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    HapticFeedback.lightImpact();

    setState(() {
      final index = _requests.indexWhere((r) => r['requestId'] == requestId);
      if (index != -1) {
        _requests[index]['isProcessing'] = true;
      }
    });

    try {
      print('\n=== REJECTING FRIEND REQUEST ===');
      print('Request ID: $requestId');

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'rejected'});

      print('✅ Request rejected successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.createSnackBar(
            'Request rejected',
            AppTheme.warning,
            icon: Icons.close_rounded,
          ),
        );
      }
    } catch (e) {
      print('❌ Error rejecting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.createSnackBar(
            'Failed to reject request',
            AppTheme.error,
            icon: Icons.error_outline_rounded,
          ),
        );
      }

      setState(() {
        final index = _requests.indexWhere((r) => r['requestId'] == requestId);
        if (index != -1) {
          _requests[index]['isProcessing'] = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leadingWidth: 70,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        title: Text(
          'Friend Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2C2C2C).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF7C7AFF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading requests...',
                    style: TextStyle(
                      color: const Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: const Color(0xFFB0B0B0),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _setupRequestsListener();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C7AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _requests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        final sender = request['fromUser'] as UserModel;
                        final timestamp = request['timestamp'] as DateTime;
                        final isProcessing = request['isProcessing'] == true;

                        return FriendRequestCard(
                          key: ValueKey(request['requestId']),
                          request: request,
                          fromUser: sender,
                          timestamp: timestamp,
                          isProcessing: isProcessing,
                          onAccepted: () =>
                              _acceptRequest(request['requestId'], sender),
                          onRejected: () =>
                              _rejectRequest(request['requestId']),
                        );
                      },
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
            Image.asset(
              'assets/icons-header/friend-request.png',
              width: 80,
              height: 80,
              color: const Color(0xFF7C7AFF).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When someone sends you a friend request,\nit will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: const Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
