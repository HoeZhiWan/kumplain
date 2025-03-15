import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class UserDataSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Default batch sizes for processing documents
  static const int _defaultBatchSize = 50;
  static const int _maxDocsPerQuery = 100; // Firestore's limit is 10-500
  
  // For caching and throttling to avoid redundant operations
  DateTime? _lastSyncTime;
  UserModel? _lastSyncedUser;
  final Map<String, DateTime> _docUpdateCache = {};
  final Duration _minSyncInterval = const Duration(minutes: 15);
  
  // Singleton instance
  static final UserDataSyncService _instance = UserDataSyncService._internal();
  
  // Private constructor
  UserDataSyncService._internal();
  
  // Factory constructor
  factory UserDataSyncService() {
    return _instance;
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Initialize sync when user logs in
  Future<void> initializeSync() async {
    if (currentUser == null) return;
    
    // Check if a sync is really needed based on time since last sync
    if (_shouldSkipSync()) {
      print('Skipping sync - recent sync already performed');
      return;
    }
    
    // Perform initial sync when service starts
    await syncUserData();
    
    // Log that sync was initialized
    print('User data sync initialized for user: ${currentUser!.uid}');
  }
  
  // Check if we should skip sync due to recent sync
  bool _shouldSkipSync() {
    if (_lastSyncTime == null || _lastSyncedUser?.uid != currentUser?.uid) {
      return false; // First sync or different user
    }
    
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync < _minSyncInterval;
  }
  
  // Main sync method - with performance optimizations
  Future<void> syncUserData() async {
    if (currentUser == null) {
      print('Cannot sync user data: No user is logged in');
      return;
    }
    
    print('Starting optimized user data sync for user: ${currentUser!.uid}');
    
    try {
      // Get current user profile from Firestore
      final userModel = await _firestoreService.getUser(currentUser!.uid);
      if (userModel == null) {
        print('Cannot sync user data: User profile not found in Firestore');
        return;
      }
      
      // Skip sync if user data hasn't changed since last sync
      if (_lastSyncedUser != null && 
          _lastSyncedUser!.uid == userModel.uid && 
          _lastSyncedUser!.lastUpdated == userModel.lastUpdated) {
        print('Skipping sync - user data unchanged since last sync');
        return;
      }
      
      // Record sync start time
      final syncStartTime = DateTime.now();
      
      // Sync complaints and comments with pagination for better performance
      await Future.wait([
        _syncUserComplaintsOptimized(userModel),
        _syncUserCommentsOptimized(userModel),
      ]);
      
      // Update sync tracking info
      _lastSyncTime = syncStartTime;
      _lastSyncedUser = userModel;
      
      print('User data sync completed for user: ${currentUser!.uid}');
    } catch (e) {
      print('Error during user data sync: $e');
    }
  }
  
  // Optimized sync for complaints with pagination
  Future<void> _syncUserComplaintsOptimized(UserModel userModel) async {
    print('Syncing complaints for user: ${userModel.uid}');
    int processed = 0;
    int updated = 0;
    
    try {
      // First query: Get count of potentially outdated complaints
      final countQuery = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: userModel.uid)
          .count()
          .get();
      
      final totalDocs = countQuery.count;
      
      if (totalDocs == 0) {
        print('No complaints found for user: ${userModel.uid}');
        return;
      }
      
      print('Found $totalDocs total complaints for user: ${userModel.uid}');
      
      // Initialize query cursor
      Query baseQuery = _firestore
          .collection('complaints')
          .where('userId', isEqualTo: userModel.uid);
      
      // Process in paginated batches
      DocumentSnapshot? lastDoc;
      bool hasMoreDocs = true;
      
      // Continue querying until we've processed all documents
      while (hasMoreDocs) {
        Query currentQuery = baseQuery.limit(_maxDocsPerQuery);
        
        if (lastDoc != null) {
          currentQuery = currentQuery.startAfterDocument(lastDoc);
        }
        
        final querySnapshot = await currentQuery.get();
        final docs = querySnapshot.docs;
        processed += docs.length;
        
        if (docs.isEmpty || docs.length < _maxDocsPerQuery) {
          hasMoreDocs = false;
        } else {
          lastDoc = docs.last;
        }
        
        // Filter to find only outdated documents
        final outdatedDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String docId = doc.id;
          
          // Skip if already recently updated (from cache)
          if (_docUpdateCache.containsKey(docId)) {
            final lastUpdate = _docUpdateCache[docId]!;
            if (DateTime.now().difference(lastUpdate) < const Duration(hours: 1)) {
              return false;
            }
          }
          
          // Check if userDataVersion is missing or older than user's lastUpdated
          if (!data.containsKey('userDataVersion')) return true;
          
          final docVersion = (data['userDataVersion'] as Timestamp).toDate();
          return docVersion.isBefore(userModel.lastUpdated);
        }).toList();
        
        // Batch update the outdated documents
        if (outdatedDocs.isNotEmpty) {
          updated += await _updateDocsInBatches(
            outdatedDocs, 
            userModel,
            _defaultBatchSize,
          );
        }
      }
      
      print('Processed $processed complaints, updated $updated for user: ${userModel.uid}');
    } catch (e) {
      print('Error in optimized complaint sync: $e');
    }
  }
  
  // Optimized sync for comments with pagination
  Future<void> _syncUserCommentsOptimized(UserModel userModel) async {
    print('Syncing comments for user: ${userModel.uid}');
    int processed = 0;
    int updated = 0;
    
    try {
      // First query: Get count of potentially outdated comments
      final countQuery = await _firestore
          .collection('comments')
          .where('userId', isEqualTo: userModel.uid)
          .count()
          .get();
      
      final totalDocs = countQuery.count;
      
      if (totalDocs == 0) {
        print('No comments found for user: ${userModel.uid}');
        return;
      }
      
      print('Found $totalDocs total comments for user: ${userModel.uid}');
      
      // Initialize query cursor
      Query baseQuery = _firestore
          .collection('comments')
          .where('userId', isEqualTo: userModel.uid);
      
      // Process in paginated batches
      DocumentSnapshot? lastDoc;
      bool hasMoreDocs = true;
      
      // Continue querying until we've processed all documents
      while (hasMoreDocs) {
        Query currentQuery = baseQuery.limit(_maxDocsPerQuery);
        
        if (lastDoc != null) {
          currentQuery = currentQuery.startAfterDocument(lastDoc);
        }
        
        final querySnapshot = await currentQuery.get();
        final docs = querySnapshot.docs;
        processed += docs.length;
        
        if (docs.isEmpty || docs.length < _maxDocsPerQuery) {
          hasMoreDocs = false;
        } else {
          lastDoc = docs.last;
        }
        
        // Filter to find only outdated documents
        final outdatedDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String docId = doc.id;
          
          // Skip if already recently updated (from cache)
          if (_docUpdateCache.containsKey(docId)) {
            final lastUpdate = _docUpdateCache[docId]!;
            if (DateTime.now().difference(lastUpdate) < const Duration(hours: 1)) {
              return false;
            }
          }
          
          // Check if userDataVersion is missing or older than user's lastUpdated
          if (!data.containsKey('userDataVersion')) return true;
          
          final docVersion = (data['userDataVersion'] as Timestamp).toDate();
          return docVersion.isBefore(userModel.lastUpdated);
        }).toList();
        
        // Batch update the outdated documents
        if (outdatedDocs.isNotEmpty) {
          updated += await _updateDocsInBatches(
            outdatedDocs, 
            userModel,
            _defaultBatchSize,
          );
        }
      }
      
      print('Processed $processed comments, updated $updated for user: ${userModel.uid}');
    } catch (e) {
      print('Error in optimized comment sync: $e');
    }
  }
  
  // Helper to update docs in batches with proper error handling
  Future<int> _updateDocsInBatches(
    List<DocumentSnapshot> docs,
    UserModel userModel,
    int batchSize,
  ) async {
    if (docs.isEmpty) return 0;
    
    int updatedCount = 0;
    List<Future<void>> batchOperations = [];
    
    // Process in batches to avoid hitting Firestore limits
    for (int i = 0; i < docs.length; i += batchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
      
      for (int j = i; j < end; j++) {
        final doc = docs[j];
        batch.update(doc.reference, {
          'userName': userModel.displayName,
          'userPhotoURL': userModel.photoURL,
          'userDataVersion': Timestamp.fromDate(userModel.lastUpdated),
        });
        
        // Update our cache to avoid redundant updates
        _docUpdateCache[doc.id] = DateTime.now();
        updatedCount++;
      }
      
      // Add batch commit to list of operations
      batchOperations.add(batch.commit());
    }
    
    // Execute all batch operations in parallel (where possible)
    await Future.wait(batchOperations);
    return updatedCount;
  }
  
  // Get complaints with outdated user data - preserved for backward compatibility
  Future<List<DocumentSnapshot>> _getOutdatedComplaints(UserModel userModel) async {
    try {
      // Query complaints by user ID
      final querySnapshot = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: userModel.uid)
          .get();
      
      // Filter to find only those with outdated user data
      return querySnapshot.docs.where((doc) {
        final data = doc.data();
        final String docId = doc.id;
        
        // Skip if already recently updated (from cache)
        if (_docUpdateCache.containsKey(docId)) {
          final lastUpdate = _docUpdateCache[docId]!;
          if (DateTime.now().difference(lastUpdate) < const Duration(hours: 1)) {
            return false;
          }
        }
        
        // Check if userDataVersion is missing or older than user's lastUpdated
        if (!data.containsKey('userDataVersion')) return true;
        
        final docVersion = (data['userDataVersion'] as Timestamp).toDate();
        return docVersion.isBefore(userModel.lastUpdated);
      }).toList();
    } catch (e) {
      print('Error getting outdated complaints: $e');
      return [];
    }
  }
  
  // Get comments with outdated user data - preserved for backward compatibility
  Future<List<DocumentSnapshot>> _getOutdatedComments(UserModel userModel) async {
    try {
      // Query comments by user ID
      final querySnapshot = await _firestore
          .collection('comments')
          .where('userId', isEqualTo: userModel.uid)
          .get();
      
      // Filter to find only those with outdated user data
      return querySnapshot.docs.where((doc) {
        final data = doc.data();
        final String docId = doc.id;
        
        // Skip if already recently updated (from cache)
        if (_docUpdateCache.containsKey(docId)) {
          final lastUpdate = _docUpdateCache[docId]!;
          if (DateTime.now().difference(lastUpdate) < const Duration(hours: 1)) {
            return false;
          }
        }
        
        // Check if userDataVersion is missing or older than user's lastUpdated
        if (!data.containsKey('userDataVersion')) return true;
        
        final docVersion = (data['userDataVersion'] as Timestamp).toDate();
        return docVersion.isBefore(userModel.lastUpdated);
      }).toList();
    } catch (e) {
      print('Error getting outdated comments: $e');
      return [];
    }
  }
  
  // Clear cache - useful for testing or forcing a full sync
  void clearCache() {
    _lastSyncTime = null;
    _lastSyncedUser = null;
    _docUpdateCache.clear();
    print('Sync cache cleared');
  }
}
