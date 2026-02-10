import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Lightweight JWT service using HMAC-SHA256.
///
/// Produces tokens in the standard
/// `base64url(header).base64url(payload).base64url(signature)`
/// format.
class JwtService {
  JwtService({required String secret}) : _secretBytes = utf8.encode(secret);

  final List<int> _secretBytes;

  /// Token type claim for short-lived access tokens.
  static const accessTokenType = 'access';

  /// Token type claim for long-lived refresh tokens.
  static const refreshTokenType = 'refresh';

  /// Default access token lifetime: 24 hours.
  static const defaultExpiry = Duration(hours: 24);

  /// Default refresh token lifetime: 30 days.
  static const defaultRefreshExpiry = Duration(days: 30);

  /// Creates a signed access JWT containing [userId].
  String createToken(String userId, {Duration expiry = defaultExpiry}) {
    return _createTokenWithType(userId, type: accessTokenType, expiry: expiry);
  }

  /// Creates a signed refresh JWT containing [userId].
  String createRefreshToken(
    String userId, {
    Duration expiry = defaultRefreshExpiry,
  }) {
    return _createTokenWithType(userId, type: refreshTokenType, expiry: expiry);
  }

  String _createTokenWithType(
    String userId, {
    required String type,
    required Duration expiry,
  }) {
    final now = DateTime.now().toUtc();
    final exp = now.add(expiry);

    final header = _encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _encode({
      'sub': userId,
      'typ': type,
      'iat': _toEpochSeconds(now),
      'exp': _toEpochSeconds(exp),
    });

    final signature = _sign('$header.$payload');
    return '$header.$payload.$signature';
  }

  /// Validates [token] and returns the `sub` (userId)
  /// claim on success, or `null` if invalid/expired.
  ///
  /// When [requiredType] is set, rejects tokens whose
  /// `typ` claim does not match.
  String? validateToken(String token, {String? requiredType}) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final expectedSig = _sign('${parts[0]}.${parts[1]}');
    if (expectedSig != parts[2]) return null;

    try {
      final payload = _decode(parts[1]);
      final exp = payload['exp'] as int?;
      if (exp == null) return null;

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      if (DateTime.now().toUtc().isAfter(expiry)) return null;

      if (requiredType != null && payload['typ'] != requiredType) {
        return null;
      }

      return payload['sub'] as String?;
    } on Object {
      return null;
    }
  }

  String _encode(Map<String, dynamic> data) {
    final json = jsonEncode(data);
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }

  Map<String, dynamic> _decode(String encoded) {
    // Re-pad base64url to a multiple-of-4 length.
    final padded = encoded.padRight(
      encoded.length + (4 - encoded.length % 4) % 4,
      '=',
    );
    final json = utf8.decode(base64Url.decode(padded));
    return jsonDecode(json) as Map<String, dynamic>;
  }

  String _sign(String input) {
    final hmac = Hmac(sha256, _secretBytes);
    final digest = hmac.convert(utf8.encode(input));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static int _toEpochSeconds(DateTime dt) {
    return dt.millisecondsSinceEpoch ~/ 1000;
  }
}
