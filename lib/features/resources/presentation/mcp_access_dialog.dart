import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/http/api_client.dart';
import '../../../core/ui/top_notification.dart';

/// MCP key of a user (Admin → Users). The key is shown once; the server stores only its SHA-256.
/// Who may use a key and the connector address: System Settings → mcp.
class McpAccessButton extends StatelessWidget {
  const McpAccessButton({
    super.key,
    required this.userId,
    required this.hasKey,
    required this.repository,
    required this.onChanged,
  });

  final String userId;
  final bool hasKey;
  final AdminResourceRepository repository;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => McpAccessDialog(userId: userId, hasKey: hasKey, repository: repository, onChanged: onChanged),
      ),
      icon: const Icon(Icons.key_outlined, size: 18),
      label: const Text('MCP key'),
    );
  }
}

class McpAccessDialog extends StatefulWidget {
  const McpAccessDialog({
    super.key,
    required this.userId,
    required this.hasKey,
    required this.repository,
    required this.onChanged,
  });

  final String userId;
  final bool hasKey;
  final AdminResourceRepository repository;
  final VoidCallback onChanged;

  @override
  State<McpAccessDialog> createState() => _McpAccessDialogState();
}

class _McpAccessDialogState extends State<McpAccessDialog> {
  Map<String, dynamic>? _issued;
  bool _busy = false;

  String _message(Object error) => error is ApiException ? error.displayMessage : '$error';

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showTopNotification(context, '$failure: ${_message(error)}', type: TopNotificationType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue() => _run(() async {
        final result = await widget.repository.createUserMcpToken(widget.userId);
        widget.onChanged();
        if (mounted) setState(() => _issued = result);
      }, 'MCP key failed');

  Future<void> _revoke() => _run(() async {
        await widget.repository.revokeUserMcpToken(widget.userId);
        widget.onChanged();
        if (!mounted) return;
        showTopNotification(context, 'MCP key revoked.', type: TopNotificationType.success);
        Navigator.of(context).pop();
      }, 'MCP key revoke failed');

  @override
  Widget build(BuildContext context) {
    final issued = _issued;
    final token = issued?['token']?.toString() ?? '';
    final url = issued?['public_url']?.toString().trim() ?? '';
    final shownUrl = url.isEmpty ? '<public URL from System Settings → mcp>' : url;
    final warningStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    const mono = TextStyle(fontFamily: 'monospace');
    return AlertDialog(
      title: const Text('MCP key'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: issued == null
                ? [
                    Text(widget.hasKey
                        ? 'This user has an MCP key. A new key replaces it: the old key stops working at once.'
                        : 'This user has no MCP key yet.'),
                  ]
                : [
                    const Text('Copy the key now. It is shown only once and cannot be read again.'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: SelectableText(token, style: mono)),
                        IconButton(
                          tooltip: 'Copy key',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: token));
                            if (context.mounted) {
                              showTopNotification(context, 'MCP key copied.', type: TopNotificationType.success);
                            }
                          },
                        ),
                      ],
                    ),
                    if (issued['enabled'] == false)
                      Text('MCP is switched off in System Settings → mcp. The key works once it is enabled.',
                          style: warningStyle),
                    if (issued['role_allowed'] == false)
                      Text('Role "${issued['role_code']}" is not in System Settings → mcp → roles: the key is refused until the role is added.',
                          style: warningStyle),
                    const SizedBox(height: 12),
                    Text('Claude app: Customize → Connectors → Add custom connector',
                        style: Theme.of(context).textTheme.titleSmall),
                    SelectableText('URL: $shownUrl\nAuthentication: No sign in\nRequest header: Authorization = Bearer $token',
                        style: mono),
                    const SizedBox(height: 12),
                    Text('Claude Code', style: Theme.of(context).textTheme.titleSmall),
                    SelectableText(
                      'claude mcp add --transport http configurator $shownUrl --header "Authorization: Bearer $token"',
                      style: mono,
                    ),
                  ],
          ),
        ),
      ),
      actions: [
        if (issued == null && widget.hasKey)
          TextButton(onPressed: _busy ? null : _revoke, child: const Text('Revoke key')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(issued == null ? 'Cancel' : 'Close'),
        ),
        if (issued == null)
          FilledButton(
            onPressed: _busy ? null : _issue,
            child: Text(widget.hasKey ? 'Issue new key' : 'Create key'),
          ),
      ],
    );
  }
}
