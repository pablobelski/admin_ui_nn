import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/http/api_client.dart';
import '../../../core/ui/top_notification.dart';
import '../data/calculator_repository.dart';
import 'calculator_message_dropdown.dart';
import 'quote_integrations_panel.dart';

class QuoteSubmitButton extends StatefulWidget {
  const QuoteSubmitButton({
    super.key,
    required this.quoteId,
    required this.statusCode,
    required this.repository,
    this.enabled = true,
    this.prominent = false,
    this.onCompleted,
  });

  final String quoteId;
  final String statusCode;
  final CalculatorRepository repository;
  final bool enabled;
  final bool prominent;
  final Future<void> Function(QuoteSubmitResult result)? onCompleted;

  @override
  State<QuoteSubmitButton> createState() => _QuoteSubmitButtonState();
}

class _QuoteSubmitButtonState extends State<QuoteSubmitButton> {
  bool _busy = false;
  bool _createKommissionAvailable = false;
  QuoteIntegrationOverview? _overview;
  int _availabilityRequest = 0;
  late String _statusCode = widget.statusCode;

  @override
  void initState() {
    super.initState();
    quoteIntegrationsRefreshTick.addListener(_handleIntegrationsChanged);
    _refreshIntegrationAvailability();
  }

  @override
  void didUpdateWidget(covariant QuoteSubmitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusCode != widget.statusCode) _statusCode = widget.statusCode;
    if (oldWidget.quoteId != widget.quoteId || oldWidget.enabled != widget.enabled || oldWidget.statusCode != widget.statusCode) {
      _refreshIntegrationAvailability();
    }
  }

  @override
  void dispose() {
    quoteIntegrationsRefreshTick.removeListener(_handleIntegrationsChanged);
    super.dispose();
  }

  void _handleIntegrationsChanged() {
    _refreshIntegrationAvailability();
  }

  Future<void> _refreshIntegrationAvailability() async {
    final request = ++_availabilityRequest;
    final quoteId = widget.quoteId.trim();
    if (!widget.enabled || quoteId.isEmpty) {
      if (mounted && (_createKommissionAvailable || _overview != null)) {
        setState(() { _createKommissionAvailable = false; _overview = null; });
      }
      return;
    }
    try {
      final overview = await widget.repository.fetchQuoteIntegrations(quoteId);
      if (!mounted || request != _availabilityRequest || quoteId != widget.quoteId.trim()) return;
      setState(() {
        _createKommissionAvailable = overview.commissionCanCreate;
        _overview = overview;
      });
    } catch (_) {
      if (!mounted || request != _availabilityRequest || quoteId != widget.quoteId.trim()) return;
      if (_createKommissionAvailable || _overview != null) {
        setState(() { _createKommissionAvailable = false; _overview = null; });
      }
    }
  }

  bool get _isResend => _statusCode.trim().toLowerCase() == 'sent';
  String get _operation => _isResend ? 'resend' : 'submit';
  String get _emailLabel => _isResend ? 'Resend customer email' : 'Send to customer';

  Future<void> _watchSubmitJob(QuoteSubmitResult queuedResult) async {
    try {
      final job = await widget.repository.waitForBackgroundJob(
        widget.quoteId,
        queuedResult.jobId,
        timeout: const Duration(minutes: 30),
        shouldContinue: () => mounted,
      );
      if (job == null) return;
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      if (job.statusCode != 'succeeded') {
        final errorText = job.errorText?.trim();
        showTopNotification(
          context,
          errorText != null && errorText.isNotEmpty
              ? '${queuedResult.operation == 'resend' ? 'Resend' : 'Submit'} failed: $errorText'
              : '${queuedResult.operation == 'resend' ? 'Resend' : 'Submit'} ${job.statusCode}.',
          type: TopNotificationType.error,
        );
        return;
      }

      final status = await widget.repository.fetchQuoteStatusTransitions(widget.quoteId);
      if (!mounted) return;
      setState(() => _statusCode = status.statusCode);
      await widget.onCompleted?.call(QuoteSubmitResult(
        ok: true,
        operation: queuedResult.operation,
        quoteId: queuedResult.quoteId,
        quoteNo: queuedResult.quoteNo,
        statusCode: status.statusCode,
        customerDeliveryEnabled: queuedResult.customerDeliveryEnabled,
        queued: false,
        jobId: queuedResult.jobId,
        jobStatusCode: 'succeeded',
      ));
      if (!mounted) return;
      showTopNotification(
        context,
        queuedResult.operation == 'resend'
            ? 'Quote email resent successfully.'
            : queuedResult.customerDeliveryEnabled
                ? 'Quote submitted and sent to the customer.'
                : 'Quote submitted and sent internally only.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        '${queuedResult.operation == 'resend' ? 'Resend' : 'Submit'} background status failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  Future<void> _watchIntegrationJob(String label, String jobId) async {
    if (jobId.isEmpty) return;
    try {
      final job = await widget.repository.waitForBackgroundJob(
        widget.quoteId,
        jobId,
        timeout: const Duration(minutes: 30),
        shouldContinue: () => mounted,
      );
      if (job == null) return;
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      if (job.statusCode == 'succeeded') {
        showTopNotification(
          context,
          '$label completed successfully.',
          type: TopNotificationType.success,
        );
        return;
      }
      final errorText = job.errorText?.trim();
      showTopNotification(
        context,
        errorText != null && errorText.isNotEmpty
            ? '$label failed: $errorText'
            : '$label ${job.statusCode}.',
        type: TopNotificationType.error,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        '$label background status failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  Future<void> _sendToCustomer() async {
    if (_busy || widget.quoteId.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final preview = await widget.repository.fetchQuoteSubmitPreview(
        widget.quoteId,
        operation: _operation,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _QuoteSubmitPreviewDialog(preview: preview),
      );
      if (confirmed != true) return;

      final result = await widget.repository.submitQuoteEmail(
        widget.quoteId,
        operation: _operation,
      );
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      if (result.queued) {
        showTopNotification(
          context,
          result.operation == 'resend'
              ? 'Quote email resend queued and continues in background.'
              : 'Quote submit queued and continues in background.',
          type: TopNotificationType.success,
        );
        unawaited(_watchSubmitJob(result));
        return;
      }
      setState(() => _statusCode = result.statusCode);
      await widget.onCompleted?.call(result);
      if (!mounted) return;
      showTopNotification(
        context,
        result.operation == 'resend'
            ? 'Quote email resent successfully.'
            : result.customerDeliveryEnabled
                ? 'Quote submitted and sent to the customer.'
                : 'Quote submitted and sent internally only.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      final message = error is ApiException ? error.displayMessage : '$error';
      showTopNotification(
        context,
        '${_isResend ? 'Resend' : 'Submit'} failed: $message',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runIntegration(String operation) async {
    if (_busy || widget.quoteId.trim().isEmpty) return;
    final label = switch (operation) {
      'create_reserve' => 'Create Reserve',
      'create_kommission' => 'Create Kommission',
      'send_sevdesk' => 'Send to Sevdesk',
      _ => operation,
    };
    setState(() => _busy = true);
    try {
      final overview = await widget.repository.fetchQuoteIntegrations(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _createKommissionAvailable = overview.commissionCanCreate;
        _overview = overview;
      });
      if (operation == 'create_reserve' && !overview.reserveComplete) {
        final details = overview.reserveWarnings.isEmpty
            ? 'The material requirement is incomplete.'
            : overview.reserveWarnings.join('\n');
        showTopNotification(
          context,
          'Create Reserve is blocked: $details',
          type: TopNotificationType.error,
        );
        return;
      }
      if (operation == 'create_kommission' && !overview.commissionCanCreate) {
        showTopNotification(
          context,
          'Create Kommission is blocked: generate_pdf is disabled and no PDF exists in Media Library for this quote.',
          type: TopNotificationType.error,
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _IntegrationConfirmationDialog(
          title: label,
          message: operation == 'send_sevdesk'
              ? 'Send this quote payload to the configured Firebase database?'
              : operation == 'create_reserve'
                  ? 'Create and send the warehouse reserve for this quote?'
                  : 'Create the TDS Glas commission row in Test_VD-Buchaltung 2026 / UNT-Kommission?',
          payload: overview.payloadFor(operation),
        ),
      );
      if (confirmed != true || !mounted) return;

      final result = await widget.repository.runQuoteIntegration(widget.quoteId, operation);
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      showTopNotification(
        context,
        result.queued
            ? result.alreadyQueued
                ? '$label is already queued or running.'
                : '$label queued and continues in background.'
            : result.reused
                ? '$label was already completed for this data version.'
                : '$label completed successfully.',
        type: TopNotificationType.success,
      );
      if (result.queued) {
        unawaited(_watchIntegrationJob(label, result.jobId));
      }
    } catch (error) {
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      final message = error is ApiException ? error.displayMessage : '$error';
      showTopNotification(
        context,
        '$label failed: $message',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBatch([String? batchId]) async {
    if (_busy || widget.quoteId.trim().isEmpty) return;
    final quoteId = widget.quoteId;
    setState(() => _busy = true);
    try {
      final preview = await widget.repository.previewIntegrationBatch(quoteId, batchId: batchId);
      if (!mounted || quoteId != widget.quoteId) return;
      final batch = Map<String, dynamic>.from(preview['batch'] as Map);
      final quote = Map<String, dynamic>.from(preview['quote'] as Map);
      final steps = (batch['items'] as List? ?? const []).whereType<Map>().toList();
      final errors = (preview['errors'] as List? ?? const []).map((item) => '$item').toList();
      final warnings = (preview['warnings'] as List? ?? const []).map((item) => '$item').toList();
      final email = preview['email'] is Map ? Map<String, dynamic>.from(preview['email'] as Map) : <String, dynamic>{};
      final recipients = email['recipients'] is Map ? email['recipients'] as Map : const {};
      final documents = email['document_batch'] is Map ? email['document_batch'] as Map : const {};
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Submit · ${batch['name']}'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quote: ${quote['quote_no']}'),
            const SizedBox(height: 12),
            for (var index = 0; index < steps.length; index++)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${index + 1}. ${steps[index]['label']}')),
            if (email.isNotEmpty) ...[
              const Divider(),
              for (final group in ['to', 'cc', 'bcc'])
                if ((recipients[group] as List? ?? const []).isNotEmpty)
                  Text('${group.toUpperCase()}: ${(recipients[group] as List).join(', ')}'),
              Text('Documents: ${documents['name'] ?? '—'}'),
            ],
            const SizedBox(height: 12),
            const Text('The operations run in order in the background. Errors are recorded and the remaining operations continue. Successful operations are not rolled back.'),
            for (final warning in warnings) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(warning, style: const TextStyle(color: Colors.orange))),
            for (final error in errors) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: preview['can_submit'] == true ? () => Navigator.of(dialogContext).pop(true) : null,
            child: const Text('Submit')),
        ],
      ));
      if (confirmed != true || !mounted || quoteId != widget.quoteId) return;
      final result = await widget.repository.submitIntegrationBatch(quoteId, '${batch['id']}', '${preview['batch_version']}');
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      showTopNotification(context, result.alreadyQueued ? 'Integration batch is already queued or running.' : '${batch['name']} queued and continues in background.', type: TopNotificationType.success);
      unawaited(_watchBatch(quoteId, '${quote['quote_no']}', result.jobId, '${batch['name']}'));
    } catch (error) {
      if (mounted) showTopNotification(context, 'Submit failed: ${error is ApiException ? error.displayMessage : error}', type: TopNotificationType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _watchBatch(String quoteId, String quoteNo, String jobId, String name) async {
    try {
      final job = await widget.repository.waitForBackgroundJob(quoteId, jobId,
        timeout: const Duration(minutes: 30), shouldContinue: () => mounted && widget.quoteId == quoteId);
      if (job == null || !mounted || widget.quoteId != quoteId) return;
      notifyQuoteIntegrationsChanged();
      final status = await widget.repository.fetchQuoteStatusTransitions(quoteId);
      if (!mounted || widget.quoteId != quoteId) return;
      setState(() => _statusCode = status.statusCode);
      await widget.onCompleted?.call(QuoteSubmitResult(ok: job.statusCode == 'succeeded', operation: 'batch',
        quoteId: quoteId, quoteNo: quoteNo, statusCode: status.statusCode, customerDeliveryEnabled: false,
        queued: false, jobId: jobId, jobStatusCode: job.statusCode));
      if (!mounted) return;
      showTopNotification(context, job.statusCode == 'succeeded' ? '$name completed.' : '$name ${job.batchOutcome == 'completed_with_errors' ? 'completed with errors' : 'failed'}: ${job.errorText ?? job.statusCode}',
        type: job.statusCode == 'succeeded' ? TopNotificationType.success : TopNotificationType.error);
    } catch (error) {
      if (mounted) showTopNotification(context, 'Batch status failed: $error', type: TopNotificationType.error);
    }
  }

  List<Widget> _menuItems(bool canPress) => [
    if ((_overview?.batches ?? const []).isEmpty)
      const MenuItemButton(child: Text('No integration batches available')),
    for (final batch in _overview?.batches ?? <Map<String, dynamic>>[])
      MenuItemButton(
        onPressed: canPress && batch['available'] == true ? () => _runBatch('${batch['id']}') : null,
        leadingIcon: const Icon(Icons.playlist_play),
        child: Text('${batch['name']}${batch['is_default'] == true ? ' (default)' : ''}'),
      ),
    if ((_overview?.batches ?? const []).isNotEmpty) const Divider(),
    if (_overview?.allowedOperations.contains('quote_email') == true)
      MenuItemButton(onPressed: canPress ? _sendToCustomer : null,
        leadingIcon: const Icon(Icons.send_outlined), child: Text(_emailLabel)),
    for (final operation in _overview?.allowedOperations ?? <String>[])
      if (operation != 'quote_email') MenuItemButton(
        onPressed: canPress && (operation != 'create_kommission' || _createKommissionAvailable) ? () => _runIntegration(operation) : null,
        leadingIcon: const Icon(Icons.play_arrow_outlined),
        child: Text(switch (operation) {
          'create_reserve' => 'Create Reserve', 'create_kommission' => 'Create Kommission',
          'send_sevdesk' => 'Send to Sevdesk', 'print_pdf' => 'Generate PDF', 'generate_glb' => 'Generate 3D', _ => operation,
        }),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final canPress = widget.enabled && !_busy && widget.quoteId.trim().isNotEmpty;
    return MenuAnchor(
      menuChildren: _menuItems(canPress),
      builder: (context, controller, child) => SizedBox(
        width: widget.prominent ? 136 : null,
        height: widget.prominent ? 36 : null,
        child: FilledButton.icon(
          onPressed: canPress
              ? () async {
                  await _refreshIntegrationAvailability();
                  if (!mounted) return;
                  if (_overview?.canManageActions == true) {
                    controller.open();
                  } else {
                    await _runBatch();
                  }
                }
              : null,
          style: widget.prominent
              ? FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                )
              : null,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_overview?.canManageActions == true ? Icons.arrow_drop_down : Icons.send_outlined, size: 18),
          label: const Text('Submit'),
        ),
      ),
    );
  }
}

class _IntegrationConfirmationDialog extends StatelessWidget {
  const _IntegrationConfirmationDialog({
    required this.title,
    required this.message,
    required this.payload,
  });

  final String title;
  final String message;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final payloadText = const JsonEncoder.withIndent('  ').convert(payload);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: const Icon(Icons.data_object_outlined),
                  title: const Text('Show payload'),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: payloadText));
                          if (!context.mounted) return;
                          showTopNotification(
                            context,
                            'Payload copied.',
                            type: TopNotificationType.success,
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy'),
                      ),
                    ),
                    TextFormField(
                      initialValue: payloadText,
                      readOnly: true,
                      minLines: 8,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _QuoteSubmitPreviewDialog extends StatelessWidget {
  const _QuoteSubmitPreviewDialog({required this.preview});

  final QuoteSubmitPreview preview;

  String _emails(List<String> values) => values.isEmpty ? '—' : values.join(', ');

  @override
  Widget build(BuildContext context) {
    final isResend = preview.operation == 'resend';
    final batchLabel = [
      preview.documentBatchName,
      if ((preview.documentBatchCode ?? '').isNotEmpty) '(${preview.documentBatchCode})',
    ].whereType<String>().where((entry) => entry.isNotEmpty).join(' ');
    final warningGroups = _submitWarningGroups(preview.warnings);
    final recipientTemplateLabel = [
      if ((preview.recipientTemplateLabels['to'] ?? '').isNotEmpty)
        "To: ${preview.recipientTemplateLabels['to']}",
      if ((preview.recipientTemplateLabels['cc'] ?? '').isNotEmpty)
        "CC: ${preview.recipientTemplateLabels['cc']}",
      if ((preview.recipientTemplateLabels['bcc'] ?? '').isNotEmpty)
        "BCC: ${preview.recipientTemplateLabels['bcc']}",
    ].join(' · ');
    final emailTemplateLabel = [
      if ((preview.emailTemplateLabels['to'] ?? '').isNotEmpty)
        "To: ${preview.emailTemplateLabels['to']}",
      if ((preview.emailTemplateLabels['cc'] ?? '').isNotEmpty)
        "CC: ${preview.emailTemplateLabels['cc']}",
      if ((preview.emailTemplateLabels['bcc'] ?? '').isNotEmpty)
        "BCC: ${preview.emailTemplateLabels['bcc']}",
    ].join(' · ');
    final subjectValues = [
      preview.emailSubjects['to'] ?? '',
      preview.emailSubjects['cc'] ?? '',
      preview.emailSubjects['bcc'] ?? '',
    ].where((entry) => entry.isNotEmpty).toSet();
    final subjectLabel = subjectValues.length <= 1
        ? preview.subject
        : [
            if ((preview.emailSubjects['to'] ?? '').isNotEmpty)
              "To: ${preview.emailSubjects['to']}",
            if ((preview.emailSubjects['cc'] ?? '').isNotEmpty)
              "CC: ${preview.emailSubjects['cc']}",
            if ((preview.emailSubjects['bcc'] ?? '').isNotEmpty)
              "BCC: ${preview.emailSubjects['bcc']}",
          ].join(' · ');

    return AlertDialog(
      title: Text(isResend ? 'Resend quote email' : 'Submit quote'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewLine(label: 'Quote', value: '${preview.quoteNo} · ${preview.statusCode} → ${preview.targetStatus}'),
              _PreviewLine(label: 'Customer', value: preview.customerOrganizationName.isEmpty ? '—' : preview.customerOrganizationName),
              if ((preview.customerContactName ?? '').isNotEmpty)
                _PreviewLine(label: 'Contact', value: preview.customerContactName!),
              _PreviewLine(
                label: 'Customer delivery',
                value: preview.customerDeliveryEnabled
                    ? 'Enabled for status ${preview.targetStatus}'
                    : 'Disabled for status ${preview.targetStatus} · internal recipients only',
              ),
              _PreviewLine(label: 'To', value: _emails(preview.to)),
              _PreviewLine(label: 'CC', value: _emails(preview.cc)),
              _PreviewLine(label: 'BCC', value: _emails(preview.bcc)),
              _PreviewLine(
                label: 'From',
                value: [preview.senderName, preview.senderAddress].where((entry) => entry.isNotEmpty).join(' · '),
              ),
              _PreviewLine(
                label: 'Documents',
                value: preview.attachmentMode == 'recipient_templates'
                    ? (recipientTemplateLabel.isEmpty
                        ? 'Separate PDF template per recipient group'
                        : recipientTemplateLabel)
                    : batchLabel.isEmpty
                        ? 'No batch selected'
                        : preview.attachmentMode == 'batch_split'
                            ? '$batchLabel · ${preview.documentCount} item(s) · separate PDFs'
                            : '$batchLabel · ${preview.documentCount} item(s) · one merged PDF',
              ),
              _PreviewLine(label: 'Email templates', value: emailTemplateLabel),
              _PreviewLine(label: 'Subject', value: subjectLabel),
              if (preview.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: CalculatorMessagesDropdown(
                    groups: warningGroups,
                    width: 120,
                  ),
                ),
              ],
              if (preview.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Submit blocked', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final error in preview.errors)
                  _IssueLine(issue: error, error: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: preview.canSubmit ? () => Navigator.of(context).pop(true) : null,
          icon: Icon(isResend ? Icons.forward_to_inbox_outlined : Icons.send_outlined),
          label: Text(isResend ? 'Resend email' : 'Submit'),
        ),
      ],
    );
  }
}

List<CalculatorMessageGroup> _submitWarningGroups(
  List<QuoteSubmitIssue> warnings,
) {
  final grouped = <String, List<String>>{};
  for (final warning in warnings) {
    final label = _submitIssueGroupLabel(warning);
    grouped.putIfAbsent(label, () => <String>[]).add(warning.message);
  }
  return [
    for (final entry in grouped.entries)
      CalculatorMessageGroup(
        label: entry.key,
        messages: entry.value,
      ),
  ];
}

String _submitIssueGroupLabel(QuoteSubmitIssue issue) {
  final field = issue.field?.trim().toLowerCase() ?? '';
  final code = issue.code.trim().toLowerCase();
  if (field.startsWith('customer.')) return 'Customer';
  if (field.startsWith('actor.')) return 'User';
  if (field.startsWith('quote.')) return 'Quote';
  if (field.startsWith('result.') || code.startsWith('calculation_')) {
    return 'Calculation';
  }
  if (field.startsWith('configurator_template.')) return 'Configurator template';
  if (field.startsWith('document_batches.')) return 'Documents';
  if (field.startsWith('integration_endpoint.')) return 'Email integration';
  if (field.startsWith('email_template.')) return 'Recipients';
  if (field.startsWith('internal_recipient')) return 'Recipients';
  return 'Calculation';
}


class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.issue, required this.error});

  final QuoteSubmitIssue issue;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? Theme.of(context).colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline : Icons.warning_amber_rounded, size: 17, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(issue.message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
