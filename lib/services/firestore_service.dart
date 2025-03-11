import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/complaint_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get users => _firestore.collection('users');
  CollectionReference get complaints => _firestore.collection('complaints');

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
      await getUserDoc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Complaint methods
  
  // Get all complaints
  Stream<List<ComplaintModel>> getComplaints() {
    return complaints
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ComplaintModel.fromFirestore(doc))
            .toList());
  }
  
  // Get complaints by user ID
  Stream<List<ComplaintModel>> getUserComplaints(String userId) {
    return complaints
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ComplaintModel.fromFirestore(doc))
            .toList());
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

  // Update user's complaint count
  Future<void> updateUserComplaintCount(String userId) async {
    try {
      // Get the current count of user's complaints
      final QuerySnapshot userComplaints = await complaints
          .where('userId', isEqualTo: userId)
          .get();
      
      final int complaintCount = userComplaints.docs.length;
      
      // Update the user document with the count
      await users.doc(userId).update({
        'complaintCount': complaintCount,
      });
    } catch (e) {
      print('Error updating user complaint count: $e');
    }
  }

  // Get user stats (submitted complaints count)
  Future<Map<String, int>> getUserComplaintStats(String userId) async {
    try {
      final QuerySnapshot userComplaints = await complaints
          .where('userId', isEqualTo: userId)
          .get();
      
      return {
        'submitted': userComplaints.docs.length,
      };
    } catch (e) {
      print('Error getting user complaint stats: $e');
      return {'submitted': 0};
    }
  }
}
