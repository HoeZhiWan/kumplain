import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/comment_model.dart';
import 'firestore_service.dart';
import 'user_data_sync_service.dart'; // Add import for sync service

class ComplaintService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataSyncService _syncService = UserDataSyncService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Submit a new complaint
  Future<String> submitComplaint({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
    List<String>? tags,
    String? aiTag,
    String? aiDescription,
  }) async {
    try {
      // Ensure user is logged in
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Check at the start of submitComplaint method
      if (_auth.currentUser == null) {
        throw Exception('You must be logged in to submit a complaint');
      }

      // Get current user profile from Firestore for the most recent data
      final userProfile = await _firestoreService.getUser(currentUser!.uid);
      final String userName = userProfile?.displayName ?? currentUser!.displayName ?? 'Anonymous User';
      final String? userPhotoURL = userProfile?.photoURL ?? currentUser!.photoURL;
      final DateTime userDataVersion = userProfile?.lastUpdated ?? DateTime.now();

      // Create a new complaint with user info
      final complaint = ComplaintModel(
        title: title,
        description: description,
        latitude: latitude,
        longitude: longitude,
        userId: currentUser!.uid,
        userName: userName,
        userPhotoURL: userPhotoURL,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        status: 'unresolved',
        tags: tags,
        userDataVersion: userDataVersion, // Include user data version
        aiTag: aiTag,
        aiDescription: aiDescription,
      );

      // Add the complaint to Firestore
      final docRef = await _firestoreService.addComplaint(complaint);

      // Update the user's complaint count
      await _firestoreService.updateUserComplaintCount(currentUser!.uid);

      return docRef.id;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw 'You don\'t have permission to submit complaints. Please check your login status.';
      } else {
        throw 'Error submitting complaint: ${e.toString()}';
      }
    }
  }

  // Get all complaints
  Stream<List<ComplaintModel>> getAllComplaints() {
    // Start a background sync when complaints are loaded
    if (currentUser != null) {
      // Use a microtask to avoid blocking the stream
      Future.microtask(() => _syncService.syncUserData());
    }
    
    return _firestoreService.getComplaints().map((complaints) {
      print('Retrieved ${complaints.length} complaints');
      for (var complaint in complaints) {
        print('Complaint ID: ${complaint.id}, User ID: ${complaint.userId}');
      }
      return complaints;
    });
  }

  // Get complaints by current user
  Stream<List<ComplaintModel>> getCurrentUserComplaints() {
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestoreService.getUserComplaints(currentUser!.uid);
  }

  // Get a specific complaint - now with user data check
  Future<ComplaintModel?> getComplaint(String id) async {
    try {
      final complaint = await _firestoreService.getComplaint(id);
      
      if (complaint != null) {
        // Check if this is the current user's complaint and ensure data is updated
        if (complaint.userId == currentUser?.uid) {
          // Trigger a background sync to ensure complaint has up-to-date user data
          _syncService.syncUserData();
        }
      }
      
      return complaint;
    } catch (e) {
      print('Error in getComplaint: $e');
      return _firestoreService.getComplaint(id);
    }
  }

  // Get user complaint stats for profile page
  Future<Map<String, int>> getUserStats() async {
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestoreService.getUserComplaintStats(currentUser!.uid);
  }

  // Get detailed user complaint stats including active/deleted/resolved counts
  Future<Map<String, int>> getDetailedUserStats() async {
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestoreService.getDetailedUserComplaintStats(currentUser!.uid);
  }

  // Get latest complaints with pagination
  Future<List<ComplaintModel>> getLatestComplaints({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    return _firestoreService.getLatestComplaints(
      limit: limit,
      startAfter: lastDocument,
    );
  }

  // Get complaints by status
  Future<List<ComplaintModel>> getComplaintsByFilter({
    String? status,
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    return _firestoreService.getComplaintsByFilter(
      status: status,
      limit: limit,
      startAfter: lastDocument,
    );
  }

  // Search for complaints
  Future<List<ComplaintModel>> searchComplaints(
    String query, {
    int limit = 10,
  }) async {
    return _firestoreService.searchComplaints(query, limit: limit);
  }

  Future<Map<String, dynamic>> updateVote(
    String complaintId,
    bool isUpvote,
  ) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final DocumentReference complaintRef = _firestore
        .collection('complaints')
        .doc(complaintId);

    return _firestore.runTransaction((transaction) async {
      final DocumentSnapshot complaintSnapshot = await transaction.get(
        complaintRef,
      );

      if (!complaintSnapshot.exists) {
        throw Exception('Complaint not found');
      }

      final Map<String, dynamic> data =
          complaintSnapshot.data() as Map<String, dynamic>;

      // Get the current votes count and voted by map
      final int currentVotes = data['votes'] ?? 0;
      final Map<String, dynamic> votedBy = Map<String, dynamic>.from(
        data['votedBy'] ?? {},
      );

      // Determine current user's vote status
      final int previousVote = votedBy[currentUser.uid] ?? 0;
      int voteChange = 0;
      int newVote = 0;

      // Handle the voting logic
      if (isUpvote) {
        // User is upvoting
        if (previousVote == 1) {
          // Cancel upvote
          newVote = 0;
          voteChange = -1;
        } else if (previousVote == -1) {
          // Change from downvote to upvote
          newVote = 1;
          voteChange = 2;
        } else {
          // New upvote
          newVote = 1;
          voteChange = 1;
        }
      } else {
        // User is downvoting
        if (previousVote == -1) {
          // Cancel downvote
          newVote = 0;
          voteChange = 1;
        } else if (previousVote == 1) {
          // Change from upvote to downvote
          newVote = -1;
          voteChange = -2;
        } else {
          // New downvote
          newVote = -1;
          voteChange = -1;
        }
      }

      if (newVote == 0) {
        votedBy.remove(currentUser.uid);
      } else {
        votedBy[currentUser.uid] = newVote;
      }

      // Update the document
      transaction.update(complaintRef, {
        'votes': currentVotes + voteChange,
        'votedBy': votedBy,
      });

      return {'newVote': newVote, 'totalVotes': currentVotes + voteChange};
    });
  }

  Future<Map<String, dynamic>> getVoteStatus(String complaintId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'userVote': 0, 'totalVotes': 0};
    }

    final DocumentSnapshot complaintSnapshot =
        await _firestore.collection('complaints').doc(complaintId).get();

    if (!complaintSnapshot.exists) {
      throw Exception('Complaint not found');
    }

    final Map<String, dynamic> data =
        complaintSnapshot.data() as Map<String, dynamic>;
    final Map<String, dynamic> votedBy = Map<String, dynamic>.from(
      data['votedBy'] ?? {},
    );

    return {
      'userVote': votedBy[currentUser.uid] ?? 0,
      'totalVotes': data['votes'] ?? 0,
    };
  }
  
  // Method to check if current user owns the complaint
  Future<bool> isComplaintOwner(String complaintId) async {
    if (currentUser == null) return false;
    
    try {
      final complaint = await _firestoreService.getComplaint(complaintId);
      if (complaint == null) return false;
      
      return complaint.userId == currentUser!.uid;
    } catch (e) {
      print('Error checking complaint ownership: $e');
      return false;
    }
  }
  
  // Method to mark a complaint as deleted
  Future<void> markComplaintAsDeleted(String complaintId) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    
    // Verify that the current user is the owner of the complaint
    final isOwner = await isComplaintOwner(complaintId);
    if (!isOwner) {
      throw Exception('You can only delete your own complaints');
    }
    
    await _firestoreService.markComplaintAsDeleted(complaintId);
  }

  // Comment methods
  
  // Get comments for a complaint
  Stream<List<CommentModel>> getComments(String complaintId) {
    return _firestoreService.getComments(complaintId);
  }

  // Add a new comment
  Future<String> addComment(String complaintId, String text) async {
    try {
      // Ensure user is logged in
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get current user profile from Firestore for the most recent data
      final userProfile = await _firestoreService.getUser(currentUser!.uid);
      final String userName = userProfile?.displayName ?? currentUser!.displayName ?? 'Anonymous User';
      final String? userPhotoURL = userProfile?.photoURL ?? currentUser!.photoURL;
      final DateTime userDataVersion = userProfile?.lastUpdated ?? DateTime.now();

      // Create a new comment with user info
      final comment = CommentModel(
        complaintId: complaintId,
        userId: currentUser!.uid,
        userName: userName,
        userPhotoURL: userPhotoURL,
        text: text,
        createdAt: DateTime.now(),
        userDataVersion: userDataVersion, // Include user data version
      );

      // Add the comment to Firestore
      final docRef = await _firestoreService.addComment(comment);
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw 'You don\'t have permission to comment. Please check your login status.';
      } else {
        throw 'Error adding comment: ${e.toString()}';
      }
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String complaintId) async {
    try {
      await _firestoreService.deleteComment(commentId, complaintId);
    } catch (e) {
      throw 'Error deleting comment: ${e.toString()}';
    }
  }

  // Get comment count for a complaint
  Future<int> getCommentCount(String complaintId) async {
    return _firestoreService.getCommentCount(complaintId);
  }
}
