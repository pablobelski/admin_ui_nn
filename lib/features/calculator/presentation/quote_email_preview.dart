import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/ui/email_html_frame.dart';

Future<void> showQuoteEmailPreviewDialog(BuildContext context, {
  required List<Map<String, dynamic>> messages,
  required Map<String, dynamic> images,
}) => showDialog<void>(
  context: context,
  builder: (previewContext) => AlertDialog(
    title: const Text('Email preview'),
    content: SizedBox(width: 900, child: SingleChildScrollView(
      child: QuoteEmailPreview(messages: messages, images: images),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.of(previewContext).pop(), child: const Text('Close')),
    ],
  ),
);

class QuoteEmailPreview extends StatefulWidget {
  const QuoteEmailPreview({super.key, required this.messages, required this.images});

  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> images;

  @override
  State<QuoteEmailPreview> createState() => _QuoteEmailPreviewState();
}

class _QuoteEmailPreviewState extends State<QuoteEmailPreview> {
  String? _selectedId;

  String _addresses(Object? value) {
    return value is List ? value.join(', ') : '$value';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12), child: Text('No email to preview.'));
    }
    final message = widget.messages.firstWhere((item) => item['id'] == _selectedId,
        orElse: () => widget.messages.first);
    var html = '${message['html'] ?? ''}';
    if (html.isEmpty) {
      html = '<pre style="white-space:pre-wrap;font-family:Arial,sans-serif">'
          '${const HtmlEscape().convert('${message['text'] ?? ''}')}</pre>';
    }
    for (final image in widget.images.entries) {
      html = html.replaceAll('cid:${image.key}', '${image.value}');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      if (widget.messages.length > 1)
        DropdownButtonFormField<String>(
          key: ValueKey(message['id']),
          initialValue: '${message['id']}',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Email to preview'),
          items: [for (final item in widget.messages)
            DropdownMenuItem(value: '${item['id']}', child: Text('${item['name']}'))],
          onChanged: (value) => setState(() => _selectedId = value),
        ),
      const SizedBox(height: 8),
      Text('From: ${message['from_name']} <${message['from_address']}>'),
      for (final group in ['to', 'cc', 'bcc'])
        if ((message[group] as List?)?.isNotEmpty == true)
          Text('${group.toUpperCase()}: ${_addresses(message[group])}'),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Subject: ${message['subject']}', style: Theme.of(context).textTheme.titleSmall)),
      Container(
        height: 360,
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        child: EmailHtmlFrame(html: html),
      ),
      const SizedBox(height: 4),
      Text('The 3D button becomes active in the sent email.', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
