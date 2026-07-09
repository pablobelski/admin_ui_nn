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
    defaultMaxGlassFieldWidthMm,
  ].any((value) => value == null)) {
    return const RoofGeometryCalculation(angleDeg: null, frontHeightMm: null, modules: []);
  }

  final beamWidth = beamWidthMm!;
  final backOffset = backOffsetMm!;
  final frontOffset = frontOffsetMm!;
  final glassFrontAdd = glassFrontAddMm!;
  final glassOverlap = glassOverlapMm!;
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
  final angle = draft.roofAngleDeg ?? (
    rearHeight != null && draft.roofFrontHeightMm != null && effectiveDepth != null && effectiveDepth > 0
        ? (math.atan((rearHeight - draft.roofFrontHeightMm!) / effectiveDepth) * 180 / math.pi).round()
        : null
  );
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
  final maxGlassWidth = draft.maxGlassFieldWidthMm ?? defaultMaxGlassWidth;
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
    final glassCount = math.max(0, beamCount + glassCountOffset).toInt();
    final glassWidth = (beamStep + glassOverlap).ceil();
    final glassLength = (beamLength + glassFrontAdd + _angleCorrection(angle)).round();
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

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}
