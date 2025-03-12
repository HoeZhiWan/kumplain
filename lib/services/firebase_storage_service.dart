import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseStorageService {
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  // Upload Image to Firebase Storage
  Future<String?> uploadImage(XFile? image, String folderPath) async {
    try {
      if (image == null) {
        throw Exception("No image selected");
      }

      // Get the file name from the image's path
      String fileName = image.path.split('/').last;

      // Create a reference to the folder in Firestore Storage
      Reference storageRef = _firebaseStorage.ref().child(folderPath).child(fileName);

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
}