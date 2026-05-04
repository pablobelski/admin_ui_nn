import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/admin_resource.dart';

class ResourceEditorDialog extends StatefulWidget {
  const ResourceEditorDialog({
    super.key,
    required this.resource,
    this.initialData,
  });

  final AdminResourceDefinition resource;
  final Map<String, dynamic>? initialData;

  @override
  State<ResourceEditorDialog> createState() => _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends State<ResourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _boolValues;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.resource.formFields)
        if (field.type != AdminFieldType.boolType)
          field.key: TextEditingController(
            text: _initialText(field.key),
          ),
    };
    _boolValues = {
      for (final field in widget.resource.formFields)
        if (field.type == AdminFieldType.boolType)
          field.key: widget.initialData?[field.key] == true,
    };
  }

  String _initialText(String key) {
    final value = widget.initialData?[key];
    if (value == null) return '';
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return '$value';
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit ${widget.resource.title}' : 'Create ${widget.resource.title}'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final field in widget.resource.formFields)
                  SizedBox(
                    width: field.type == AdminFieldType.longText ||
                            field.type == AdminFieldType.json
                        ? 680
                        : 332,
                    child: _buildField(field),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildField(AdminField field) {
    if (field.type == AdminFieldType.boolType) {
      return CheckboxListTile(
        value: _boolValues[field.key] ?? false,
        onChanged: field.readOnly
            ? null
            : (value) {
                setState(() {
                  _boolValues[field.key] = value ?? false;
                });
              },
        title: Text(field.label),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    return TextFormField(
      controller: _controllers[field.key],
      readOnly: field.readOnly,
      maxLines: field.type == AdminFieldType.longText || field.type == AdminFieldType.json ? 8 : 1,
      keyboardType: field.type == AdminFieldType.number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: field.label),
      validator: (value) {
        if (!field.readOnly && (value == null || value.trim().isEmpty) && field.key != 'id') {
          return null;
        }
        if (field.type == AdminFieldType.json && value != null && value.trim().isNotEmpty) {
          try {
            jsonDecode(value);
          } catch (_) {
            return 'Invalid JSON';
          }
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final payload = <String, dynamic>{};

    for (final field in widget.resource.formFields) {
      if (field.type == AdminFieldType.boolType) {
        payload[field.key] = _boolValues[field.key] ?? false;
        continue;
      }

      final rawValue = _controllers[field.key]!.text.trim();
      if (rawValue.isEmpty) continue;

      switch (field.type) {
        case AdminFieldType.number:
          payload[field.key] = num.tryParse(rawValue) ?? rawValue;
          break;
        case AdminFieldType.json:
          payload[field.key] = jsonDecode(rawValue);
          break;
        default:
          payload[field.key] = rawValue;
      }
    }

    Navigator.of(context).pop(payload);
  }
}
