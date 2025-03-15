import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'user_data_sync_service.dart'; // Add import for sync service

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final UserDataSyncService _syncService = UserDataSyncService();

  // Get the current logged in user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserProfile(userCredential.user!);
        
        // Start background sync service after user profile is created/updated
        await _syncService.initializeSync();
      }
      
      return userCredential;
    } catch (e) {
      print('Error during Google Sign In: $e');
      return null;
    }
  }

  // Create or update user profile in Firestore
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      // Check if user exists
      final existingUser = await _firestoreService.getUser(user.uid);
      
      if (existingUser == null) {
        // Create new user profile
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Anonymous User',
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          lastUpdated: DateTime.now(), // Set initial lastUpdated
        );
        
        await _firestoreService.setUser(userModel);
      } else {
        // Check if user profile data has changed
        bool profileChanged = existingUser.displayName != user.displayName || 
                              existingUser.photoURL != user.photoURL;
        
        // If profile changed, update with new lastUpdated timestamp
        if (profileChanged) {
          final updatedUser = UserModel(
            uid: user.uid,
            email: user.email ?? existingUser.email,
            displayName: user.displayName ?? existingUser.displayName,
            photoURL: user.photoURL,
            createdAt: existingUser.createdAt,
            lastLogin: DateTime.now(),
            lastUpdated: DateTime.now(), // Update timestamp when profile changes
          );
          await _firestoreService.setUser(updatedUser);
        } else {
          // Just update lastLogin
          await _firestoreService.updateUserLastLogin(user.uid);
        }
      }
    } catch (e) {
      print('Error creating/updating user profile: $e');
    }
  }

  // Update user's profile data manually (for future profile edit screen)
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    if (currentUser == null) {
      throw Exception('No user logged in');
    }
    
    try {
      // First update Firebase Auth
      await currentUser!.updateDisplayName(displayName);
      await currentUser!.updatePhotoURL(photoURL);
      
      // Then get existing user data
      final existingUser = await _firestoreService.getUser(currentUser!.uid);
      if (existingUser == null) throw Exception('User not found in Firestore');
      
      // Create updated user model
      final updatedUser = UserModel(
        uid: currentUser!.uid,
        email: currentUser!.email ?? existingUser.email,
        displayName: displayName ?? existingUser.displayName,
        photoURL: photoURL ?? existingUser.photoURL,
        createdAt: existingUser.createdAt,
        lastLogin: existingUser.lastLogin,
        lastUpdated: DateTime.now(), // Update timestamp
      );
      
      // Update Firestore and propagate changes
      await _firestoreService.setUser(updatedUser);
      
      // Force sync after profile update to ensure all documents are updated
      await _syncService.syncUserData();
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get current user profile from Firestore
  Future<UserModel?> getCurrentUserProfile() async {
    if (currentUser != null) {
      return await _firestoreService.getUser(currentUser!.uid);
    }
    return null;
  }
}