import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/complaint_model.dart';
import '../models/comment_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get users => _firestore.collection('users');
  CollectionReference get complaints => _firestore.collection('complaints');
  CollectionReference get comments => _firestore.collection('comments');
  DocumentReference get libraryComplaintDoc => _firestore.collection('library').doc('complaint');

  // Get user document reference
  DocumentReference getUserDoc(String uid) => users.doc(uid);

  // Get user data
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await getUserDoc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Create or update user
  Future<void> setUser(UserModel user) async {
    try {
      await getUserDoc(user.uid).set(user.toMap());
    } catch (e) {
      print('Error saving user: $e');
      throw e;
    }
  }

  // Update user's last login
  Future<void> updateUserLastLogin(String uid) async {
    try {
      await getUserDoc(uid).update({'lastLogin': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Complaint methods

  // Get all complaints
  Stream<List<ComplaintModel>> getComplaints() {
    try {
      print('Starting Firestore query for all complaints');
      
      // Check Firestore collection size directly first
      complaints.get().then((snapshot) {
        print('DIRECT CHECK: Total complaints in Firestore: ${snapshot.docs.length}');
        if (snapshot.docs.isNotEmpty) {
          print('First complaint ID: ${snapshot.docs.first.id}');
        }
      });
      
      return complaints
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) {
              print('Stream emission received: ${snapshot.docs.length} complaints');
              
              // Check if documents exist but conversion is failing
              try {
                final results = snapshot.docs
                    .map((doc) => ComplaintModel.fromFirestore(doc))
                    .toList();
                
                print('Successfully converted ${results.length} complaints to models');
                return results;
              } catch (e) {
                print('Error converting documents to models: $e');
                if (snapshot.docs.isNotEmpty) {
                  print('Sample document data: ${snapshot.docs.first.data()}');
                }
                return <ComplaintModel>[];
              }
            },
          );
    } catch (e) {
      print('Error getting complaints: $e');
      return Stream.value([]);
    }
  }

  // Get complaints by user ID
  Stream<List<ComplaintModel>> getUserComplaints(String userId) {
    return complaints
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ComplaintModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get a single complaint
  Future<ComplaintModel?> getComplaint(String id) async {
    try {
      DocumentSnapshot doc = await complaints.doc(id).get();
      if (doc.exists) {
        return ComplaintModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting complaint: $e');
      return null;
    }
  }

  // Add a new complaint
  Future<DocumentReference> addComplaint(ComplaintModel complaint) async {
    try {
      return await complaints.add(complaint.toMap());
    } catch (e) {
      print('Error adding complaint: $e');
      throw e;
    }
  }

  // Update a complaint
  Future<void> updateComplaint(String id, Map<String, dynamic> data) async {
    try {
      await complaints.doc(id).update(data);
    } catch (e) {
      print('Error updating complaint: $e');
      throw e;
    }
  }

  // Delete a complaint
  Future<void> deleteComplaint(String id) async {
    try {
      await complaints.doc(id).delete();
    } catch (e) {
      print('Error deleting complaint: $e');
      throw e;
    }
  }

  // Mark a complaint as deleted
  Future<void> markComplaintAsDeleted(String id) async {
    try {
      // Get current status first
      DocumentSnapshot doc = await complaints.doc(id).get();
      if (!doc.exists) {
        throw 'Complaint not found';
      }
      
      String currentStatus = (doc.data() as Map<String, dynamic>)['status'] ?? 'unresolved';
      
      // Update with new status
      await complaints.doc(id).update({
        'status': 'deleted - $currentStatus',
        'updatedAt': FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error marking complaint as deleted: $e');
      throw e;
    }
  }

  // Update user's complaint count
  Future<void> updateUserComplaintCount(String userId) async {
    try {
      // Get the current count of user's complaints
      final QuerySnapshot userComplaints =
          await complaints.where('userId', isEqualTo: userId).get();

      final int complaintCount = userComplaints.docs.length;

      // Update the user document with the count
      await users.doc(userId).update({'complaintCount': complaintCount});
    } catch (e) {
      print('Error updating user complaint count: $e');
    }
  }

  // Get user stats (submitted complaints count)
  Future<Map<String, int>> getUserComplaintStats(String userId) async {
    try {
      final QuerySnapshot userComplaints =
          await complaints.where('userId', isEqualTo: userId).get();

      return {'submitted': userComplaints.docs.length};
    } catch (e) {
      print('Error getting user complaint stats: $e');
      return {'submitted': 0};
    }
  }

  // Get detailed user complaint statistics with status breakdown
  Future<Map<String, int>> getDetailedUserComplaintStats(String userId) async {
    try {
      final QuerySnapshot userComplaints =
          await complaints.where('userId', isEqualTo: userId).get();
      
      int activeCount = 0;
      int deletedCount = 0;
      int resolvedCount = 0;
      
      // Process each complaint to categorize by status
      for (var doc in userComplaints.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        if (status == null || status.isEmpty) {
          activeCount++; // Treat null/empty status as active
        } else if (status.startsWith('deleted')) {
          deletedCount++;
        } else if (status == 'resolved') {
          resolvedCount++;
        } else {
          // All other statuses (pending, processing, etc.) are active
          activeCount++;
        }
      }
      
      return {
        'submitted': userComplaints.docs.length,
        'active': activeCount,
        'deleted': deletedCount,
        'resolved': resolvedCount,
      };
    } catch (e) {
      print('Error getting detailed user complaint stats: $e');
      return {
        'submitted': 0,
        'active': 0,
        'deleted': 0,
        'resolved': 0
      };
    }
  }

  // Get latest complaints with pagination
  Future<List<ComplaintModel>> getLatestComplaints({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = complaints
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // If startAfter is provided, use it for pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ComplaintModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting latest complaints: $e');
      return [];
    }
  }

  // Get latest complaints by status
  Future<List<ComplaintModel>> getComplaintsByFilter({
    String? status,
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = complaints.orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.limit(limit);

      // If startAfter is provided, use it for pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ComplaintModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting filtered complaints: $e');
      return [];
    }
  }

  // Get complaints by search query
  Future<List<ComplaintModel>> searchComplaints(
    String searchQuery, {
    int limit = 10,
  }) async {
    try {
      // Since Firestore doesn't support native full-text search,
      // we'll do a simple prefix search on title
      final snapshot =
          await complaints
              .where('title', isGreaterThanOrEqualTo: searchQuery)
              .where('title', isLessThan: searchQuery + 'z')
              .limit(limit)
              .get();

      return snapshot.docs
          .map((doc) => ComplaintModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error searching complaints: $e');
      return [];
    }
  }

  // Get tags from the library collection
  Future<List<String>> getTags() async {
    try {
      DocumentSnapshot doc = await libraryComplaintDoc.get();
      if (doc.exists) {
        List<dynamic> tags = doc['tags'];
        return tags.cast<String>();
      }
      return [];
    } catch (e) {
      print('Error getting tags: $e');
      return [];
    }
  }

  // Comment methods

  // Get comments for a complaint
  Stream<List<CommentModel>> getComments(String complaintId) {
    try {
      return comments
        .where('complaintId', isEqualTo: complaintId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromFirestore(doc))
            .toList(),
        );
    } catch (e) {
      print('Error getting comments: $e');
      return Stream.value([]);
    }
  }

  // Add a new comment
  Future<DocumentReference> addComment(CommentModel comment) async {
    try {
      // Start a transaction to update both collections
      final DocumentReference commentRef = await _firestore.runTransaction((transaction) async {
        // Get the complaint document
        final DocumentReference complaintRef = complaints.doc(comment.complaintId);
        final DocumentSnapshot complaintDoc = await transaction.get(complaintRef);
        
        if (!complaintDoc.exists) {
          throw 'Complaint not found';
        }
        
        // Get current comment count
        final data = complaintDoc.data() as Map<String, dynamic>;
        final int currentCommentCount = data['commentCount'] ?? 0;
        
        // Add the new comment
        final DocumentReference newCommentRef = comments.doc();
        transaction.set(newCommentRef, comment.toMap());
        
        // Update the comment count in the complaint document
        transaction.update(complaintRef, {
          'commentCount': currentCommentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return newCommentRef;
      });
      
      return commentRef;
    } catch (e) {
      print('Error adding comment: $e');
      throw e;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String id, String complaintId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get the complaint document
        final DocumentReference complaintRef = complaints.doc(complaintId);
        final DocumentReference commentRef = comments.doc(id);
        
        final DocumentSnapshot complaintDoc = await transaction.get(complaintRef);
        final DocumentSnapshot commentDoc = await transaction.get(commentRef);
        
        if (!complaintDoc.exists) {
          throw 'Complaint not found';
        }
        
        if (!commentDoc.exists) {
          throw 'Comment not found';
        }
        
        // Get current comment count
        final data = complaintDoc.data() as Map<String, dynamic>;
        final int currentCommentCount = data['commentCount'] ?? 0;
        
        // Delete the comment
        transaction.delete(commentRef);
        
        // Update the comment count in the complaint document
        transaction.update(complaintRef, {
          'commentCount': currentCommentCount > 0 ? currentCommentCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error deleting comment: $e');
      throw e;
    }
  }

  // Get comment count for a complaint
  Future<int> getCommentCount(String complaintId) async {
    try {
      final QuerySnapshot snapshot = await comments
        .where('complaintId', isEqualTo: complaintId)
        .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting comment count: $e');
      return 0;
    }
  }
}
