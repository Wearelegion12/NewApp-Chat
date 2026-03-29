// screens/friends/search_users_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/screens/friends/search_users_card.dart';
import 'package:loveell/theme/app_theme.dart';

class SearchUsersScreen extends StatefulWidget {
  final UserModel currentUser;

  const SearchUsersScreen({super.key, required this.currentUser});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  UserModel? _foundUser;
  bool _isSearching = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  // Cache for search results to avoid redundant searches
  String? _lastSearchedUserId;
  UserModel? _cachedResult;
  String? _cachedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (value.isNotEmpty && mounted) {
        _searchByUserId(value);
      }
    });
  }

  Future<void> _searchByUserId(String userId) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      _updateState(error: 'Please enter a User ID', foundUser: null);
      return;
    }

    if (trimmedUserId == widget.currentUser.userId) {
      _updateState(error: 'This is your own User ID', foundUser: null);
      return;
    }

    // Check cache first
    if (_lastSearchedUserId == trimmedUserId) {
      if (_cachedResult != null) {
        _updateState(foundUser: _cachedResult, error: null);
      } else if (_cachedError != null) {
        _updateState(error: _cachedError, foundUser: null);
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
    });

    try {
      final result = await _firestore
          .collection('users')
          .where('userId', isEqualTo: trimmedUserId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (result.docs.isEmpty) {
        final errorMsg = 'No user found with ID: $trimmedUserId';
        _cacheSearchResult(trimmedUserId, null, errorMsg);
        _updateState(error: errorMsg, foundUser: null);
        return;
      }

      final userData = result.docs.first.data();
      final foundUser = UserModel.fromMap(userData);

      if (foundUser.uid == widget.currentUser.uid) {
        final errorMsg = 'This is your own User ID';
        _cacheSearchResult(trimmedUserId, null, errorMsg);
        _updateState(error: errorMsg, foundUser: null);
        return;
      }

      _cacheSearchResult(trimmedUserId, foundUser, null);
      _updateState(foundUser: foundUser, error: null);
    } catch (e) {
      print('Search error: $e');
      final errorMsg = 'Error searching: ${_getFriendlyErrorMessage(e)}';
      _cacheSearchResult(trimmedUserId, null, errorMsg);
      if (mounted) {
        _updateState(error: errorMsg, foundUser: null);
      }
    }
  }

  void _cacheSearchResult(String userId, UserModel? user, String? error) {
    _lastSearchedUserId = userId;
    _cachedResult = user;
    _cachedError = error;
  }

  void _updateState({UserModel? foundUser, String? error}) {
    setState(() {
      _foundUser = foundUser;
      _errorMessage = error;
      _isSearching = false;
    });
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('permission-denied')) {
      return 'Permission denied. Please check your login status.';
    } else if (errorString.contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'An unexpected error occurred';
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _foundUser = null;
      _errorMessage = null;
    });
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _handleRequestSent() {
    // Clear cache for this search after request is sent
    if (_lastSearchedUserId != null) {
      _cacheSearchResult(_lastSearchedUserId!, null, null);
    }

    setState(() {
      _foundUser = null;
      _searchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.createSnackBar(
        'Friend request sent!',
        AppTheme.success,
        icon: Icons.check_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      toolbarHeight: 56,
      leadingWidth: 70,
      leading: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: BackButton(
          color: Colors.white,
          style: ButtonStyle(
            iconSize: WidgetStatePropertyAll(18.0),
          ),
        ),
      ),
      title: const Text(
        'Find Friends',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: _buildSearchBar(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'SEARCH BY FRIENDS ID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Color(0xFFB0B0B0),
              ),
            ),
          ),
          RepaintBoundary(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchController.text.isNotEmpty
                      ? const Color(0xFF7C7AFF).withOpacity(0.3)
                      : const Color(0xFF2C2C2C),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      size: 20,
                      color: Color(0xFF7C7AFF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter ID...',
                        hintStyle: TextStyle(
                          color: const Color(0xFFB0B0B0).withOpacity(0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _searchByUserId,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFFB0B0B0),
                      ),
                      onPressed: _clearSearch,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                    ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _searchController.text.isNotEmpty && !_isSearching
                          ? const Color(0xFF7C7AFF)
                          : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isSearching
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
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                      color: _searchController.text.isNotEmpty
                          ? Colors.white
                          : const Color(0xFFB0B0B0).withOpacity(0.5),
                      onPressed:
                          (_searchController.text.isNotEmpty && !_isSearching)
                              ? () => _searchByUserId(_searchController.text)
                              : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) return const _SearchingIndicator();
    if (_errorMessage != null) return _buildErrorState();
    if (_foundUser == null) return const _EmptyState();
    return _buildResultsState();
  }

  Widget _buildResultsState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        child: UserSearchResultCard(
          user: _foundUser!,
          currentUser: widget.currentUser,
          onRequestSent: _handleRequestSent,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isNoUserFound = _errorMessage?.startsWith('No user found') ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isNoUserFound) ...[
              const Text(
                'No User Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB0B0B0),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _searchController.text.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB0B0B0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB0B0B0),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _clearSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB0B0B0),
                    side: const BorderSide(color: Color(0xFF2C2C2C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(80, 36),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _searchByUserId(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C7AFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(80, 36),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Extracted stateless widgets for better performance
class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C7AFF)),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFB0B0B0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Find Friends',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Enter a User ID in the search bar\nto find and connect with friends',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
