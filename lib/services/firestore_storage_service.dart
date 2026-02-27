import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'cloud_storage_interface.dart';
import 'firebase_web_safe.dart';

class FirestoreStorageService implements CloudStorageInterface {
  // Lazy access with Safety Check
  FirebaseFirestore get _firestore {
    try {
      // CRITICAL: Check for JS object first to prevent ReferenceError crash on iOS
      if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) {
        throw Exception("Firebase JS SDK not loaded (Offline/iOS strict mode)");
      }

      if (Firebase.apps.isEmpty) {
        throw Exception("Firestore accessed before Firebase Init (Offline?)");
      }
      return FirebaseFirestore.instance;
    } catch (e) {
      throw Exception("Firestore Access Failed (Safety): $e");
    }
  }

  @override
  Future<void> syncData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('current')
          .set({
        ...data,
        'lastSync': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      rethrow;
    } catch (_) {
      throw Exception("Firestore sync failed");
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('current')
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } on FirebaseException {
      rethrow;
    } catch (_) {
      throw Exception("Firestore fetch failed");
    }
  }

  @override
  Future<void> deleteData(String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('current')
          .delete();
      await _firestore.collection('users').doc(uid).delete();
    } on FirebaseException {
      rethrow;
    } catch (_) {
      throw Exception("Firestore deletion failed");
    }
  }
}
