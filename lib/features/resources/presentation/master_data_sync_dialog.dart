import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/http/api_client.dart';
import '../../../core/ui/top_notification.dart';

/// Run action of a master data endpoint (Integrations → Integration Endpoints, scope master_data).
class MasterDataSyncButton extends StatelessWidget {
  const MasterDataSyncButton({super.key, required this.endpointCode, required this.repository});

  final String endpointCode;
  final AdminResourceRepository repository;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => MasterDataSyncDialog(endpointCode: endpointCode, repository: repository),
      ),
      icon: const Icon(Icons.cloud_sync_outlined, size: 18),
      label: const Text('Run sync'),
    );
  }
}

/// Block selection, confirmation and progress of the master data sync job.
class MasterDataSyncDialog extends StatefulWidget {
  const MasterDataSyncDialog({super.key, required this.endpointCode, required this.repository});

  final String endpointCode;
  final AdminResourceRepository repository;

  @override
  State<MasterDataSyncDialog> createState() => _MasterDataSyncDialogState();
}

class _MasterDataSyncDialogState extends State<MasterDataSyncDialog> {
  Map<String, dynamic>? _status;
  Object? _error;
  final Set<String> _selected = {};
  bool _starting = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _blocks => (_status?['blocks'] as List? ?? const [])
      .whereType<Map>()
      .map((block) => Map<String, dynamic>.from(block))
      .toList();

  Map<String, dynamic> get _job =>
      _status?['job'] is Map ? Map<String, dynamic>.from(_status!['job'] as Map) : const <String, dynamic>{};

  bool get _active => const {'pending', 'running'}.contains(_job['status_code']);

  List<String> get _available =>
      _blocks.where((block) => block['enabled'] == true).map((block) => '${block['code']}').toList();

  String _message(Object error) => error is ApiException ? error.displayMessage : '$error';

  Future<void> _load({bool initial = false}) async {
    try {
      final status = await widget.repository.fetchMasterDataSync(widget.endpointCode);
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
        if (initial) _selected.addAll(_available);
      });
      _poll?.cancel();
      if (_active) _poll = Timer(const Duration(seconds: 2), _load);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _preset(Iterable<String> codes) => setState(() {
        _selected
          ..clear()
          ..addAll(codes.where(_available.contains));
      });

  Future<void> _run() async {
    final blocks = _available.where(_selected.contains).toList();
    final labels = _blocks
        .where((block) => blocks.contains(block['code']))
        .map((block) => '• ${block['label']} (${block['sheet']})')
        .join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start master data sync?'),
        content: Text(
          'Configurator data will be updated from "${_status?['endpoint_name'] ?? widget.endpointCode}":\n\n$labels\n\n'
          'Records that came from these sheets and are no longer there are deactivated or closed; '
          'changed price lists and the TDS grid get a new version from today.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Start')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _starting = true);
    try {
      final status = await widget.repository.runMasterDataSync(widget.endpointCode, blocks);
      if (!mounted) return;
      setState(() => _status = status);
      _poll?.cancel();
      _poll = Timer(const Duration(seconds: 2), _load);
    } catch (error) {
      if (!mounted) return;
      showTopNotification(context, 'Master data sync could not be started: ${_message(error)}',
          type: TopNotificationType.error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    return parsed == null ? '—' : DateFormat('dd.MM.yy HH:mm').format(parsed);
  }

  Widget _levelIcon(String level) => switch (level) {
        'error' => Icon(Icons.error, size: 18, color: Theme.of(context).colorScheme.error),
        'warning' => const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
        _ => const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
      };

  Widget _jobView() {
    final job = _job;
    if (job.isEmpty) return const Text('The sync has not been run yet.');
    final status = '${job['status_code']}';
    final events = (_status?['events'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_active)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              _levelIcon(status == 'failed' ? 'error' : 'info'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last run: $status · started ${_date(job['started_at'] ?? job['created_at'])}'
                '${job['finished_at'] == null ? '' : ' · finished ${_date(job['finished_at'])}'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final event in events) _eventView(event),
      ],
    );
  }

  Widget _eventView(Map<String, dynamic> event) {
    final payload = event['payload_json'] is Map
        ? Map<String, dynamic>.from(event['payload_json'] as Map)
        : const <String, dynamic>{};
    final warnings = (payload['warnings'] as List? ?? const []).map((warning) => '$warning').toList();
    final title = Text('${event['message'] ?? ''}', style: Theme.of(context).textTheme.bodySmall);
    if (warnings.isEmpty) {
      return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: _levelIcon('${event['level_code']}'), title: title);
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: _levelIcon('${event['level_code']}'),
      title: title,
      children: [
        for (final warning in warnings)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: SelectableText(warning, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final canRun = status != null && status['enabled'] == true && !_active && !_starting &&
        _available.any(_selected.contains);
    return AlertDialog(
      title: Text('Sync: ${status?['endpoint_name'] ?? widget.endpointCode}'),
      content: SizedBox(
        width: 680,
        child: status == null
            ? (_error == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : Text('Status could not be loaded: ${_message(_error!)}'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Source: Google Sheet ${status['spreadsheet_id'] ?? '—'}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (status['enabled'] != true)
                      Text('The integration endpoint is inactive.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _active ? null : () => _preset(const ['customers']),
                          child: const Text('Customers only'),
                        ),
                        OutlinedButton(onPressed: _active ? null : () => _preset(_available), child: const Text('All data')),
                      ],
                    ),
                    for (final block in _blocks)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(block['code']),
                        onChanged: block['enabled'] == true && !_active
                            ? (value) => setState(() => value == true
                                ? _selected.add('${block['code']}')
                                : _selected.remove('${block['code']}'))
                            : null,
                        title: Text('${block['label']}'),
                        subtitle: Text('Sheet: ${block['sheet'] ?? '—'}'),
                      ),
                    const Divider(),
                    _jobView(),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton.icon(
          onPressed: canRun ? _run : null,
          icon: const Icon(Icons.cloud_sync_outlined, size: 18),
          label: const Text('Run sync'),
        ),
      ],
    );
  }
}
