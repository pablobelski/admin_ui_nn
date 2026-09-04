import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/calculator_repository.dart';

final quoteIntegrationsRefreshTick = ValueNotifier<int>(0);

void notifyQuoteIntegrationsChanged() {
  quoteIntegrationsRefreshTick.value += 1;
}

class ReserveMaterialsView extends StatelessWidget {
  const ReserveMaterialsView({
    super.key,
    required this.items,
    this.warnings = const [],
  });

  final List<Map<String, dynamic>> items;
  final List<String> warnings;

  String _quantity(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return parsed == parsed.roundToDouble()
        ? parsed.toInt().toString()
        : parsed.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No reserve materials were generated.'),
        ),
      );
    }

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (warnings.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reserve warnings', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final warning in warnings) Text('• $warning'),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(
              children: [
                Text(
                  'Warehouse reserve',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} line(s)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                '${items[index]['Bezeichnung'] ?? ''}'.trim().isEmpty
                    ? '${items[index]['Artikel'] ?? 'Reserve line'}'
                    : '${items[index]['Bezeichnung']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Artikel ${items[index]['Artikel'] ?? '—'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${_quantity(items[index]['Anzahl'])} ${items[index]['Einheit'] ?? ''}'.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class QuoteIntegrationsTab extends StatefulWidget {
  const QuoteIntegrationsTab({
    super.key,
    required this.quoteId,
    required this.repository,
  });

  final String? quoteId;
  final CalculatorRepository repository;

  @override
  State<QuoteIntegrationsTab> createState() => _QuoteIntegrationsTabState();
}

class _QuoteIntegrationsTabState extends State<QuoteIntegrationsTab>
    with AutomaticKeepAliveClientMixin<QuoteIntegrationsTab> {
  Future<QuoteIntegrationOverview>? _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    quoteIntegrationsRefreshTick.addListener(_externalRefresh);
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant QuoteIntegrationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quoteId != widget.quoteId) _future = _fetch();
  }

  @override
  void dispose() {
    quoteIntegrationsRefreshTick.removeListener(_externalRefresh);
    super.dispose();
  }

  void _externalRefresh() {
    if (mounted) _reload();
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<QuoteIntegrationOverview>? _fetch() {
    final quoteId = widget.quoteId?.trim() ?? '';
    return quoteId.isEmpty
        ? null
        : widget.repository.fetchQuoteIntegrations(quoteId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_future == null) {
      return const Center(child: Text('Save the calculation to track integration jobs.'));
    }
    return FutureBuilder<QuoteIntegrationOverview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Integration state could not be loaded: ${snapshot.error}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final overview = snapshot.data!;
        return SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Connections & jobs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _reload,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (overview.connections.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.link_off_outlined),
                    title: Text('No connections configured'),
                  ),
                )
              else
                for (final connection in overview.connections)
                  _ConnectionExpansionCard(
                    connection: connection,
                    jobs: overview.jobs
                        .where(
                          (job) =>
                              job.endpointCode == '${connection['code'] ?? ''}',
                        )
                        .toList(growable: false),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionExpansionCard extends StatelessWidget {
  const _ConnectionExpansionCard({
    required this.connection,
    required this.jobs,
  });

  final Map<String, dynamic> connection;
  final List<QuoteIntegrationJob> jobs;

  IconData _jobStatusIcon(String status) => switch (status) {
        'succeeded' => Icons.check_circle,
        'failed' => Icons.error,
        'running' => Icons.sync,
        'pending' => Icons.schedule,
        'cancelled' => Icons.pause_circle,
        _ => Icons.help_outline,
      };

  Color _jobStatusColor(BuildContext context, String status, bool hasErrors) =>
      switch (status) {
        'succeeded' => Colors.green,
        'failed' => Theme.of(context).colorScheme.error,
        'running' => Colors.blue,
        'pending' => Colors.orange,
        'cancelled' => Colors.grey,
        _ => hasErrors ? Theme.of(context).colorScheme.error : Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    final active = connection['is_active'] == true;
    final configured = connection['configured'] == true;
    final ok = active && configured;
    final jobCount = connection['job_count'] is num
        ? (connection['job_count'] as num).toInt()
        : int.tryParse('${connection['job_count'] ?? ''}') ?? jobs.length;
    final hasJobErrors = connection['has_errors'] == true;
    final latestStatus = '${connection['latest_status_code'] ?? ''}'
        .trim()
        .toLowerCase();
    final provider = '${connection['provider_code'] ?? '—'}';
    final status = ok
        ? 'Ready'
        : !active
            ? 'Inactive'
            : 'Needs setup';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: jobCount == 0
            ? null
            : Icon(
                _jobStatusIcon(latestStatus),
                color: _jobStatusColor(context, latestStatus, hasJobErrors),
              ),
        title: Text(
          '${connection['name'] ?? connection['code'] ?? 'Integration'}',
        ),
        subtitle: Text(
          '$status · $provider · $jobCount job(s)'
          '${latestStatus.isEmpty ? '' : ' · latest: $latestStatus'}',
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Connection code: ${connection['code'] ?? '—'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          if (jobs.isEmpty)
            const ListTile(
              dense: true,
              leading: Icon(Icons.inbox_outlined),
              title: Text('No jobs for this connection yet'),
            )
          else
            for (final job in jobs) _IntegrationJobCard(job: job),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _IntegrationJobCard extends StatelessWidget {
  const _IntegrationJobCard({required this.job});

  final QuoteIntegrationJob job;

  IconData get _icon => switch (job.statusCode) {
        'succeeded' => Icons.check_circle,
        'failed' => Icons.error,
        'running' => Icons.sync,
        'pending' => Icons.schedule,
        'cancelled' => Icons.pause_circle,
        _ => Icons.help_outline,
      };

  Color _color(BuildContext context) => switch (job.statusCode) {
        'succeeded' => Colors.green,
        'failed' => Theme.of(context).colorScheme.error,
        'running' => Colors.blue,
        'pending' => Colors.orange,
        'cancelled' => Colors.grey,
        _ => Colors.grey,
      };

  String get _label => switch (job.operationCode) {
        'create_reserve' => 'Create Reserve',
        'create_kommission' => 'Create Kommission',
        'send_sevdesk' => 'Send to Sevdesk',
        'generate_glb' => 'Generate GLB',
        'quote_submit' => 'Send to customer',
        'quote_resend' => 'Resend customer email',
        _ => job.operationCode,
      };

  String _date(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    return parsed == null ? value : DateFormat('dd.MM.yy HH:mm').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final serverResponse = job.serverResponse ??
        job.errorText ??
        job.latestMessage ??
        'No server response recorded';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ListTile(
        leading: Icon(_icon, color: _color(context)),
        title: Row(
          children: [
            Expanded(child: Text(_label)),
            Text(job.statusCode, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        subtitle: Text(
          'Server: $serverResponse\n${_date(job.createdAt)} · attempts ${job.attemptCount}'
          '\nJob: ${job.id}',
        ),
      ),
    );
  }
}
