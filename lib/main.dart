import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/initial_loading_screen.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'utils/navigation_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: InitialLoadingScreen(),
  ));

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final totalUnreadMessages = ValueNotifier<int>(0);
  static final unreadNotificationsCount = ValueNotifier<int>(0);
  static final unreadStoriesCount = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoveELL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show splash screen while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          // User is signed in
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<UserModel?>(
              future: AuthService().getCurrentUserData(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                if (userSnapshot.hasData && userSnapshot.data != null) {
                  return MainNavigationScreen(
                    currentUser: userSnapshot.data!,
                    key: ValueKey(userSnapshot
                        .data!.uid), // Add key to force rebuild on user change
                  );
                }

                // If user data fetch fails, sign out and show auth screen
                FirebaseAuth.instance.signOut();
                return const AuthScreen(
                    key: ValueKey('auth_screen')); // Add key
              },
            );
          }

          // User is signed out - return a new instance with a key
          return const AuthScreen(key: ValueKey('auth_screen'));
        },
      ),
    );
  }
}
