import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int totalUnreadMessages;
  final int unreadNotificationsCount;
  final bool isLiveActive;
  final Color surfaceColor;
  final Color primaryColor;
  final Color secondaryTextColor;
  final Gradient primaryGradient;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.totalUnreadMessages,
    required this.unreadNotificationsCount,
    this.isLiveActive = false,
    required this.surfaceColor,
    required this.primaryColor,
    required this.secondaryTextColor,
    required this.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 6), // Reduced padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItemWithCustomIcon(
                  index: 0,
                  iconPath: 'assets/icons-bottom/chats.png',
                  label: 'Chats',
                  badgeCount: totalUnreadMessages,
                ),
                _buildNavItemWithCustomIcon(
                  index: 1,
                  iconPath: 'assets/icons-bottom/profile.png',
                  label: 'Account',
                  badgeCount: 0,
                ),
                _buildNavItemWithCustomIcon(
                  index: 2,
                  iconPath: 'assets/icons-bottom/live.png',
                  label: 'Stream',
                  badgeCount: 0,
                  isLive: true,
                  isLiveActive: isLiveActive,
                ),
                _buildNavItemWithCustomIcon(
                  index: 3,
                  iconPath: 'assets/icons-bottom/notification.png',
                  label: 'Alerts',
                  badgeCount: unreadNotificationsCount,
                ),
                _buildNavItemWithCustomIcon(
                  index: 4,
                  iconPath: 'assets/icons-bottom/map.png',
                  label: 'Map',
                  badgeCount: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Method for custom PNG icons
  Widget _buildNavItemWithCustomIcon({
    required int index,
    required String iconPath,
    required String label,
    required int badgeCount,
    bool isLive = false,
    bool isLiveActive = false,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4), // Reduced padding
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live indicator dot for live tab
                  if (isLive && isLiveActive && !isSelected)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 6, // Smaller dot
                        height: 6, // Smaller dot
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                  // Custom icon with animation - SMALLER SIZE
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      iconPath,
                      key: ValueKey<bool>(isSelected),
                      width: 24, // Reduced from 24 to 20
                      height: 24, // Reduced from 24 to 20
                      color: isSelected
                          ? (isLive ? Colors.red : primaryColor)
                          : secondaryTextColor,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback icon if image fails to load
                        return Icon(
                          Icons.error_outline,
                          color: isSelected
                              ? (isLive ? Colors.red : primaryColor)
                              : secondaryTextColor,
                          size: 24, // Reduced from 24 to 20
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced from 4 to 2

                  // Animated label with color - SMALLER TEXT
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isSelected
                          ? (isLive ? Colors.red : primaryColor)
                          : secondaryTextColor,
                      fontSize: 10, // Reduced from 11 to 10
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    child: Text(label),
                  ),
                ],
              ),

              // Badge for unread counts - ADJUSTED POSITION
              if (badgeCount > 0)
                Positioned(
                  top: -4, // Adjusted position
                  right: -4, // Adjusted position
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(2), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(
                                10), // Slightly smaller radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 3, // Reduced blur
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14, // Reduced from 16
                            minHeight: 14, // Reduced from 16
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8, // Reduced from 9
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
