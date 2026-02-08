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
  final uri = Uri.parse(web.window.location.href);
  final token = uri.queryParameters['token'];
  if (token != null && token.isNotEmpty) {
    initialOAuthToken = token;
    // Clean the URL so the token isn't re-processed on
    // refresh or back navigation.
    web.window.history.replaceState(''.toJSBox, '', '/browse');
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
