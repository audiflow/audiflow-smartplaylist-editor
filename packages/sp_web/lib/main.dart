import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sp_web/app/app.dart';
import 'package:web/web.dart' as web;

/// Access token extracted from the URL before the widget
/// tree builds, consumed once by [AuthController.build].
String? initialOAuthToken;

/// Refresh token extracted alongside the access token.
String? initialOAuthRefreshToken;

void main() {
  usePathUrlStrategy();

  // Extract tokens from the OAuth callback redirect
  // (e.g. /login?token=xyz&refresh_token=abc) before
  // building the widget tree so providers can read them
  // synchronously.
  // Prefer fresh tokens from the OAuth callback URL,
  // fall back to previously stored tokens.
  final uri = Uri.parse(web.window.location.href);
  final urlToken = uri.queryParameters['token'];
  if (urlToken != null && urlToken.isNotEmpty) {
    initialOAuthToken = urlToken;
    web.window.localStorage.setItem('auth_token', urlToken);

    final urlRefresh = uri.queryParameters['refresh_token'];
    if (urlRefresh != null && urlRefresh.isNotEmpty) {
      initialOAuthRefreshToken = urlRefresh;
      web.window.localStorage.setItem('refresh_token', urlRefresh);
    }

    // Clean the URL so tokens aren't re-processed on
    // refresh or back navigation.
    web.window.history.replaceState(''.toJSBox, '', '/browse');
  } else {
    final stored = web.window.localStorage.getItem('auth_token');
    if (stored != null && stored.isNotEmpty) {
      initialOAuthToken = stored;
    }
    final storedRefresh = web.window.localStorage.getItem('refresh_token');
    if (storedRefresh != null && storedRefresh.isNotEmpty) {
      initialOAuthRefreshToken = storedRefresh;
    }
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
