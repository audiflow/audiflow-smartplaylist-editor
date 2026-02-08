import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/settings/controllers/settings_controller.dart';
import 'package:sp_web/features/settings/widgets/api_key_manager.dart';

/// Settings screen with API key management.
///
/// Loads API keys on initialization and displays the
/// [ApiKeyManager] widget for key generation, listing,
/// and revocation.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to after build so the notifier is ready.
    Future.microtask(() {
      ref.read(settingsControllerProvider.notifier).loadKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ApiKeyManager()],
        ),
      ),
    );
  }
}
