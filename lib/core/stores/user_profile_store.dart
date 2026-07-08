import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../data/models/user_model.dart';

/// حقول التسجيل: الاسم الرباعي، المدرسة، الصف، العمر، الجنس.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.school,
    required this.grade,
    required this.age,
    required this.gender,
    this.profileImageUrl = '',
  });

  final String uid;
  final String fullName;
  final String school;
  final String grade;
  final int age;
  final String gender;
  final String profileImageUrl;

  factory UserProfile.fromUserModel(UserModel user) {
    return UserProfile(
      uid: user.uid,
      fullName: user.fullName,
      school: user.school,
      grade: user.grade,
      age: user.age,
      gender: user.gender,
      profileImageUrl: user.profileImageUrl,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      school: map['school'] ?? '',
      grade: map['grade'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'school': school,
      'grade': grade,
      'age': age,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? school,
    String? grade,
    int? age,
    String? gender,
    String? profileImageUrl,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  static const UserProfile empty = UserProfile(
    uid: '',
    fullName: '',
    school: '',
    grade: '',
    age: 0,
    gender: '',
  );
}

final ValueNotifier<UserProfile> userProfileNotifier =
    ValueNotifier<UserProfile>(UserProfile.empty);

const String _kUid = 'profile_uid';
const String _kFullName = 'profile_full_name';
const String _kSchool = 'profile_school';
const String _kGrade = 'profile_grade';
const String _kAge = 'profile_age';
const String _kGender = 'profile_gender';
const String _kProfileImageUrl = 'profile_image_url';

Future<void> loadUserProfile() async {
  final p = await SharedPreferences.getInstance();
  final uid = p.getString(_kUid) ?? '';
  if (uid.isEmpty) {
    userProfileNotifier.value = UserProfile.empty;
    return;
  }

  userProfileNotifier.value = UserProfile(
    uid: uid,
    fullName: p.getString(_kFullName) ?? '',
    school: p.getString(_kSchool) ?? '',
    grade: p.getString(_kGrade) ?? '',
    age: p.getInt(_kAge) ?? 0,
    gender: p.getString(_kGender) ?? '',
    profileImageUrl: p.getString(_kProfileImageUrl) ?? '',
  );
}

Future<void> saveUserProfile(UserProfile profile) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kUid, profile.uid);
  await p.setString(_kFullName, profile.fullName);
  await p.setString(_kSchool, profile.school);
  await p.setString(_kGrade, profile.grade);
  await p.setInt(_kAge, profile.age);
  await p.setString(_kGender, profile.gender);
  await p.setString(_kProfileImageUrl, profile.profileImageUrl);

  if (profile.uid.isNotEmpty) {
    final firebaseService = FirebaseService();
    await firebaseService.saveUserProfile(UserModel(
      uid: profile.uid,
      fullName: profile.fullName,
      school: profile.school,
      grade: profile.grade,
      age: profile.age,
      gender: profile.gender,
      profileImageUrl: profile.profileImageUrl,
    ));
  }

  userProfileNotifier.value = profile;
}

Future<void> clearUserProfile() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(_kUid);
  await p.remove(_kFullName);
  await p.remove(_kSchool);
  await p.remove(_kGrade);
  await p.remove(_kAge);
  await p.remove(_kGender);
  await p.remove(_kProfileImageUrl);
  userProfileNotifier.value = UserProfile.empty;
}

String firstNameFromFullName(String fullName) {
  final t = fullName.trim();
  if (t.isEmpty) return 'طالب';
  return t.split(RegExp(r'\s+')).first;
}
