import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String userId;
  final String email;
  final String name;
  final DateTime createdAt;
  bool isOnline;
  DateTime? lastSeen;
  String? profileImageBase64; // Add this field

  UserModel({
    required this.uid,
    required this.userId,
    required this.email,
    required this.name,
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.profileImageBase64, // Add this parameter
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userId': userId,
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'profileImageBase64': profileImageBase64, // Add this
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
      profileImageBase64: map['profileImageBase64'], // Add this
    );
  }

  UserModel copyWith({
    String? uid,
    String? userId,
    String? email,
    String? name,
    DateTime? createdAt,
    bool? isOnline,
    DateTime? lastSeen,
    String? profileImageBase64, // Add this parameter
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      profileImageBase64:
          profileImageBase64 ?? this.profileImageBase64, // Add this
    );
  }
}
