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

  /// Retrieves the UUID of the device currently marked as the active logged-in session.
  Future<String?> getActiveSessionId(String uid);

  /// Sets the specified device's UUID as the actively tracked session for this user account.
  Future<void> setActiveSessionId(String uid, String deviceId);

  /// Clears the active session device ID from the cloud.
  Future<void> clearActiveSessionId(String uid);

  /// Retrieves the region hint for the user from the global database.
  Future<String?> getRegionHint(String uid);

  /// Sets the region hint for the user in the global database.
  Future<void> setRegionHint(String uid, String region);
}
