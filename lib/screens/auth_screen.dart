import 'package:flutter/material.dart';
import 'package:loveell/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isDarkMode = false; // Dark mode state
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color schemes for light and dark mode
  late ColorScheme _lightColorScheme;
  late ColorScheme _darkColorScheme;

  @override
  void initState() {
    super.initState();
    _initColorSchemes();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  void _initColorSchemes() {
    // Light color scheme
    _lightColorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF5E5CE6),
      onPrimary: Colors.white,
      secondary: Color(0xFF9D4EDD),
      onSecondary: Colors.white,
      error: Color(0xFFE55B4B),
      onError: Colors.white,
      background: Color(0xFFF5F5F5),
      onBackground: Color(0xFF1D1F2F),
      surface: Colors.white,
      onSurface: Color(0xFF1D1F2F),
    );

    // Dark color scheme
    _darkColorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7C7AFF), // Lighter purple for dark mode
      onPrimary: Colors.white,
      secondary: Color(0xFFB46EFF), // Lighter pinkish purple for dark mode
      onSecondary: Colors.white,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      background: Color(0xFF121212),
      onBackground: Colors.white,
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  // Get current color scheme based on dark mode state
  ColorScheme get _currentColorScheme =>
      _isDarkMode ? _darkColorScheme : _lightColorScheme;

  // Get background gradient based on mode
  List<Color> get _backgroundGradient {
    if (_isDarkMode) {
      return const [
        Color(0xFF121212),
        Color(0xFF1A1A2E),
        Color(0xFF16213E),
      ];
    } else {
      return const [
        Color(0xFFF5F5F5),
        Color(0xFFFAFAFA),
        Color(0xFFFFFFFF),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _currentColorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _backgroundGradient,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Theme Toggle and App Title Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40), // Spacer for balance

                          // App Title - LovELL
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'LovELL',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Dark Mode Toggle Icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.surface.withOpacity(0.1),
                              border: Border.all(
                                color: colorScheme.onSurface.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isDarkMode
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                size: 22,
                                color: colorScheme.primary,
                              ),
                              onPressed: _toggleDarkMode,
                              tooltip: _isDarkMode
                                  ? 'Switch to Light Mode'
                                  : 'Switch to Dark Mode',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        _isLogin
                            ? 'Sign in to continue'
                            : 'Create your account',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Auth Form - Pass color scheme
                      AuthForm(
                        isLogin: _isLogin,
                        onSubmit: _handleAuth,
                        colorScheme: colorScheme,
                        isDarkMode: _isDarkMode,
                        key: ValueKey('$_isLogin-$_isDarkMode'),
                      ),

                      const SizedBox(height: 40),

                      // Toggle Mode - Clean divider style
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Toggle option
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text:
                                  _isLogin ? "New here? " : "Have an account? ",
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              children: [
                                TextSpan(
                                  text: _isLogin ? 'Sign Up' : 'Sign In',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAuth({
    required String email,
    required String password,
    String? name,
  }) async {
    final authService = AuthService();

    if (_isLogin) {
      final result = await authService.signIn(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        _showSuccessSnackBar('Welcome back! 👋');
      } else {
        _showErrorSnackBar(result['error']);
      }
    } else {
      final result = await authService.signUp(
        email: email,
        password: password,
        name: name!,
      );

      if (result['success'] == true) {
        _showSuccessSnackBar('Account created! 🎉');
      } else {
        _showErrorSnackBar(result['error']);
      }
    }
  }

  void _showErrorSnackBar(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Something went wrong',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            _isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFFE55B4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            _isDarkMode ? const Color(0xFF6FCF97) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============== Updated AuthForm Widget with Dark Mode Support ==============

class AuthForm extends StatefulWidget {
  final bool isLogin;
  final Function({
    required String email,
    required String password,
    String? name,
  }) onSubmit;
  final ColorScheme colorScheme;
  final bool isDarkMode;

  const AuthForm({
    super.key,
    required this.isLogin,
    required this.onSubmit,
    required this.colorScheme,
    required this.isDarkMode,
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _isNameFocused = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      await widget.onSubmit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: widget.isLogin ? null : _nameController.text.trim(),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field (only for signup)
            if (!widget.isLogin) ...[
              _buildAnimatedField(
                visible: !widget.isLogin,
                child: _buildNameField(colorScheme),
              ),
              const SizedBox(height: 16),
            ],

            // Email field
            _buildEmailField(colorScheme),
            const SizedBox(height: 16),

            // Password field
            _buildPasswordField(colorScheme),
            const SizedBox(height: 32),

            // Submit button
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [
                          colorScheme.onSurface.withOpacity(0.2),
                          colorScheme.onSurface.withOpacity(0.3),
                        ]
                      : [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colorScheme.onPrimary,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedField({
    required bool visible,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: visible ? child : const SizedBox.shrink(),
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isEmailFocused = hasFocus);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isDarkMode
              ? colorScheme.surface.withOpacity(0.3)
              : colorScheme.surface.withOpacity(0.8),
          border: Border.all(
            color: _isEmailFocused
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.1),
            width: _isEmailFocused ? 2 : 1,
          ),
        ),
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _isEmailFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            floatingLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
            hintText: 'you@example.com',
            hintStyle: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            prefixIcon: Icon(
              Icons.email_outlined,
              size: 20,
              color: _isEmailFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Invalid email format';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isPasswordFocused = hasFocus);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isDarkMode
              ? colorScheme.surface.withOpacity(0.3)
              : colorScheme.surface.withOpacity(0.8),
          border: Border.all(
            color: _isPasswordFocused
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.1),
            width: _isPasswordFocused ? 2 : 1,
          ),
        ),
        child: TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _isPasswordFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            floatingLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
            hintText: widget.isLogin ? 'Enter password' : 'Create password',
            hintStyle: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: _isPasswordFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: _isPasswordFocused
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (!widget.isLogin) {
              if (value.length < 8) {
                return 'Minimum 8 characters';
              }
              if (!value.contains(RegExp(r'[A-Z]'))) {
                return 'Include at least one uppercase letter';
              }
              if (!value.contains(RegExp(r'[0-9]'))) {
                return 'Include at least one number';
              }
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildNameField(ColorScheme colorScheme) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isNameFocused = hasFocus);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isDarkMode
              ? colorScheme.surface.withOpacity(0.3)
              : colorScheme.surface.withOpacity(0.8),
          border: Border.all(
            color: _isNameFocused
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.1),
            width: _isNameFocused ? 2 : 1,
          ),
        ),
        child: TextFormField(
          controller: _nameController,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            labelText: 'Full Name',
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _isNameFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            floatingLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
            hintText: 'Enter your full name',
            hintStyle: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: _isNameFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Name is required';
            }
            if (value.length < 2) {
              return 'Name is too short';
            }
            return null;
          },
        ),
      ),
    );
  }
}
