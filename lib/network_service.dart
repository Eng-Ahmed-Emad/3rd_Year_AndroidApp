import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  // Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Additional check by trying to reach a known host
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Attempt to fetch data with retries
  static Future<http.Response?> fetchWithRetry(
      String url, {
        Map<String, String>? headers,
        int maxRetries = 3,
        Duration retryDelay = const Duration(seconds: 2),
      }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(Duration(seconds: 10));

        return response;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          return null;
        }

        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }

    return null;
  }

  // Check if Exploit-DB API is available
  static Future<bool> isExploitDBApiAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.exploit-db.com/search?type=exploits&format=json'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Check if GitHub repository is available
  static Future<bool> isGitHubRepoAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/offensive-security/exploitdb/master/files_exploits.csv'),
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}