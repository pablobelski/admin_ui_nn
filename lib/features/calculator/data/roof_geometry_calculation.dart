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
}

class RoofGeometryCalculation {
  const RoofGeometryCalculation({
    required this.angleDeg,
    required this.frontHeightMm,
    required this.modules,
  });

  final int? angleDeg;
  final int? frontHeightMm;
  final List<RoofModuleCalculation> modules;
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
      ),
    );
  }
  if (modules.isEmpty) return null;
  modules.sort((a, b) => a.moduleIndex.compareTo(b.moduleIndex));
  return RoofGeometryCalculation(
    angleDeg: _asInt(geometry['angle_deg'] ?? geometry['angleDeg']),
    frontHeightMm: _asInt(geometry['front_height_mm'] ?? geometry['frontHeightMm']),
    modules: modules,
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
  final coatingMaxLengthMm = _number(params, 'coatingMaxLengthMm', 'coating_max_length_mm');
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
    coatingMaxLengthMm,
    defaultMaxGlassFieldWidthMm,
  ].any((value) => value == null)) {
    return const RoofGeometryCalculation(angleDeg: null, frontHeightMm: null, modules: []);
  }

  final beamWidth = beamWidthMm!;
  final backOffset = backOffsetMm!;
  final frontOffset = frontOffsetMm!;
  final glassFrontAdd = glassFrontAddMm!;
  final glassOverlap = glassOverlapMm!;
  final coatingMaxLength = coatingMaxLengthMm!;
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
  if (angle == null) {
    return RoofGeometryCalculation(angleDeg: null, frontHeightMm: frontHeight, modules: const []);
  }

  final modelCode = model?.code.trim().toUpperCase() ?? draft.modelCode?.trim().toUpperCase() ?? '';
  final offsets = _glassOffsets(params, modelCode, _optionMetadata(model));
  final coveringMaxGlassWidth = template?.maxGlassFieldWidthFor(draft.coveringCode) ?? defaultMaxGlassWidth;
  final maxGlassWidth = math.min(
    draft.maxGlassFieldWidthMm ?? defaultMaxGlassWidth,
    coveringMaxGlassWidth,
  ).toInt();
  final calculated = <RoofModuleCalculation>[];

  for (var index = 0; index < orderedTabs.length; index++) {
    final tab = orderedTabs[index];
    final role = tab.moduleRole.trim().isEmpty
        ? (index < roles.length ? roles[index] : 'main')
        : tab.moduleRole.trim();
    final width = tab.moduleWidthMm;
    final depth = tab.moduleDepthMm;
    if (width == null || depth == null || width <= 0 || depth <= 0) continue;
    final longLeg = depth - backOffset - frontOffset;
    if (longLeg <= 0) continue;
    final beamCount = _calculateBeamCount(
      width,
      beamWidth,
      glassOverlap,
      maxGlassWidth,
      draft.forceOddBeams,
    );
    final beamLength = (longLeg / math.cos(angle * math.pi / 180)).round();
    final beamStep = (width - beamCount * beamWidth) / (beamCount - 1);
    final glassCountOffset = offsets[role] ?? -1;
    final glassCountAcrossWidth = math.max(0, beamCount + glassCountOffset).toInt();
    final glassWidth = beamStep.round() + glassOverlap.round();
    final unsplitGlassLength = (beamLength + glassFrontAdd + _angleCorrection(angle)).round();
    final glassDepthFieldCount = math.max(1, (unsplitGlassLength / coatingMaxLength).ceil()).toInt();
    final glassLength = (unsplitGlassLength / glassDepthFieldCount).ceil();
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
        beamStepMm: (beamStep * 10).round() / 10,
        glassCountOffset: glassCountOffset,
        glassDepthFieldCount: glassDepthFieldCount,
        glassCount: glassCount,
        glassWidthMm: glassWidth,
        glassLengthMm: glassLength,
        glassAreaM2: glassArea,
      ),
    );
  }

  return RoofGeometryCalculation(
    angleDeg: angle,
    frontHeightMm: frontHeight,
    modules: calculated,
  );
}

int _calculateBeamCount(
  int widthMm,
  double beamWidthMm,
  double glassOverlapMm,
  int maxGlassFieldWidthMm,
  bool forceOdd,
) {
  for (var count = 2; count <= 52; count++) {
    if (forceOdd && count.isEven) continue;
    final glassFieldWidth = ((widthMm - count * beamWidthMm) / (count - 1)) + glassOverlapMm;
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

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}
