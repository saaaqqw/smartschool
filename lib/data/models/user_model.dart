import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String school;
  final String grade;
  final int age;
  final String gender;
  final String profileImageUrl;
  final String email;
  final String pin;
  final String semester;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.school,
    required this.grade,
    required this.age,
    required this.gender,
    this.profileImageUrl = '',
    this.email = '',
    this.pin = '',
    this.semester = 'الفصل الدراسي الأول',
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      school: data['school'] ?? '',
      grade: data['grade'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      email: data['email'] ?? '',
      pin: data['pin'] ?? '',
      semester: data['semester'] ?? 'الفصل الدراسي الأول',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'school': school,
      'grade': grade,
      'age': age,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'email': email,
      'pin': pin,
      'semester': semester,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? school,
    String? grade,
    int? age,
    String? gender,
    String? profileImageUrl,
    String? email,
    String? pin,
    String? semester,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      semester: semester ?? this.semester,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

