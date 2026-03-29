import 'package:flutter/material.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/screens/messages/partner_list_screen.dart';
import 'package:loveell/screens/profile/profile_screen.dart';
import 'package:loveell/screens/notifications/notifications_screen.dart';
import 'package:loveell/screens/live/live_screen.dart';
import 'package:loveell/widgets/bottom_navigation/custom_bottom_nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel currentUser;

  const MainNavigationScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late UserModel currentUser;
  int _currentNavIndex = 0;
  bool _isDarkMode = false;

  int _totalUnreadMessages = 0;
  int _unreadNotificationsCount = 0;
  bool _isLiveActive = false;

  late AnimationController _animationController;

  // Dark Theme Colors
  static const Color _primary = Color(0xFF7C7AFF);
  static const Color _secondary = Color(0xFFB46EFF);
  static const Color _background = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2C);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB0B0B0);
  static const Color _borderColor = Color(0xFF2C2C2C);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _success = Color(0xFF10B981);

  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [Color(0xFF7C7AFF), Color(0xFFB46EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color get _surfaceColor => _surface;
  Color get _secondaryTextColor => _textSecondary;

  late final List<Widget> _screens;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _screens = [
      PartnerListScreen(
        currentUser: currentUser,
        onCountsUpdated: _updateCounts,
        key: const PageStorageKey('partner_list'),
      ),
      ProfileScreen(
        currentUser: currentUser,
        onProfileUpdated: _onProfileUpdated,
        key: const PageStorageKey('profile'),
      ),
      LiveDashboardScreen(
        currentUser: currentUser,
        key: const PageStorageKey('live'),
      ),
      NotificationsScreen(
        currentUser: currentUser,
        onCountsUpdated: _updateCounts,
        key: const PageStorageKey('notifications'),
      ),
    ];

    _checkLiveStatus();
  }

  void _checkLiveStatus() {
    FirebaseFirestore.instance
        .collection('live_rooms')
        .where('status', isEqualTo: 'broadcasting')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isLiveActive = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  void _updateCounts({
    int? totalUnreadMessages,
    int? unreadNotificationsCount,
    int? unreadStoriesCount,
  }) {
    setState(() {
      if (totalUnreadMessages != null)
        _totalUnreadMessages = totalUnreadMessages;
      if (unreadNotificationsCount != null)
        _unreadNotificationsCount = unreadNotificationsCount;
    });
  }

  void _onProfileUpdated() {
    setState(() {});
  }

  void _onNavItemTapped(int index) {
    if (_currentNavIndex == index) {
      _scrollToTop();
      return;
    }

    setState(() {
      _currentNavIndex = index;
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _scrollToTop() {}

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _screens[_currentNavIndex],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavItemTapped,
        totalUnreadMessages: _totalUnreadMessages,
        unreadNotificationsCount: _unreadNotificationsCount,
        isLiveActive: _isLiveActive,
        surfaceColor: _surfaceColor,
        primaryColor: _primary,
        secondaryTextColor: _secondaryTextColor,
        primaryGradient: _primaryGradient,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
