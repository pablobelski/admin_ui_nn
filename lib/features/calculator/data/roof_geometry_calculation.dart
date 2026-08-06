import 'dart:convert';
import 'dart:math' as math;

import 'calculator_models.dart';

const Map<String, List<String>> _fallbackModuleOrderByModel = {
  'SR': ['main'],
  'LRTR': ['main', 'small'],
  'LRTL': ['main', 'small'],
  'LWTR': ['main', 'small'],
  'LWTL': ['main', 'small'],
  'UWTM': ['left', 'right', 'middle'],
  'TWTM': ['middle', 'left', 'right'],
  'SWL': ['main'],
  'SWR': ['main'],
  'SRL': ['main'],
  'SRR': ['main'],
};

const Map<String, Map<String, int>> _fallbackGlassOffsetsByModel = {
  'SR': {'main': -1},
  'LRTR': {'main': -1, 'small': -1},
  'LRTL': {'main': -1, 'small': -1},
  'LWTR': {'main': -1, 'small': 0},
  'LWTL': {'main': -1, 'small': 0},
  'UWTM': {'left': -1, 'right': -1, 'middle': 1},
  'TWTM': {'middle': -1, 'left': 0, 'right': 0},
  'SWL': {'main': -1},
  'SWR': {'main': -1},
  'SRL': {'main': -1},
  'SRR': {'main': -1},
};

const Map<String, Map<String, int>> _fallbackBeamCountOffsetsByModel = {
  'SR': {'main': -1},
  'LRTR': {'main': -1, 'small': -1},
  'LRTL': {'main': -1, 'small': -1},
  'LWTR': {'main': -1, 'small': -1},
  'LWTL': {'main': -1, 'small': -1},
  'UWTM': {'left': -1, 'right': -1, 'middle': -1},
  'TWTM': {'middle': -1, 'left': -1, 'right': -1},
  'SWL': {'main': -1},
  'SWR': {'main': -1},
  'SRL': {'main': -1},
  'SRR': {'main': -1},
};

class RoofModuleCalculation {
  const RoofModuleCalculation({
    required this.moduleIndex,
    required this.role,
    required this.widthMm,
    required this.depthMm,
    required this.beamCount,
    required this.beamLengthMm,
    required this.beamStepMm,
    required this.glassCountOffset,
    required this.glassDepthFieldCount,
    required this.glassCount,
    required this.glassWidthMm,
    required this.glassLengthMm,
    required this.glassAreaM2,
    this.coveringCode,
    this.maxGlassFieldWidthMm,
  });

  final int moduleIndex;
  final String role;
  final int widthMm;
  final int depthMm;
  final int beamCount;
  final int beamLengthMm;
  final double beamStepMm;
  final int glassCountOffset;
  final int glassDepthFieldCount;
  final int glassCount;
  final int glassWidthMm;
  final int glassLengthMm;
  final double glassAreaM2;
  final String? coveringCode;
  final int? maxGlassFieldWidthMm;
}

class RoofStaticBeamCalculation {
  const RoofStaticBeamCalculation({
    required this.enabled,
    required this.positionCode,
    required this.positionLabel,
    required this.overallWidthMm,
    required this.totalLengthMm,
    required this.pieceCount,
    required this.pieceLengthMm,
    required this.endCapCount,
    this.instructionCode,
    this.instructionText,
    this.instructionMediaFilename,
  });

  final bool enabled;
  final String positionCode;
  final String positionLabel;
  final int overallWidthMm;
  final int totalLengthMm;
  final int pieceCount;
  final double? pieceLengthMm;
  final int endCapCount;
  final String? instructionCode;
  final String? instructionText;
  final String? instructionMediaFilename;
}

class RoofGeometryCalculation {
  const RoofGeometryCalculation({
    required this.angleDeg,
    required this.frontHeightMm,
    required this.postCount,
    required this.modules,
    this.staticBeam,
  });

  final int? angleDeg;
  final int? frontHeightMm;
  final int postCount;
  final List<RoofModuleCalculation> modules;
  final RoofStaticBeamCalculation? staticBeam;
}

List<String> roofModuleRolesForModel(CalculatorOption? model) {
  final metadata = _optionMetadata(model);
  final segmentOrder = _stringList(metadata['segment_order'] ?? metadata['segmentOrder']);
  final moduleOrder = _stringList(metadata['module_order'] ?? metadata['moduleOrder']);
  final configured = segmentOrder.isNotEmpty ? segmentOrder : moduleOrder;
  if (configured.isNotEmpty) return configured;
  final code = model?.code.trim().toUpperCase() ?? '';
  return _fallbackModuleOrderByModel[code] ?? const ['main'];
}


RoofGeometryCalculation? roofGeometryCalculationFromSources(
  Map<String, dynamic> sources,
) {
  final rawGeometry = sources['roof_geometry'] ?? sources['roofGeometry'];
  final geometry = _mapValue(rawGeometry);
  if (geometry.isEmpty) return null;

  final rawModules = geometry['modules'];
  if (rawModules is! List) return null;
  final modules = <RoofModuleCalculation>[];
  for (final raw in rawModules) {
    final module = _mapValue(raw);
    if (module.isEmpty) continue;
    final moduleIndex = _asInt(module['module_index'] ?? module['moduleIndex']);
    final role = '${module['role'] ?? ''}'.trim();
    final widthMm = _asInt(module['width_mm'] ?? module['widthMm']);
    final depthMm = _asInt(module['depth_mm'] ?? module['depthMm']);
    final beamCount = _asInt(module['beam_count'] ?? module['beamCount']);
    final beamLengthMm = _asInt(module['beam_length_mm'] ?? module['beamLengthMm']);
    final beamStepMm = _asDouble(module['beam_step_mm'] ?? module['beamStepMm']);
    final glassCountOffset = _asInt(module['glass_count_offset'] ?? module['glassCountOffset']);
    final glassDepthFieldCount = _asInt(module['glass_depth_field_count'] ?? module['glassDepthFieldCount']) ?? 1;
    final glassCount = _asInt(module['glass_count'] ?? module['glassCount']);
    final glassWidthMm = _asInt(module['glass_width_mm'] ?? module['glassWidthMm']);
    final glassLengthMm = _asInt(module['glass_length_mm'] ?? module['glassLengthMm']);
    final glassAreaM2 = _asDouble(module['glass_area_m2'] ?? module['glassAreaM2']);
    final coveringCode = _nullableText(
      module['glass_type_code'] ??
          module['covering_code'] ??
          module['glassTypeCode'] ??
          module['coveringCode'],
    );
    final maxGlassFieldWidthMm = _asInt(
      module['max_glass_field_width_mm'] ??
          module['maxGlassFieldWidthMm'],
    );
    if (moduleIndex == null ||
        role.isEmpty ||
        widthMm == null ||
        depthMm == null ||
        beamCount == null ||
        beamLengthMm == null ||
        beamStepMm == null ||
        glassCountOffset == null ||
        glassCount == null ||
        glassWidthMm == null ||
        glassLengthMm == null ||
        glassAreaM2 == null) {
      continue;
    }
    modules.add(
      RoofModuleCalculation(
        moduleIndex: moduleIndex,
        role: role,
        widthMm: widthMm,
        depthMm: depthMm,
        beamCount: beamCount,
        beamLengthMm: beamLengthMm,
        beamStepMm: beamStepMm,
        glassCountOffset: glassCountOffset,
        glassDepthFieldCount: glassDepthFieldCount,
        glassCount: glassCount,
        glassWidthMm: glassWidthMm,
        glassLengthMm: glassLengthMm,
        glassAreaM2: glassAreaM2,
        coveringCode: coveringCode,
        maxGlassFieldWidthMm: maxGlassFieldWidthMm,
      ),
    );
  }
  if (modules.isEmpty) return null;
  modules.sort((a, b) => a.moduleIndex.compareTo(b.moduleIndex));
  final staticBeamEnabled =
      geometry['add_static_beam_assembly'] == true || geometry['addStaticBeamAssembly'] == true;
  final staticBeamPositionCode =
      '${geometry['static_beam_position_code'] ?? geometry['staticBeamPositionCode'] ?? ''}'.trim();
  final staticBeamPositionLabel =
      '${geometry['static_beam_position_label'] ?? geometry['staticBeamPositionLabel'] ?? ''}'.trim();
  final staticBeam = staticBeamEnabled
      ? RoofStaticBeamCalculation(
          enabled: true,
          positionCode: staticBeamPositionCode,
          positionLabel: staticBeamPositionLabel.isEmpty
              ? _staticBeamFallbackLabel(staticBeamPositionCode)
              : staticBeamPositionLabel,
          overallWidthMm: _asInt(
                geometry['static_beam_overall_width_mm'] ?? geometry['staticBeamOverallWidthMm'],
              ) ??
              0,
          totalLengthMm: _asInt(
                geometry['static_beam_total_length_mm'] ?? geometry['staticBeamTotalLengthMm'],
              ) ??
              0,
          pieceCount: _asInt(
                geometry['static_beam_piece_count'] ?? geometry['staticBeamPieceCount'],
              ) ??
              0,
          pieceLengthMm: _asDouble(
            geometry['static_beam_piece_length_mm'] ?? geometry['staticBeamPieceLengthMm'],
          ),
          endCapCount: _asInt(
                geometry['static_beam_end_cap_count'] ?? geometry['staticBeamEndCapCount'],
              ) ??
              0,
          instructionCode: _nullableText(
            geometry['static_beam_instruction_code'] ?? geometry['staticBeamInstructionCode'],
          ),
          instructionText: _nullableText(
            geometry['static_beam_instruction_text'] ?? geometry['staticBeamInstructionText'],
          ),
          instructionMediaFilename: _nullableText(
            geometry['static_beam_instruction_media_filename'] ??
                geometry['staticBeamInstructionMediaFilename'],
          ),
        )
      : null;
  return RoofGeometryCalculation(
    angleDeg: _asInt(geometry['angle_deg'] ?? geometry['angleDeg']),
    frontHeightMm: _asInt(geometry['front_height_mm'] ?? geometry['frontHeightMm']),
    postCount: _asInt(geometry['post_count'] ?? geometry['postCount']) ?? 0,
    modules: modules,
    staticBeam: staticBeam,
  );
}

RoofGeometryCalculation calculateRoofGeometryForDraft({
  required CalculatorDraft draft,
  required CalculatorTemplateOption? template,
  required CalculatorOption? model,
}) {
  final params = template?.roofParameters ?? const <String, dynamic>{};
  final beamWidthMm = _number(params, 'beamWidthMm', 'beam_width_mm');
  final backOffsetMm = _number(params, 'backOffsetMm', 'back_offset_mm');
  final frontOffsetMm = _number(params, 'frontOffsetMm', 'front_offset_mm');
  final glassFrontAddMm = _number(params, 'glassFrontAddMm', 'glass_front_add_mm');
  final glassOverlapMm = _number(params, 'glassOverlapMm', 'glass_overlap_mm');
  final wallGutterBlendeClearanceMm = _number(
        params,
        'wallGutterBlendeClearanceMm',
        'wall_gutter_blende_clearance_mm',
      ) ??
      0.5;
  final defaultGlassDepthFieldCount = _number(params, 'defaultGlassDepthFieldCount', 'default_glass_depth_field_count');
  final maxPostSpanMm = _number(params, 'maxPostSpanMm', 'max_post_span_mm') ?? 4000;
  final glassDepthJointGapMm = _number(params, 'glassDepthJointGapMm', 'glass_depth_joint_gap_mm');
  final singleGlassFieldMaxBeamLengthMm = _number(
    params,
    'singleGlassFieldMaxBeamLengthMm',
    'single_glass_field_max_beam_length_mm',
  ) ??
      _number(params, 'glassMaxPanelLengthMm', 'glass_max_panel_length_mm');
  final defaultMaxGlassFieldWidthMm = _number(
    params,
    'defaultMaxGlassFieldWidthMm',
    'default_max_glass_field_width_mm',
  );
  if ([
    beamWidthMm,
    backOffsetMm,
    frontOffsetMm,
    glassFrontAddMm,
    glassOverlapMm,
    defaultGlassDepthFieldCount,
    glassDepthJointGapMm,
    singleGlassFieldMaxBeamLengthMm,
    defaultMaxGlassFieldWidthMm,
  ].any((value) => value == null)) {
    return const RoofGeometryCalculation(angleDeg: null, frontHeightMm: null, postCount: 0, modules: []);
  }

  final beamWidth = beamWidthMm!;
  final backOffset = backOffsetMm!;
  final frontOffset = frontOffsetMm!;
  final glassFrontAdd = glassFrontAddMm!;
  final glassOverlap = glassOverlapMm!;
  final glassDepthJointGap = glassDepthJointGapMm!;
  final singleGlassFieldMaxBeamLength = singleGlassFieldMaxBeamLengthMm!;
  final defaultMaxGlassWidth = defaultMaxGlassFieldWidthMm!.round();
  final roles = roofModuleRolesForModel(model);
  final tabsByRole = <String, CalculatorSetContentTab>{
    for (final tab in draft.setContents)
      if (tab.moduleRole.trim().isNotEmpty) tab.moduleRole.trim(): tab,
  };
  final orderedTabs = <CalculatorSetContentTab>[];
  for (final role in roles) {
    final tab = tabsByRole[role];
    if (tab != null) orderedTabs.add(tab);
  }
  for (final tab in draft.setContents) {
    if (!orderedTabs.contains(tab)) orderedTabs.add(tab);
  }

  final maxDepthMm = orderedTabs
      .map((tab) => tab.moduleDepthMm)
      .whereType<int>()
      .fold<int?>(null, (maxValue, value) => maxValue == null || value > maxValue ? value : maxValue);
  final effectiveDepth = maxDepthMm ?? draft.depthMm;
  final rearHeight = draft.roofRearHeightMm ?? draft.heightMm;
  final rawAngle = draft.roofAngleDeg ?? (
    rearHeight != null && draft.roofFrontHeightMm != null && effectiveDepth != null && effectiveDepth > 0
        ? (math.atan((rearHeight - draft.roofFrontHeightMm!) / effectiveDepth) * 180 / math.pi).round()
        : null
  );
  final angle = rawAngle?.clamp(
    template?.minRoofAngleDeg ?? 2,
    template?.maxRoofAngleDeg ?? 14,
  ).toInt();
  final frontHeight = draft.roofFrontHeightMm ?? (
    rearHeight != null && effectiveDepth != null && effectiveDepth > 0 && angle != null
        ? (rearHeight - math.tan(angle * math.pi / 180) * effectiveDepth).round()
        : null
  );
  final totalWidthMm = orderedTabs
      .map((tab) => tab.moduleWidthMm)
      .whereType<int>()
      .fold<int>(0, (sum, value) => sum + math.max(0, value));
  final postCount = totalWidthMm > 0
      ? math.max(3, (totalWidthMm / math.max(1, maxPostSpanMm)).ceil()).toInt()
      : 0;
  final staticBeam = _staticBeamCalculationForDraft(
    draft: draft,
    params: params,
    overallWidthMm: totalWidthMm,
  );
  if (angle == null) {
    return RoofGeometryCalculation(
      angleDeg: null,
      frontHeightMm: frontHeight,
      postCount: postCount,
      modules: const [],
      staticBeam: staticBeam,
    );
  }

  final modelCode = model?.code.trim().toUpperCase() ?? draft.modelCode?.trim().toUpperCase() ?? '';
  final modelMetadata = _optionMetadata(model);
  final offsets = _glassOffsets(params, modelCode, modelMetadata);
  final beamCountOffsets = _beamCountOffsets(modelCode, modelMetadata);
  final calculated = <RoofModuleCalculation>[];

  for (var index = 0; index < orderedTabs.length; index++) {
    final tab = orderedTabs[index];
    final role = tab.moduleRole.trim().isEmpty
        ? (index < roles.length ? roles[index] : 'main')
        : tab.moduleRole.trim();
    final width = tab.moduleWidthMm;
    final depth = tab.moduleDepthMm;
    if (width == null || depth == null || width <= 0 || depth <= 0) continue;
    final coveringCode = tab.moduleCoveringCode ?? draft.coveringCode;
    final coveringMaxGlassWidth =
        template?.maxGlassFieldWidthFor(coveringCode) ?? defaultMaxGlassWidth;
    final maxGlassWidth = math.min(
      tab.moduleMaxGlassFieldWidthMm ??
          draft.maxGlassFieldWidthMm ??
          defaultMaxGlassWidth,
      coveringMaxGlassWidth,
    ).toInt();
    final longLeg = depth - backOffset - frontOffset;
    if (longLeg <= 0) continue;
    final glassCountOffset = offsets[role] ?? -1;
    final beamCount = _calculateBeamCount(
      width,
      beamWidth,
      glassOverlap,
      maxGlassWidth,
      draft.forceOddBeams,
      beamCountOffsets[role] ?? -1,
    );
    final beamLength = (longLeg / math.cos(angle * math.pi / 180)).round();
    final glassCountAcrossWidth = math.max(0, beamCount + glassCountOffset).toInt();
    if (glassCountAcrossWidth <= 0) continue;
    final beamStep = (width - beamCount * beamWidth) / glassCountAcrossWidth;
    final roundedBeamStep = (beamStep * 10).round() / 10;
    final glassWidth = (roundedBeamStep - wallGutterBlendeClearanceMm + glassOverlap).truncate();
    final unsplitGlassLength = (beamLength + glassFrontAdd + _angleCorrection(angle)).round();
    final glassDepthFieldCount = math.max(
      1,
      (beamLength / singleGlassFieldMaxBeamLength).ceil(),
    ).toInt();
    final totalGlassJointGap = glassDepthJointGap * math.max(0, glassDepthFieldCount - 1);
    final glassLength = ((unsplitGlassLength - totalGlassJointGap) / glassDepthFieldCount).round();
    final glassCount = glassCountAcrossWidth * glassDepthFieldCount;
    final glassArea = _roundAreaUp(
      glassCount * (glassWidth / 1000) * (glassLength / 1000),
    );
    calculated.add(
      RoofModuleCalculation(
        moduleIndex: index + 1,
        role: role,
        widthMm: width,
        depthMm: depth,
        beamCount: beamCount,
        beamLengthMm: beamLength,
        beamStepMm: roundedBeamStep,
        glassCountOffset: glassCountOffset,
        glassDepthFieldCount: glassDepthFieldCount,
        glassCount: glassCount,
        glassWidthMm: glassWidth,
        glassLengthMm: glassLength,
        glassAreaM2: glassArea,
        coveringCode: coveringCode,
        maxGlassFieldWidthMm: maxGlassWidth,
      ),
    );
  }

  return RoofGeometryCalculation(
    angleDeg: angle,
    frontHeightMm: frontHeight,
    postCount: postCount,
    modules: calculated,
    staticBeam: staticBeam,
  );
}

RoofStaticBeamCalculation? _staticBeamCalculationForDraft({
  required CalculatorDraft draft,
  required Map<String, dynamic> params,
  required int overallWidthMm,
}) {
  if (!draft.addStaticBeamAssembly) return null;
  final requestedCode = draft.staticBeamPositionCode.trim().isEmpty
      ? 'front_overhang'
      : draft.staticBeamPositionCode.trim();
  final positionCode = !draft.wallMounted && requestedCode == 'rear_wall'
      ? 'front_overhang'
      : requestedCode;
  final rawRules = params['staticBeamPositionRules'] ?? params['static_beam_position_rules'];
  final rules = rawRules is Map ? Map<String, dynamic>.from(rawRules) : const <String, dynamic>{};
  final rawRule = rules[positionCode];
  final rule = rawRule is Map ? Map<String, dynamic>.from(rawRule) : const <String, dynamic>{};
  final lengthSubtractMm = _asDouble(
        rule['length_subtract_mm'] ?? rule['lengthSubtractMm'],
      ) ??
      0;
  final endCapCount = _asInt(rule['end_cap_count'] ?? rule['endCapCount']) ??
      (positionCode == 'wall_extension' ? 1 : 2);
  final totalLengthMm = math.max(0, overallWidthMm - lengthSubtractMm).round();
  final splitThresholdMm = _number(
        params,
        'profileSplitThresholdMm',
        'profile_split_threshold_mm',
      ) ??
      7080;
  final pieceCount = totalLengthMm <= 0
      ? 0
      : (overallWidthMm > splitThresholdMm ? 2 : 1);
  final instructionCode = _nullableText(
    rule['instruction_code'] ?? rule['instructionCode'],
  );
  final instructionText = instructionCode == 'wall_sheet'
      ? 'Blech - $overallWidthMm mm'
      : null;
  return RoofStaticBeamCalculation(
    enabled: true,
    positionCode: positionCode,
    positionLabel: _nullableText(rule['label']) ?? _staticBeamFallbackLabel(positionCode),
    overallWidthMm: overallWidthMm,
    totalLengthMm: totalLengthMm,
    pieceCount: pieceCount,
    pieceLengthMm: pieceCount > 0 ? totalLengthMm / pieceCount : null,
    endCapCount: pieceCount > 0 ? endCapCount : 0,
    instructionCode: instructionCode,
    instructionText: instructionText,
    instructionMediaFilename: pieceCount > 0
        ? _nullableText(
            rule['instruction_media_filename'] ?? rule['instructionMediaFilename'],
          )
        : null,
  );
}

String _staticBeamFallbackLabel(String code) {
  const labels = <String, String>{
    'rear_wall': 'Hinten+Wand',
    'under_gutter': 'Unter der Rinne',
    'front_overhang': 'Vorne überstehend',
    'wall_extension': 'Als Wandverlängerung',
  };
  return labels[code] ?? code;
}

int _calculateBeamCount(
  int widthMm,
  double beamWidthMm,
  double glassOverlapMm,
  int maxGlassFieldWidthMm,
  bool forceOdd,
  int glassCountOffset,
) {
  for (var count = 2; count <= 52; count++) {
    if (forceOdd && count.isEven) continue;
    final glassFieldCount = count + glassCountOffset;
    if (glassFieldCount <= 0) continue;
    final glassFieldWidth = ((widthMm - count * beamWidthMm) / glassFieldCount) + glassOverlapMm;
    if (glassFieldWidth <= maxGlassFieldWidthMm) return count;
  }
  return 52;
}

double _angleCorrection(int angleDeg) {
  if (angleDeg <= 2) return -6;
  if (angleDeg >= 14) return 16;
  return -6 + (angleDeg - 2) * (22 / 12);
}

double _roundAreaUp(double value) => (value * 10 - 1e-9).ceil() / 10;

Map<String, int> _beamCountOffsets(
  String modelCode,
  Map<String, dynamic> modelMetadata,
) {
  final raw = modelMetadata['beam_count_offset_by_module']
      ?? modelMetadata['beamCountOffsetByModule'];
  if (raw is Map) {
    final resolved = {
      for (final entry in raw.entries)
        if (_asInt(entry.value) != null) '${entry.key}': _asInt(entry.value)!,
    };
    if (resolved.isNotEmpty) return resolved;
  }
  return _fallbackBeamCountOffsetsByModel[modelCode] ?? const {'main': -1};
}

Map<String, int> _glassOffsets(
  Map<String, dynamic> params,
  String modelCode,
  Map<String, dynamic> modelMetadata,
) {
  final modelRaw = modelMetadata['glass_count_offset_by_module']
      ?? modelMetadata['glassCountOffsetByModule'];
  if (modelRaw is Map) {
    final resolved = {
      for (final entry in modelRaw.entries)
        if (_asInt(entry.value) != null) '${entry.key}': _asInt(entry.value)!,
    };
    if (resolved.isNotEmpty) return resolved;
  }

  // Backward-compatible fallback for installations that temporarily stored
  // model offsets inside the template Parameters module.
  final raw = params['glassCountOffsetsByModel'] ?? params['glass_count_offsets_by_model'];
  if (raw is Map) {
    final configured = raw[modelCode] ?? raw[modelCode.toLowerCase()];
    if (configured is Map) {
      final resolved = {
        for (final entry in configured.entries)
          if (_asInt(entry.value) != null) '${entry.key}': _asInt(entry.value)!,
      };
      if (resolved.isNotEmpty) return resolved;
    }
  }
  return _fallbackGlassOffsetsByModel[modelCode] ?? const {'main': -1};
}

Map<String, dynamic> _optionMetadata(CalculatorOption? model) {
  if (model == null) return const {};
  final raw = model.raw['metadata_json'] ?? model.raw['metadata'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return model.raw;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((entry) => '$entry'.trim()).where((entry) => entry.isNotEmpty).toList(growable: false);
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('[')) {
      try {
        return _stringList(jsonDecode(text));
      } catch (_) {
        // Continue with delimited parsing.
      }
    }
    return text.split(RegExp(r'[,;|]')).map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toList(growable: false);
  }
  return const [];
}

double? _number(Map<String, dynamic> source, String camel, String snake) {
  final raw = source[camel] ?? source[snake];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw');
}


Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const {};
    }
  }
  return const {};
}


String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}
