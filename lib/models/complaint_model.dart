import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String? id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String userId;
  final String userName;
  final String? userPhotoURL;
  final DateTime createdAt;
  final int votes;
  final String? imageUrl;
  final String? status;  
  final List<String>? tags;
  final int commentCount;
  final DateTime userDataVersion; // New field to track user data version
  final String? aiTag;
  final String? aiDescription;
  
  ComplaintModel({
    this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.userName,
    this.userPhotoURL,
    required this.createdAt,
    this.votes = 0,
    this.imageUrl,
    this.status,
    this.tags,
    this.commentCount = 0,
    DateTime? userDataVersion, // Optional parameter with default
    this.aiTag,
    this.aiDescription,
  }) : this.userDataVersion = userDataVersion ?? DateTime.now();

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ComplaintModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoURL: data['userPhotoURL'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      votes: data['votes'] ?? 0,
      imageUrl: data['imageUrl'],
      status: data['status'],
      tags: data['tags']?.cast<String>(),
      commentCount: data['commentCount'] ?? 0,
      userDataVersion: data['userDataVersion'] != null 
          ? (data['userDataVersion'] as Timestamp).toDate() 
          : null,
      aiTag: data['aiTag'],
      aiDescription: data['aiDescription'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'userId': userId,
      'userName': userName,
      'userPhotoURL': userPhotoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'votes': votes,
      'imageUrl': imageUrl,
      'status': status,
      'tags': tags,
      'commentCount': commentCount,
      'userDataVersion': Timestamp.fromDate(userDataVersion), // Include userDataVersion in the map
      'aiTag': aiTag,
      'aiDescription': aiDescription,
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
