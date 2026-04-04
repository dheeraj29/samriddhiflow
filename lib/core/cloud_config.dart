class CloudDatabaseRegion {
  static const String india = 'india';
  // Add future regions here (e.g. static const String us = 'us';)
}

/// Central mapping of human-readable region IDs to their corresponding
/// Firestore database names. A null value maps to the '(default)' database.
const Map<String, String?> regionDatabaseMapping = {
  CloudDatabaseRegion.india: null,
};
