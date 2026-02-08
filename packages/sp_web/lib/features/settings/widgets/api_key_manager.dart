import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/settings/controllers/settings_controller.dart';

/// Displays and manages API keys: list, generate, revoke.
///
/// Shows a card with a header, optional new-key banner,
/// and a list of existing keys with revoke actions.
class ApiKeyManager extends ConsumerWidget {
  const ApiKeyManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, ref, settingsState),
            const Divider(height: 24),
            if (settingsState.newlyGeneratedKey != null)
              _NewKeyBanner(keyValue: settingsState.newlyGeneratedKey!),
            if (settingsState.error != null)
              _ErrorBanner(message: settingsState.error!),
            if (settingsState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (settingsState.keys.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No API keys yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              _KeyList(keys: settingsState.keys),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    SettingsState settingsState,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.key, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('API Keys', style: theme.textTheme.titleLarge)),
        FilledButton.icon(
          onPressed: () {
            ref.read(settingsControllerProvider.notifier).generateKey();
          },
          icon: const Icon(Icons.add),
          label: const Text('Generate'),
        ),
      ],
    );
  }
}

/// Banner shown once after a new key is generated.
///
/// Displays the full key value with a copy button and
/// a warning that the key will not be shown again.
class _NewKeyBanner extends ConsumerWidget {
  const _NewKeyBanner({required this.keyValue});

  final String keyValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New API Key Generated',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref.read(settingsControllerProvider.notifier).clearNewKey();
                  },
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      keyValue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(context, keyValue),
                    tooltip: 'Copy to clipboard',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'Save this key - it won\'t be shown again',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Displays an error banner with the given [message].
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the list of existing API keys with revoke
/// actions.
class _KeyList extends ConsumerWidget {
  const _KeyList({required this.keys});

  final List<Map<String, dynamic>> keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final key = keys[index];
        final id = key['id'] as String;
        final prefix = key['prefix'] as String? ?? '';
        final createdAt = key['createdAt'] as String? ?? '';

        return _KeyListTile(id: id, prefix: prefix, createdAt: createdAt);
      },
    );
  }
}

/// A single API key entry showing prefix, creation date,
/// and a revoke button.
class _KeyListTile extends ConsumerWidget {
  const _KeyListTile({
    required this.id,
    required this.prefix,
    required this.createdAt,
  });

  final String id;
  final String prefix;
  final String createdAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.vpn_key, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        '$prefix...',
        style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
      ),
      subtitle: Text('Created: ${_formatDate(createdAt)}'),
      trailing: TextButton.icon(
        onPressed: () => _confirmRevoke(context, ref),
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        label: Text('Revoke', style: TextStyle(color: theme.colorScheme.error)),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'Unknown';
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return '${parsed.year}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke API Key'),
        content: Text(
          'Are you sure you want to revoke the key "$prefix..."? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(settingsControllerProvider.notifier).revokeKey(id);
    }
  }
}
