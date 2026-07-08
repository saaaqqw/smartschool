import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import '../data/models/user_model.dart';

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

  Future<void> updateUnitProgress(String userId, String subjectId, String unitTitle, double progress) async {
    // This updates a specific subject's progress in a subcollection or map
    final docRef = _db.collection('users').doc(userId).collection('progress').doc(subjectId);
    
    await docRef.set({
      'unitProgress': {
        unitTitle: progress,
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getProgressStream(String userId, String subjectId) {
    return _db.collection('users').doc(userId).collection('progress').doc(subjectId).snapshots();
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
    await _db.collection('grades').add({
      'userId': userId,
      'subjectId': subjectId,
      'score': score,
      'maxScore': maxScore,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getGradesStream(String userId) {
    return _db.collection('grades').where('userId', isEqualTo: userId).snapshots();
  }
}
