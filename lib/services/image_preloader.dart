import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:loveell/models/user_model.dart';
import 'package:loveell/services/image_cache_service.dart';

class ImagePreloader {
  static Future<void> preloadUserImages(List<UserModel> users) async {
    for (final user in users) {
      if (user.profileImageBase64 != null &&
          user.profileImageBase64!.isNotEmpty) {
        try {
          final bytes = base64Decode(user.profileImageBase64!);

          // Cache both HD and thumbnail versions with different keys
          final hdCacheKey =
              '${user.uid}_${user.profileImageBase64!.hashCode}_hd';
          final thumbCacheKey =
              '${user.uid}_${user.profileImageBase64!.hashCode}_thumb';

          ImageCacheService().cacheImage(hdCacheKey, bytes, userId: user.uid);
          ImageCacheService()
              .cacheImage(thumbCacheKey, bytes, userId: user.uid);

          debugPrint('Preloaded images for user: ${user.uid}');
        } catch (e) {
          debugPrint('Error preloading image for ${user.uid}: $e');
        }
      }
    }
  }

  static void clearUserCache(String uid) {
    ImageCacheService().clearUserCache(uid);
  }

  static void clearAllCache() {
    ImageCacheService().clearAllCache();
  }

  // Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return ImageCacheService().getCacheStats();
  }
}
