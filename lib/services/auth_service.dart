import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loveell/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null) {
        // Generate a unique display ID for the user (for finding friends)
        String displayId = _generateDisplayId();

        // Also generate a unique ID for backend
        String uniqueId = _generateUniqueId();

        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          createdAt: DateTime.now(),
          isOnline: true,
          lastSeen: DateTime.now(),
          userId: displayId, // Store the display ID here for easy sharing
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

        // Add additional searchable fields
        await _firestore.collection('users').doc(user.uid).update({
          'displayId': displayId,
          'uniqueId': uniqueId,
          'searchableIds': [
            displayId.toLowerCase(),
            uniqueId.toLowerCase(),
            email.toLowerCase(),
            name.toLowerCase(),
          ],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Return the user with the display ID
        final updatedUser = newUser.copyWith(userId: displayId);

        return {'success': true, 'user': updatedUser};
      }

      return {'success': false, 'error': 'User creation failed'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'This email is already registered. Please login instead.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          errorMessage = 'Password should be at least 6 characters.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during sign up.';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generate a unique display ID (for users to share)
  String _generateDisplayId() {
    // Format: LOVE + 6 random digits
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = (100000 + (timestamp.hashCode % 900000)).toString();
    return 'LOVE$random';
  }

  // Generate a unique ID (for backend)
  String _generateUniqueId() {
    // Format: timestamp + random string
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = (1000 + (DateTime.now().microsecond % 9000)).toString();
    return '${timestamp}_$random';
  }

  // Sign In
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': true,
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });

        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          UserModel userData =
              UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
          return {'success': true, 'user': userData};
        }
      }

      return {'success': false, 'error': 'Sign in failed'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during sign in.';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Search for users by ID (for finding friends)
  Future<List<UserModel>> searchUsersByDisplayId(String displayId) async {
    try {
      if (displayId.isEmpty) return [];

      // Search for exact match first
      final exactMatch = await _firestore
          .collection('users')
          .where('displayId', isEqualTo: displayId)
          .limit(10)
          .get();

      if (exactMatch.docs.isNotEmpty) {
        return exactMatch.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList();
      }

      // If no exact match, search in searchableIds
      final searchResults = await _firestore
          .collection('users')
          .where('searchableIds', arrayContains: displayId.toLowerCase())
          .limit(10)
          .get();

      return searchResults.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user by display ID
  Future<UserModel?> getUserByDisplayId(String displayId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayId', isEqualTo: displayId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      print('Error updating status: $e');
    }
    await _auth.signOut();
  }

  // Get Current User Data
  Future<UserModel?> getCurrentUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error loading user data: $e');
      return null;
    }
  }

  // Get All Users Stream
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  // Update Online Status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  // Auth State Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current User Display ID (for showing to user)
  Future<String?> getCurrentUserId() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          // Return the display ID
          return userDoc.get('displayId') as String? ??
              userDoc.get('userId') as String?;
        }
      }
      return null;
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  // Check if display ID is unique
  Future<bool> isDisplayIdUnique(String displayId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayId', isEqualTo: displayId)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking display ID: $e');
      return false;
    }
  }
}
