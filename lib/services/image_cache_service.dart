import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  static const int _maxCacheSize = 150;
  static final Map<String, CacheEntry> _memoryCache = {};
  static final List<String> _cacheOrder = [];

  void cacheImage(String key, Uint8List bytes, {String? userId}) {
    if (_memoryCache.containsKey(key)) {
      // Update existing entry
      _memoryCache[key] =
          CacheEntry(bytes: bytes, userId: userId, timestamp: DateTime.now());
      // Move to end of order (most recent)
      _cacheOrder.remove(key);
      _cacheOrder.add(key);
      debugPrint('ImageCacheService: Updated existing cache entry: $key');
      return;
    }

    // Remove oldest if cache is full
    if (_memoryCache.length >= _maxCacheSize) {
      final oldestKey = _cacheOrder.removeAt(0);
      _memoryCache.remove(oldestKey);
      debugPrint('ImageCacheService: Removed oldest cache entry: $oldestKey');
    }

    _memoryCache[key] =
        CacheEntry(bytes: bytes, userId: userId, timestamp: DateTime.now());
    _cacheOrder.add(key);

    debugPrint(
        'ImageCacheService: Cached image: $key, total cache size: ${_memoryCache.length}');
  }

  Uint8List? getCachedImage(String key) {
    final entry = _memoryCache[key];
    if (entry != null) {
      // Move to end of order (most recent)
      _cacheOrder.remove(key);
      _cacheOrder.add(key);
      debugPrint('ImageCacheService: Cache hit for: $key');
      return entry.bytes;
    }
    debugPrint('ImageCacheService: Cache miss for: $key');
    return null;
  }

  void clearUserCache(String userId) {
    if (userId.isEmpty) return;

    final keysToRemove = _memoryCache.keys
        .where((key) => _memoryCache[key]?.userId == userId)
        .toList();

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheOrder.remove(key);
    }

    debugPrint(
        'ImageCacheService: Cleared cache for user: $userId, removed ${keysToRemove.length} entries');

    // Also clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    debugPrint('ImageCacheService: Cleared Flutter image cache');
  }

  void clearAllCache() {
    _memoryCache.clear();
    _cacheOrder.clear();
    PaintingBinding.instance.imageCache.clear();
    debugPrint('ImageCacheService: Cleared all image caches');
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _memoryCache.length,
      'maxSize': _maxCacheSize,
      'users': _memoryCache.values
          .where((e) => e.userId != null)
          .map((e) => e.userId)
          .toSet()
          .length,
    };
  }
}

class CacheEntry {
  final Uint8List bytes;
  final String? userId;
  final DateTime timestamp;

  CacheEntry({
    required this.bytes,
    this.userId,
    required this.timestamp,
  });
}
