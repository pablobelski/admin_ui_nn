import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/job_updates.dart';
import '../navigation/admin_providers.dart';

class ActiveJobsIndicator extends ConsumerWidget {
  const ActiveJobsIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(jobUpdatesProvider);
    return StreamBuilder<JobUpdate>(
      stream: updates.changes,
      builder: (context, snapshot) => _content(context, updates),
    );
  }

  String _operation(Map<String, dynamic> job) {
    final code = '${job['current_operation'] ?? job['operation_code']}';
    final label = switch (code) {
      'quote_email' || 'quote_submit' || 'quote_resend' => 'Email / PDF',
      'create_reserve' => 'Reserve',
      'create_kommission' => 'Kommission / Google',
      'send_sevdesk' => 'Sevdesk',
      'print_pdf' => 'PDF',
      'generate_glb' => '3D',
      'integration_batch' => '${job['batch_name'] ?? 'Submit'}',
      _ => code,
    };
    return job['status_code'] == 'pending' ? '$label (queued)' : label;
  }

  Widget _content(BuildContext context, JobUpdates updates) {
    final jobs = updates.jobs;
    final stale = updates.stale;
    if (jobs.isEmpty) return const SizedBox.shrink();
    final groups = <String, Set<String>>{};
    for (final job in jobs) {
      groups.putIfAbsent('${job['quote_no']}', () => <String>{}).add(_operation(job));
    }
    final labels = groups.entries.map((entry) => '${entry.key} · ${entry.value.join(', ')}').toList();
    final compact = MediaQuery.sizeOf(context).width < 900;
    final summary = '${labels.first}${labels.length > 1 ? ' · +${labels.length - 1}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Tooltip(
        message: stale ? 'Task status could not be refreshed' : labels.join('\n'),
        child: MenuAnchor(
          menuChildren: [
            if (stale) const Padding(padding: EdgeInsets.all(12), child: Text('Task status could not be refreshed')),
            for (final job in jobs)
              SizedBox(width: 420, child: ListTile(
                dense: true,
                leading: Icon(job['status_code'] == 'pending' ? Icons.schedule : Icons.sync, size: 18),
                title: Text('${job['quote_no']} · ${_operation(job)}'),
                subtitle: Text('${job['message'] ?? job['batch_name'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
              )),
          ],
          builder: (context, controller, child) => OutlinedButton.icon(
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            icon: stale ? const Icon(Icons.sync_problem, size: 15) : const SizedBox(
              width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            label: compact ? Text('${jobs.length}') : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
        ),
      ),
    );
  }
}
