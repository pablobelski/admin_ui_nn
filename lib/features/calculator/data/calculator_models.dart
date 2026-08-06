import 'dart:convert';

class CalculatorContext {
  const CalculatorContext({
    required this.organizations,
    required this.relatedCustomers,
    this.headBranding,
    required this.productFamilies,
    required this.templates,
    required this.references,
    required this.priceModes,
    required this.defaultSteps,
    required this.optionItemTypes,
    required this.optionCatalogItems,
    required this.optionCatalogVariants,
    required this.templateSetCatalogItems,
    required this.templateSetCatalogVariants,
    required this.additionalHandlingByParentItemId,
    this.customPaintCatalogItem,
    this.loadedCatalogWarnings = const [],
  });

  factory CalculatorContext.fromJson(Map<String, dynamic> json) {
    final customPaintCatalogItem = json['customPaintCatalogItem'] is Map
        ? CalculatorCatalogItemOption.fromJson(Map<String, dynamic>.from(json['customPaintCatalogItem'] as Map))
        : null;
    final optionCatalogItems = _list(json['optionCatalogItems'])
        .map(CalculatorCatalogItemOption.fromJson)
        .toList();
    if (customPaintCatalogItem != null
        && !optionCatalogItems.any((item) => item.id == customPaintCatalogItem.id)) {
      optionCatalogItems.add(customPaintCatalogItem);
    }

    return CalculatorContext(
      organizations: _list(json['organizations']).map(CalculatorOption.fromJson).toList(),
      relatedCustomers: _list(json['relatedCustomers'] ?? json['related_customers']).map(CalculatorOption.fromJson).toList(),
      headBranding: (json['headBranding'] ?? json['head_branding']) is Map
          ? CalculatorBranding.fromJson(Map<String, dynamic>.from((json['headBranding'] ?? json['head_branding']) as Map))
          : null,
      productFamilies: _list(json['productFamilies']).map(CalculatorOption.fromJson).toList(),
      templates: _list(json['templates']).map(CalculatorTemplateOption.fromJson).toList(),
      references: _references(json['references']),
      priceModes: _list(json['priceModes']).map(CalculatorOption.fromJson).toList(),
      defaultSteps: (json['defaultSteps'] as List? ?? const [])
          .map((entry) => '$entry')
          .toList(),
      optionItemTypes: _list(json['optionItemTypes']).map(CalculatorOption.fromJson).toList(),
      optionCatalogItems: optionCatalogItems,
      optionCatalogVariants: _list(json['optionCatalogVariants']).map(CalculatorCatalogVariantOption.fromJson).toList(),
      templateSetCatalogItems: _list(json['templateSetCatalogItems']).map(CalculatorCatalogItemOption.fromJson).toList(),
      templateSetCatalogVariants: _list(json['templateSetCatalogVariants']).map(CalculatorCatalogVariantOption.fromJson).toList(),
      additionalHandlingByParentItemId: _additionalHandlingMap(json['additionalHandlingByParentItemId']),
      customPaintCatalogItem: customPaintCatalogItem,
    );
  }

  final List<CalculatorOption> organizations;
  final List<CalculatorOption> relatedCustomers;
  final CalculatorBranding? headBranding;
  final List<CalculatorOption> productFamilies;
  final List<CalculatorTemplateOption> templates;
  final Map<String, List<CalculatorOption>> references;
  final List<CalculatorOption> priceModes;
  final List<String> defaultSteps;
  final List<CalculatorOption> optionItemTypes;
  final List<CalculatorCatalogItemOption> optionCatalogItems;
  final List<CalculatorCatalogVariantOption> optionCatalogVariants;
  final List<CalculatorCatalogItemOption> templateSetCatalogItems;
  final List<CalculatorCatalogVariantOption> templateSetCatalogVariants;
  final Map<String, List<CalculatorAdditionalHandlingOption>> additionalHandlingByParentItemId;
  final CalculatorCatalogItemOption? customPaintCatalogItem;
  final List<Map<String, dynamic>> loadedCatalogWarnings;

  List<CalculatorCatalogItemOption> templateSetCatalogItemsFor(String? templateId) {
    final normalizedTemplateId = templateId?.trim() ?? '';
    if (normalizedTemplateId.isEmpty) return const [];
    return templateSetCatalogItems.where((item) {
      if (!item.isSelectable) return false;
      final rawTemplateIds = item.raw['template_ids'];
      if (rawTemplateIds is! List) return false;
      return rawTemplateIds.any((value) => '$value' == normalizedTemplateId);
    }).toList(growable: false);
  }

  CalculatorContext withRestoredCatalog({
    required List<CalculatorCatalogItemOption> catalogItems,
    required List<CalculatorCatalogVariantOption> catalogVariants,
    required List<Map<String, dynamic>> warnings,
  }) {
    List<T> mergeById<T>(List<T> current, List<T> restored, String Function(T) idOf) {
      final merged = <T>[...current];
      final knownIds = current.map(idOf).toSet();
      for (final entry in restored) {
        if (knownIds.add(idOf(entry))) merged.add(entry);
      }
      return merged;
    }

    return CalculatorContext(
      organizations: organizations,
      relatedCustomers: relatedCustomers,
      headBranding: headBranding,
      productFamilies: productFamilies,
      templates: templates,
      references: references,
      priceModes: priceModes,
      defaultSteps: defaultSteps,
      optionItemTypes: optionItemTypes,
      optionCatalogItems: mergeById(optionCatalogItems, catalogItems, (entry) => entry.id),
      optionCatalogVariants: mergeById(optionCatalogVariants, catalogVariants, (entry) => entry.id),
      templateSetCatalogItems: templateSetCatalogItems,
      templateSetCatalogVariants: templateSetCatalogVariants,
      additionalHandlingByParentItemId: additionalHandlingByParentItemId,
      customPaintCatalogItem: customPaintCatalogItem,
      loadedCatalogWarnings: warnings,
    );
  }

  CalculatorBuyerContact buyerContactFor(CalculatorDraft draft) {
    CalculatorOption? option;
    final relatedId = draft.relatedCustomerId?.trim() ?? '';
    if (relatedId.isNotEmpty) {
      option = relatedCustomers.where((entry) => entry.id == relatedId).firstOrNull;
    }
    final organizationId = draft.organizationId?.trim() ?? '';
    option ??= organizations.where((entry) => entry.id == organizationId).firstOrNull;
    if (option == null) return const CalculatorBuyerContact();
    final raw = option.raw;
    String? text(Object? value) {
      final normalized = value == null ? '' : '$value'.trim();
      return normalized.isEmpty ? null : normalized;
    }
    return CalculatorBuyerContact(
      organizationName: text(raw['legal_name']) ?? text(raw['display_name']) ?? option.label,
      contactName: text(raw['configurator_contact_full_name']),
      email: text(raw['configurator_contact_email']),
      phone: text(raw['configurator_contact_phone']),
    );
  }

  List<CalculatorOption> relatedCustomersFor(String? parentOrganizationId) {
    if (parentOrganizationId == null || parentOrganizationId.isEmpty) return const [];
    return relatedCustomers
        .where((entry) => '${entry.raw['parent_organization_id'] ?? ''}' == parentOrganizationId)
        .toList(growable: false);
  }
}


class CalculatorBuyerContact {
  const CalculatorBuyerContact({
    this.organizationName,
    this.contactName,
    this.email,
    this.phone,
  });

  final String? organizationName;
  final String? contactName;
  final String? email;
  final String? phone;

  bool get hasOrganization => (organizationName ?? '').isNotEmpty;
  bool get hasContact => [contactName, email, phone].any((value) => (value ?? '').isNotEmpty);
}


class CalculatorBranding {
  const CalculatorBranding({
    this.brandingId,
    this.organizationId,
    this.organizationShortName,
    this.brandName,
    this.logoFileId,
    this.logoFilename,
    this.engravingText,
  });

  factory CalculatorBranding.fromJson(Map<String, dynamic> json) {
    return CalculatorBranding(
      brandingId: _nullableString(json['branding_id'] ?? json['id']),
      organizationId: _nullableString(
        json['organization_id'] ?? json['branding_organization_id'] ?? json['child_organization_id'],
      ),
      organizationShortName: _nullableString(
        json['organization_short_name'] ?? json['short_name'] ?? json['display_name'] ?? json['legal_name'],
      ),
      brandName: _nullableString(json['branding_brand_name'] ?? json['brand_name']),
      logoFileId: _nullableString(json['branding_logo_file_id'] ?? json['logo_file_id']),
      logoFilename: _nullableString(json['branding_logo_filename'] ?? json['logo_filename'] ?? json['logo_original_filename']),
      engravingText: _nullableString(json['branding_engraving_text'] ?? json['engraving_text']),
    );
  }

  final String? brandingId;
  final String? organizationId;
  final String? organizationShortName;
  final String? brandName;
  final String? logoFileId;
  final String? logoFilename;
  final String? engravingText;

  bool get hasLogo => logoFileId != null && logoFileId!.isNotEmpty;

  String get shortLabel {
    final raw = organizationShortName ?? brandName ?? '';
    final value = raw.trim();
    return value.isEmpty ? 'Logo' : value;
  }

  Map<String, dynamic> toCalculationJson({
    required String sourceCode,
    bool engravingEnabled = false,
  }) {
    return {
      'source_code': sourceCode,
      if (brandingId != null && brandingId!.isNotEmpty) 'branding_id': brandingId,
      if (organizationId != null && organizationId!.isNotEmpty) 'organization_id': organizationId,
      if (organizationShortName != null && organizationShortName!.isNotEmpty) 'organization_short_name': organizationShortName,
      if (brandName != null && brandName!.isNotEmpty) 'brand_name': brandName,
      if (logoFileId != null && logoFileId!.isNotEmpty) 'logo_file_id': logoFileId,
      if (logoFilename != null && logoFilename!.isNotEmpty) 'logo_filename': logoFilename,
      if (engravingText != null && engravingText!.isNotEmpty) 'engraving_text': engravingText,
      'engraving_enabled': engravingEnabled,
    };
  }
}

class CalculatorOption {
  const CalculatorOption({
    required this.id,
    required this.code,
    required this.label,
    this.raw = const {},
  });

  factory CalculatorOption.fromJson(Map<String, dynamic> json) {
    return CalculatorOption(
      id: _string(json['id'] ?? json['code']),
      code: _string(json['code'] ?? json['id']),
      label: _string(json['label'] ?? json['name'] ?? json['display_name'] ?? json['legal_name'] ?? json['code'] ?? json['id']),
      raw: json,
    );
  }

  final String id;
  final String code;
  final String label;
  final Map<String, dynamic> raw;
}

class CalculatorTemplateOption {
  const CalculatorTemplateOption({
    required this.id,
    required this.code,
    required this.name,
    required this.productFamilyId,
    required this.productFamilyCode,
    required this.productFamilyName,
    this.defaultValues = const {},
    this.uiSchema = const {},
    this.parametersModuleId,
    this.parametersModuleData = const {},
    this.roofParameters = const {},
    this.roofParameterMissingKeys = const [],
  });

  factory CalculatorTemplateOption.fromJson(Map<String, dynamic> json) {
    return CalculatorTemplateOption(
      id: _string(json['id']),
      code: _string(json['code']),
      name: _string(json['name']),
      productFamilyId: _string(json['product_family_id']),
      productFamilyCode: _string(json['product_family_code']),
      productFamilyName: _string(json['product_family_name']),
      defaultValues: _map(json['default_values_json']),
      uiSchema: _map(json['ui_schema_json']),
      parametersModuleId: _nullableString(json['parameters_module_id']),
      parametersModuleData: _map(json['parameters_module_data_json']),
      roofParameters: _map(json['roof_parameters_json']),
      roofParameterMissingKeys: (json['roof_parameter_missing_keys'] as List? ?? const [])
          .map((entry) => '$entry')
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  final String id;
  final String code;
  final String name;
  final String productFamilyId;
  final String productFamilyCode;
  final String productFamilyName;
  final Map<String, dynamic> defaultValues;
  final Map<String, dynamic> uiSchema;
  final String? parametersModuleId;
  final Map<String, dynamic> parametersModuleData;
  final Map<String, dynamic> roofParameters;
  final List<String> roofParameterMissingKeys;

  bool get hasCompleteRoofParameters => parametersModuleId != null && roofParameterMissingKeys.isEmpty && roofParameters.isNotEmpty;

  int? get defaultHeightMm => _intOrNull(
        defaultValues['default_height'] ?? defaultValues['defaultHeight'],
      );

  String get statiktragerLengthCalculationDefaultMethod {
    final moduleParameters = _map(
      parametersModuleData['tds_glass_params'] ??
          parametersModuleData['tdsGlassParams'],
    );
    final value = _string(
      roofParameters['statiktragerLengthCalculationDefaultMethod'] ??
          roofParameters['statiktrager_length_calculation_default_method'] ??
          moduleParameters['statiktragerLengthCalculationDefaultMethod'] ??
          moduleParameters['statiktrager_length_calculation_default_method'] ??
          roofParameters['statiktragerLengthCalculationMethod'] ??
          roofParameters['statiktrager_length_calculation_method'] ??
          moduleParameters['statiktragerLengthCalculationMethod'] ??
          moduleParameters['statiktrager_length_calculation_method'],
    );
    return const {'legacy_rounded', 'shortest_sku', 'installed_length'}.contains(value)
        ? value
        : 'legacy_rounded';
  }

  List<CalculatorOption> get statiktragerLengthCalculationMethods {
    final moduleParameters = _map(
      parametersModuleData['tds_glass_params'] ??
          parametersModuleData['tdsGlassParams'],
    );
    final raw = roofParameters['statiktragerLengthCalculationMethods'] ??
        roofParameters['statiktrager_length_calculation_methods'] ??
        moduleParameters['statiktragerLengthCalculationMethods'] ??
        moduleParameters['statiktrager_length_calculation_methods'];
    final configured = _list(raw)
        .map(CalculatorOption.fromJson)
        .where((entry) => const {
              'legacy_rounded',
              'shortest_sku',
              'installed_length',
            }.contains(entry.code))
        .toList(growable: false);
    if (configured.isNotEmpty) return configured;
    return const [
      CalculatorOption(
        id: 'legacy_rounded',
        code: 'legacy_rounded',
        label: 'Legacy rounding (1000 mm / x100 + 100 mm)',
      ),
      CalculatorOption(
        id: 'shortest_sku',
        code: 'shortest_sku',
        label: 'Shortest suitable SKU',
      ),
      CalculatorOption(
        id: 'installed_length',
        code: 'installed_length',
        label: 'Installed calculated length',
      ),
    ];
  }

  List<String> get manualSetContentArticleNos {
    final moduleParameters = _map(
      parametersModuleData['tds_glass_params'] ??
          parametersModuleData['tdsGlassParams'],
    );
    return _stringList(
      roofParameters['manualSetContentArticleNos'] ??
          roofParameters['manual_set_content_article_nos'] ??
          moduleParameters['manualSetContentArticleNos'] ??
          moduleParameters['manual_set_content_article_nos'],
    );
  }

  int? get defaultMaxGlassFieldWidthMm => _intOrNull(
        roofParameters['defaultMaxGlassFieldWidthMm'] ?? roofParameters['default_max_glass_field_width_mm'],
      );

  int get minRoofAngleDeg => _intOrNull(
        roofParameters['minRoofAngleDeg'] ?? roofParameters['min_roof_angle_deg'],
      ) ?? 2;

  int get maxRoofAngleDeg => _intOrNull(
        roofParameters['maxRoofAngleDeg'] ?? roofParameters['max_roof_angle_deg'],
      ) ?? 14;

  Map<int, int> get glassMaxFieldWidthByThicknessMm {
    final raw = roofParameters['glassMaxFieldWidthByThicknessMm']
        ?? roofParameters['glass_max_field_width_by_thickness_mm'];
    if (raw is! Map) return const {8: 750, 10: 980};
    final resolved = <int, int>{8: 750, 10: 980};
    for (final entry in raw.entries) {
      final thickness = int.tryParse('${entry.key}'.trim());
      final width = _intOrNull(entry.value);
      if (thickness != null && width != null && thickness > 0 && width > 0) {
        resolved[thickness] = width;
      }
    }
    return resolved;
  }

  int maxGlassFieldWidthFor(String? coveringCode) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(coveringCode ?? '');
    final thickness = match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'))?.round();
    return glassMaxFieldWidthByThicknessMm[thickness]
        ?? defaultMaxGlassFieldWidthMm
        ?? 750;
  }
}

class CalculatorCatalogItemOption {
  const CalculatorCatalogItemOption({
    required this.id,
    required this.itemTypeCode,
    required this.baseCode,
    required this.name,
    this.profileNo,
    this.shortName,
    this.measureTypeCode,
    this.packageUnitCode,
    this.packageContentQty,
    this.packageContentUnitCode,
    this.defaultSalesUnitCode,
    this.allowedSalesUnitCodes = const [],
    this.saleRoundingCode,
    this.priceBasisUnitCode,
    this.defaultLengthMm,
    this.defaultColorCode,
    this.mediaFileId,
    this.mediaLargeFileId,
    this.mediaKind,
    this.raw = const {},
  });

  factory CalculatorCatalogItemOption.fromJson(Map<String, dynamic> json) {
    return CalculatorCatalogItemOption(
      id: _string(json['id']),
      itemTypeCode: _string(json['item_type_code']),
      baseCode: _string(json['base_code']),
      name: _string(json['name']),
      profileNo: _nullableString(json['profile_no']),
      shortName: _nullableString(json['short_name']),
      measureTypeCode: _nullableString(json['measure_type_code']),
      packageUnitCode: _nullableString(json['package_unit_code']),
      packageContentQty: _numOrNull(json['package_content_qty']),
      packageContentUnitCode: _nullableString(json['package_content_unit_code']),
      defaultSalesUnitCode: _nullableString(json['default_sales_unit_code']),
      allowedSalesUnitCodes: _stringList(json['allowed_sales_unit_codes']),
      saleRoundingCode: _nullableString(json['sale_rounding_code']),
      priceBasisUnitCode: _nullableString(json['price_basis_unit_code']),
      defaultLengthMm: _lengthOrNull(json['default_length_mm']),
      defaultColorCode: _nullableString(json['default_color_code']),
      mediaFileId: _nullableString(json['media_file_id'] ?? json['primary_media_file_id'] ?? json['catalog_media_file_id']),
      mediaLargeFileId: _nullableString(json['media_large_file_id'] ?? json['large_media_file_id']),
      mediaKind: _nullableString(json['media_kind']),
      raw: json,
    );
  }

  final String id;
  final String itemTypeCode;
  final String baseCode;
  final String name;
  final String? profileNo;
  final String? shortName;
  final String? measureTypeCode;
  final String? packageUnitCode;
  final num? packageContentQty;
  final String? packageContentUnitCode;
  final String? defaultSalesUnitCode;
  final List<String> allowedSalesUnitCodes;
  final String? saleRoundingCode;
  final String? priceBasisUnitCode;
  final int? defaultLengthMm;
  final String? defaultColorCode;
  final String? mediaFileId;
  final String? mediaLargeFileId;
  final String? mediaKind;
  final Map<String, dynamic> raw;

  bool get isActive => _boolValue(raw['is_active'], true);
  bool get isRestoredOnly => _boolValue(raw['restored_only'], false);
  bool get isSelectable => isActive && !isRestoredOnly;

  String get displayName {
    final code = baseCode.isEmpty ? null : baseCode;
    return [code, name].whereType<String>().where((entry) => entry.isNotEmpty).join(' · ');
  }
}

class CalculatorCatalogVariantOption {
  const CalculatorCatalogVariantOption({
    required this.id,
    required this.catalogItemId,
    required this.variantSku,
    this.articleNo,
    this.profileNo,
    this.colorCode,
    this.colorName,
    this.lengthMm,
    this.glassTypeCode,
    this.coatingTypeCode,
    this.systemCode,
    this.systemName,
    this.packageUnitCode,
    this.packageContentQty,
    this.packageContentUnitCode,
    this.defaultSalesUnitCode,
    this.allowedSalesUnitCodes = const [],
    this.saleRoundingCode,
    this.priceBasisUnitCode,
    this.imageFileId,
    this.imageLargeFileId,
    this.raw = const {},
  });

  factory CalculatorCatalogVariantOption.fromJson(Map<String, dynamic> json) {
    return CalculatorCatalogVariantOption(
      id: _string(json['id']),
      catalogItemId: _string(json['catalog_item_id']),
      variantSku: _string(json['variant_sku']),
      articleNo: _nullableString(json['article_no']),
      profileNo: _nullableString(json['profile_no']),
      colorCode: _nullableString(json['color_code']),
      colorName: _nullableString(json['color_name']),
      lengthMm: _lengthOrNull(json['length_mm'] ?? json['default_length_mm']),
      glassTypeCode: _nullableString(json['glass_type_code']),
      coatingTypeCode: _nullableString(json['coating_type_code']),
      systemCode: _nullableString(json['system_code']),
      systemName: _nullableString(json['system_name']),
      packageUnitCode: _nullableString(json['package_unit_code']),
      packageContentQty: _numOrNull(json['package_content_qty']),
      packageContentUnitCode: _nullableString(json['package_content_unit_code']),
      defaultSalesUnitCode: _nullableString(json['default_sales_unit_code']),
      allowedSalesUnitCodes: _stringList(json['allowed_sales_unit_codes']),
      saleRoundingCode: _nullableString(json['sale_rounding_code']),
      priceBasisUnitCode: _nullableString(json['price_basis_unit_code']),
      imageFileId: _nullableString(json['image_file_id']),
      imageLargeFileId: _nullableString(json['image_large_file_id'] ?? json['large_image_file_id']),
      raw: json,
    );
  }

  final String id;
  final String catalogItemId;
  final String variantSku;
  final String? articleNo;
  final String? profileNo;
  final String? colorCode;
  final String? colorName;
  final int? lengthMm;
  final String? glassTypeCode;
  final String? coatingTypeCode;
  final String? systemCode;
  final String? systemName;
  final String? packageUnitCode;
  final num? packageContentQty;
  final String? packageContentUnitCode;
  final String? defaultSalesUnitCode;
  final List<String> allowedSalesUnitCodes;
  final String? saleRoundingCode;
  final String? priceBasisUnitCode;
  final String? imageFileId;
  final String? imageLargeFileId;
  final Map<String, dynamic> raw;

  bool get isActive => _boolValue(raw['is_active'], true);
  bool get parentItemIsActive => _boolValue(raw['parent_item_is_active'], true);
  bool get isRestoredOnly => _boolValue(raw['restored_only'], false);
  bool get isSelectable => isActive && parentItemIsActive && !isRestoredOnly;

  String get displayName {
    final parts = [
      if (profileNo != null && profileNo!.isNotEmpty) profileNo,
      if (variantSku.isNotEmpty) variantSku,
      if (articleNo != null && articleNo!.isNotEmpty) articleNo,
      if (colorName != null && colorName!.isNotEmpty) colorName,
      if (lengthMm != null) '$lengthMm mm',
    ];
    return parts.join(' · ');
  }
}


class CalculatorAdditionalHandlingOption {
  const CalculatorAdditionalHandlingOption({
    required this.parentCatalogItemId,
    required this.catalogItemId,
    required this.name,
    this.itemTypeCode,
    this.baseCode,
    this.profileNo,
    this.unitCode,
    this.maxQuantity = 1,
    this.unitPrice,
    this.sortOrder = 100,
    this.raw = const {},
  });

  factory CalculatorAdditionalHandlingOption.fromJson(Map<String, dynamic> json) {
    return CalculatorAdditionalHandlingOption(
      parentCatalogItemId: _string(json['parent_catalog_item_id']),
      catalogItemId: _string(json['catalog_item_id']),
      itemTypeCode: _nullableString(json['item_type_code']),
      baseCode: _nullableString(json['base_code']),
      profileNo: _nullableString(json['profile_no']),
      name: _string(json['name']),
      unitCode: _nullableString(json['unit_code']),
      maxQuantity: _numOrDefault(json['max_quantity'], 1),
      unitPrice: _numOrNull(json['unit_price']),
      sortOrder: _intOrNull(json['sort_order']) ?? 100,
      raw: json,
    );
  }

  final String parentCatalogItemId;
  final String catalogItemId;
  final String? itemTypeCode;
  final String? baseCode;
  final String? profileNo;
  final String name;
  final String? unitCode;
  final num maxQuantity;
  final num? unitPrice;
  final int sortOrder;
  final Map<String, dynamic> raw;

  String get displayName {
    final parts = [
      if (baseCode != null && baseCode!.isNotEmpty) baseCode,
      if (profileNo != null && profileNo!.isNotEmpty) profileNo,
      if (name.isNotEmpty) name,
    ];
    return parts.whereType<String>().join(' · ');
  }
}

class CalculatorSelectedAdditionalHandling {
  const CalculatorSelectedAdditionalHandling({
    required this.catalogItemId,
    required this.quantity,
  });

  factory CalculatorSelectedAdditionalHandling.fromJson(Map<String, dynamic> json) {
    return CalculatorSelectedAdditionalHandling(
      catalogItemId: _string(json['catalog_item_id']),
      quantity: _numOrDefault(json['quantity'], 0),
    );
  }

  final String catalogItemId;
  final num quantity;

  Map<String, dynamic> toJson() {
    return {
      'catalog_item_id': catalogItemId,
      'quantity': quantity,
    };
  }
}


class CalculatorSetContentsPreview {
  const CalculatorSetContentsPreview({
    required this.tabs,
    required this.source,
    required this.trace,
    required this.warnings,
    required this.raw,
  });

  factory CalculatorSetContentsPreview.fromJson(Map<String, dynamic> json) {
    return CalculatorSetContentsPreview(
      tabs: _list(json['tabs']).map(CalculatorSetContentTab.fromJson).toList(),
      source: _map(json['source']),
      trace: _list(json['trace']),
      warnings: _list(json['warnings']),
      raw: json,
    );
  }

  final List<CalculatorSetContentTab> tabs;
  final Map<String, dynamic> source;
  final List<Map<String, dynamic>> trace;
  final List<Map<String, dynamic>> warnings;
  final Map<String, dynamic> raw;

  List<Map<String, dynamic>> get standardBom => _list(raw['standard_bom'] ?? raw['standardBom']);
  List<Map<String, dynamic>> get calculatedBom => _list(raw['calculated_bom'] ?? raw['calculatedBom']);
  List<Map<String, dynamic>> get effectiveBom => _list(raw['effective_bom'] ?? raw['effectiveBom']);
  List<Map<String, dynamic>> get manualBom => _list(raw['manual_bom'] ?? raw['manualBom']);
  List<Map<String, dynamic>> get derivedAccessories => _list(raw['derived_accessories'] ?? raw['derivedAccessories']);
  List<Map<String, dynamic>> get setDeltaBom => _list(raw['set_delta_bom'] ?? raw['setDeltaBom']);
}

class CalculatorSetContentTab {
  const CalculatorSetContentTab({
    required this.id,
    required this.label,
    required this.items,
    this.geometryKey = const {},
  });

  factory CalculatorSetContentTab.fromJson(Map<String, dynamic> json) {
    return CalculatorSetContentTab(
      id: _string(json['id']).isEmpty ? 'part-1' : _string(json['id']),
      label: _string(json['label']).isEmpty ? 'Module 1' : _string(json['label']),
      geometryKey: _map(json['geometry_key']),
      items: _list(json['items']).map(CalculatorSetContentItem.fromJson).toList(),
    );
  }

  final String id;
  final String label;
  final Map<String, dynamic> geometryKey;
  final List<CalculatorSetContentItem> items;

  CalculatorSetContentTab copyWith({
    String? id,
    String? label,
    Map<String, dynamic>? geometryKey,
    List<CalculatorSetContentItem>? items,
  }) {
    return CalculatorSetContentTab(
      id: id ?? this.id,
      label: label ?? this.label,
      geometryKey: geometryKey ?? this.geometryKey,
      items: items ?? this.items,
    );
  }

  int? geometryInt(String key) => _intOrNull(geometryKey[key]);
  String? geometryString(String key) => _nullableString(geometryKey[key]);

  String get moduleRole => _nullableString(geometryKey['role']) ?? '';
  int? get moduleWidthMm => geometryInt('width_mm');
  int? get moduleDepthMm => geometryInt('depth_mm');
  String? get moduleCoveringCode =>
      geometryString('glass_type_code') ?? geometryString('covering_code');
  int? get moduleMaxGlassFieldWidthMm =>
      geometryInt('max_glass_field_width_mm');

  // Backward-compatible getters kept for Set contents and older saved quotes.
  int? get blockWidthMm => moduleWidthMm;
  int? get blockDepthMm => moduleDepthMm;
  int? get blockHeightMm => geometryInt('height_mm');

  CalculatorSetContentTab duplicateAs(int index) {
    return CalculatorSetContentTab(
      id: 'part-$index',
      label: 'Module $index',
      geometryKey: geometryKey,
      items: items.map((entry) => entry.copyWith()).toList(),
    );
  }

  CalculatorSetContentTab withGeometryValue(String key, int? value) {
    final nextGeometry = <String, dynamic>{...geometryKey};
    if (value == null || value <= 0) {
      nextGeometry.remove(key);
    } else {
      nextGeometry[key] = value;
    }
    return copyWith(geometryKey: nextGeometry);
  }


  CalculatorSetContentTab withGeometryText(String key, String? value) {
    final nextGeometry = <String, dynamic>{...geometryKey};
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      nextGeometry.remove(key);
    } else {
      nextGeometry[key] = normalized;
    }
    return copyWith(geometryKey: nextGeometry);
  }

  CalculatorSetContentTab withGeometryRole(String role) {
    final normalizedRole = role.trim();
    final nextGeometry = <String, dynamic>{...geometryKey};
    if (normalizedRole.isEmpty) {
      nextGeometry.remove('role');
    } else {
      nextGeometry['role'] = normalizedRole;
    }
    return copyWith(geometryKey: nextGeometry);
  }

  Map<String, dynamic> toCalculationJson() {
    return {
      'id': id,
      'label': label,
      if (geometryKey.isNotEmpty) 'geometry_key': geometryKey,
      'items': items.where((entry) => entry.shouldPersist).map((entry) => entry.toCalculationJson()).toList(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      if (geometryKey.isNotEmpty) 'geometry_key': geometryKey,
      'items': items.where((entry) => entry.shouldPersist).map((entry) => entry.toJson()).toList(),
    };
  }
}

class CalculatorSetContentItem {
  const CalculatorSetContentItem({
    required this.catalogItemId,
    this.catalogVariantId,
    this.quantity = 1,
    this.salesUnitCode,
    this.lengthMm,
    this.name,
    this.itemTypeCode,
    this.baseCode,
    this.profileNo,
    this.articleNo,
    this.variantSku,
    this.unitCode,
    this.editableLength = false,
    this.enabled = true,
    this.raw = const {},
  });

  factory CalculatorSetContentItem.fromJson(Map<String, dynamic> json) {
    final sourceComponent = _map(json['source_component']);
    String? metaString(String snakeKey, [String? camelKey]) {
      return _nullableString(json[snakeKey]) ?? _nullableString(sourceComponent[snakeKey]) ?? (camelKey == null ? null : _nullableString(sourceComponent[camelKey]));
    }

    final itemTypeCode = metaString('item_type_code', 'itemTypeCode');
    final lengthMm = _numOrNull(json['length_mm'] ?? sourceComponent['length_mm'] ?? sourceComponent['lengthMm']);
    final editable = json['editable_length'] == true
        || sourceComponent['editable_length'] == true
        || sourceComponent['editableLength'] == true
        || (itemTypeCode ?? '').toLowerCase().contains('profile')
        || (lengthMm != null && lengthMm > 1);
    return CalculatorSetContentItem(
      catalogItemId: _string(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      quantity: _numOrDefault(json['quantity'], 1),
      salesUnitCode: _nullableString(json['sales_unit_code']),
      lengthMm: lengthMm,
      name: metaString('name') ?? metaString('component_name', 'componentName'),
      itemTypeCode: itemTypeCode,
      baseCode: metaString('base_code', 'baseCode'),
      profileNo: metaString('profile_no', 'profileNo'),
      articleNo: metaString('article_no', 'articleNo'),
      variantSku: metaString('variant_sku', 'variantSku'),
      unitCode: metaString('unit_code', 'unitCode'),
      editableLength: editable,
      enabled: json['enabled'] != false,
      raw: json,
    );
  }

  final String catalogItemId;
  final String? catalogVariantId;
  final num quantity;
  final String? salesUnitCode;
  final num? lengthMm;
  final String? name;
  final String? itemTypeCode;
  final String? baseCode;
  final String? profileNo;
  final String? articleNo;
  final String? variantSku;
  final String? unitCode;
  final bool editableLength;
  final bool enabled;
  final Map<String, dynamic> raw;

  bool get isProfile => editableLength || (itemTypeCode ?? '').toLowerCase().contains('profile') || (lengthMm != null && lengthMm! > 1);

  bool get isAccessory => (itemTypeCode ?? '').toLowerCase().contains('accessory');

  Map<String, dynamic> get sourceComponent => _map(raw['source_component']);
  String get sourceType => _nullableString(sourceComponent['source_type'] ?? sourceComponent['sourceType']) ?? 'manual';
  String? get segmentId => _nullableString(sourceComponent['segment_id'] ?? sourceComponent['segmentId']);
  String get overrideState => _nullableString(sourceComponent['override_state'] ?? sourceComponent['overrideState']) ?? 'automatic';
  num? get calculatedQuantity => _numOrNull(sourceComponent['calculated_quantity'] ?? sourceComponent['calculatedQuantity']);
  num? get calculatedLengthMm => _numOrNull(sourceComponent['calculated_length_mm'] ?? sourceComponent['calculatedLengthMm']);
  bool get overrideApplied => sourceComponent['override_applied'] == true || sourceComponent['overrideApplied'] == true;
  int? get stockLengthMm => _intOrNull(sourceComponent['catalog_variant_length_mm'] ?? sourceComponent['catalogVariantLengthMm']);
  int? get glassFieldIndex => _intOrNull(sourceComponent['glass_field_index'] ?? sourceComponent['glassFieldIndex']);
  int? get glassFieldCount => _intOrNull(sourceComponent['glass_field_count'] ?? sourceComponent['glassFieldCount']);
  int? get cutGroupIndex => _intOrNull(sourceComponent['cut_group_index'] ?? sourceComponent['cutGroupIndex']);
  int? get cutGroupCount => _intOrNull(sourceComponent['cut_group_count'] ?? sourceComponent['cutGroupCount']);
  bool get isCalculated => sourceType == 'calculated';
  bool get isManual => sourceType == 'manual' || sourceType == 'legacy';
  bool get isDerivedOverride => sourceType == 'derived_accessory_override' || sourceType == 'derived';
  bool get hasCalculatedValueOverride =>
      (calculatedQuantity != null && calculatedQuantity != quantity) ||
      (calculatedLengthMm != null && calculatedLengthMm != lengthMm);
  bool get isOverridden => overrideState == 'excluded' ||
      hasCalculatedValueOverride ||
      (overrideState == 'overridden' && !overrideApplied);
  bool get shouldPersist => !isCalculated || !enabled || isOverridden;

  CalculatorSetContentItem copyWith({
    String? catalogItemId,
    bool clearCatalogItem = false,
    String? catalogVariantId,
    bool clearCatalogVariant = false,
    num? quantity,
    String? salesUnitCode,
    bool clearSalesUnit = false,
    num? lengthMm,
    bool clearLength = false,
    String? name,
    String? itemTypeCode,
    String? baseCode,
    String? profileNo,
    String? articleNo,
    String? variantSku,
    String? unitCode,
    bool? editableLength,
    bool? enabled,
    Map<String, dynamic>? raw,
  }) {
    return CalculatorSetContentItem(
      catalogItemId: clearCatalogItem ? '' : catalogItemId ?? this.catalogItemId,
      catalogVariantId: clearCatalogVariant ? null : catalogVariantId ?? this.catalogVariantId,
      quantity: quantity ?? this.quantity,
      salesUnitCode: clearSalesUnit ? null : salesUnitCode ?? this.salesUnitCode,
      lengthMm: clearLength ? null : lengthMm ?? this.lengthMm,
      name: name ?? this.name,
      itemTypeCode: itemTypeCode ?? this.itemTypeCode,
      baseCode: baseCode ?? this.baseCode,
      profileNo: profileNo ?? this.profileNo,
      articleNo: articleNo ?? this.articleNo,
      variantSku: variantSku ?? this.variantSku,
      unitCode: unitCode ?? this.unitCode,
      editableLength: editableLength ?? this.editableLength,
      enabled: enabled ?? this.enabled,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toCalculationJson() {
    final sourceComponent = {
      ..._map(raw['source_component']),
      if (name != null && name!.isNotEmpty) 'name': name,
      if (itemTypeCode != null && itemTypeCode!.isNotEmpty) 'item_type_code': itemTypeCode,
      if (baseCode != null && baseCode!.isNotEmpty) 'base_code': baseCode,
      if (profileNo != null && profileNo!.isNotEmpty) 'profile_no': profileNo,
      if (articleNo != null && articleNo!.isNotEmpty) 'article_no': articleNo,
      if (variantSku != null && variantSku!.isNotEmpty) 'variant_sku': variantSku,
      if (unitCode != null && unitCode!.isNotEmpty) 'unit_code': unitCode,
      if (editableLength) 'editable_length': true,
    };

    return {
      'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
      if (salesUnitCode != null && salesUnitCode!.isNotEmpty) 'sales_unit_code': salesUnitCode,
      if (lengthMm != null && lengthMm! > 0) 'length_mm': lengthMm,
      'enabled': enabled,
      if (sourceComponent.isNotEmpty) 'source_component': sourceComponent,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toCalculationJson(),
      if (!enabled) 'enabled': false,
    };
  }
}

class CalculatorMarkiseSelection {
  const CalculatorMarkiseSelection({
    required this.moduleIndex,
    required this.moduleRole,
    required this.typeCode,
  });

  factory CalculatorMarkiseSelection.fromJson(Map<String, dynamic> json) {
    return CalculatorMarkiseSelection(
      moduleIndex: _intOrNull(json['module_index'] ?? json['moduleIndex']),
      moduleRole: _string(json['module_role'] ?? json['moduleRole']),
      typeCode: _string(json['type_code'] ?? json['typeCode']),
    );
  }

  final int? moduleIndex;
  final String moduleRole;
  final String typeCode;

  Map<String, dynamic> toJson() => {
        if (moduleIndex != null) 'module_index': moduleIndex,
        'module_role': moduleRole,
        'type_code': typeCode,
      };
}

class CalculatorDraft {
  const CalculatorDraft({
    this.organizationId,
    this.productFamilyId,
    this.templateId,
    this.priceMode = 'dealer_sales',
    this.modelCode,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.roofAngleDeg,
    this.roofRearHeightMm,
    this.roofFrontHeightMm,
    this.forceOddBeams = false,
    this.wallMounted = true,
    this.coveringEnabled = true,
    this.markiseEnabled = false,
    this.markiseExcludeFromPrice = false,
    this.markiseSelections = const [],
    this.addStaticBeamAssembly = false,
    this.staticBeamPositionCode = 'front_overhang',
    this.staticBeamLengthCalculationMethod = 'legacy_rounded',
    this.maxGlassFieldWidthMm,
    this.coveringCode,
    this.colorCode,
    this.productionColorCode,
    this.handoverTypeCode,
    this.completionWeek,
    this.quoteNoExternal,
    this.externalNotes,
    this.relatedCustomerId,
    this.branding = const {},
    this.options = const [],
    this.setContents = const [],
    this.missingSetPieceAbzugArticleNos = const [],
  });

  factory CalculatorDraft.fromCalculationJson(
    Map<String, dynamic> json, {
    String? productFamilyId,
    Map<String, dynamic>? resultJson,
  }) {
    final dimensions = _map(json['dimensions']);
    final roof = _map(json['roof']);
    final markise = _map(json['markise']);
    final options = json['options'] is List
        ? (json['options'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSelectedOption.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSelectedOption>[];
    final inputSetContents = json['set_contents'] is List
        ? (json['set_contents'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSetContentTab.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSetContentTab>[];
    final resultSetContents = _list(
      resultJson?['setContents'] ?? resultJson?['set_contents'],
    ).map(CalculatorSetContentTab.fromJson).toList();
    final savedSetContents = _restoreSetContentItems(
      inputSetContents,
      resultSetContents,
    );
    final roofModules = _list(roof['modules']);
    final restoredSetContents = _restoreRoofModuleGeometry(
      savedSetContents,
      roofModules,
    );
    final coveringEnabledValue =
        roof['add_covering'] ?? roof['addCovering'];
    final coveringEnabled = coveringEnabledValue is bool
        ? coveringEnabledValue
        : true;
    final legacyCoveringCode = _nullableString(json['covering_code']);
    final legacyMaxGlassFieldWidth = _intOrNull(
      roof['max_glass_field_width_mm'],
    );
    final setContents = [
      for (final tab in restoredSetContents)
        tab
            .withGeometryText(
              'covering_code',
              coveringEnabled
                  ? tab.moduleCoveringCode ?? legacyCoveringCode
                  : null,
            )
            .withGeometryText(
              'glass_type_code',
              coveringEnabled
                  ? tab.moduleCoveringCode ?? legacyCoveringCode
                  : null,
            )
            .withGeometryValue(
              'max_glass_field_width_mm',
              coveringEnabled
                  ? tab.moduleMaxGlassFieldWidthMm ?? legacyMaxGlassFieldWidth
                  : null,
            ),
    ];
    final wallMounted = roof['wall_mounted'] is bool
        ? roof['wall_mounted'] as bool
        : true;
    final savedStaticBeamPositionCode = _string(
      roof['static_beam_position_code'] ?? roof['staticBeamPositionCode'],
    );
    const validStaticBeamPositionCodes = {
      'rear_wall',
      'under_gutter',
      'front_overhang',
      'wall_extension',
    };
    final normalizedStaticBeamPositionCode =
        validStaticBeamPositionCodes.contains(savedStaticBeamPositionCode)
            ? savedStaticBeamPositionCode
            : 'front_overhang';
    final staticBeamPositionCode = !wallMounted && normalizedStaticBeamPositionCode == 'rear_wall'
        ? 'front_overhang'
        : normalizedStaticBeamPositionCode;

    return CalculatorDraft(
      organizationId: _nullableString(json['organization_id']),
      productFamilyId: productFamilyId,
      templateId: _nullableString(json['template_id']),
      priceMode: _string(json['price_mode']).isEmpty ? 'dealer_sales' : _string(json['price_mode']),
      modelCode: _nullableString(json['model_code']),
      widthMm: _intOrNull(dimensions['width_mm']),
      depthMm: _intOrNull(dimensions['depth_mm']),
      heightMm: _intOrNull(dimensions['height_mm']),
      roofAngleDeg: _intOrNull(roof['angle_deg']),
      roofRearHeightMm: _intOrNull(roof['rear_height_mm']),
      roofFrontHeightMm: _intOrNull(roof['front_height_mm']),
      forceOddBeams: roof['force_odd_beams'] is bool ? roof['force_odd_beams'] as bool : false,
      wallMounted: wallMounted,
      coveringEnabled: coveringEnabled,
      markiseEnabled: markise['enabled'] is bool ? markise['enabled'] as bool : false,
      markiseExcludeFromPrice: markise['exclude_from_price'] is bool
          ? markise['exclude_from_price'] as bool
          : false,
      markiseSelections: _list(markise['segments'])
          .map(CalculatorMarkiseSelection.fromJson)
          .where((entry) => entry.moduleRole.isNotEmpty && entry.typeCode.isNotEmpty)
          .toList(growable: false),
      addStaticBeamAssembly: (roof['add_static_beam_assembly'] ?? roof['addStaticBeamAssembly']) is bool
          ? (roof['add_static_beam_assembly'] ?? roof['addStaticBeamAssembly']) as bool
          : false,
      staticBeamPositionCode: staticBeamPositionCode,
      staticBeamLengthCalculationMethod: _staticBeamLengthCalculationMethod(
        roof['static_beam_length_calculation_method'] ??
            roof['staticBeamLengthCalculationMethod'],
      ),
      maxGlassFieldWidthMm: coveringEnabled
          ? _intOrNull(roof['max_glass_field_width_mm'])
          : null,
      coveringCode: coveringEnabled
          ? _nullableString(json['covering_code'])
          : null,
      colorCode: _nullableString(json['color_code']),
      productionColorCode: _nullableString(
        json['production_color_code'] ?? json['productionColorCode'],
      ),
      handoverTypeCode: _nullableString(json['handover_type_code']),
      completionWeek: _intOrNull(json['completion_week'] ?? json['completionWeek']),
      quoteNoExternal: _nullableString(json['quote_no_external'] ?? json['quoteNoExternal']),
      externalNotes: _nullableString(json['external_notes'] ?? json['externalNotes']),
      relatedCustomerId: _nullableString(json['related_customer_id'] ?? json['relatedCustomerId']),
      branding: _map(json['branding']),
      options: options,
      setContents: setContents,
      missingSetPieceAbzugArticleNos: _stringList(
        json['missing_set_piece_abzug_article_nos'] ??
            json['missingSetPieceAbzugArticleNos'],
      ),
    );
  }

  final String? organizationId;
  final String? productFamilyId;
  final String? templateId;
  final String priceMode;
  final String? modelCode;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final int? roofAngleDeg;
  final int? roofRearHeightMm;
  final int? roofFrontHeightMm;
  final bool forceOddBeams;
  final bool wallMounted;
  final bool coveringEnabled;
  final bool markiseEnabled;
  final bool markiseExcludeFromPrice;
  final List<CalculatorMarkiseSelection> markiseSelections;
  final bool addStaticBeamAssembly;
  final String staticBeamPositionCode;
  final String staticBeamLengthCalculationMethod;
  final int? maxGlassFieldWidthMm;
  final String? coveringCode;
  final String? colorCode;
  final String? productionColorCode;
  final String? handoverTypeCode;
  final int? completionWeek;
  final String? quoteNoExternal;
  final String? externalNotes;
  final String? relatedCustomerId;
  final Map<String, dynamic> branding;
  final List<CalculatorSelectedOption> options;
  final List<CalculatorSetContentTab> setContents;
  final List<String> missingSetPieceAbzugArticleNos;

  CalculatorDraft copyWith({
    String? organizationId,
    bool clearOrganization = false,
    String? productFamilyId,
    bool clearProductFamily = false,
    String? templateId,
    bool clearTemplate = false,
    String? priceMode,
    String? modelCode,
    bool clearModel = false,
    int? widthMm,
    bool clearWidth = false,
    int? depthMm,
    bool clearDepth = false,
    int? heightMm,
    bool clearHeight = false,
    int? roofAngleDeg,
    bool clearRoofAngle = false,
    int? roofRearHeightMm,
    bool clearRoofRearHeight = false,
    int? roofFrontHeightMm,
    bool clearRoofFrontHeight = false,
    bool? forceOddBeams,
    bool? wallMounted,
    bool? coveringEnabled,
    bool? markiseEnabled,
    bool? markiseExcludeFromPrice,
    List<CalculatorMarkiseSelection>? markiseSelections,
    bool? addStaticBeamAssembly,
    String? staticBeamPositionCode,
    String? staticBeamLengthCalculationMethod,
    int? maxGlassFieldWidthMm,
    bool clearMaxGlassFieldWidth = false,
    String? coveringCode,
    bool clearCovering = false,
    String? colorCode,
    bool clearColor = false,
    String? productionColorCode,
    bool clearProductionColorCode = false,
    String? handoverTypeCode,
    bool clearHandover = false,
    int? completionWeek,
    bool clearCompletionWeek = false,
    String? quoteNoExternal,
    bool clearQuoteNoExternal = false,
    String? externalNotes,
    bool clearExternalNotes = false,
    String? relatedCustomerId,
    bool clearRelatedCustomer = false,
    Map<String, dynamic>? branding,
    bool clearBranding = false,
    List<CalculatorSelectedOption>? options,
    List<CalculatorSetContentTab>? setContents,
    List<String>? missingSetPieceAbzugArticleNos,
  }) {
    return CalculatorDraft(
      organizationId: clearOrganization ? null : organizationId ?? this.organizationId,
      productFamilyId: clearProductFamily ? null : productFamilyId ?? this.productFamilyId,
      templateId: clearTemplate ? null : templateId ?? this.templateId,
      priceMode: priceMode ?? this.priceMode,
      modelCode: clearModel ? null : modelCode ?? this.modelCode,
      widthMm: clearWidth ? null : widthMm ?? this.widthMm,
      depthMm: clearDepth ? null : depthMm ?? this.depthMm,
      heightMm: clearHeight ? null : heightMm ?? this.heightMm,
      roofAngleDeg: clearRoofAngle ? null : roofAngleDeg ?? this.roofAngleDeg,
      roofRearHeightMm: clearRoofRearHeight ? null : roofRearHeightMm ?? this.roofRearHeightMm,
      roofFrontHeightMm: clearRoofFrontHeight ? null : roofFrontHeightMm ?? this.roofFrontHeightMm,
      forceOddBeams: forceOddBeams ?? this.forceOddBeams,
      wallMounted: wallMounted ?? this.wallMounted,
      coveringEnabled: coveringEnabled ?? this.coveringEnabled,
      markiseEnabled: markiseEnabled ?? this.markiseEnabled,
      markiseExcludeFromPrice:
          markiseExcludeFromPrice ?? this.markiseExcludeFromPrice,
      markiseSelections: markiseSelections ?? this.markiseSelections,
      addStaticBeamAssembly:
          addStaticBeamAssembly ?? this.addStaticBeamAssembly,
      staticBeamPositionCode:
          staticBeamPositionCode ?? this.staticBeamPositionCode,
      staticBeamLengthCalculationMethod: staticBeamLengthCalculationMethod ??
          this.staticBeamLengthCalculationMethod,
      maxGlassFieldWidthMm: clearMaxGlassFieldWidth ? null : maxGlassFieldWidthMm ?? this.maxGlassFieldWidthMm,
      coveringCode: clearCovering ? null : coveringCode ?? this.coveringCode,
      colorCode: clearColor ? null : colorCode ?? this.colorCode,
      productionColorCode:
          clearProductionColorCode ? null : productionColorCode ?? this.productionColorCode,
      handoverTypeCode: clearHandover ? null : handoverTypeCode ?? this.handoverTypeCode,
      completionWeek: clearCompletionWeek ? null : completionWeek ?? this.completionWeek,
      quoteNoExternal: clearQuoteNoExternal ? null : quoteNoExternal ?? this.quoteNoExternal,
      externalNotes: clearExternalNotes ? null : externalNotes ?? this.externalNotes,
      relatedCustomerId: clearRelatedCustomer ? null : relatedCustomerId ?? this.relatedCustomerId,
      branding: clearBranding ? const {} : branding ?? this.branding,
      options: options ?? this.options,
      setContents: setContents ?? this.setContents,
      missingSetPieceAbzugArticleNos:
          missingSetPieceAbzugArticleNos ?? this.missingSetPieceAbzugArticleNos,
    );
  }


  String? get _commonCoveringCode {
    if (!coveringEnabled) return null;
    final codes = setContents
        .map((tab) => tab.moduleCoveringCode)
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (codes.length == 1) return codes.first;
    if (codes.isEmpty && (coveringCode ?? '').trim().isNotEmpty) {
      return coveringCode!.trim();
    }
    return null;
  }

  Map<String, dynamic> _roofJson() {
    final moduleJson = <Map<String, dynamic>>[];
    for (final tab in setContents) {
      final role = tab.moduleRole.trim();
      final width = tab.moduleWidthMm;
      final depth = tab.moduleDepthMm;
      if (role.isEmpty && width == null && depth == null) continue;
      moduleJson.add({
        'role': role.isEmpty ? 'main' : role,
        if (width != null) 'width_mm': width,
        if (depth != null) 'depth_mm': depth,
        if (coveringEnabled &&
            (tab.moduleCoveringCode ?? coveringCode)?.isNotEmpty == true) ...{
          'covering_code': tab.moduleCoveringCode ?? coveringCode,
          'glass_type_code': tab.moduleCoveringCode ?? coveringCode,
        },
        if (coveringEnabled &&
            (tab.moduleMaxGlassFieldWidthMm ?? maxGlassFieldWidthMm) != null)
          'max_glass_field_width_mm':
              tab.moduleMaxGlassFieldWidthMm ?? maxGlassFieldWidthMm,
      });
    }

    final hasRoofData = (modelCode != null && modelCode!.isNotEmpty) ||
        roofAngleDeg != null ||
        roofRearHeightMm != null ||
        roofFrontHeightMm != null ||
        moduleJson.isNotEmpty;
    if (!hasRoofData) return const {};

    return {
      if (modelCode != null && modelCode!.isNotEmpty) 'model_code': modelCode,
      if (roofAngleDeg != null) 'angle_deg': roofAngleDeg,
      if (roofRearHeightMm != null) 'rear_height_mm': roofRearHeightMm,
      if (roofFrontHeightMm != null) 'front_height_mm': roofFrontHeightMm,
      'force_odd_beams': forceOddBeams,
      'wall_mounted': wallMounted,
      'add_covering': coveringEnabled,
      'add_static_beam_assembly': addStaticBeamAssembly,
      'static_beam_position_code': staticBeamPositionCode,
      'static_beam_length_calculation_method':
          staticBeamLengthCalculationMethod,
      if (coveringEnabled && maxGlassFieldWidthMm != null)
        'max_glass_field_width_mm': maxGlassFieldWidthMm,
      if (moduleJson.isNotEmpty) 'modules': moduleJson,
    };
  }

  Map<String, dynamic> _baseJson({required List<Map<String, dynamic>> setContentsJson}) {
    return {
      if (organizationId != null && organizationId!.isNotEmpty) 'organization_id': organizationId,
      if (templateId != null && templateId!.isNotEmpty) 'template_id': templateId,
      'price_mode': priceMode,
      if (modelCode != null && modelCode!.isNotEmpty) 'model_code': modelCode,
      'dimensions': {
        if (widthMm != null) 'width_mm': widthMm,
        if (depthMm != null) 'depth_mm': depthMm,
        if (heightMm != null) 'height_mm': heightMm,
      },
      if (_roofJson().isNotEmpty) 'roof': _roofJson(),
      'markise': {
        'enabled': markiseEnabled,
        'exclude_from_price': markiseExcludeFromPrice,
        'segments': markiseSelections.map((entry) => entry.toJson()).toList(),
      },
      if (_commonCoveringCode != null) 'covering_code': _commonCoveringCode,
      if (colorCode != null && colorCode!.isNotEmpty) 'color_code': colorCode,
      if (productionColorCode != null && productionColorCode!.trim().isNotEmpty)
        'production_color_code': productionColorCode!.trim(),
      if (handoverTypeCode != null && handoverTypeCode!.isNotEmpty) 'handover_type_code': handoverTypeCode,
      if (completionWeek != null) 'completion_week': completionWeek,
      if (quoteNoExternal != null && quoteNoExternal!.isNotEmpty) 'quote_no_external': quoteNoExternal,
      if (externalNotes != null && externalNotes!.isNotEmpty) 'external_notes': externalNotes,
      if (relatedCustomerId != null && relatedCustomerId!.isNotEmpty) 'related_customer_id': relatedCustomerId,
      if (branding.isNotEmpty) 'branding': branding,
      'options': options.map((entry) => entry.toJson()).toList(),
      'set_contents': setContentsJson,
      'missing_set_piece_abzug_article_nos': missingSetPieceAbzugArticleNos,
      'language_code': 'de',
    };
  }

  Map<String, dynamic> toCalculationJson() {
    final activeSetContents = setContents
        .map((entry) => entry.toCalculationJson())
        .where((entry) => (entry['items'] as List).isNotEmpty)
        .toList();

    return _baseJson(setContentsJson: activeSetContents);
  }

  Map<String, dynamic> toWorkspaceJson() {
    return _baseJson(
      setContentsJson: setContents.map((entry) => entry.toJson()).toList(),
    );
  }

  bool differsFromLoadedQuote(LoadedQuote quote) {
    return _stableJson(toWorkspaceJson()) != _stableJson(quote.normalizedInput);
  }

  bool hasSameBuyerAndShipToAs(LoadedQuote quote) {
    final currentBuyer = organizationId ?? '';
    return (quote.buyerOrganizationId ?? '') == currentBuyer &&
        (quote.shipToOrganizationId ?? '') == currentBuyer;
  }

  bool canSaveAsOptionFor(LoadedQuote? quote) {
    if (quote == null) return false;
    return differsFromLoadedQuote(quote) && hasSameBuyerAndShipToAs(quote);
  }
}

class CalculatorSelectedOption {
  const CalculatorSelectedOption({
    this.optionCode,
    this.catalogItemId,
    this.catalogVariantId,
    this.quantity = 1,
    this.salesUnitCode,
    this.lengthMm,
    this.schraegCount,
    this.additionalHandlings = const [],
  });

  factory CalculatorSelectedOption.fromJson(Map<String, dynamic> json) {
    return CalculatorSelectedOption(
      optionCode: _nullableString(json['option_code']),
      catalogItemId: _nullableString(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      salesUnitCode: _nullableString(json['sales_unit_code']),
      lengthMm: _intOrNull(json['length_mm']),
      quantity: _numOrDefault(json['quantity'], 1),
      schraegCount: _intOrNull(json['schraeg_count']),
      additionalHandlings: _list(json['additional_handlings'])
          .map(CalculatorSelectedAdditionalHandling.fromJson)
          .where((entry) => entry.catalogItemId.isNotEmpty && entry.quantity > 0)
          .toList(),
    );
  }

  final String? optionCode;
  final String? catalogItemId;
  final String? catalogVariantId;
  final num quantity;
  final String? salesUnitCode;
  final int? lengthMm;
  final int? schraegCount;
  final List<CalculatorSelectedAdditionalHandling> additionalHandlings;


  CalculatorSelectedOption copyWith({
    String? optionCode,
    bool clearOptionCode = false,
    String? catalogItemId,
    bool clearCatalogItem = false,
    String? catalogVariantId,
    bool clearCatalogVariant = false,
    num? quantity,
    String? salesUnitCode,
    bool clearSalesUnit = false,
    int? lengthMm,
    bool clearLength = false,
    int? schraegCount,
    bool clearSchraeg = false,
    List<CalculatorSelectedAdditionalHandling>? additionalHandlings,
  }) {
    return CalculatorSelectedOption(
      optionCode: clearOptionCode ? null : optionCode ?? this.optionCode,
      catalogItemId: clearCatalogItem ? null : catalogItemId ?? this.catalogItemId,
      catalogVariantId: clearCatalogVariant ? null : catalogVariantId ?? this.catalogVariantId,
      quantity: quantity ?? this.quantity,
      salesUnitCode: clearSalesUnit ? null : salesUnitCode ?? this.salesUnitCode,
      lengthMm: clearLength ? null : lengthMm ?? this.lengthMm,
      schraegCount: clearSchraeg ? null : schraegCount ?? this.schraegCount,
      additionalHandlings: additionalHandlings ?? this.additionalHandlings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (optionCode != null && optionCode!.isNotEmpty) 'option_code': optionCode,
      if (catalogItemId != null && catalogItemId!.isNotEmpty) 'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
      if (salesUnitCode != null && salesUnitCode!.isNotEmpty) 'sales_unit_code': salesUnitCode,
      if (lengthMm != null && lengthMm! > 0) 'length_mm': lengthMm,
      if (schraegCount != null && schraegCount! > 0) 'schraeg_count': schraegCount,
      if (additionalHandlings.isNotEmpty)
        'additional_handlings': additionalHandlings.map((entry) => entry.toJson()).toList(),
    };
  }
}

class CalculatorResult {
  const CalculatorResult({
    required this.status,
    required this.currency,
    required this.price,
    required this.visibleLines,
    required this.summary,
    required this.warnings,
    required this.weights,
    required this.internalPrice,
    required this.sources,
    required this.bom,
    required this.glassLines,
    required this.baseBom,
    required this.optionBom,
    required this.setContentBom,
    required this.calculatedBom,
    required this.effectiveSetBom,
    required this.manualBom,
    required this.derivedAccessories,
    required this.setDeltaBom,
    required this.derivedAccessoryDiagnostics,
    required this.manualComponentDiagnostics,
    required this.setDeltaDiagnostics,
    required this.optionDiagnostics,
    required this.setContentDiagnostics,
    required this.trace,
    required this.raw,
  });

  factory CalculatorResult.fromJson(Map<String, dynamic> json) {
    return CalculatorResult(
      status: _string(json['status']),
      currency: _string(json['currency']),
      price: _map(json['price']),
      visibleLines: _list(_visibleLineItems(json['visibleLines'])),
      summary: _list(json['summary']),
      warnings: _list(json['warnings']),
      weights: _map(json['weights']),
      internalPrice: _map(json['internalPrice']),
      sources: _map(json['sources']),
      bom: _list(json['bom']),
      glassLines: _list(json['glassLines'] ?? json['glass_lines']),
      baseBom: _list(json['baseBom'] ?? json['base_bom']),
      optionBom: _list(json['optionBom'] ?? json['option_bom']),
      setContentBom: _list(json['setContentBom'] ?? json['set_content_bom']),
      calculatedBom: _list(json['calculatedBom'] ?? json['calculated_bom']),
      effectiveSetBom: _list(json['effectiveSetBom'] ?? json['effective_set_bom']),
      manualBom: _list(json['manualBom'] ?? json['manual_bom']),
      derivedAccessories: _list(json['derivedAccessories'] ?? json['derived_accessories']),
      setDeltaBom: _list(json['setDeltaBom'] ?? json['set_delta_bom']),
      derivedAccessoryDiagnostics: _list(json['derivedAccessoryDiagnostics'] ?? json['derived_accessory_diagnostics']),
      manualComponentDiagnostics: _list(json['manualComponentDiagnostics'] ?? json['manual_component_diagnostics']),
      setDeltaDiagnostics: _list(json['setDeltaDiagnostics'] ?? json['set_delta_diagnostics']),
      optionDiagnostics: _list(
        _diagnosticItems(
          json['optionDiagnostics'] ?? json['option_diagnostics'],
        ),
      ),
      setContentDiagnostics: _list(json['setContentDiagnostics'] ?? json['set_content_diagnostics']),
      trace: _list(json['trace']),
      raw: json,
    );
  }

  final String status;
  final String currency;
  final Map<String, dynamic> price;
  final List<Map<String, dynamic>> visibleLines;
  final List<Map<String, dynamic>> summary;
  final List<Map<String, dynamic>> warnings;
  final Map<String, dynamic> weights;
  final Map<String, dynamic> internalPrice;
  final Map<String, dynamic> sources;
  final List<Map<String, dynamic>> bom;
  final List<Map<String, dynamic>> glassLines;
  final List<Map<String, dynamic>> baseBom;
  final List<Map<String, dynamic>> optionBom;
  final List<Map<String, dynamic>> setContentBom;
  final List<Map<String, dynamic>> calculatedBom;
  final List<Map<String, dynamic>> effectiveSetBom;
  final List<Map<String, dynamic>> manualBom;
  final List<Map<String, dynamic>> derivedAccessories;
  final List<Map<String, dynamic>> setDeltaBom;
  final List<Map<String, dynamic>> derivedAccessoryDiagnostics;
  final List<Map<String, dynamic>> manualComponentDiagnostics;
  final List<Map<String, dynamic>> setDeltaDiagnostics;
  final List<Map<String, dynamic>> optionDiagnostics;
  final List<Map<String, dynamic>> setContentDiagnostics;
  final List<Map<String, dynamic>> trace;
  final Map<String, dynamic> raw;
}

class SavedQuote {
  const SavedQuote({
    required this.id,
    required this.quoteNo,
    required this.statusCode,
    this.createdAt,
  });

  factory SavedQuote.fromJson(Map<String, dynamic> json) {
    return SavedQuote(
      id: _string(json['id']),
      quoteNo: _string(json['quote_no'] ?? json['quoteNo']),
      statusCode: _string(json['status_code'] ?? json['statusCode']),
      createdAt: _nullableString(
        json['updated_at'] ?? json['updatedAt'] ?? json['created_at'] ?? json['createdAt'],
      ),
    );
  }

  final String id;
  final String quoteNo;
  final String statusCode;
  final String? createdAt;
}

class LoadedQuote {
  const LoadedQuote({
    required this.id,
    required this.quoteNo,
    required this.statusCode,
    required this.input,
    this.productFamilyId,
    this.resultJson,
    this.sellerOrganizationId,
    this.buyerOrganizationId,
    this.shipToOrganizationId,
    this.quoteNoExternal,
    this.externalNotes,
    this.createdAt,
    this.catalogItems = const [],
    this.catalogVariants = const [],
    this.catalogWarnings = const [],
  });

  factory LoadedQuote.fromJson(Map<String, dynamic> json) {
    final quote = _map(json['quote']);
    final quoteNoExternal = _nullableString(quote['quote_no_external'] ?? json['quote_no_external']);
    final externalNotes = _nullableString(quote['external_notes'] ?? json['external_notes']);
    final input = Map<String, dynamic>.from(_map(json['input'] ?? quote['input_json']));
    if (quoteNoExternal != null && quoteNoExternal.isNotEmpty) input['quote_no_external'] = quoteNoExternal;
    if (externalNotes != null && externalNotes.isNotEmpty) input['external_notes'] = externalNotes;
    final catalogContext = _map(json['catalog_context'] ?? json['catalogContext']);
    final catalogWarnings = _list(json['catalog_warnings'] ?? json['catalogWarnings']);
    final rawResult = json['result'] ?? quote['result_json'];
    final resultJson = rawResult is Map ? Map<String, dynamic>.from(rawResult) : null;
    if (resultJson != null && catalogWarnings.isNotEmpty) {
      final existingWarnings = _list(resultJson['warnings']);
      resultJson['warnings'] = [...existingWarnings, ...catalogWarnings];
    }
    return LoadedQuote(
      id: _string(quote['id'] ?? json['id']),
      quoteNo: _string(quote['quote_no'] ?? quote['quoteNo'] ?? json['quote_no'] ?? json['quoteNo']),
      statusCode: _string(quote['status_code'] ?? quote['statusCode'] ?? json['status_code'] ?? json['statusCode']),
      input: input,
      productFamilyId: _nullableString(quote['product_family_id'] ?? json['product_family_id']),
      resultJson: resultJson,
      sellerOrganizationId: _nullableString(quote['seller_organization_id'] ?? json['seller_organization_id']),
      buyerOrganizationId: _nullableString(quote['buyer_organization_id'] ?? json['buyer_organization_id']),
      shipToOrganizationId: _nullableString(quote['ship_to_organization_id'] ?? json['ship_to_organization_id']),
      quoteNoExternal: quoteNoExternal,
      externalNotes: externalNotes,
      catalogItems: _list(catalogContext['items'])
          .map(CalculatorCatalogItemOption.fromJson)
          .toList(growable: false),
      catalogVariants: _list(catalogContext['variants'])
          .map(CalculatorCatalogVariantOption.fromJson)
          .toList(growable: false),
      catalogWarnings: catalogWarnings,
      createdAt: _nullableString(
        quote['updated_at'] ??
            quote['updatedAt'] ??
            json['updated_at'] ??
            json['updatedAt'] ??
            quote['created_at'] ??
            quote['createdAt'] ??
            json['created_at'] ??
            json['createdAt'],
      ),
    );
  }

  final String id;
  final String quoteNo;
  final String statusCode;
  final Map<String, dynamic> input;
  final String? productFamilyId;
  final Map<String, dynamic>? resultJson;
  final String? sellerOrganizationId;
  final String? buyerOrganizationId;
  final String? shipToOrganizationId;
  final String? quoteNoExternal;
  final String? externalNotes;
  final String? createdAt;
  final List<CalculatorCatalogItemOption> catalogItems;
  final List<CalculatorCatalogVariantOption> catalogVariants;
  final List<Map<String, dynamic>> catalogWarnings;

  Map<String, dynamic> get normalizedInput => CalculatorDraft.fromCalculationJson(
        input,
        productFamilyId: productFamilyId,
      ).toWorkspaceJson();
}

enum SaveQuoteMode {
  asNew,
  asOption;

  String get apiValue {
    switch (this) {
      case SaveQuoteMode.asNew:
        return 'new';
      case SaveQuoteMode.asOption:
        return 'option';
    }
  }

  String get label {
    switch (this) {
      case SaveQuoteMode.asNew:
        return 'As New';
      case SaveQuoteMode.asOption:
        return 'As Option';
    }
  }
}

List<CalculatorSetContentTab> _restoreSetContentItems(
  List<CalculatorSetContentTab> inputTabs,
  List<CalculatorSetContentTab> resultTabs,
) {
  if (resultTabs.isEmpty) return inputTabs;
  if (inputTabs.isEmpty) return resultTabs;

  return [
    for (var index = 0; index < inputTabs.length; index++)
      inputTabs[index].copyWith(
        items: resultTabs.firstWhere(
          (tab) => inputTabs[index].moduleRole.isNotEmpty &&
              tab.moduleRole == inputTabs[index].moduleRole,
          orElse: () => resultTabs[index < resultTabs.length ? index : 0],
        ).items,
      ),
  ];
}

List<CalculatorSetContentTab> _restoreRoofModuleGeometry(
  List<CalculatorSetContentTab> savedTabs,
  List<Map<String, dynamic>> roofModules,
) {
  if (roofModules.isEmpty) return savedTabs;

  if (savedTabs.isEmpty) {
    return [
      for (var index = 0; index < roofModules.length; index++)
        CalculatorSetContentTab(
          id: 'part-${index + 1}',
          label: 'Module ${index + 1}',
          geometryKey: _roofModuleGeometry(roofModules[index]),
          items: const [],
        ),
    ];
  }

  return [
    for (var index = 0; index < savedTabs.length; index++)
      if (index < roofModules.length)
        savedTabs[index].copyWith(
          geometryKey: {
            ..._roofModuleGeometry(roofModules[index]),
            ...savedTabs[index].geometryKey,
          },
        )
      else
        savedTabs[index],
  ];
}

Map<String, dynamic> _roofModuleGeometry(Map<String, dynamic> module) {
  final role = _nullableString(module['role']);
  final width = _intOrNull(module['width_mm']);
  final depth = _intOrNull(module['depth_mm']);
  final covering = _nullableString(
    module['glass_type_code'] ?? module['covering_code'],
  );
  final maxGlassFieldWidth = _intOrNull(
    module['max_glass_field_width_mm'],
  );
  return {
    if (role != null) 'role': role,
    if (width != null && width > 0) 'width_mm': width,
    if (depth != null && depth > 0) 'depth_mm': depth,
    if (covering != null) ...{
      'covering_code': covering,
      'glass_type_code': covering,
    },
    if (maxGlassFieldWidth != null && maxGlassFieldWidth > 0)
      'max_glass_field_width_mm': maxGlassFieldWidth,
  };
}

String _staticBeamLengthCalculationMethod(Object? value) {
  final normalized = _string(value);
  return const {'legacy_rounded', 'shortest_sku', 'installed_length'}
          .contains(normalized)
      ? normalized
      : 'legacy_rounded';
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
  }
  return const [];
}

dynamic _visibleLineItems(dynamic value) {
  if (value is Map) return value['items'];
  return value;
}

dynamic _diagnosticItems(dynamic value) {
  if (value is Map) return value['items'];
  return value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, List<CalculatorOption>> _references(dynamic value) {
  final map = _map(value);
  return map.map((key, entries) {
    final options = entries is List
        ? entries.whereType<Map>().map((entry) => CalculatorOption.fromJson(Map<String, dynamic>.from(entry))).toList()
        : <CalculatorOption>[];
    return MapEntry(key, options);
  });
}

Map<String, List<CalculatorAdditionalHandlingOption>> _additionalHandlingMap(dynamic value) {
  final map = _map(value);
  return map.map((parentId, entries) {
    final options = entries is List
        ? entries
            .whereType<Map>()
            .map((entry) => CalculatorAdditionalHandlingOption.fromJson(Map<String, dynamic>.from(entry)))
            .where((entry) => entry.parentCatalogItemId.isNotEmpty && entry.catalogItemId.isNotEmpty)
            .toList()
        : <CalculatorAdditionalHandlingOption>[];
    options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return MapEntry(parentId, options);
  });
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => '$entry'.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(RegExp(r'[,;|]'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

bool _boolValue(dynamic value, bool fallback) {
  if (value is bool) return value;
  final normalized = '$value'.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

num _numOrDefault(dynamic value, num fallback) {
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(',', '.')) ?? fallback;
}

num? _numOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(',', '.'));
}

String _string(dynamic value) => value == null ? '' : '$value';

String? _nullableString(dynamic value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

int? _lengthOrNull(dynamic value) {
  final length = _intOrNull(value);
  if (length == null || length <= 1) return null;
  return length;
}

String _stableJson(dynamic value) {
  return jsonEncode(_stableValue(value));
}

dynamic _stableValue(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((entry) => '$entry').toList()..sort();
    return {
      for (final key in keys)
        if (value[key] != null) key: _stableValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_stableValue).toList();
  }
  return value;
}
