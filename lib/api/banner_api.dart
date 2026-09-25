import 'dart:async';
import 'dart:developer';
import '../models/banner_model/banner_model.dart';
import '../models/text_nugget_model/text_nugget_model.dart';
import 'core/api_core.dart';

mixin BannerApi on ApiCore {
  // Simple test to check API connectivity
  Future<void> testBannerApiConnection() async {
    try {
      log('Testing banner API connectivity...');
      final uri = Uri.parse('https://besim.mynt.in/banner/banners/homescreen');

      final res = await apiClient.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      log('Test API Response - Status: ${res.statusCode}');
      log('Test API Response - Body: ${res.body}');
    } catch (e) {
      log('Test API Connection Error: $e');
    }
  }

  Future<BannerResponse?> fetchBanners() async {
    try {
      final uri = Uri.parse('https://besim.mynt.in/banner/banners/screens');

      log("Fetching all banners from: $uri");

      final res = await apiClient.get(uri, headers: defaultHeaders).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Banner API request timed out', const Duration(seconds: 8));
        },
      );

      log("Banner API Response - Status: ${res.statusCode}");
      log("Banner API Response - Body: ${res.body}");

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final response = BannerResponse.fromJson(json as Map<String, dynamic>);

        log("Parsed response - Success: ${response.success}");
        log("Available screens: ${response.screens.keys.toList()}");

        for (var screenEntry in response.screens.entries) {
          final screenName = screenEntry.key;
          final screenBanners = screenEntry.value;
          log("Screen '$screenName': ${screenBanners.count} banners");
          for (var banner in screenBanners.banners) {
            log("  - Banner: ${banner.id}, Image: ${banner.imageUrl}, Active: ${banner.isActive}");
          }
        }

        return response;
      } else {
        log("Failed to fetch banners - Status Code: ${res.statusCode}, Body: ${res.body}");
        return BannerResponse(
          screens: {},
          success: false,
          message: "HTTP ${res.statusCode}: ${res.body}",
        );
      }
    } catch (e, stackTrace) {
      log("Error fetching banners: $e");
      log("Stack trace: $stackTrace");
      return BannerResponse(
        screens: {},
        success: false,
        message: "Network error: $e",
      );
    }
  }

  Future<bool> markBannerSeen({required String bannerId}) async {
    try {
      final uri = Uri.parse('https://besim.mynt.in/banner/banners/$bannerId/seen');

      final data = {
        "user_id": prefs.clientId ?? '',
      };

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(data),
      );

      log("Mark Banner Seen API - Status: ${res.statusCode}");
      log("Mark Banner Seen API - Response: ${res.body}");

      return res.statusCode == 200;
    } catch (e) {
      log("Error marking banner as seen: $e");
      return false;
    }
  }

  Future<BannerResponse?> getBannersForScreen({required String screenName}) async {
    try {
      final uri = Uri.parse('${apiLinks.bemynt}/banners?screen=$screenName');

      final res = await apiClient.get(uri, headers: defaultHeaders);

      log("Fetch Banners for $screenName => ${res.body}");
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return BannerResponse.fromJson(json as Map<String, dynamic>);
      } else {
        return BannerResponse(
          screens: {},
          success: false,
          message: "Failed to fetch banners for screen",
        );
      }
    } catch (e) {
      log("Error fetching banners for screen: $e");
      return BannerResponse(
        screens: {},
        success: false,
        message: "Network error: $e",
      );
    }
  }

  // Text Nugget API Methods
  Future<TextNuggetResponse?> fetchTextNuggets() async {
    try {
      final uri = Uri.parse('https://besim.mynt.in/banner/texts/screens');

      log("Fetching all text nuggets from: $uri");

      final res = await apiClient.get(uri, headers: defaultHeaders).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Text Nugget API request timed out', const Duration(seconds: 8));
        },
      );

      log("Text Nugget API Response - Status: ${res.statusCode}");
      log("Text Nugget API Response - Body: ${res.body}");

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final response = TextNuggetResponse.fromJson(json as Map<String, dynamic>);

        log("Parsed response - Success: ${response.success}");
        log("Available screens: ${response.screens.keys.toList()}");

        for (var screenEntry in response.screens.entries) {
          final screenName = screenEntry.key;
          final screenTexts = screenEntry.value;
          log("Screen '$screenName': ${screenTexts.count} text nuggets");
          for (var text in screenTexts.texts) {
            log("  - Text: ${text.id}, Content: ${text.content}, Active: ${text.isActive}");
          }
        }

        return response;
      } else {
        log("Failed to fetch text nuggets - Status Code: ${res.statusCode}, Body: ${res.body}");
        return TextNuggetResponse(
          screens: {},
          success: false,
          message: "HTTP ${res.statusCode}: ${res.body}",
        );
      }
    } catch (e, stackTrace) {
      log("Error fetching text nuggets: $e");
      log("Stack trace: $stackTrace");
      return TextNuggetResponse(
        screens: {},
        success: false,
        message: "Network error: $e",
      );
    }
  }

  Future<bool> markTextNuggetSeen({required String textId}) async {
    try {
      final uri = Uri.parse('https://besim.mynt.in/banner/texts/$textId/seen');

      final data = {
        "user_id": prefs.clientId ?? '',
      };

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(data),
      );

      log("Mark Text Nugget Seen API - Status: ${res.statusCode}");
      log("Mark Text Nugget Seen API - Response: ${res.body}");

      return res.statusCode == 200;
    } catch (e) {
      log("Error marking text nugget as seen: $e");
      return false;
    }
  }

  Future<TextNuggetResponse?> getTextNuggetsForScreen({required String screenName}) async {
    try {
      final uri = Uri.parse('${apiLinks.bemynt}/texts?screen=$screenName');

      final res = await apiClient.get(uri, headers: defaultHeaders);

      log("Fetch Text Nuggets for $screenName => ${res.body}");
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return TextNuggetResponse.fromJson(json as Map<String, dynamic>);
      } else {
        return TextNuggetResponse(
          screens: {},
          success: false,
          message: "Failed to fetch text nuggets for screen",
        );
      }
    } catch (e) {
      log("Error fetching text nuggets for screen: $e");
      return TextNuggetResponse(
        screens: {},
        success: false,
        message: "Network error: $e",
      );
    }
  }
}