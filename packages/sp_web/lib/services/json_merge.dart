/// Three-way JSON merge utility.
///
/// Given a [base] snapshot, the [latest] server version, and the
/// user's [modified] version, produces a merged result where user
/// changes win on conflict.
abstract final class JsonMerge {
  /// Merges three versions of a JSON map.
  ///
  /// - Keys the user changed (vs base) use the user's value.
  /// - Keys the user did not change take the latest server value.
  /// - Nested maps are merged recursively.
  /// - Arrays of maps with `id` fields are matched by id.
  /// - Other arrays are merged by index.
  static Map<String, dynamic> merge({
    required Map<String, dynamic> base,
    required Map<String, dynamic> latest,
    required Map<String, dynamic> modified,
  }) {
    return _mergeMaps(base, latest, modified);
  }

  static Map<String, dynamic> _mergeMaps(
    Map<String, dynamic> base,
    Map<String, dynamic> latest,
    Map<String, dynamic> modified,
  ) {
    final allKeys = <String>{...base.keys, ...latest.keys, ...modified.keys};

    final result = <String, dynamic>{};

    for (final key in allKeys) {
      final inBase = base.containsKey(key);
      final inLatest = latest.containsKey(key);
      final inModified = modified.containsKey(key);

      final baseVal = base[key];
      final latestVal = latest[key];
      final modifiedVal = modified[key];

      final userChanged =
          inModified && (!inBase || !_deepEquals(baseVal, modifiedVal));
      final userRemoved = inBase && !inModified;

      if (userRemoved) {
        // User explicitly removed this key -- honor the removal.
        continue;
      }

      if (!inBase && !inModified && inLatest) {
        // Upstream added a new key the user never touched.
        result[key] = latestVal;
        continue;
      }

      if (!inBase && inModified && !inLatest) {
        // User added a new key.
        result[key] = modifiedVal;
        continue;
      }

      if (inBase && !inLatest && !userChanged) {
        // Upstream removed and user did not change -- drop it.
        continue;
      }

      if (userChanged) {
        // User changed this key -- recurse if both sides are maps,
        // otherwise user wins outright.
        if (modifiedVal is Map<String, dynamic> &&
            latestVal is Map<String, dynamic> &&
            baseVal is Map<String, dynamic>) {
          result[key] = _mergeMaps(baseVal, latestVal, modifiedVal);
        } else if (modifiedVal is List &&
            latestVal is List &&
            baseVal is List) {
          result[key] = _mergeLists(baseVal, latestVal, modifiedVal);
        } else {
          result[key] = modifiedVal;
        }
      } else {
        // User did not change -- take latest.
        result[key] = latestVal;
      }
    }

    return result;
  }

  static List<dynamic> _mergeLists(
    List<dynamic> base,
    List<dynamic> latest,
    List<dynamic> modified,
  ) {
    if (_isIdArray(base) || _isIdArray(latest) || _isIdArray(modified)) {
      return _mergeIdLists(base, latest, modified);
    }
    return _mergeIndexLists(base, latest, modified);
  }

  /// Whether [list] is a list of maps that all have an `id` field.
  static bool _isIdArray(List<dynamic> list) {
    if (list.isEmpty) return false;
    return list.every(
      (item) => item is Map<String, dynamic> && item.containsKey('id'),
    );
  }

  /// Merge arrays of maps matched by their `id` field.
  static List<dynamic> _mergeIdLists(
    List<dynamic> base,
    List<dynamic> latest,
    List<dynamic> modified,
  ) {
    final baseById = _indexById(base);
    final latestById = _indexById(latest);
    final modifiedById = _indexById(modified);

    final result = <dynamic>[];

    // Process items in latest order first.
    for (final item in latest) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String;
      final baseItem = baseById[id];
      final modItem = modifiedById[id];

      if (modItem != null && baseItem != null) {
        result.add(_mergeMaps(baseItem, item, modItem));
      } else if (modItem != null) {
        result.add(modItem);
      } else {
        result.add(item);
      }
    }

    // Items removed upstream but user modified -> keep them.
    for (final item in modified) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String;
      if (latestById.containsKey(id)) continue; // Already handled.
      final baseItem = baseById[id];
      if (baseItem != null && !_deepEquals(baseItem, item)) {
        // User modified an item that upstream removed -- keep user version.
        result.add(item);
      } else if (baseItem == null) {
        // User added a brand new item.
        result.add(item);
      }
      // Otherwise: was in base, upstream removed, user did not change -> drop.
    }

    return result;
  }

  static Map<String, Map<String, dynamic>> _indexById(List<dynamic> list) {
    final map = <String, Map<String, dynamic>>{};
    for (final item in list) {
      if (item is Map<String, dynamic> && item.containsKey('id')) {
        map[item['id'] as String] = item;
      }
    }
    return map;
  }

  /// Merge arrays by index position.
  static List<dynamic> _mergeIndexLists(
    List<dynamic> base,
    List<dynamic> latest,
    List<dynamic> modified,
  ) {
    final baseLen = base.length;
    final latestLen = latest.length;
    final modifiedLen = modified.length;

    // Determine how many indices to process from the shared range.
    final minLen = _min(baseLen, _min(latestLen, modifiedLen));
    final result = <dynamic>[];

    for (var i = 0; i < minLen; i++) {
      final userChanged = !_deepEquals(base[i], modified[i]);
      if (userChanged) {
        result.add(modified[i]);
      } else {
        result.add(latest[i]);
      }
    }

    // Handle tail: items beyond the base length.
    // If user extended the list, keep user's extras.
    if (baseLen < modifiedLen) {
      for (var i = baseLen; i < modifiedLen; i++) {
        if (i < minLen) continue; // Already processed.
        result.add(modified[i]);
      }
    }
    // If upstream extended the list, keep upstream extras.
    if (baseLen < latestLen) {
      for (var i = baseLen; i < latestLen; i++) {
        if (i < minLen) continue; // Already processed.
        result.add(latest[i]);
      }
    }

    return result;
  }

  static int _min(int a, int b) => a < b ? a : b;

  static bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
