import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sp_web/app/app.dart';
import 'package:web/web.dart' as web;

/// Token extracted from the URL before the widget tree
/// builds, consumed once by [AuthController.build].
String? initialOAuthToken;

void main() {
  usePathUrlStrategy();

  // Extract token from the OAuth callback redirect
  // (e.g. /login?token=xyz) before building the widget
  // tree so providers can read it synchronously.
  // Prefer a fresh token from the OAuth callback URL,
  // fall back to a previously stored token.
  final uri = Uri.parse(web.window.location.href);
  final urlToken = uri.queryParameters['token'];
  if (urlToken != null && urlToken.isNotEmpty) {
    initialOAuthToken = urlToken;
    web.window.localStorage.setItem('auth_token', urlToken);
    // Clean the URL so the token isn't re-processed on
    // refresh or back navigation.
    web.window.history.replaceState(''.toJSBox, '', '/browse');
  } else {
    final stored = web.window.localStorage.getItem('auth_token');
    if (stored != null && stored.isNotEmpty) {
      initialOAuthToken = stored;
    }
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
