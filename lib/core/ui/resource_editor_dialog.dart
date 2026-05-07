import 'dart:convert';
import '../http/admin_resource_repository.dart';
import 'package:flutter/material.dart';
import '../models/admin_resource.dart';

class ResourceEditorDialog extends StatefulWidget {
  const ResourceEditorDialog({
    super.key,
    required this.resource,
    this.repository,
    this.initialData,
  });

  final AdminResourceDefinition resource;
  final AdminResourceRepository? repository;
  final Map<String, dynamic>? initialData;

  @override
  State<ResourceEditorDialog> createState() => _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends State<ResourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _boolValues;
  late final Map<String, Future<List<Map<String, dynamic>>>> _lookupFutures;

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
          field.key: widget.initialData?[field.key] == true ||
              (widget.initialData == null && _defaultBoolValue(field.key)),
    };
    _lookupFutures = {
      for (final field in widget.resource.formFields)
        if (field.lookup != null)
          field.key: widget.repository?.fetchLookup(field.lookup!, limit: field.lookup!.limit) ??
              Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]),
    };
  }

  bool _defaultBoolValue(String key) {
    return key == 'is_active' || key == 'is_default';
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

    if (field.lookup != null) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _lookupFutures[field.key],
        builder: (context, snapshot) {
          final lookup = field.lookup!;
          final controller = _controllers[field.key]!;
          final currentValue = controller.text.trim();
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          final options = <DropdownMenuItem<String>>[
            const DropdownMenuItem(value: '', child: Text('— Not selected —')),
          ];
          var hasCurrentValue = currentValue.isEmpty;

          for (final row in rows) {
            final id = row[lookup.idKey]?.toString();
            if (id == null || id.isEmpty) continue;
            hasCurrentValue = hasCurrentValue || id == currentValue;
            options.add(
              DropdownMenuItem(
                value: id,
                child: Text(
                  _lookupLabel(lookup, row),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }

          if (!hasCurrentValue) {
            options.add(
              DropdownMenuItem(
                value: currentValue,
                child: Text(currentValue, overflow: TextOverflow.ellipsis),
              ),
            );
          }

          return DropdownButtonFormField<String>(
            initialValue: currentValue.isEmpty ? '' : currentValue,
            isExpanded: true,
            items: options,
            onChanged: field.readOnly
                ? null
                : (value) {
              controller.text = value ?? '';
            },
            decoration: InputDecoration(
              labelText: field.label,
              helperText: snapshot.connectionState == ConnectionState.waiting
                  ? 'Loading options...'
                  : snapshot.hasError
                  ? 'Failed to load; keep existing value or leave empty'
                  : null,
            ),
          );
        },
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

  String _lookupLabel(AdminLookup lookup, Map<String, dynamic> row) {
    final labels = <String>[];
    for (final key in lookup.labelKeys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        labels.add(value.toString());
      }
    }

    final id = row[lookup.idKey]?.toString() ?? '';
    if (labels.isEmpty) return id;
    if (id.isEmpty || !lookup.showIdInDropdown) return labels.join(' · ');
    return '${labels.join(' · ')} ($id)';
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
