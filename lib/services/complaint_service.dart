import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import 'firestore_service.dart';

class ComplaintService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Submit a new complaint
  Future<String> submitComplaint({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
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
}
