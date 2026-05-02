import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_service.dart';
import 'models/user_model.dart';

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

  static const UserProfile defaults = UserProfile(
    uid: '',
    fullName: 'محمد أحمد علي حسن',
    school: 'مدرسة المستقبل الابتدائية',
    grade: 'الصف السابع',
    age: 13,
    gender: 'ذكر',
  );
}

final ValueNotifier<UserProfile> userProfileNotifier =
    ValueNotifier<UserProfile>(UserProfile.defaults);

const String _kUid = 'profile_uid';
const String _kFullName = 'profile_full_name';
const String _kSchool = 'profile_school';
const String _kGrade = 'profile_grade';
const String _kAge = 'profile_age';
const String _kGender = 'profile_gender';

Future<void> loadUserProfile() async {
  final p = await SharedPreferences.getInstance();
  userProfileNotifier.value = UserProfile(
    uid: p.getString(_kUid) ?? UserProfile.defaults.uid,
    fullName: p.getString(_kFullName) ?? UserProfile.defaults.fullName,
    school: p.getString(_kSchool) ?? UserProfile.defaults.school,
    grade: p.getString(_kGrade) ?? UserProfile.defaults.grade,
    age: p.getInt(_kAge) ?? UserProfile.defaults.age,
    gender: p.getString(_kGender) ?? UserProfile.defaults.gender,
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
  
  // Sync with Firebase if UID exists
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

String firstNameFromFullName(String fullName) {
  final t = fullName.trim();
  if (t.isEmpty) return 'طالب';
  return t.split(RegExp(r'\s+')).first;
}
