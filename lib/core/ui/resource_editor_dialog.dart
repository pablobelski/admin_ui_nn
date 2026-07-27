import 'dart:convert';

import 'package:flutter/material.dart';

import '../http/admin_resource_repository.dart';
import '../models/admin_resource.dart';
import 'media_file_actions.dart';
import 'media_file_picker.dart';
import 'media_preview_dialog.dart';
import 'searchable_select_form_field.dart';
import 'top_notification.dart';

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
  late final Map<String, Future<List<AdminSelectOption>>> _referenceOptionFutures;
  late final Future<List<Map<String, dynamic>>> _referenceOwnerTableFuture;
  Future<List<Map<String, dynamic>>>? _referenceOwnerRecordFuture;
  String? _referenceOwnerRecordObjectName;
  late final Map<String, FocusNode> _jsonFocusNodes;
  final Set<String> _uploadingFields = <String>{};

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.resource.formFields)
        if (field.type != AdminFieldType.boolType)
          field.key: TextEditingController(
            text: _initialText(field),
          ),
    };
    _jsonFocusNodes = {
      for (final field in widget.resource.formFields)
        if (field.type == AdminFieldType.json) field.key: FocusNode(),
    };
    for (final entry in _jsonFocusNodes.entries) {
      entry.value.addListener(() => _formatJsonController(entry.key));
    }
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
    _referenceOptionFutures = {
      for (final field in widget.resource.formFields)
        if (field.referenceDomain != null && field.referenceDomain!.trim().isNotEmpty)
          field.key: widget.repository?.fetchReferenceOptions(field.referenceDomain!.trim()) ??
              Future<List<AdminSelectOption>>.value(const <AdminSelectOption>[]),
    };
    _referenceOwnerTableFuture = widget.repository?.fetchReferenceDomainOwnerTables(limit: 1000) ??
        Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
  }

  bool _defaultBoolValue(String key) {
    return key == 'is_active' || key == 'is_default' || key == 'enabled';
  }

  dynamic _valueAtPath(Map<String, dynamic>? source, String key) {
    if (source == null) return null;
    if (!key.contains('.')) return source[key];

    dynamic cursor = source;
    for (final part in key.split('.')) {
      if (cursor is Map<String, dynamic>) {
        cursor = cursor[part];
      } else if (cursor is Map) {
        cursor = cursor[part];
      } else {
        return null;
      }
    }
    return cursor;
  }

  void _setPayloadValue(Map<String, dynamic> target, String key, dynamic value) {
    if (!key.contains('.')) {
      target[key] = value;
      return;
    }

    final parts = key.split('.');
    var cursor = target;
    for (final part in parts.take(parts.length - 1)) {
      final existing = cursor[part];
      if (existing is Map<String, dynamic>) {
        cursor = existing;
      } else if (existing is Map) {
        final converted = Map<String, dynamic>.from(existing);
        cursor[part] = converted;
        cursor = converted;
      } else {
        final created = <String, dynamic>{};
        cursor[part] = created;
        cursor = created;
      }
    }
    cursor[parts.last] = value;
  }

  String _initialText(AdminField field) {
    final value = _valueAtPath(widget.initialData, field.key);
    if (value == null) return widget.initialData == null ? field.defaultValue ?? '' : '';
    if (field.type == AdminFieldType.json) return _prettyJsonText(value);
    return '$value';
  }

  String _prettyJsonText(Object? value) {
    if (value == null) return '';

    try {
      if (value is Map || value is List) {
        return const JsonEncoder.withIndent('  ').convert(value);
      }

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return '';
        final decoded = jsonDecode(trimmed);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
    } catch (_) {
      return '$value';
    }

    return '$value';
  }

  void _formatJsonController(String key) {
    final controller = _controllers[key];
    if (controller == null) return;

    final currentText = controller.text;
    final prettyText = _prettyJsonText(currentText);
    if (prettyText == currentText) return;

    controller.value = TextEditingValue(
      text: prettyText,
      selection: TextSelection.collapsed(offset: prettyText.length),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _jsonFocusNodes.values) {
      focusNode.dispose();
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

    if (field.type == AdminFieldType.date) {
      return _buildDateField(field);
    }

    if (field.type == AdminFieldType.file) {
      return _buildFileField(field);
    }

    if (_isReferenceDomainObjectNameField(field)) {
      return _buildReferenceDomainObjectNameField(field);
    }

    if (_isReferenceDomainParentIdField(field)) {
      return _buildReferenceDomainParentIdField(field);
    }

    if (field.options.isNotEmpty) {
      final controller = _controllers[field.key]!;
      final currentValue = controller.text.trim();
      return SearchableSelectFormField(
        value: currentValue,
        options: [
          for (final option in field.options)
            SearchableSelectOption(value: option.value, label: option.label),
        ],
        enabled: !field.readOnly,
        labelText: field.label,
        helperText: field.helperText,
        onChanged: (value) {
          controller.text = value ?? '';
          if (_isReferenceDomainScopeField(field)) {
            _handleReferenceDomainScopeChanged(controller.text);
          }
        },
      );
    }

    if (field.referenceDomain != null && field.referenceDomain!.trim().isNotEmpty) {
      return FutureBuilder<List<AdminSelectOption>>(
        future: _referenceOptionFutures[field.key],
        builder: (context, snapshot) {
          final controller = _controllers[field.key]!;
          final currentValue = controller.text.trim();
          final loadedOptions = snapshot.data ?? const <AdminSelectOption>[];
          final options = <SearchableSelectOption>[];
          var hasCurrentValue = currentValue.isEmpty;

          for (final option in loadedOptions) {
            hasCurrentValue = hasCurrentValue || option.value == currentValue;
            options.add(SearchableSelectOption(value: option.value, label: option.label));
          }

          if (!hasCurrentValue) {
            options.add(SearchableSelectOption(value: currentValue, label: currentValue));
          }

          return SearchableSelectFormField(
            value: currentValue,
            options: options,
            enabled: !field.readOnly && snapshot.connectionState != ConnectionState.waiting,
            labelText: field.label,
            helperText: snapshot.connectionState == ConnectionState.waiting
                ? 'Loading options...'
                : snapshot.hasError
                ? 'Failed to load; keep existing value or leave empty'
                : field.helperText,
            onChanged: (value) {
              controller.text = value ?? '';
            },
          );
        },
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
          final options = <SearchableSelectOption>[];
          var hasCurrentValue = currentValue.isEmpty;

          for (final row in rows) {
            final id = row[lookup.idKey]?.toString();
            if (id == null || id.isEmpty) continue;
            hasCurrentValue = hasCurrentValue || id == currentValue;
            options.add(SearchableSelectOption(value: id, label: _lookupLabel(lookup, row)));
          }

          if (!hasCurrentValue) {
            options.add(SearchableSelectOption(value: currentValue, label: currentValue));
          }

          return SearchableSelectFormField(
            value: currentValue,
            options: options,
            enabled: !field.readOnly && snapshot.connectionState != ConnectionState.waiting,
            labelText: field.label,
            helperText: snapshot.connectionState == ConnectionState.waiting
                ? 'Loading options...'
                : snapshot.hasError
                ? 'Failed to load; keep existing value or leave empty'
                : field.helperText,
            onChanged: (value) {
              controller.text = value ?? '';
            },
          );
        },
      );
    }

    return TextFormField(
      controller: _controllers[field.key],
      focusNode: field.type == AdminFieldType.json ? _jsonFocusNodes[field.key] : null,
      readOnly: field.readOnly,
      maxLines: field.type == AdminFieldType.longText || field.type == AdminFieldType.json ? 8 : 1,
      keyboardType: field.type == AdminFieldType.number
          ? TextInputType.number
          : field.type == AdminFieldType.json
          ? TextInputType.multiline
          : TextInputType.text,
      obscureText: field.type == AdminFieldType.password,
      autocorrect: field.type != AdminFieldType.json,
      enableSuggestions: field.type != AdminFieldType.json,
      style: field.type == AdminFieldType.json
          ? Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
          : null,
      decoration: InputDecoration(labelText: field.label, helperText: field.helperText),
      onChanged: field.type == AdminFieldType.json
          ? (value) {
              if (!value.contains('\n')) {
                _formatJsonController(field.key);
              }
            }
          : null,
      validator: (value) {
        if (!field.readOnly && (value == null || value.trim().isEmpty) && field.key != 'id') {
          return null;
        }
        if (field.type == AdminFieldType.number && value != null && value.trim().isNotEmpty) {
          if (num.tryParse(value.trim().replaceAll(',', '.')) == null) {
            return 'Invalid number';
          }
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


  bool _isReferenceDomainScopeField(AdminField field) {
    return widget.resource.key == 'reference_domains' && field.key == 'scope_code';
  }

  bool _isReferenceDomainObjectNameField(AdminField field) {
    return widget.resource.key == 'reference_domains' && field.key == 'object_name';
  }

  bool _isReferenceDomainParentIdField(AdminField field) {
    return widget.resource.key == 'reference_domains' && field.key == 'parent_id';
  }

  bool get _referenceDomainUsesTableScope {
    final scope = _controllers['scope_code']?.text.trim().toLowerCase() ?? '';
    return scope == 'table';
  }

  void _handleReferenceDomainScopeChanged(String scopeCode) {
    final nextScope = scopeCode.trim().toLowerCase();
    if (nextScope != 'table') {
      _controllers['object_name']?.clear();
      _controllers['parent_id']?.clear();
      _referenceOwnerRecordObjectName = null;
      _referenceOwnerRecordFuture = null;
    }
    setState(() {});
  }

  void _handleReferenceDomainObjectChanged(String? objectName) {
    _controllers['object_name']!.text = objectName ?? '';
    _controllers['parent_id']?.clear();
    _referenceOwnerRecordObjectName = null;
    _referenceOwnerRecordFuture = null;
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _referenceOwnerRecordsFuture(String objectName) {
    final normalized = objectName.trim();
    if (normalized.isEmpty) {
      return Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
    }
    if (_referenceOwnerRecordObjectName != normalized || _referenceOwnerRecordFuture == null) {
      _referenceOwnerRecordObjectName = normalized;
      _referenceOwnerRecordFuture = widget.repository?.fetchReferenceDomainOwnerRecords(
            normalized,
            limit: 1000,
          ) ??
          Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
    }
    return _referenceOwnerRecordFuture!;
  }

  Widget _buildReferenceDomainObjectNameField(AdminField field) {
    final controller = _controllers[field.key]!;
    final enabled = !field.readOnly && _referenceDomainUsesTableScope;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _referenceOwnerTableFuture,
      builder: (context, snapshot) {
        final currentValue = controller.text.trim();
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final options = <SearchableSelectOption>[];
        var hasCurrentValue = currentValue.isEmpty;

        for (final row in rows) {
          final value = row['code']?.toString() ?? row['id']?.toString() ?? '';
          if (value.isEmpty) continue;
          final label = row['label']?.toString().trim() ?? value;
          final labelColumns = row['label_columns']?.toString().trim() ?? '';
          hasCurrentValue = hasCurrentValue || value == currentValue;
          options.add(SearchableSelectOption(
            value: value,
            label: labelColumns.isEmpty ? label : '$label · $labelColumns',
          ));
        }

        if (!hasCurrentValue) {
          options.add(SearchableSelectOption(value: currentValue, label: currentValue));
        }

        return SearchableSelectFormField(
          value: currentValue,
          options: options,
          enabled: enabled && snapshot.connectionState != ConnectionState.waiting,
          labelText: field.label,
          helperText: !_referenceDomainUsesTableScope
              ? 'Available when Scope = Table records'
              : snapshot.connectionState == ConnectionState.waiting
              ? 'Loading configurator tables...'
              : snapshot.hasError
              ? 'Failed to load tables; keep existing value or leave empty'
              : field.helperText,
          onChanged: _handleReferenceDomainObjectChanged,
        );
      },
    );
  }

  Widget _buildReferenceDomainParentIdField(AdminField field) {
    final controller = _controllers[field.key]!;
    final objectName = _controllers['object_name']?.text.trim() ?? '';
    final enabled = !field.readOnly && _referenceDomainUsesTableScope && objectName.isNotEmpty;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: enabled
          ? _referenceOwnerRecordsFuture(objectName)
          : Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]),
      builder: (context, snapshot) {
        final currentValue = controller.text.trim();
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final options = <SearchableSelectOption>[];
        var hasCurrentValue = currentValue.isEmpty;

        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final label = row['label']?.toString().trim() ?? id;
          hasCurrentValue = hasCurrentValue || id == currentValue;
          options.add(SearchableSelectOption(value: id, label: label.isEmpty ? id : label));
        }

        if (!hasCurrentValue) {
          options.add(SearchableSelectOption(value: currentValue, label: currentValue));
        }

        return SearchableSelectFormField(
          value: currentValue,
          options: options,
          enabled: enabled && snapshot.connectionState != ConnectionState.waiting,
          labelText: field.label,
          helperText: !_referenceDomainUsesTableScope
              ? 'Available when Scope = Table records'
              : objectName.isEmpty
              ? 'Select Object name first'
              : snapshot.connectionState == ConnectionState.waiting
              ? 'Loading records from $objectName...'
              : snapshot.hasError
              ? 'Failed to load records; keep existing id or leave empty'
              : field.helperText,
          onChanged: (value) {
            controller.text = value ?? '';
          },
        );
      },
    );
  }

  Widget _buildFileField(AdminField field) {
    final controller = _controllers[field.key]!;
    final isUploading = _uploadingFields.contains(field.key);
    final hasFile = controller.text.trim().isNotEmpty;

    return TextFormField(
      controller: controller,
      readOnly: field.readOnly,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helperText ?? 'Upload file to Media Library and save its asset file id.',
        suffixIcon: SizedBox(
          width: isUploading ? 48 : 138,
          child: isUploading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Preview file',
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: hasFile && widget.repository != null
                          ? () => _showFieldMedia(field)
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Download file',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: hasFile && widget.repository != null
                          ? () => _downloadFieldMedia(field)
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Upload file',
                      icon: const Icon(Icons.upload_file_outlined),
                      onPressed: field.readOnly || widget.repository == null
                          ? null
                          : () => _pickAndUploadFile(field),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  MediaFileRef? _mediaRefForField(AdminField field) {
    final fileId = _controllers[field.key]?.text.trim() ?? '';
    if (fileId.isEmpty) return null;
    return MediaFileRef(
      fieldKey: field.key,
      label: field.label,
      fileId: fileId,
    );
  }

  Future<void> _showFieldMedia(AdminField field) async {
    final ref = _mediaRefForField(field);
    if (ref == null || widget.repository == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => MediaPreviewDialog(
        repository: widget.repository!,
        files: [ref],
      ),
    );
  }

  Future<void> _downloadFieldMedia(AdminField field) async {
    final ref = _mediaRefForField(field);
    if (ref == null || widget.repository == null) return;

    try {
      final media = await widget.repository!.fetchMediaFileUrl(ref.fileId);
      final url = media['download_url']?.toString().trim() ?? '';
      if (url.isEmpty) {
        throw StateError('File download URL is empty');
      }
      final file = media['file'];
      final filename = file is Map
          ? file['original_filename']?.toString().trim()
          : null;
      downloadMediaUrl(
        url,
        filename: filename == null || filename.isEmpty ? ref.label : filename,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'File download failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  Future<void> _pickAndUploadFile(AdminField field) async {
    final picked = await pickMediaFile(accept: field.accept);
    if (picked == null) return;

    setState(() {
      _uploadingFields.add(field.key);
    });

    try {
      final uploaded = await widget.repository!.uploadMediaFile(
        filename: picked.filename,
        contentType: picked.mimeType,
        dataBase64: picked.base64Data,
        purpose: field.filePurpose ?? '${widget.resource.key}/${field.key.replaceAll('.', '_')}',
        metadata: {
          'resource_key': widget.resource.key,
          'field_key': field.key,
          'file_size_bytes': picked.sizeBytes,
        },
      );
      _controllers[field.key]!.text = uploaded['id']?.toString() ?? '';
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'File upload failed: $error',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFields.remove(field.key);
        });
      }
    }
  }

  Widget _buildDateField(AdminField field) {
    final controller = _controllers[field.key]!;

    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: !field.readOnly,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helperText,
        suffixIcon: IconButton(
          tooltip: 'Select date',
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: field.readOnly ? null : () => _selectDate(field),
        ),
      ),
      onTap: field.readOnly ? null : () => _selectDate(field),
    );
  }

  Future<void> _selectDate(AdminField field) async {
    final controller = _controllers[field.key]!;
    final now = DateTime.now();
    final initialDate = _parseDate(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 50),
    );

    if (picked == null) return;
    controller.text = _formatDate(picked);
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
    return DateTime.tryParse(normalized);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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
    for (final field in widget.resource.formFields) {
      if (field.type == AdminFieldType.json) {
        _formatJsonController(field.key);
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final payload = <String, dynamic>{};

    for (final field in widget.resource.formFields) {
      if (!field.includeInPayload) continue;

      if (field.type == AdminFieldType.boolType) {
        _setPayloadValue(payload, field.key, _boolValues[field.key] ?? false);
        continue;
      }

      final rawValue = _controllers[field.key]!.text.trim();
      if (rawValue.isEmpty) {
        final existingValue = _valueAtPath(widget.initialData, field.key);
        if (!field.readOnly && widget.initialData != null && existingValue != null) {
          _setPayloadValue(payload, field.key, null);
        } else if (!field.readOnly && field.type == AdminFieldType.json) {
          _setPayloadValue(payload, field.key, null);
        }
        continue;
      }

      switch (field.type) {
        case AdminFieldType.number:
          _setPayloadValue(payload, field.key, num.parse(rawValue.replaceAll(',', '.')));
          break;
        case AdminFieldType.json:
          _setPayloadValue(payload, field.key, jsonDecode(rawValue));
          break;
        default:
          _setPayloadValue(payload, field.key, rawValue);
      }
    }

    Navigator.of(context).pop(payload);
  }
}
