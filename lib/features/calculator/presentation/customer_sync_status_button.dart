import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/top_notification.dart';
import 'calculator_providers.dart';

/// Latest customer sync status (server JSON) of the organization selected on the
/// Product step. Kept outside the step widget so a sync started on "Next" is
/// still followed after the Product step is left.
class CustomerSyncNotifier extends Notifier<Map<String, dynamic>?> {
  String? _organizationId;
  Timer? _poll;

  @override
  Map<String, dynamic>? build() {
    ref.onDispose(() => _poll?.cancel());
    return null;
  }

  void watch(String? organizationId) {
    final id = organizationId?.trim() ?? '';
    // A running job is already followed by polling.
    if (!_track(id) && _isActive(state)) return;
    if (id.isNotEmpty) unawaited(_refresh());
  }

  /// Returns true when the followed organization changed.
  bool _track(String id) {
    if (id == (_organizationId ?? '')) return false;
    _organizationId = id.isEmpty ? null : id;
    _poll?.cancel();
    state = null;
    return true;
  }

  Future<void> runManual() async {
    final id = _organizationId;
    if (id == null) return;
    _apply(id, await ref.read(calculatorRepositoryProvider).runCustomerSync(id));
  }

  /// Calculator step navigation hook; the server rules decide what starts.
  void leaveStep(String step, {String? templateId, String? organizationId}) {
    unawaited(() async {
      try {
        final response = await ref.read(calculatorRepositoryProvider).runStepIntegrations(
              step: step,
              templateId: templateId,
              organizationId: organizationId,
            );
        for (final result in (response['results'] as List? ?? const []).whereType<Map>()) {
          final status = result['status'];
          if (result['operation_code'] == 'sync_customer' && status is Map && organizationId != null) {
            _track(organizationId);
            _apply(organizationId, Map<String, dynamic>.from(status));
          }
        }
      } catch (_) {
        // Background integrations never block step navigation.
      }
    }());
  }

  Future<void> _refresh() async {
    final id = _organizationId;
    if (id == null) return;
    try {
      _apply(id, await ref.read(calculatorRepositoryProvider).fetchCustomerSyncStatus(id));
    } catch (_) {
      if (id == _organizationId && _isActive(state)) {
        _poll = Timer(const Duration(seconds: 5), () => unawaited(_refresh()));
      }
    }
  }

  void _apply(String organizationId, Map<String, dynamic> next) {
    if (organizationId != _organizationId) return;
    final previous = state;
    state = next;
    _poll?.cancel();
    if (_isActive(next)) {
      _poll = Timer(const Duration(seconds: 2), () => unawaited(_refresh()));
    } else if (_isActive(previous) &&
        _job(previous)['id'] == _job(next)['id'] &&
        _job(next)['status_code'] == 'succeeded') {
      // Updated discounts, prices and contacts become visible to the calculation.
      ref.invalidate(calculatorContextProvider);
    }
  }
}

Map<String, dynamic> _job(Map<String, dynamic>? status) =>
    status?['job'] is Map ? Map<String, dynamic>.from(status!['job'] as Map) : const <String, dynamic>{};

bool _isActive(Map<String, dynamic>? status) =>
    const {'pending', 'running'}.contains(_job(status)['status_code']);

final customerSyncProvider = NotifierProvider<CustomerSyncNotifier, Map<String, dynamic>?>(
  CustomerSyncNotifier.new,
);

/// Status icon of the customer sync, shown right of the organization plaque.
/// Same icons/colors as the Integrations tab; a tap starts a manual sync.
class CustomerSyncStatusButton extends ConsumerStatefulWidget {
  const CustomerSyncStatusButton({super.key, required this.organizationId});

  final String? organizationId;

  @override
  ConsumerState<CustomerSyncStatusButton> createState() => _CustomerSyncStatusButtonState();
}

class _CustomerSyncStatusButtonState extends ConsumerState<CustomerSyncStatusButton> {
  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(covariant CustomerSyncStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) _watch();
  }

  // Providers must not be modified while the widget tree is building.
  void _watch() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(customerSyncProvider.notifier).watch(widget.organizationId);
      });

  Future<void> _run() async {
    try {
      await ref.read(customerSyncProvider.notifier).runManual();
    } catch (error) {
      if (!mounted) return;
      showTopNotification(context, 'Customer sync could not be started: $error', type: TopNotificationType.error);
    }
  }

  IconData _icon(String status) => switch (status) {
        'succeeded' => Icons.check_circle,
        'failed' => Icons.error,
        'running' => Icons.sync,
        'pending' => Icons.schedule,
        'cancelled' => Icons.pause_circle,
        _ => Icons.cloud_sync_outlined,
      };

  Color _color(BuildContext context, String status) => switch (status) {
        'succeeded' => Colors.green,
        'failed' => Theme.of(context).colorScheme.error,
        'running' => Colors.blue,
        'pending' => Colors.orange,
        _ => Colors.grey,
      };

  String _date(Object? value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    return parsed == null ? '—' : DateFormat('dd.MM.yy HH:mm').format(parsed);
  }

  String _tooltip(Map<String, dynamic> job, String status, bool canRun) {
    final message = switch (status) {
      'succeeded' => '${job['message'] ?? 'Customer data synced.'}\n'
          'Synced ${_date(job['finished_at'])} (${job['trigger'] ?? '—'}).',
      'failed' => 'Customer sync failed: ${job['error_text'] ?? job['message'] ?? 'unknown error'}',
      'running' => 'Customer data is being synced from VD-Buchaltung…',
      'pending' => 'Customer sync is queued.',
      _ => 'Customer data (discounts, special prices, contacts, delivery address) '
          'has not been synced from VD-Buchaltung yet.',
    };
    return canRun ? '$message\nClick to sync now.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(customerSyncProvider);
    if (syncStatus == null ||
        syncStatus['enabled'] != true ||
        syncStatus['organization_id'] != widget.organizationId?.trim()) {
      return const SizedBox.shrink();
    }
    final job = _job(syncStatus);
    final status = '${job['status_code'] ?? ''}';
    final canRun = syncStatus['manual_enabled'] == true && !_isActive(syncStatus);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: _tooltip(job, status, canRun),
        child: DecoratedBox(
          decoration: ShapeDecoration(shape: shape),
          child: InkWell(
            onTap: canRun ? _run : null,
            customBorder: shape,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: SizedBox(
              width: 48,
              child: Center(child: Icon(_icon(status), color: _color(context, status))),
            ),
          ),
        ),
      ),
    );
  }
}
