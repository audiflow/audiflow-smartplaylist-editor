import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/api_key.dart';

/// Service for generating, storing, and validating
/// API keys using in-memory storage.
///
/// Keys are hashed with SHA-256 before storage;
/// the plaintext is returned only once at creation.
class ApiKeyService {
  final Map<String, ApiKey> _keysById = {};
  final Map<String, List<String>> _keyIdsByUser = {};

  /// Index from hashed key to key ID for fast lookup.
  final Map<String, String> _keyIdByHash = {};

  /// Generates a new API key for [userId].
  ///
  /// Returns a record containing the [ApiKey] metadata
  /// and the plaintext key. The plaintext is only
  /// available at creation time.
  ({ApiKey apiKey, String plaintext}) generateKey(String userId, String name) {
    final plaintext = _generateRandomKey();
    final hashed = _hashKey(plaintext);
    final masked = _maskKey(plaintext);
    final now = DateTime.now();
    final id = 'key_${now.microsecondsSinceEpoch}';

    final apiKey = ApiKey(
      id: id,
      userId: userId,
      name: name,
      hashedKey: hashed,
      maskedKey: masked,
      createdAt: now,
    );

    _keysById[id] = apiKey;
    _keyIdsByUser.putIfAbsent(userId, () => []).add(id);
    _keyIdByHash[hashed] = id;

    return (apiKey: apiKey, plaintext: plaintext);
  }

  /// Lists all API keys for [userId].
  ///
  /// Returns metadata only; hashed keys are excluded
  /// from the JSON representation.
  List<ApiKey> listKeys(String userId) {
    final ids = _keyIdsByUser[userId];
    if (ids == null) return [];

    return ids.map((id) => _keysById[id]).whereType<ApiKey>().toList();
  }

  /// Deletes an API key by [keyId] for [userId].
  ///
  /// Returns `true` if the key existed and was
  /// deleted, `false` otherwise.
  bool deleteKey(String userId, String keyId) {
    final apiKey = _keysById[keyId];
    if (apiKey == null || apiKey.userId != userId) {
      return false;
    }

    _keysById.remove(keyId);
    _keyIdByHash.remove(apiKey.hashedKey);
    _keyIdsByUser[userId]?.remove(keyId);

    return true;
  }

  /// Validates a plaintext API key.
  ///
  /// Returns the associated userId if valid,
  /// or `null` if the key is not recognized.
  String? validateKey(String plaintextKey) {
    final hashed = _hashKey(plaintextKey);
    final keyId = _keyIdByHash[hashed];
    if (keyId == null) return null;

    return _keysById[keyId]?.userId;
  }

  /// Generates a cryptographically random 32-byte key
  /// encoded as base64url.
  static String _generateRandomKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Hashes a plaintext key with SHA-256.
  static String _hashKey(String plaintext) {
    final bytes = utf8.encode(plaintext);
    return sha256.convert(bytes).toString();
  }

  /// Masks a key to show only the last 8 characters.
  static String _maskKey(String plaintext) {
    if (8 < plaintext.length) {
      final visible = plaintext.substring(plaintext.length - 8);
      return '****$visible';
    }
    return plaintext;
  }
}
