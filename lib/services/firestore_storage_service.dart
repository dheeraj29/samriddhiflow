import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'cloud_storage_interface.dart';
import 'firebase_web_safe.dart';

class FirestoreStorageService implements CloudStorageInterface {
  static const String permissionDeniedCode = 'permission-denied';
  final String? databaseId;

  FirestoreStorageService({this.databaseId});

  // Lazy access to $(default) database for global metadata
  FirebaseFirestore get _globalFirestore {
    try {
      if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) {
        throw Exception("Firebase JS SDK not loaded (Offline/iOS strict mode)");
      }
      if (Firebase.apps.isEmpty) {
        throw Exception("Firestore accessed before Firebase Init (Offline?)");
      }
      // Passing databaseId: null (or omitting) always points to (default)
      return FirebaseFirestore.instanceFor(app: Firebase.app());
    } catch (e) {
      throw Exception("Global Firestore Access Failed (Safety): $e");
    }
  }

  // Lazy access to Regional database for actual financial data
  FirebaseFirestore get _firestore {
    try {
      if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) {
        throw Exception("Firebase JS SDK not loaded (Offline/iOS strict mode)");
      }

      if (Firebase.apps.isEmpty) {
        throw Exception("Firestore accessed before Firebase Init (Offline?)");
      }

      // If databaseId is null, this also falls back to (default),
      // which is fine for users who haven't been routed yet.
      return FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseId: databaseId);
    } catch (e) {
      throw Exception("Regional Firestore Access Failed (Safety): $e");
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
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore deletion failed");
    }
  }

  @override
  Future<String?> getActiveSessionId(String uid) async {
    try {
      final doc = await _globalFirestore
          .collection('users')
          .doc(uid)
          .collection('session')
          .doc('current')
          .get();
      if (!doc.exists) return null;
      return doc.data()?['deviceId'] as String?;
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore session check failed");
    }
  }

  @override
  Future<void> setActiveSessionId(String uid, String deviceId) async {
    try {
      await _globalFirestore
          .collection('users')
          .doc(uid)
          .collection('session')
          .doc('current')
          .set({
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore session set failed");
    }
  }

  @override
  Future<void> clearActiveSessionId(String uid) async {
    try {
      await _globalFirestore
          .collection('users')
          .doc(uid)
          .collection('session')
          .doc('current')
          .delete();
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore session clear failed");
    }
  }

  @override
  Future<String?> getRegionHint(String uid) async {
    try {
      final doc = await _globalFirestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?['region'] as String?;
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore region fetch failed");
    }
  }

  @override
  Future<void> setRegionHint(String uid, String region) async {
    try {
      await _globalFirestore.collection('users').doc(uid).set({
        'region': region,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == permissionDeniedCode) throw Exception(permissionDeniedCode);
      rethrow;
    } catch (_) {
      throw Exception("Firestore region set failed");
    }
  }
}
