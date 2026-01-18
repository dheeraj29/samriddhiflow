import 'dart:async';

abstract class CloudStorageInterface {
  /// Synchronizes the provided structured data to the cloud.
  /// [uid] is the unique user identifier.
  /// [data] is a JSON-compatible map containing all app data.
  Future<void> syncData(String uid, Map<String, dynamic> data);

  /// Fetches the latest structured data from the cloud.
  /// Returns null if no data exists.
  Future<Map<String, dynamic>?> fetchData(String uid);

  /// Deletes all cloud data for the specified user.
  Future<void> deleteData(String uid);
}
