import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/media_file_actions.dart';
import '../../../core/ui/top_notification.dart';
import '../data/calculator_repository.dart';
import 'quote_integrations_panel.dart';

class QuoteDocumentsButton extends StatelessWidget {
  const QuoteDocumentsButton({
    super.key,
    required this.quoteId,
    required this.repository,
    this.enabled = true,
    this.filled = true,
  });

  final String quoteId;
  final CalculatorRepository repository;
  final bool enabled;
  final bool filled;

  Future<void> _showDocuments(BuildContext context) async {
    if (!enabled) return;
    await showDialog<void>(
      context: context,
      builder: (_) => QuoteDocumentsOptionsDialog(
        quoteId: quoteId,
        repository: repository,
        // The button outlives the dialog, so the background print job can still
        // report its completion after the user closed the Documents dialog.
        onBackgroundNotification: (message, type) {
          if (!context.mounted) return;
          showTopNotification(context, message, type: type);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return filled
        ? FilledButton.icon(
            onPressed: enabled ? () => _showDocuments(context) : null,
            icon: const Icon(Icons.description_outlined),
            label: const Text('documents'),
          )
        : OutlinedButton.icon(
            onPressed: enabled ? () => _showDocuments(context) : null,
            icon: const Icon(Icons.description_outlined),
            label: const Text('documents'),
          );
  }
}

class QuoteDocumentsOptionsDialog extends StatefulWidget {
  const QuoteDocumentsOptionsDialog({
    super.key,
    required this.quoteId,
    required this.repository,
    this.onBackgroundNotification,
  });

  final String quoteId;
  final CalculatorRepository repository;
  final void Function(String message, TopNotificationType type)?
      onBackgroundNotification;

  @override
  State<QuoteDocumentsOptionsDialog> createState() => _QuoteDocumentsOptionsDialogState();
}

class _QuoteDocumentsOptionsDialogState extends State<QuoteDocumentsOptionsDialog> {
  late final Future<PrintDialogData> _dataFuture;
  final Set<String> _selectedTemplateIds = <String>{};
  final ScrollController _documentsScrollController = ScrollController();
  final FocusNode _printFocusNode = FocusNode();
  List<GeneratedDocument> _documents = const [];
  String? _selectedBatchId;
  bool _initialized = false;
  bool _isPrinting = false;
  bool _splitOutput = false;
  bool _includeGeometryPreview = false;
  bool _includeGeometryWarnings = true;
  bool _showPayloadPreview = false;
  String? _statusText;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.repository.fetchPrintDialogData(widget.quoteId);
    _dataFuture.then(
      (data) {
        if (!mounted) return;
        setState(() => _initialize(data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_hasPrintSelection || _isPrinting) return;
          _printFocusNode.requestFocus();
        });
      },
      onError: (Object _, StackTrace __) {},
    );
  }

  @override
  void dispose() {
    _documentsScrollController.dispose();
    _printFocusNode.dispose();
    super.dispose();
  }

  void _initialize(PrintDialogData data) {
    if (_initialized) return;
    _initialized = true;
    _documents = data.recentDocuments;

    DocumentBatchOption? batch = data.defaultBatch;
    if (batch == null || !batch.compatible || batch.items.isEmpty) {
      batch = null;
      for (final candidate in data.batches) {
        if (candidate.compatible && candidate.items.isNotEmpty) {
          batch = candidate;
          break;
        }
      }
    }

    if (batch != null) {
      _selectedBatchId = batch.id;
      _splitOutput = batch.splitOutput;
      _selectedTemplateIds.addAll(batch.documentTemplateIds);
      _includeGeometryPreview = batch.hasGeometryPreview && data.geometryPreviewSettings.pdfEnabled;
      _includeGeometryWarnings = data.geometryPreviewSettings.includeWarnings;
    } else if (data.templates.isNotEmpty) {
      _selectedTemplateIds.add(data.templates.first.id);
      _includeGeometryWarnings = data.geometryPreviewSettings.includeWarnings;
    }
  }

  bool get _hasPrintSelection => _selectedTemplateIds.isNotEmpty || _includeGeometryPreview;

  DocumentBatchOption? _batchById(PrintDialogData data, String? id) {
    for (final batch in data.batches) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  bool _sameIds(Iterable<String> first, Iterable<String> second) {
    final a = first.toSet();
    final b = second.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  // Not bound to the dialog lifetime: the job keeps running in background and
  // must report its result even when the user already closed this dialog.
  Future<void> _watchPrintJob(String jobId) async {
    try {
      final job = await widget.repository.waitForBackgroundJob(
        widget.quoteId,
        jobId,
        timeout: const Duration(minutes: 30),
      );
      if (job == null) return;
      notifyQuoteIntegrationsChanged();
      if (job.statusCode != 'succeeded') {
        final message = job.errorText?.trim().isNotEmpty == true
            ? 'Document generation failed: ${job.errorText!.trim()}'
            : 'Document generation ${job.statusCode}.';
        widget.onBackgroundNotification?.call(message, TopNotificationType.error);
        if (!mounted) return;
        setState(() {
          _statusText = null;
          _errorText = message;
        });
        return;
      }

      widget.onBackgroundNotification?.call(
        'Document generation completed. The generated PDF is available in Documents.',
        TopNotificationType.success,
      );
      if (!mounted) return;
      final refreshed = await widget.repository.fetchPrintDialogData(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _documents = refreshed.recentDocuments;
        _statusText = 'Document generation completed. The generated PDF is available below.';
        _errorText = null;
      });
    } catch (error) {
      widget.onBackgroundNotification?.call(
        'Document generation background status failed: $error',
        TopNotificationType.error,
      );
      if (!mounted) return;
      setState(() {
        _statusText = null;
        _errorText = '$error';
      });
    }
  }

  Future<void> _print(PrintDialogData data) async {
    if (!_hasPrintSelection || _isPrinting) return;

    setState(() {
      _isPrinting = true;
      _statusText = 'Queueing document generation…';
      _errorText = null;
    });

    try {
      final selectedBatch = _batchById(data, _selectedBatchId);
      final geometryPreviewOnly = selectedBatch != null
          && selectedBatch.compatible
          && selectedBatch.hasGeometryPreview
          && _selectedTemplateIds.isEmpty
          && _includeGeometryPreview;
      final useExactBatch = !geometryPreviewOnly
          && selectedBatch != null
          && selectedBatch.compatible
          && _sameIds(selectedBatch.documentTemplateIds, _selectedTemplateIds);
      final orderedTemplateIds = data.templates
          .where((template) => _selectedTemplateIds.contains(template.id))
          .map((template) => template.id)
          .toList(growable: false);

      final operation = await widget.repository.printPdf(
        quoteId: widget.quoteId,
        documentBatchId: geometryPreviewOnly
            ? selectedBatch.id
            : useExactBatch
                ? selectedBatch.id
                : null,
        documentTemplateIds: useExactBatch || geometryPreviewOnly
            ? const <String>[]
            : orderedTemplateIds,
        splitOutput: _splitOutput,
        includeGeometryPreview: selectedBatch?.hasGeometryPreview == true
            ? _includeGeometryPreview
            : false,
        includeGeometryWarnings: selectedBatch?.hasGeometryPreview == true
                && _includeGeometryPreview
            ? _includeGeometryWarnings
            : null,
        geometryPreviewOnly: geometryPreviewOnly,
      );
      if (operation.jobId.isEmpty) {
        throw StateError('Document generation job id is empty');
      }
      notifyQuoteIntegrationsChanged();
      if (!mounted) return;
      setState(() {
        _statusText = operation.alreadyQueued
            ? 'Document generation is already queued or running in background.'
            : 'Document generation queued and continues in background.';
        _errorText = null;
      });
      unawaited(_watchPrintJob(operation.jobId));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusText = null;
        _errorText = '$error';
      });
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final contentHeight = (screenHeight * .52).clamp(390.0, 500.0).toDouble();
    final documentsHeight = (screenHeight * .16).clamp(110.0, 145.0).toDouble();

    return AlertDialog(
      title: const Text('Documents'),
      content: SizedBox(
        width: 720,
        height: contentHeight,
        child: FutureBuilder<PrintDialogData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _DocumentsHint(
                icon: Icons.error_outline,
                title: 'Document data failed',
                text: '${snapshot.error}',
              );
            }

            final data = snapshot.data!;
            _initialize(data);
            final selectedBatch = _batchById(data, _selectedBatchId);
            final exactBatchSelection = selectedBatch != null
                && _sameIds(selectedBatch.documentTemplateIds, _selectedTemplateIds);

            final payloadText = const JsonEncoder.withIndent('  ').convert(data.payloadPreview);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(
                  children: [
                    Text('Generated documents', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${_documents.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: documentsHeight,
                  child: _documents.isEmpty
                      ? const _DocumentsHint(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'No generated PDF yet',
                          text: 'Generated documents will appear here.',
                        )
                      : Scrollbar(
                          controller: _documentsScrollController,
                          child: ListView.builder(
                            controller: _documentsScrollController,
                            itemCount: _documents.length,
                            itemBuilder: (context, index) => _GeneratedDocumentTile(
                              document: _documents[index],
                              repository: widget.repository,
                            ),
                          ),
                        ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Text('Print documents', style: Theme.of(context).textTheme.titleSmall),
                    if (_isPrinting) ...[
                      const SizedBox(width: 12),
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                if (_isPrinting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.batches.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBatchId,
                            decoration: const InputDecoration(
                              labelText: 'Document batch',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final batch in data.batches)
                                DropdownMenuItem(
                                  value: batch.id,
                                  enabled: batch.compatible && batch.items.isNotEmpty,
                                  child: Text(
                                    !batch.compatible
                                        ? '${batch.name} · incompatible'
                                        : batch.items.isEmpty
                                            ? '${batch.displayName} · empty'
                                            : batch.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _isPrinting
                                ? null
                                : (value) {
                                    final batch = _batchById(data, value);
                                    if (batch == null) return;
                                    setState(() {
                                      _selectedBatchId = batch.id;
                                      _splitOutput = batch.splitOutput;
                                      _selectedTemplateIds
                                        ..clear()
                                        ..addAll(batch.documentTemplateIds);
                                      _includeGeometryPreview = batch.hasGeometryPreview
                                          && data.geometryPreviewSettings.pdfEnabled;
                                      _includeGeometryWarnings =
                                          data.geometryPreviewSettings.includeWarnings;
                                    });
                                  },
                          ),
                        if (selectedBatch != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _splitOutput
                                ? 'Output: one PDF per selected item, named from the template / Geometry preview.'
                                : 'Output: ${selectedBatch.outputFilename}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (selectedBatch != null || _selectedTemplateIds.length > 1) ...[
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _splitOutput,
                            title: const Text('Print templates separately'),
                            subtitle: const Text(
                              'Create one PDF per selected item; otherwise merge them into one PDF.',
                            ),
                            onChanged: _isPrinting
                                ? null
                                : (value) => setState(() => _splitOutput = value == true),
                          ),
                        ],
                        if (data.batches.isNotEmpty) const SizedBox(height: 12),
                        if (data.templates.isEmpty
                            && !(selectedBatch?.hasGeometryPreview ?? false))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: _DocumentsHint(
                              icon: Icons.print_disabled_outlined,
                              title: 'No print items',
                              text: 'No accessible active document templates or Geometry preview are available for this quote.',
                            ),
                          )
                        else ...[
                          Text(
                            'Print items',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedBatch == null
                                ? 'Select one or more standalone templates.'
                                : exactBatchSelection
                                    ? 'The selected templates match this batch.'
                                    : 'Custom selection based on ${selectedBatch.name}.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final template in data.templates)
                                  CheckboxListTile(
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    value: _selectedTemplateIds.contains(template.id),
                                    title: Text(
                                      template.displayName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onChanged: _isPrinting
                                        ? null
                                        : (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                _selectedTemplateIds.add(template.id);
                                              } else {
                                                _selectedTemplateIds.remove(template.id);
                                              }
                                            });
                                          },
                                  ),
                                if (selectedBatch?.hasGeometryPreview ?? false)
                                  CheckboxListTile(
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    value: data.geometryPreviewSettings.pdfEnabled
                                        && _includeGeometryPreview,
                                    title: const Text('Geometry preview'),
                                    subtitle: Text(
                                      data.geometryPreviewSettings.pdfEnabled
                                          ? 'Large Geometry preview block from this batch.'
                                          : 'Disabled in System Settings → geometry_preview.',
                                    ),
                                    onChanged: _isPrinting
                                            || !data.geometryPreviewSettings.pdfEnabled
                                        ? null
                                        : (checked) => setState(
                                              () => _includeGeometryPreview = checked == true,
                                            ),
                                  ),
                                if ((selectedBatch?.hasGeometryPreview ?? false)
                                    && data.geometryPreviewSettings.pdfEnabled
                                    && _includeGeometryPreview)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 32),
                                    child: CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      value: _includeGeometryWarnings,
                                      title: const Text('Include warnings in Geometry preview'),
                                      subtitle: const Text(
                                        'Overrides the system default for this print run only.',
                                      ),
                                      onChanged: _isPrinting
                                          ? null
                                          : (checked) => setState(
                                                () => _includeGeometryWarnings = checked == true,
                                              ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_statusText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _statusText!,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        if (_errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _errorText!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                  ],
                ),
                if (_showPayloadPreview)
                  Positioned.fill(
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Renderer payload JSON',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: payloadText));
                                    if (!context.mounted) return;
                                    showTopNotification(
                                      context,
                                      'Render JSON copied.',
                                      type: TopNotificationType.success,
                                    );
                                  },
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Copy'),
                                ),
                                IconButton(
                                  tooltip: 'Close JSON preview',
                                  onPressed: () => setState(() => _showPayloadPreview = false),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: payloadText,
                                readOnly: true,
                                expands: true,
                                minLines: null,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        FutureBuilder<PrintDialogData>(
          future: _dataFuture,
          builder: (context, snapshot) => TextButton.icon(
            onPressed: snapshot.hasData && !_isPrinting
                ? () => setState(() => _showPayloadPreview = !_showPayloadPreview)
                : null,
            icon: Icon(
              _showPayloadPreview
                  ? Icons.visibility_off_outlined
                  : Icons.data_object_outlined,
            ),
            label: Text(
              _showPayloadPreview
                  ? 'Hide render JSON'
                  : 'Show render JSON',
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FutureBuilder<PrintDialogData>(
              future: _dataFuture,
              builder: (context, snapshot) => FilledButton.icon(
                focusNode: _printFocusNode,
                onPressed: snapshot.hasData && _hasPrintSelection && !_isPrinting
                    ? () => _print(snapshot.data!)
                    : null,
                icon: _isPrinting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: const Text('Print'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeneratedDocumentTile extends StatelessWidget {
  const _GeneratedDocumentTile({
    required this.document,
    required this.repository,
  });

  final GeneratedDocument document;
  final CalculatorRepository repository;

  Future<void> _openPdf(BuildContext context) async {
    final target = 'generated_document_${DateTime.now().microsecondsSinceEpoch}';
    openMediaUrl('about:blank', target: target);
    try {
      var url = document.url?.trim() ?? '';
      if (url.isEmpty && document.fileId.trim().isNotEmpty) {
        final media = await repository.fetchMediaFileUrl(document.fileId);
        url = '${media['url'] ?? media['download_url'] ?? ''}'.trim();
      }
      if (url.isEmpty) throw StateError('Document URL is empty');
      openMediaUrl(url, target: target);
    } catch (error) {
      if (!context.mounted) return;
      showTopNotification(
        context,
        'Open PDF failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = document.createdAt?.trim();
    final createdAtDateTime = createdAt == null || createdAt.isEmpty
        ? null
        : DateTime.tryParse(createdAt);
    final formattedCreatedAt = createdAtDateTime == null
        ? createdAt
        : DateFormat('dd.MM.yyyy HH:mm').format(createdAtDateTime.toLocal());
    final metadata = [
      document.documentTypeCode,
      formattedCreatedAt,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    final printedBy = document.printedByLabel;
    final canOpen = document.fileId.trim().isNotEmpty || (document.url ?? '').isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(document.filename, overflow: TextOverflow.ellipsis),
        subtitle: printedBy == null && metadata.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (printedBy != null)
                    Text(
                      'by: $printedBy',
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (metadata.isNotEmpty)
                    Text(
                      metadata,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
        trailing: TextButton.icon(
          onPressed: canOpen ? () => _openPdf(context) : null,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View / Download PDF'),
        ),
      ),
    );
  }
}

class _DocumentsHint extends StatelessWidget {
  const _DocumentsHint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
