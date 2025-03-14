import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import 'firestore_service.dart';

class ComplaintService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      
      // Create a new complaint with user info
      final complaint = ComplaintModel(
        title: title,
        description: description,
        latitude: latitude,
        longitude: longitude,
        userId: currentUser!.uid,
        userName: currentUser!.displayName ?? 'Anonymous User',
        userPhotoURL: currentUser!.photoURL,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        status: 'unresolved',
        tags: tags,
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
    return _firestoreService.getComplaints();
  }
  
  // Get complaints by current user
  Stream<List<ComplaintModel>> getCurrentUserComplaints() {
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestoreService.getUserComplaints(currentUser!.uid);
  }
  
  // Get a specific complaint
  Future<ComplaintModel?> getComplaint(String id) {
    return _firestoreService.getComplaint(id);
  }
  
  // Get user complaint stats for profile page
  Future<Map<String, int>> getUserStats() async {
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestoreService.getUserComplaintStats(currentUser!.uid);
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
  Future<List<ComplaintModel>> searchComplaints(String query, {int limit = 10}) async {
    return _firestoreService.searchComplaints(query, limit: limit);
  }

  Future<Map<String, dynamic>> updateVote(String complaintId, bool isUpvote) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final DocumentReference complaintRef = _firestore.collection('complaints').doc(complaintId);
    
    return _firestore.runTransaction((transaction) async {
      final DocumentSnapshot complaintSnapshot = await transaction.get(complaintRef);
      
      if (!complaintSnapshot.exists) {
        throw Exception('Complaint not found');
      }
      
      final Map<String, dynamic> data = complaintSnapshot.data() as Map<String, dynamic>;
      
      // Get the current votes count and voted by map
      final int currentVotes = data['votes'] ?? 0;
      final Map<String, dynamic> votedBy = Map<String, dynamic>.from(data['votedBy'] ?? {});
      
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
      
      return {
        'newVote': newVote,
        'totalVotes': currentVotes + voteChange,
      };
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
    
    final Map<String, dynamic> data = complaintSnapshot.data() as Map<String, dynamic>;
    final Map<String, dynamic> votedBy = Map<String, dynamic>.from(data['votedBy'] ?? {});
    
    return {
      'userVote': votedBy[currentUser.uid] ?? 0,
      'totalVotes': data['votes'] ?? 0,
    };
  }
}
