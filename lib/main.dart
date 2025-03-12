import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authService = AuthService();
  final appRouter = AppRouter(authService);

  // Firebase app check
  // To add the debug token to appcheck, look for the line below after flutter run 
  // D/com.google.firebase.appcheck.debug.internal.DebugAppCheckProvider(10207): Enter this debug secret into the allow list in the Firebase Console for your project: _______ (copy this)
  // Go to firebase website > Build(left side) > App Check > Apps (on top) > open menu (three dots when pointing on the tab) of kumplain(android) > Manage debug tokens > Add debug token
  if(!kDebugMode) {
    // -- havent Activated App Check in production
    // await FirebaseAppCheck.instance.activate(
    //   androidProvider: AndroidProvider.playIntegrity,
    //   appleProvider: AppleProvider.appAttest,
    //   webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    // );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  runApp(MyApp(appRouter: appRouter));
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;

  const MyApp({
    super.key,
    required this.appRouter,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KumplAIn',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: appRouter.router,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              User? user = snapshot.data;
              if (user == null) {
                // User is not signed in
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome to KumplAIn!',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _handleSignIn,
                            icon: Image.asset(
                              'assets/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            label: const Text('Sign in with Google'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                  ],
                );
              } else {
                // User is signed in
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (user.photoURL != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(user.photoURL!),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome, ${user.displayName ?? 'User'}!',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _authService.signOut,
                      child: const Text('Sign Out'),
                    ),
                  ],
                );
              }
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithGoogle();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}