import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheService {
  static const String EXPLOITS_CACHE_KEY = 'cached_exploits';
  static const String LAST_UPDATED_KEY = 'last_updated';
  static const Duration CACHE_DURATION = Duration(days: 1);

  // Save exploits to cache
  static Future<bool> cacheExploits(List<Map<String, dynamic>> exploits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = json.encode(exploits);

      // Save data and timestamp
      await prefs.setString(EXPLOITS_CACHE_KEY, jsonData);
      await prefs.setInt(LAST_UPDATED_KEY, DateTime.now().millisecondsSinceEpoch);

      return true;
    } catch (e) {
      print('Error caching exploits: $e');
      return false;
    }
  }

  // Load exploits from cache
  static Future<List<Map<String, dynamic>>?> getCachedExploits() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists
      if (!prefs.containsKey(EXPLOITS_CACHE_KEY)) {
        return null;
      }

      // Check if cache is expired
      final lastUpdated = prefs.getInt(LAST_UPDATED_KEY) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdated;

      if (cacheAge > CACHE_DURATION.inMilliseconds) {
        // Cache is expired
        return null;
      }

      // Get and parse cache data
      final jsonData = prefs.getString(EXPLOITS_CACHE_KEY);
      if (jsonData == null) return null;

      final List<dynamic> decodedData = json.decode(jsonData);
      return decodedData.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting cached exploits: $e');
      return null;
    }
  }

  // Cache the CSV or JSON data from URL
  static Future<String?> cacheRemoteFile(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      return await file.readAsString();
    } catch (e) {
      print('Error caching remote file: $e');
      return null;
    }
  }

  // Get cache info
  static Future<String> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!prefs.containsKey(LAST_UPDATED_KEY)) {
        return 'No cache available';
      }

      final lastUpdated = prefs.getInt(LAST_UPDATED_KEY) ?? 0;
      final lastUpdatedDate = DateTime.fromMillisecondsSinceEpoch(lastUpdated);

      return 'Cache last updated: ${lastUpdatedDate.toString()}';
    } catch (e) {
      return 'Error getting cache info';
    }
  }

  // Clear cache
  static Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(EXPLOITS_CACHE_KEY);
      await prefs.remove(LAST_UPDATED_KEY);
      await DefaultCacheManager().emptyCache();
      return true;
    } catch (e) {
      print('Error clearing cache: $e');
      return false;
    }
  }
}