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

  /// Default token lifetime: 24 hours.
  static const defaultExpiry = Duration(hours: 24);

  /// Creates a signed JWT containing [userId].
  String createToken(String userId, {Duration expiry = defaultExpiry}) {
    final now = DateTime.now().toUtc();
    final exp = now.add(expiry);

    final header = _encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _encode({
      'sub': userId,
      'iat': _toEpochSeconds(now),
      'exp': _toEpochSeconds(exp),
    });

    final signature = _sign('$header.$payload');
    return '$header.$payload.$signature';
  }

  /// Validates [token] and returns the `sub` (userId)
  /// claim on success, or `null` if invalid/expired.
  String? validateToken(String token) {
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
