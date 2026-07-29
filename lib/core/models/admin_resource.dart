import 'package:flutter/material.dart';

enum AdminFieldType { text, email, longText, number, boolType, date, json, password, file }

class AdminSelectOption {
  const AdminSelectOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class AdminLookup {
  const AdminLookup({
    required this.endpoint,
    this.idKey = 'id',
    this.labelKeys = const ['display_name', 'legal_name', 'name', 'code'],
    this.limit = 500,
    this.showIdInDropdown = true,
  });

  final String endpoint;
  final String idKey;
  final List<String> labelKeys;
  final int limit;
  final bool showIdInDropdown;
}

class AdminField {
  const AdminField({
    required this.key,
    required this.label,
    this.type = AdminFieldType.text,
    this.readOnly = false,
    this.lookup,
    this.options = const [],
    this.helperText,
    this.defaultValue,
    this.referenceDomain,
    this.includeInPayload = true,
    this.filePurpose,
    this.accept,
    this.createOnly = false,
    this.requiredOnCreate = false,
    this.minLength,
    this.matchesFieldKey,
    this.lookupFilterFieldKey,
    this.lookupFilterQueryKey,
    this.lookupFilters = const {},
  });

  final String key;
  final String label;
  final AdminFieldType type;
  final bool readOnly;
  final AdminLookup? lookup;
  final List<AdminSelectOption> options;
  final String? helperText;
  final String? defaultValue;
  final String? referenceDomain;
  final bool includeInPayload;
  final String? filePurpose;
  final String? accept;
  final bool createOnly;
  final bool requiredOnCreate;
  final int? minLength;
  final String? matchesFieldKey;
  final String? lookupFilterFieldKey;
  final String? lookupFilterQueryKey;
  final Map<String, String> lookupFilters;
}

class AdminColumn {
  const AdminColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.isPrimary = false,
    this.lookup,
  });

  final String key;
  final String label;
  final int flex;
  final bool isPrimary;
  final AdminLookup? lookup;
}

class AdminResourceFilter {
  const AdminResourceFilter({
    required this.key,
    required this.label,
    this.lookup,
    this.options = const [],
  });

  final String key;
  final String label;
  final AdminLookup? lookup;
  final List<AdminSelectOption> options;
}

class AdminDetailAction {
  const AdminDetailAction({
    required this.label,
    required this.targetResourceKey,
    required this.filterKey,
    required this.sourceValueKey,
    this.icon = Icons.open_in_new_rounded,
    this.selectTargetRow = false,
    this.extraFilters = const {},
  }) : assert(
          !selectTargetRow || filterKey == 'id',
          'selectTargetRow can only be used with filterKey: id',
        );

  final String label;
  final String targetResourceKey;
  final String filterKey;
  final String sourceValueKey;
  final IconData icon;
  final Map<String, String> extraFilters;

  /// Select the target row after opening the target resource.
  ///
  /// Use this for exact child -> parent navigation, for example
  /// Catalog Variant -> Catalog Item, where [filterKey] is usually `id` and
  /// [sourceValueKey] is a foreign-key field from the source record.
  final bool selectTargetRow;
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
    this.listFilters = const [],
    this.detailActions = const [],
    this.requiresSysadmin = false,
    this.showInNavigation = true,
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
  final List<AdminResourceFilter> listFilters;
  final List<AdminDetailAction> detailActions;
  final bool requiresSysadmin;
  final bool showInNavigation;
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
