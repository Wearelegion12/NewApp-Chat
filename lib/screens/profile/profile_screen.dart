import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/utils/image_converter.dart';
import 'package:loveell/services/image_cache_service.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function()? onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.currentUser,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late UserModel _user;
  bool _isLoading = false;
  bool _isStatsLoading = true;
  bool _isSigningOut = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _currentImageHash;
  ValueKey _avatarKey = const ValueKey('avatar_initial');

  int _chatCount = 0;
  int _friendCount = 0;
  String? _statsError;

  // Dark theme color palette
  static const Color _primary = Color(0xFF00D4AA);
  static const Color _primaryDark = Color(0xFF00B894);
  static const Color _primaryLight = Color(0xFF80E9D0);
  static const Color _secondary = Color(0xFF6C5CE7);
  static const Color _accent = Color(0xFFFD9644);
  static const Color _background = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _surfaceAlt = Color(0xFF252525);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB0B0B0);
  static const Color _textTertiary = Color(0xFF6B6B6B);
  static const Color _success = Color(0xFF00D4AA);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _border = Color(0xFF2A2A2A);
  static const Color _shadow = Color(0x40000000);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _currentImageHash = _user.profileImageBase64?.hashCode.toString();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _loadUserStatistics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileImage();
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUser.uid != oldWidget.currentUser.uid ||
        widget.currentUser.profileImageBase64 !=
            oldWidget.currentUser.profileImageBase64) {
      setState(() {
        _user = widget.currentUser;
        _currentImageHash = _user.profileImageBase64?.hashCode.toString();
        _avatarKey = ValueKey(
            'avatar_${_currentImageHash}_${DateTime.now().millisecondsSinceEpoch}');
      });
    }
  }

  Future<void> _loadUserStatistics() async {
    if (!mounted) return;
    setState(() {
      _isStatsLoading = true;
      _statsError = null;
    });

    try {
      try {
        final chatsSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _user.uid)
            .get();
        _chatCount = chatsSnapshot.docs.length;
      } catch (e) {
        _chatCount = 0;
        if (e.toString().contains('permission-denied')) {
          _statsError = 'Unable to load chat statistics';
        }
      }

      try {
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .collection('friends')
            .get();
        _friendCount = friendsSnapshot.docs.length;
      } catch (e) {
        _friendCount = 0;
        if (e.toString().contains('permission-denied')) {
          _statsError = _statsError == null
              ? 'Unable to load friends statistics'
              : 'Unable to load some statistics';
        }
      }

      if (mounted) {
        setState(() {
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatCount = 0;
          _friendCount = 0;
          _isStatsLoading = false;
          _statsError = 'Unable to load statistics';
        });
      }
    }
  }

  Future<void> _refreshProfileImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final newImageBase64 = data['profileImageBase64'] as String?;
        final newImageHash = newImageBase64?.hashCode.toString();

        if (newImageHash != _currentImageHash) {
          ImageCacheService().clearUserCache(_user.uid);

          if (mounted) {
            setState(() {
              _user = _user.copyWith(profileImageBase64: newImageBase64);
              _currentImageHash = newImageHash;
              _avatarKey = ValueKey(
                  'avatar_${newImageHash}_${DateTime.now().millisecondsSinceEpoch}');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await ImageConverter.pickImage(
        ImageSource.gallery,
        highQuality: true,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final base64Image = await ImageConverter.xFileToBase64(
        image,
        highQuality: true,
      );

      if (base64Image == null) throw Exception('Failed to convert image');

      final imageSize = base64Image.length;
      if (imageSize > 5 * 1024 * 1024) {
        _showToast('Image must be less than 5MB', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final newImageHash = base64Image.hashCode.toString();

      ImageCacheService().clearUserCache(_user.uid);
      await Future.delayed(const Duration(milliseconds: 100));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({'profileImageBase64': base64Image});

      if (mounted) {
        setState(() {
          _user = _user.copyWith(profileImageBase64: base64Image);
          _currentImageHash = newImageHash;
          _isLoading = false;
          _avatarKey = ValueKey(
              'avatar_${newImageHash}_${DateTime.now().millisecondsSinceEpoch}');
        });
      }

      widget.onProfileUpdated?.call();
      _showToast('Profile picture updated');
    } catch (e) {
      if (mounted) {
        _showToast('Error updating profile picture', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? _error : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error signing out'),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildHeaderSection(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildInfoList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildActionButtons(),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 95, 67, 173),
            const Color.fromARGB(255, 57, 108, 167),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with avatar and stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const Spacer(),
              _buildCompactStats(),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom row with name and ID
          _buildNameAndIdSection(),
          const SizedBox(height: 12),
          // Bottom right buttons - Settings and Logout
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBottomIconButton(
                  iconPath: 'assets/icons-profile/settings.png',
                  onPressed: () {},
                  isLogout: false,
                ),
                const SizedBox(width: 8),
                _buildBottomIconButton(
                  iconPath: 'assets/icons-profile/logout.png',
                  onPressed: _showLogoutDialog,
                  isLogout: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIconButton({
    required String iconPath,
    required VoidCallback onPressed,
    required bool isLogout,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isLogout ? _error.withOpacity(0.2) : Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: isLogout
              ? _error.withOpacity(0.5)
              : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              iconPath,
              width: 16,
              height: 16,
              color: isLogout ? _error : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickAndUploadImage,
      child: Stack(
        children: [
          Container(
            key: _avatarKey,
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: ImageConverter.getCachedAvatar(
                base64Image: _user.profileImageBase64,
                name: _user.name,
                uid: _user.uid,
                size: 80,
                backgroundColor: Colors.transparent,
                textColor: Colors.white,
                highQuality: true,
                key: ValueKey(
                    'profile_avatar_inner_${_currentImageHash ?? 'null'}'),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: const Color.fromARGB(255, 88, 76, 155),
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStats() {
    if (_isStatsLoading) {
      return _buildCompactStatsShimmer();
    }

    if (_statsError != null) {
      return _buildCompactStatsError();
    }

    return Column(
      children: [
        _buildCompactStatItem(
          value: _chatCount.toString(),
          label: 'Chats',
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        _buildCompactStatItem(
          value: _friendCount.toString(),
          label: 'Friends',
          icon: Icons.people_alt_rounded,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildCompactStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatsShimmer() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 20,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: 25,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 20,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: 30,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatsError() {
    return GestureDetector(
      onTap: _loadUserStatistics,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _warning.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _warning.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 10,
            ),
            const SizedBox(width: 4),
            Text(
              'Retry',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameAndIdSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _user.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 12,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _user.userId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _user.userId));
                  _showToast('User ID copied');
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoList() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _buildInfoTile(
            iconPath: 'assets/icons-profile/email.png',
            title: 'Email',
            value: _user.email,
          ),
          _buildDivider(),
          _buildInfoTile(
            iconPath: 'assets/icons-profile/calendar.png',
            title: 'Joined',
            value: _formatDate(_user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String iconPath,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              iconPath,
              width: 16,
              height: 16,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: _border,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildActionButtons() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _buildActionButton(
            iconPath: 'assets/icons-profile/privacy.png',
            label: 'Privacy',
            onTap: () {},
          ),
          _buildDivider(),
          _buildActionButton(
            iconPath: 'assets/icons-profile/notification.png',
            label: 'Notifications',
            onTap: () {},
          ),
          _buildDivider(),
          _buildActionButton(
            iconPath: 'assets/icons-profile/help.png',
            label: 'Help',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  iconPath,
                  width: 16,
                  height: 16,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textTertiary,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _isSigningOut
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_error),
                          ),
                        )
                      : Image.asset(
                          'assets/icons-profile/logout.png',
                          width: 28,
                          height: 28,
                          color: _error,
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to leave?',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isSigningOut ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: _surfaceAlt,
                          foregroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSigningOut ? null : _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSigningOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
