import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String? id;
  final String complaintId;
  final String userId;
  final String userName;
  final String? userPhotoURL;
  final String text;
  final DateTime createdAt;
  
  CommentModel({
    this.id,
    required this.complaintId,
    required this.userId,
    required this.userName,
    this.userPhotoURL,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      complaintId: data['complaintId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoURL: data['userPhotoURL'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'userId': userId,
      'userName': userName,
      'userPhotoURL': userPhotoURL,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Helper method to format the creation time
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
