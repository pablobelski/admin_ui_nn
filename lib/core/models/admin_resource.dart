import 'package:flutter/material.dart';

enum AdminFieldType { text, longText, number, boolType, date, json }

class AdminField {
  const AdminField({
    required this.key,
    required this.label,
    this.type = AdminFieldType.text,
    this.readOnly = false,
  });

  final String key;
  final String label;
  final AdminFieldType type;
  final bool readOnly;
}

class AdminColumn {
  const AdminColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.isPrimary = false,
  });

  final String key;
  final String label;
  final int flex;
  final bool isPrimary;
}

class AdminResourceDefinition {
  const AdminResourceDefinition({
    required this.key,
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.columns,
    required this.formFields,
    this.supportsCreate = true,
    this.supportsEdit = true,
    this.supportsDelete = false,
    this.description,
  });

  final String key;
  final String title;
  final String endpoint;
  final IconData icon;
  final List<AdminColumn> columns;
  final List<AdminField> formFields;
  final bool supportsCreate;
  final bool supportsEdit;
  final bool supportsDelete;
  final String? description;
}

class AdminNavGroup {
  const AdminNavGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.resources,
  });

  final String key;
  final String title;
  final IconData icon;
  final List<AdminResourceDefinition> resources;
}
