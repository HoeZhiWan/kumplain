import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  // Upload Image to Firebase Storage
  Future<String?> uploadImage(XFile image) async {
    try {
      // Ensure user is logged in
      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      // Get the file name from the image's path
      String fileName = image.path.split('/').last;

      final folderPath = 'complaints/images/${currentUser!.uid}/$fileName';

      // Create a reference to the folder in Firestore Storage
      Reference storageRef = _firebaseStorage.ref().child(folderPath);
      print(storageRef.fullPath);

      // Upload the file to Firebase Storage
      UploadTask uploadTask = storageRef.putFile(File(image.path));

      // Wait for the upload to complete and get the download URL
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;  // Return the download URL of the uploaded image
    } catch (e) {
      rethrow;
    }
  }

  // Delete Image from Firebase Storage using Image URL
  Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      // Ensure user is logged in
      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      // Create a reference to the image in Firebase Storage using the path
      Reference storageRef = _firebaseStorage.refFromURL(imageUrl);

      // Delete the image
      await storageRef.delete();
      print('Image deleted successfully');
    } catch (e) {
      print('Error deleting image: $e');
      rethrow;
    }
  }
}