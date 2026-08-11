import 'package:flutter/material.dart';

import '../../../core/http/api_client.dart';
import '../../../core/ui/top_notification.dart';
import '../data/calculator_repository.dart';
import 'calculator_message_dropdown.dart';

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
  late String _statusCode = widget.statusCode;

  @override
  void didUpdateWidget(covariant QuoteSubmitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusCode != widget.statusCode) _statusCode = widget.statusCode;
  }

  bool get _isResend => _statusCode.trim().toLowerCase() == 'sent';
  String get _operation => _isResend ? 'resend' : 'submit';
  String get _label => _isResend ? 'Resend email' : 'Submit';

  Future<void> _run() async {
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
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final canPress = widget.enabled && !_busy && widget.quoteId.trim().isNotEmpty;
    if (widget.prominent) {
      return SizedBox(
        width: 120,
        height: 36,
        child: FilledButton(
          onPressed: canPress ? _run : null,
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_label),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: canPress ? _run : null,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isResend ? Icons.forward_to_inbox_outlined : Icons.send_outlined, size: 18),
      label: Text(_label),
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
                value: batchLabel.isEmpty
                    ? 'No batch selected'
                    : '$batchLabel · ${preview.documentCount} template(s) · one merged PDF',
              ),
              _PreviewLine(label: 'Subject', value: preview.subject),
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
