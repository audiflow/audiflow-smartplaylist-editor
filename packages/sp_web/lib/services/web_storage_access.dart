import 'package:web/web.dart' as web;

import 'package:sp_web/services/local_draft_service.dart';

/// Production [StorageAccess] backed by browser localStorage.
final class WebStorageAccess implements StorageAccess {
  const WebStorageAccess();

  @override
  String? getItem(String key) => web.window.localStorage.getItem(key);

  @override
  void setItem(String key, String value) =>
      web.window.localStorage.setItem(key, value);

  @override
  void removeItem(String key) => web.window.localStorage.removeItem(key);
}
