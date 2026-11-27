import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_comparison_result.dart';
import '../services/storage_capacity_service.dart';

class CachedActivityComparison {
  const CachedActivityComparison({
    required this.results,
    required this.createdAt,
    required this.isStale,
  });

  final List<ActivityComparisonResult> results;
  final DateTime createdAt;
  final bool isStale;
}

class ActivityComparisonCache {
  ActivityComparisonCache({
    StorageCapacityService? capacityService,
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? now,
    this.maxEntries = defaultMaxEntries,
    this.freshness = defaultFreshness,
    this.maxStaleAge = defaultMaxStaleAge,
  }) : _capacityService = capacityService ?? StorageCapacityService(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries');
    }
    if (freshness.isNegative || maxStaleAge < freshness) {
      throw ArgumentError('maxStaleAge must be at least freshness.');
    }
  }

  static const defaultMaxEntries = 20;
  static const defaultFreshness = Duration(minutes: 30);
  static const defaultMaxStaleAge = Duration(days: 7);
  static const _keyPrefix = 'activity_comparison_results_v1_';

  final StorageCapacityService _capacityService;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _now;
  final int maxEntries;
  final Duration freshness;
  final Duration maxStaleAge;

  final Map<String, Map<String, _CacheEntry>> _entriesByUser = {};

  Future<CachedActivityComparison?> get({
    required String userId,
    required String key,
    required bool allowStale,
  }) async {
    final entries = await _entriesFor(userId);
    final entry = entries.remove(key);
    if (entry == null) return null;

    final age = _now().difference(entry.createdAt);
    if (age.isNegative || age > maxStaleAge) return null;

    final isStale = age > freshness;
    if (isStale && !allowStale) {
      entries[key] = entry;
      return null;
    }

    entries[key] = entry;
    return CachedActivityComparison(
      results: entry.results,
      createdAt: entry.createdAt,
      isStale: isStale,
    );
  }

  Future<void> put({
    required String userId,
    required String key,
    required List<ActivityComparisonResult> results,
  }) async {
    final entry = _CacheEntry(
      key: key,
      createdAt: _now().toUtc(),
      results: List.unmodifiable(results),
    );
    final entries = await _entriesFor(userId);
    entries.remove(key);
    entries[key] = entry;
    while (entries.length > maxEntries) {
      entries.remove(entries.keys.first);
    }

    late final SharedPreferences preferences;
    try {
      preferences = await _preferencesProvider();
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return;
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return;
    }
    final storageKey = _storageKey(userId);
    final encoded = jsonEncode(
      entries.values.map((item) => item.toMap()).toList(),
    );
    final capacity = await _capacityService.check(
      estimatedWriteBytes: utf8.encode(encoded).length,
    );
    if (!capacity.canWriteOptionalData) return;

    try {
      final saved = await preferences.setString(storageKey, encoded);
      if (!saved) {
        _reportError(
          StateError('The comparison cache could not be persisted.'),
          StackTrace.current,
        );
      }
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<Map<String, _CacheEntry>> _entriesFor(String userId) async {
    final existing = _entriesByUser[userId];
    if (existing != null) return existing;

    final entries = <String, _CacheEntry>{};
    try {
      final preferences = await _preferencesProvider();
      final raw = preferences.getString(_storageKey(userId));
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          throw const FormatException('Comparison cache is not a list.');
        }
        for (final item in decoded) {
          if (item is! Map) {
            throw const FormatException('Comparison cache entry is invalid.');
          }
          final entry = _CacheEntry.fromMap(Map<String, dynamic>.from(item));
          entries[entry.key] = entry;
        }
      }
    } on FormatException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _removeStoredCache(userId);
      entries.clear();
    } on TypeError catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _removeStoredCache(userId);
      entries.clear();
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }

    while (entries.length > maxEntries) {
      entries.remove(entries.keys.first);
    }
    _entriesByUser[userId] = entries;
    return entries;
  }

  Future<void> _removeStoredCache(String userId) async {
    try {
      await (await _preferencesProvider()).remove(_storageKey(userId));
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  String _storageKey(String userId) => '$_keyPrefix$userId';

  void _reportError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'activity comparison cache',
      ),
    );
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.key,
    required this.createdAt,
    required this.results,
  });

  final String key;
  final DateTime createdAt;
  final List<ActivityComparisonResult> results;

  Map<String, Object?> toMap() => {
    'key': key,
    'createdAt': createdAt.toIso8601String(),
    'results': results.map((result) => result.toMap()).toList(),
  };

  factory _CacheEntry.fromMap(Map<String, dynamic> map) {
    final rawResults = map['results'];
    if (map['key'] is! String ||
        map['createdAt'] is! String ||
        rawResults is! List) {
      throw const FormatException('Comparison cache entry is incomplete.');
    }
    final createdAt = DateTime.tryParse(map['createdAt'] as String);
    if (createdAt == null) {
      throw const FormatException('Comparison cache timestamp is invalid.');
    }
    return _CacheEntry(
      key: map['key'] as String,
      createdAt: createdAt.toUtc(),
      results: List.unmodifiable(
        rawResults.map(
          (result) => ActivityComparisonResult.fromMap(
            Map<String, dynamic>.from(result as Map),
          ),
        ),
      ),
    );
  }
}
