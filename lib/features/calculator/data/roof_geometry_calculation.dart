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
  'LWTL': {'main': -1, 'small': 0},
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
    this.glassDepthSegmentLengthsMm = const [],
    this.glassSplitMode = 'auto',
    this.glassCutPositionsMm = const [],
    this.profileSplitMode = 'auto',
    this.profileCutPositionsMm = const [],
    this.beamSegmentLengthsMm = const [],
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
  final List<int> glassDepthSegmentLengthsMm;
  final String glassSplitMode;
  final List<int> glassCutPositionsMm;
  final String profileSplitMode;
  final List<int> profileCutPositionsMm;
  final List<int> beamSegmentLengthsMm;
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
    final glassDepthSegmentLengthsMm = _intList(
      module['glass_depth_segment_lengths_mm'] ??
          module['glassDepthSegmentLengthsMm'],
    );
    final glassSplitMode = _nullableText(
          module['glass_split_mode'] ?? module['glassSplitMode'],
        ) ??
        'auto';
    final glassCutPositionsMm = _intList(
      module['glass_cut_positions_mm'] ?? module['glassCutPositionsMm'],
    );
    final profileSplitMode = _nullableText(
          module['profile_split_mode'] ?? module['profileSplitMode'],
        ) ??
        'auto';
    final profileCutPositionsMm = _intList(
      module['profile_cut_positions_mm'] ?? module['profileCutPositionsMm'],
    );
    final beamSegmentLengthsMm = _intList(
      module['beam_segment_lengths_mm'] ?? module['beamSegmentLengthsMm'],
    );
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
        glassDepthSegmentLengthsMm: glassDepthSegmentLengthsMm.isEmpty
            ? [glassLengthMm]
            : glassDepthSegmentLengthsMm,
        glassSplitMode: glassSplitMode,
        glassCutPositionsMm: glassCutPositionsMm,
        profileSplitMode: profileSplitMode,
        profileCutPositionsMm: profileCutPositionsMm,
        beamSegmentLengthsMm: beamSegmentLengthsMm.isEmpty
            ? [beamLengthMm]
            : beamSegmentLengthsMm,
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
  final profileSplitThresholdMm = _number(
        params,
        'profileSplitThresholdMm',
        'profile_split_threshold_mm',
      ) ??
      7080;
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
    final coveringCodes = tab.moduleCoveringTypeCodes.isNotEmpty
        ? tab.moduleCoveringTypeCodes
        : [
            if ((coveringCode ?? '').trim().isNotEmpty)
              coveringCode!.trim(),
          ];
    final coveringMaxGlassWidth = coveringCodes.isEmpty
        ? defaultMaxGlassWidth
        : coveringCodes
            .map(
              (code) =>
                  template?.maxGlassFieldWidthFor(code) ??
                  defaultMaxGlassWidth,
            )
            .reduce((left, right) => math.min(left, right).toInt());
    final maxGlassWidth = math.min(
      tab.moduleMaxGlassFieldWidthMm ??
          draft.maxGlassFieldWidthMm ??
          defaultMaxGlassWidth,
      coveringMaxGlassWidth,
    ).toInt();
    final longLeg = depth - backOffset - frontOffset;
    if (longLeg <= 0) continue;
    final glassCountOffset = offsets[role] ?? -1;
    final beamOverride = _beamOverrideForTab(tab);
    final beamCount = beamOverride.beamCount ??
        _calculateBeamCount(
          width,
          beamWidth,
          glassOverlap,
          maxGlassWidth,
          draft.forceOddBeams,
          beamCountOffsets[role] ?? -1,
        );
    final beamLength = beamOverride.beamLengthMm ??
        (longLeg / math.cos(angle * math.pi / 180)).round();
    final glassCountAcrossWidth = math.max(0, beamCount + glassCountOffset).toInt();
    if (glassCountAcrossWidth <= 0) continue;
    final beamStep = (width - beamCount * beamWidth) / glassCountAcrossWidth;
    final roundedBeamStep = (beamStep * 10).round() / 10;
    final glassWidth = (roundedBeamStep - wallGutterBlendeClearanceMm + glassOverlap).truncate();
    final unsplitGlassLength = (beamLength + glassFrontAdd + _angleCorrection(angle)).round();

    final beamRunStartMm = backOffset.round();
    final beamRunEndMm = (depth - frontOffset).round();
    final glassSplitMode = tab.manufacturingSplitMode('glass');
    final profileSplitMode = tab.manufacturingSplitMode('profiles');
    final manualGlassCutPositionsMm = _normalizedManualCutPositions(
      tab.manufacturingSplitCuts('glass'),
      glassSplitMode,
      beamRunStartMm,
      beamRunEndMm,
    );
    final manualProfileCutPositionsMm = _normalizedManualCutPositions(
      tab.manufacturingSplitCuts('profiles'),
      profileSplitMode,
      beamRunStartMm,
      beamRunEndMm,
    );
    final automaticProfilePieceCount = math.max(
      1,
      (beamLength / profileSplitThresholdMm).ceil(),
    ).toInt();
    final automaticProfileCutPositionsMm = _automaticCutPositions(
      beamRunStartMm,
      beamRunEndMm,
      automaticProfilePieceCount,
    );

    final automaticGlassDepthFieldCount = math.max(
      1,
      (beamLength / singleGlassFieldMaxBeamLength).ceil(),
    ).toInt();
    final automaticGlassCutPositionsMm = _automaticCutPositions(
      beamRunStartMm,
      beamRunEndMm,
      automaticGlassDepthFieldCount,
    );

    final baseProfileCutPositionsMm = profileSplitMode == 'manual'
        ? manualProfileCutPositionsMm
        : profileSplitMode.startsWith('as_module:')
            ? _moduleLengthCutPositions(
                profileSplitMode,
                orderedTabs,
                beamRunStartMm,
                beamRunEndMm,
                frontOffset,
              )
            : automaticProfileCutPositionsMm;
    final baseGlassCutPositionsMm = glassSplitMode == 'manual'
        ? manualGlassCutPositionsMm
        : glassSplitMode.startsWith('as_module:')
            ? _moduleLengthCutPositions(
                glassSplitMode,
                orderedTabs,
                beamRunStartMm,
                beamRunEndMm,
                frontOffset,
              )
            : automaticGlassCutPositionsMm;

    late final List<int> profileCutPositionsMm;
    late final List<int> glassCutPositionsMm;
    if (profileSplitMode == 'as_glass' && glassSplitMode == 'as_profile') {
      profileCutPositionsMm = automaticProfileCutPositionsMm;
      glassCutPositionsMm = profileCutPositionsMm;
    } else {
      profileCutPositionsMm = profileSplitMode == 'as_glass'
          ? baseGlassCutPositionsMm
          : baseProfileCutPositionsMm;
      glassCutPositionsMm = glassSplitMode == 'as_profile'
          ? profileCutPositionsMm
          : baseGlassCutPositionsMm;
    }

    final calculatedBeamSegmentLengthsMm = profileSplitMode != 'auto'
        ? _slopedSegmentsFromWallCuts(
            beamRunStartMm,
            beamRunEndMm,
            profileCutPositionsMm,
            angle,
          )
        : List<int>.filled(
            automaticProfilePieceCount,
            automaticProfilePieceCount > 1
                ? (beamLength / automaticProfilePieceCount).round()
                : beamLength,
            growable: false,
          );
    final beamSegmentLengthsMm = beamOverride.beamLengthMm != null
        ? _scaleSegmentLengthsToTotal(calculatedBeamSegmentLengthsMm, beamLength)
        : calculatedBeamSegmentLengthsMm;
    final automaticGlassJointGap =
        glassDepthJointGap * math.max(0, automaticGlassDepthFieldCount - 1);
    final automaticGlassLength =
        ((unsplitGlassLength - automaticGlassJointGap) /
                automaticGlassDepthFieldCount)
            .round();

    final calculatedGlassBeamSegmentsMm = glassSplitMode != 'auto'
        ? _slopedSegmentsFromWallCuts(
            beamRunStartMm,
            beamRunEndMm,
            glassCutPositionsMm,
            angle,
          )
        : const <int>[];
    final resolvedGlassBeamSegmentsMm = beamOverride.beamLengthMm != null
        ? _scaleSegmentLengthsToTotal(calculatedGlassBeamSegmentsMm, beamLength)
        : calculatedGlassBeamSegmentsMm;
    final glassDepthSegmentLengthsMm = glassSplitMode != 'auto'
        ? _manualGlassSegmentLengths(
            resolvedGlassBeamSegmentsMm,
            glassFrontAdd,
            glassDepthJointGap,
            angle,
          )
        : List<int>.filled(
            automaticGlassDepthFieldCount,
            automaticGlassLength,
            growable: false,
          );
    final glassDepthFieldCount =
        math.max(1, glassDepthSegmentLengthsMm.length).toInt();
    final totalGlassLengthMm = glassDepthSegmentLengthsMm.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final glassLength = (totalGlassLengthMm / glassDepthFieldCount).round();
    final glassCount = glassCountAcrossWidth * glassDepthFieldCount;
    final glassArea = _roundAreaUp(
      glassCountAcrossWidth *
          (glassWidth / 1000) *
          (totalGlassLengthMm / 1000),
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
        glassDepthSegmentLengthsMm: glassDepthSegmentLengthsMm,
        glassSplitMode: glassSplitMode,
        glassCutPositionsMm: glassCutPositionsMm,
        profileSplitMode: profileSplitMode,
        profileCutPositionsMm: profileCutPositionsMm,
        beamSegmentLengthsMm: beamSegmentLengthsMm,
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

List<int> _normalizedManualCutPositions(
  List<int> requested,
  String mode,
  int minPositionMm,
  int maxPositionMm,
) {
  if (mode != 'manual') return const [];
  final values = requested
      .where((value) => value > minPositionMm && value < maxPositionMm)
      .toSet()
      .toList(growable: false)
    ..sort();
  return values;
}

List<int> _automaticCutPositions(
  int startPositionMm,
  int endPositionMm,
  int pieceCount,
) {
  if (pieceCount <= 1) return const [];
  final runMm = endPositionMm - startPositionMm;
  return List<int>.generate(
    pieceCount - 1,
    (index) => (startPositionMm + runMm * (index + 1) / pieceCount).round(),
    growable: false,
  );
}

List<int> _moduleLengthCutPositions(
  String mode,
  List<CalculatorSetContentTab> tabs,
  int minPositionMm,
  int maxPositionMm,
  double frontOffsetMm,
) {
  if (!mode.startsWith('as_module:')) return const [];
  final role = mode.substring('as_module:'.length).trim().toLowerCase();
  CalculatorSetContentTab? reference;
  for (final tab in tabs) {
    if (tab.moduleRole.trim().toLowerCase() == role) {
      reference = tab;
      break;
    }
  }
  final depthMm = reference?.moduleDepthMm;
  if (depthMm == null || depthMm <= 0) return const [];
  final referenceRunMm = depthMm - minPositionMm - frontOffsetMm;
  if (referenceRunMm <= 0) return const [];
  final cutPositionMm = (maxPositionMm - referenceRunMm).round();
  if (cutPositionMm <= minPositionMm || cutPositionMm >= maxPositionMm) {
    return const [];
  }
  return [cutPositionMm];
}

List<int> _slopedSegmentsFromWallCuts(
  int startPositionMm,
  int endPositionMm,
  List<int> cutPositionsMm,
  int angleDeg,
) {
  final cosine = math.cos(angleDeg * math.pi / 180);
  final points = [startPositionMm, ...cutPositionsMm, endPositionMm];
  return List<int>.generate(
    math.max(0, points.length - 1),
    (index) => math.max(
      1,
      ((points[index + 1] - points[index]) / cosine).round(),
    ).toInt(),
    growable: false,
  );
}

List<int> _manualGlassSegmentLengths(
  List<int> beamSegmentsMm,
  double glassFrontAddMm,
  double glassDepthJointGapMm,
  int angleDeg,
) {
  if (beamSegmentsMm.isEmpty) return const [];
  final segments = [...beamSegmentsMm];
  segments[segments.length - 1] +=
      (glassFrontAddMm + _angleCorrection(angleDeg)).round();
  final halfGap = glassDepthJointGapMm / 2;
  for (var index = 0; index < segments.length - 1; index++) {
    segments[index] = math.max(1, (segments[index] - halfGap).round()).toInt();
    segments[index + 1] =
        math.max(1, (segments[index + 1] - halfGap).round()).toInt();
  }
  return segments;
}

/// Article that carries the module beam (Träger) rows in Set Contents.
/// Overriding its quantity or installed length changes the glass fields and the
/// dependent profiles 15184 / 15189 / 16912, so the geometry itself has to
/// follow the override instead of only the resulting BOM. Mirrors
/// `resolveBeamModuleOverrides` in `roof-calculation-service.ts`.
const String _beamOverrideArticleNo = '15698';

class _BeamModuleOverride {
  const _BeamModuleOverride({this.beamCount, this.beamLengthMm});

  final int? beamCount;
  final int? beamLengthMm;
}

bool _setContentItemHasArticle(
  CalculatorSetContentItem item,
  String articleNo,
) {
  final wanted = articleNo.trim();
  if (wanted.isEmpty) return false;
  for (final value in [item.articleNo, item.profileNo, item.baseCode]) {
    final normalized = value?.trim() ?? '';
    if (normalized == wanted ||
        normalized.split(RegExp(r'\s+')).first == wanted) {
      return true;
    }
  }
  return false;
}

num _setContentSourceNumber(
  CalculatorSetContentItem item,
  String snakeKey,
  String camelKey,
  num fallback,
) {
  final raw = item.sourceComponent[snakeKey] ?? item.sourceComponent[camelKey];
  return raw is num ? raw : num.tryParse('$raw') ?? fallback;
}

_BeamModuleOverride _beamOverrideForTab(CalculatorSetContentTab tab) {
  const empty = _BeamModuleOverride();
  const minimumDependentBeamLengthMm = 100;
  final items = tab.items
      .where((item) =>
          item.isCalculated &&
          _setContentItemHasArticle(item, _beamOverrideArticleNo))
      .toList(growable: false);
  if (items.isEmpty) return empty;
  final active = items
      .where((item) => item.enabled && item.overrideState != 'excluded')
      .toList(growable: false);
  // Fully excluded beams keep the last valid automatic layout, exactly like the
  // server does when it reports set_content_beam_dependency_not_applied.
  if (active.isEmpty) return empty;
  final expectedCutGroupCount = items.fold<int>(1, (current, item) {
    final count = math.max(
      1,
      _setContentSourceNumber(item, 'cut_group_count', 'cutGroupCount', 1)
          .round(),
    ).toInt();
    return math.max(current, count).toInt();
  });
  final activeCutGroups = active
      .map((item) => _setContentSourceNumber(
            item,
            'cut_group_index',
            'cutGroupIndex',
            1,
          ).round())
      .toSet();
  final hasCompleteCutGroup = expectedCutGroupCount <= 1 ||
      activeCutGroups.length == expectedCutGroupCount;

  int? beamCount;
  for (final item in active) {
    final dependencyApplied =
        item.sourceComponent['dependency_override_applied'] == true;
    final baseline = item.calculatedQuantity;
    if (!dependencyApplied &&
        baseline != null &&
        (item.quantity - baseline).abs() <= 0.000001) {
      continue;
    }
    final splitCount = math.max(
      1,
      _setContentSourceNumber(item, 'split_count', 'splitCount', 1).round(),
    ).toInt();
    final cutGroupCount = math.max(
      1,
      _setContentSourceNumber(item, 'cut_group_count', 'cutGroupCount', 1)
          .round(),
    ).toInt();
    beamCount = math.max(
      0,
      (cutGroupCount > 1 ? item.quantity : item.quantity / splitCount).round(),
    ).toInt();
    break;
  }
  if (beamCount != null && beamCount < 2) return empty;

  final first = active.first;
  final splitCount = math.max(
    1,
    _setContentSourceNumber(first, 'split_count', 'splitCount', 1).round(),
  ).toInt();
  final cutGroupCount = math.max(
    1,
    _setContentSourceNumber(first, 'cut_group_count', 'cutGroupCount', 1)
        .round(),
  ).toInt();
  final installedLengthMm = cutGroupCount > 1
      ? active.fold<double>(
          0,
          (sum, item) => sum + (item.lengthMm ?? 0).toDouble(),
        )
      : (first.lengthMm ?? 0).toDouble() * splitCount;
  final calculatedInstalledLengthMm = first.installedLengthMm?.toDouble() ??
      (cutGroupCount > 1
          ? items.fold<double>(
              0,
              (sum, item) =>
                  sum +
                  (item.calculatedLengthMm ?? item.lengthMm ?? 0).toDouble(),
            )
          : (first.calculatedLengthMm ?? first.lengthMm ?? 0).toDouble() *
              splitCount);
  final beamLengthMm = hasCompleteCutGroup &&
          installedLengthMm >= minimumDependentBeamLengthMm &&
          (installedLengthMm - calculatedInstalledLengthMm).abs() > 0.0001
      ? installedLengthMm.round()
      : null;

  if (beamCount == null && beamLengthMm == null) return empty;
  return _BeamModuleOverride(beamCount: beamCount, beamLengthMm: beamLengthMm);
}

List<int> _scaleSegmentLengthsToTotal(List<int> values, int totalMm) {
  if (values.isEmpty || totalMm <= 0) return values;
  final currentTotal = values.fold<int>(0, (sum, value) => sum + value);
  if (currentTotal <= 0) return values;
  var assigned = 0;
  return [
    for (var index = 0; index < values.length; index++)
      () {
        final next = index == values.length - 1
            ? math.max(1, totalMm - assigned).toInt()
            : math.max(1, (totalMm * values[index] / currentTotal).round())
                .toInt();
        assigned += next;
        return next;
      }(),
  ];
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

List<int> _intList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_asInt)
      .whereType<int>()
      .where((entry) => entry > 0)
      .toList(growable: false);
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
