import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../data/models/user_model.dart';

/// حقول التسجيل: الاسم الرباعي، المدرسة، الصف، العمر، الجنس، البريد الإلكتروني، والرمز.
class UserProfile {
  const UserProfile({
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
  });

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

  factory UserProfile.fromUserModel(UserModel user) {
    return UserProfile(
      uid: user.uid,
      fullName: user.fullName,
      school: user.school,
      grade: user.grade,
      age: user.age,
      gender: user.gender,
      profileImageUrl: user.profileImageUrl,
      email: user.email,
      pin: user.pin,
      semester: user.semester,
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
      email: map['email'] ?? '',
      pin: map['pin'] ?? '',
      semester: map['semester'] ?? 'الفصل الدراسي الأول',
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
      'email': email,
      'pin': pin,
      'semester': semester,
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
    String? email,
    String? pin,
    String? semester,
  }) {
    return UserProfile(
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
    );
  }

  static const UserProfile empty = UserProfile(
    uid: '',
    fullName: '',
    school: '',
    grade: '',
    age: 0,
    gender: '',
    email: '',
    pin: '',
    semester: 'الفصل الدراسي الأول',
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
const String _kEmail = 'profile_email';
const String _kPin = 'profile_pin';
const String _kSemester = 'profile_semester';

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
    email: p.getString(_kEmail) ?? '',
    pin: p.getString(_kPin) ?? '',
    semester: p.getString(_kSemester) ?? 'الفصل الدراسي الأول',
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
  await p.setString(_kEmail, profile.email);
  await p.setString(_kPin, profile.pin);
  await p.setString(_kSemester, profile.semester);

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
      email: profile.email,
      pin: profile.pin,
      semester: profile.semester,
    ));
  }

  userProfileNotifier.value = profile;
}

Future<void> updateSelectedSemester(String newSemester) async {
  final current = userProfileNotifier.value;
  final updated = current.copyWith(semester: newSemester);
  userProfileNotifier.value = updated;
  final p = await SharedPreferences.getInstance();
  await p.setString(_kSemester, newSemester);

  if (updated.uid.isNotEmpty) {
    final firebaseService = FirebaseService();
    await firebaseService.saveUserProfile(UserModel(
      uid: updated.uid,
      fullName: updated.fullName,
      school: updated.school,
      grade: updated.grade,
      age: updated.age,
      gender: updated.gender,
      profileImageUrl: updated.profileImageUrl,
      email: updated.email,
      pin: updated.pin,
      semester: updated.semester,
    ));
  }
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
  await p.remove(_kEmail);
  await p.remove(_kPin);
  await p.remove(_kSemester);
  userProfileNotifier.value = UserProfile.empty;
}

String firstNameFromFullName(String fullName) {
  final t = fullName.trim();
  if (t.isEmpty) return 'طالب';
  return t.split(RegExp(r'\s+')).first;
}


