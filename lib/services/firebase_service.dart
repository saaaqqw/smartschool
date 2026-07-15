import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../data/models/user_model.dart';
import 'firebase_sync_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    final ref = _storage.ref().child('users').child(userId).child('profile.jpg');
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  // --- Auth ---

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  // --- Email Link (Passwordless Sign-In) ---

  static const String _pendingEmailKey = 'pending_email_link_address';

  Future<void> savePendingEmailLink(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmailKey, email);
  }

  Future<String?> getPendingEmailLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingEmailKey);
  }

  Future<void> clearPendingEmailLink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingEmailKey);
  }

  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
    await savePendingEmailLink(email);
  }

  bool isSignInWithEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    final creds = await _auth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    await clearPendingEmailLink();
    return creds;
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // --- User Profile ---

  Future<void> saveUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toFirestore());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // --- Subjects & Progress ---

  Future<void> updateUnitProgress(
    String userId,
    String subjectId,
    String unitTitle,
    double progress, {
    String semester = 'الفصل الدراسي الأول',
  }) async {
    final docId = FirebaseSyncService.getProgressDocId(subjectId, semester: semester);
    final docRef = _db.collection('users').doc(userId).collection('progress').doc(docId);
    
    await docRef.set({
      'unitProgress': {
        unitTitle: progress,
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ترقية تقدم الطالب للدرس التالي (أو الوحدة التالية) بعد إكمال الدرس الحالي.
  Future<void> advanceLessonProgress({
    required String uid,
    required String subjectTitle,
    required int currentUnitIndex,
    required int currentLessonNumber,
    required int maxLessonsInUnit,
    required int maxUnits,
    String semester = 'الفصل الدراسي الأول',
  }) async {
    final docId = FirebaseSyncService.getProgressDocId(subjectTitle, semester: semester);
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId);

    int nextUnit = currentUnitIndex;
    int nextLesson = currentLessonNumber + 1;

    if (nextLesson > maxLessonsInUnit) {
      nextLesson = 1;
      nextUnit = currentUnitIndex + 1;
    }

    if (nextUnit >= maxUnits) {
      nextUnit = maxUnits - 1;
      nextLesson = maxLessonsInUnit;
    }

    await docRef.set({
      'currentUnitIndex': nextUnit,
      'currentLessonNumber': nextLesson,
      'completed_lessons_set': FieldValue.arrayUnion([
        'u${currentUnitIndex}_l$currentLessonNumber',
      ]),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getProgressStream(
    String userId,
    String subjectId, {
    String semester = 'الفصل الدراسي الأول',
  }) {
    final docId = FirebaseSyncService.getProgressDocId(subjectId, semester: semester);
    return _db.collection('users').doc(userId).collection('progress').doc(docId).snapshots();
  }

  // --- Study Plan ---

  Future<void> saveStudyPlanTask(String userId, String taskId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).collection('study_plan').doc(taskId).set(data);
  }

  Stream<QuerySnapshot> getStudyPlanStream(String userId) {
    return _db.collection('users').doc(userId).collection('study_plan').snapshots();
  }

  // --- Grades ---

  Future<void> saveGrade(String userId, String subjectId, double score, double maxScore) async {
    await _db.collection('grades').doc('${userId}_$subjectId').set({
      'userId': userId,
      'subjectId': subjectId,
      'score': score,
      'maxScore': maxScore,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getGradesStream(String userId) {
    return _db.collection('grades').where('userId', isEqualTo: userId).snapshots();
  }
}
