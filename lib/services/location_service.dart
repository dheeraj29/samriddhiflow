import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class LocationService {
  final StorageService _storageService;

  LocationService(this._storageService);

  Future<String?> fetchCurrentCountryCode() async {
    try {
      // Use Firebase Hosting i18n Rewrites (Keyless, free, and robust)
      const obscuredUrl =
          'https://samriddhiflow.web.app/api/v1/geocheck-8f2n1.json';
      final response = await http
          .get(Uri.parse(obscuredUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // coverage:ignore-start
        final data = json.decode(response.body);
        final countryCode = data['country'] as String?;
        if (countryCode != null && countryCode != 'OTHER') {
          await _storageService.setDetectedCountry(countryCode);
          // coverage:ignore-end
          return countryCode;
        }
      }
    } catch (e) {
      // Fallback to last detected country if offline or error
      return _storageService.getDetectedCountry(); // coverage:ignore-line
    }
    return _storageService.getDetectedCountry();
  }

  bool isCloudSyncRestricted(String? countryCode) {
    if (countryCode == null) {
      return false; // Allow if unknown/offline fallback to avoid blocking valid users unfairly on first load
    }
    return countryCode.toUpperCase() != 'IN';
  }
}
