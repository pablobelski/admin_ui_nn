import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/http/admin_resource_repository.dart';
import '../../../core/ui/media_file_actions.dart';
import '../data/calculator_models.dart';
import '../data/roof_geometry_calculation.dart';

class ModelGeometryPreview extends ConsumerStatefulWidget {
  const ModelGeometryPreview({
    super.key,
    required this.modelCode,
    required this.modelLabel,
    required this.mediaRepository,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.geometryParams = const [],
    this.modules = const [],
    this.moduleRoles = const [],
    this.calculatedModules = const [],
    this.calculationNumber,
    this.calculationName,
    this.colorCode,
    this.colorSwatchColor,
    this.coveringName,
    this.highlightedModuleIndex,
    this.roofAngleDeg,
    this.rearHeightMm,
    this.frontHeightMm,
  });

  final String? modelCode;
  final String? modelLabel;
  final AdminResourceRepository mediaRepository;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final List<CalculatorSetContentTab> modules;
  final List<String> moduleRoles;
  final List<RoofModuleCalculation> calculatedModules;
  final String? calculationNumber;
  final String? calculationName;
  final String? colorCode;
  final Color? colorSwatchColor;
  final String? coveringName;
  final int? highlightedModuleIndex;
  final int? roofAngleDeg;
  final int? rearHeightMm;
  final int? frontHeightMm;

  @override
  ConsumerState<ModelGeometryPreview> createState() => _ModelGeometryPreviewState();
}

class _ModelGeometryPreviewState extends ConsumerState<ModelGeometryPreview> {
  late Future<ui.Image?> _humanImageFuture;

  @override
  void initState() {
    super.initState();
    _humanImageFuture = _loadHumanImage();
  }

  Future<ui.Image?> _loadHumanImage() async {
    try {
      final mediaFile = await widget.mediaRepository.findMediaFileByOriginalFilename('human.png');
      final fileId = mediaFile?['id']?.toString().trim() ?? '';
      if (fileId.isEmpty) return null;
      final response = await widget.mediaRepository.viewMediaFile(fileId);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(response.bytes, completer.complete);
      return completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = _modelDisplayLabel;
    final hasSelection = widget.modelCode?.trim().isNotEmpty ?? false;
    final authSession = ref.watch(authSessionProvider);
    final currentUser = _currentUserLabel(authSession);

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Open large geometry preview',
                  onPressed: hasSelection ? () => _showExpandedPreview(context, currentUser) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                ),
                const SizedBox(width: 4),
                Icon(Icons.schema_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Geometry preview', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasSelection
                  ? 'Schematic of $label, scaled to the entered dimensions.'
                  : 'Select a model to show a schematic of the roof shape.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: _buildGeometryCanvas(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  String get _modelDisplayLabel {
    final label = widget.modelLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final code = widget.modelCode?.trim();
    return code != null && code.isNotEmpty ? code : 'No model selected';
  }

  Widget _buildGeometryCanvas(ColorScheme colorScheme) {
    return FutureBuilder<ui.Image?>(
      future: _humanImageFuture,
      builder: (context, snapshot) {
        return CustomPaint(
          painter: _ModelGeometryPreviewPainter(
            modelCode: widget.modelCode,
            modelLabel: widget.modelLabel,
            widthMm: widget.widthMm,
            depthMm: widget.depthMm,
            heightMm: widget.heightMm,
            geometryParams: widget.geometryParams,
            colorCode: widget.colorCode,
            colorSwatchColor: widget.colorSwatchColor,
            coveringName: widget.coveringName,
            humanImage: snapshot.data,
            lineColor: colorScheme.onSurface,
            mutedLineColor: colorScheme.onSurfaceVariant,
            accentColor: colorScheme.primary,
            surfaceColor: colorScheme.surface,
            highlightedModuleIndex: widget.highlightedModuleIndex,
            roofAngleDeg: widget.roofAngleDeg,
            rearHeightMm: widget.rearHeightMm,
            frontHeightMm: widget.frontHeightMm,
            calculatedModules: widget.calculatedModules,
          ),
        );
      },
    );
  }

  Future<void> _showExpandedPreview(BuildContext context, String currentUser) async {
    final repaintBoundaryKey = GlobalKey();
    final colorScheme = Theme.of(context).colorScheme;
    final exportDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(28),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.schema_outlined, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Geometry preview · $_modelDisplayLabel',
                          style: Theme.of(dialogContext).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download PNG',
                        onPressed: () => _downloadExpandedPreview(
                          repaintBoundaryKey,
                          exportDate,
                        ),
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: RepaintBoundary(
                      key: repaintBoundaryKey,
                      child: ColoredBox(
                        color: colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _ExpandedPreviewInfo(
                                  date: exportDate,
                                  modelLabel: _modelDisplayLabel,
                                  modelCode: widget.modelCode,
                                  calculationNumber: widget.calculationNumber,
                                  calculationName: widget.calculationName,
                                  widthMm: widget.widthMm,
                                  depthMm: widget.depthMm,
                                  heightMm: widget.heightMm,
                                  roofAngleDeg: widget.roofAngleDeg,
                                  coveringName: widget.coveringName,
                                  modules: widget.modules,
                                  moduleRoles: widget.moduleRoles,
                                  currentUser: currentUser,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(child: _buildGeometryCanvas(colorScheme)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadExpandedPreview(GlobalKey repaintBoundaryKey, DateTime exportDate) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = repaintBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Geometry preview is not ready for export.');
      }

      final image = await renderObject.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('PNG encoding failed.');

      final calculation = widget.calculationNumber?.trim();
      final baseName = calculation == null || calculation.isEmpty ? 'roof_geometry' : calculation;
      downloadMediaBytes(
        byteData.buffer.asUint8List(),
        filename: '${_safeFilename(baseName)}_${_fileDate(exportDate)}.png',
        contentType: 'image/png',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geometry preview download failed: $error')),
      );
    }
  }
}

class _ExpandedPreviewInfo extends StatelessWidget {
  const _ExpandedPreviewInfo({
    required this.date,
    required this.modelLabel,
    required this.modelCode,
    required this.calculationNumber,
    required this.calculationName,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.roofAngleDeg,
    required this.coveringName,
    required this.modules,
    required this.moduleRoles,
    required this.currentUser,
  });

  final DateTime date;
  final String modelLabel;
  final String? modelCode;
  final String? calculationNumber;
  final String? calculationName;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final int? roofAngleDeg;
  final String? coveringName;
  final List<CalculatorSetContentTab> modules;
  final List<String> moduleRoles;
  final String currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final modelCodeValue = modelCode?.trim();
    final calculationNumberValue = calculationNumber?.trim();
    final calculationNameValue = calculationName?.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium ?? const TextStyle(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roof geometry', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _PreviewMetadataRow(label: 'Date', value: _displayDate(date)),
            _PreviewMetadataRow(
              label: 'Roof type',
              value: modelCodeValue == null || modelCodeValue.isEmpty
                  ? modelLabel
                  : '$modelLabel ($modelCodeValue)',
            ),
            if (coveringName?.trim().isNotEmpty == true)
              _PreviewMetadataRow(label: 'Covering', value: coveringName!.trim()),
            _PreviewMetadataRow(
              label: 'Calculation',
              value: calculationNumberValue == null || calculationNumberValue.isEmpty
                  ? 'New calculation'
                  : calculationNumberValue,
            ),
            if (calculationNameValue != null && calculationNameValue.isNotEmpty)
              _PreviewMetadataRow(label: 'Name', value: calculationNameValue),
            _PreviewMetadataRow(
              label: 'Overall dimensions',
              value: 'B: ${_dimensionValue(widthMm)} mm × T: ${_dimensionValue(depthMm)} mm × H: ${_dimensionValue(heightMm)} mm',
            ),
            if (roofAngleDeg != null) _PreviewMetadataRow(label: 'Roof angle', value: '$roofAngleDeg°'),
            const SizedBox(height: 8),
            Text('Modules', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (modules.isEmpty)
              const Text('—')
            else
              for (var index = 0; index < modules.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '${index + 1} · ${_moduleLabel(_effectiveModuleRole(modules[index], index, moduleRoles), index + 1)} · '
                    'T: ${_dimensionValue(modules[index].moduleDepthMm)} mm × '
                    'B: ${_dimensionValue(modules[index].moduleWidthMm)} mm',
                  ),
                ),
            const Spacer(),
            const Divider(),
            _PreviewMetadataRow(label: 'User', value: currentUser),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetadataRow extends StatelessWidget {
  const _PreviewMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _currentUserLabel(AuthSessionState session) {
  final fullName = session.fullName?.trim();
  final email = session.email?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    if (email != null && email.isNotEmpty) return '$fullName · $email';
    return fullName;
  }
  if (email != null && email.isNotEmpty) return email;
  return '—';
}


String _effectiveModuleRole(
  CalculatorSetContentTab module,
  int index,
  List<String> moduleRoles,
) {
  final storedRole = module.moduleRole.trim();
  final normalized = storedRole.toLowerCase();
  final isGenericRole = storedRole.isEmpty || RegExp(r'^module[_\s-]*\d+$').hasMatch(normalized);
  if (isGenericRole && index < moduleRoles.length) {
    final configuredRole = moduleRoles[index].trim();
    if (configuredRole.isNotEmpty) return configuredRole;
  }
  return storedRole;
}

String _moduleLabel(String role, int index) {
  final value = role.trim();
  if (value.isEmpty) return 'Module $index';
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _dimensionValue(int? value) => value == null ? '—' : '$value';

String _displayDate(DateTime value) {
  String two(int item) => item.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
}

String _fileDate(DateTime value) {
  String two(int item) => item.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_${two(value.hour)}${two(value.minute)}';
}

String _safeFilename(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return normalized.isEmpty ? 'roof_geometry' : normalized;
}

List<RoofGeometryParam> geometryPreviewParamsFromDraft(CalculatorDraft draft) {
  final params = <RoofGeometryParam>[
    RoofGeometryParam('B', draft.widthMm),
    RoofGeometryParam('BR', draft.widthMm),
    RoofGeometryParam('BW', draft.widthMm),
    RoofGeometryParam('TK', draft.depthMm),
    RoofGeometryParam('T', draft.depthMm),
    RoofGeometryParam('D', draft.depthMm),
    RoofGeometryParam('H', draft.heightMm),
  ];

  for (var i = 0; i < draft.setContents.length; i++) {
    final tab = draft.setContents[i];
    final index = i + 1;
    params.add(RoofGeometryParam('BR$index', tab.blockWidthMm));
    params.add(RoofGeometryParam('BW$index', tab.blockWidthMm));
    params.add(RoofGeometryParam('TK$index', tab.blockDepthMm));
  }

  return params;
}

class RoofGeometryParam {
  const RoofGeometryParam(this.code, this.valueMm);

  final String code;
  final int? valueMm;
}

enum _RoofShape {
  rectangle,
  lFront,
  lBack,
  uBack,
  tBack,
  angleFront,
  angleBack,
}

class _RoofProfile {
  const _RoofProfile({
    required this.shape,
    required this.smallPartOnLeft,
    this.mirrorView = false,
  });

  final _RoofShape shape;
  final bool smallPartOnLeft;
  final bool mirrorView;
}

class _RoofLayout {
  const _RoofLayout({
    required this.front,
    required this.back,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.dimensions,
    required this.postPoints,
    required this.rafterX,
    this.moduleAreas = const [],
    this.widthDimensionsOnFront = false,
  });

  final List<Offset> front;
  final List<Offset> back;
  final double widthMm;
  final double depthMm;
  final double heightMm;
  final List<_RoofDimensionLine> dimensions;
  final List<Offset> postPoints;
  final List<double> rafterX;
  final List<_RoofModuleArea> moduleAreas;
  final bool widthDimensionsOnFront;
}

class _RoofModuleArea {
  const _RoofModuleArea({required this.index, required this.corners});

  final int index;
  final List<Offset> corners;
}

class _RoofDimensionLine {
  const _RoofDimensionLine({
    required this.code,
    required this.start,
    required this.end,
    this.offset = Offset.zero,
    this.hAlign = 0.5,
  });

  final String code;
  final Offset start;
  final Offset end;
  final Offset offset;
  final double hAlign;
}

class _GeometryParamBag {
  _GeometryParamBag(List<RoofGeometryParam> params)
      : _values = {
          for (final param in params)
            if (param.valueMm != null && param.valueMm! > 0) _normalizeCode(param.code): param.valueMm!.toDouble(),
        };

  final Map<String, double> _values;

  double value(List<String> codes, double fallback) {
    for (final code in codes) {
      final value = _values[_normalizeCode(code)];
      if (value != null && value > 0) return value;
    }
    return fallback;
  }

  int? intValue(String code) {
    final value = _values[_normalizeCode(code)];
    return value?.round();
  }

  static String _normalizeCode(String code) => code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

class _ModelGeometryPreviewPainter extends CustomPainter {
  const _ModelGeometryPreviewPainter({
    required this.modelCode,
    required this.modelLabel,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.geometryParams,
    required this.colorCode,
    required this.colorSwatchColor,
    required this.coveringName,
    required this.humanImage,
    required this.lineColor,
    required this.mutedLineColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.highlightedModuleIndex,
    required this.roofAngleDeg,
    required this.rearHeightMm,
    required this.frontHeightMm,
    required this.calculatedModules,
  });

  final String? modelCode;
  final String? modelLabel;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final String? colorCode;
  final Color? colorSwatchColor;
  final String? coveringName;
  final ui.Image? humanImage;
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;
  final int? highlightedModuleIndex;
  final int? roofAngleDeg;
  final int? rearHeightMm;
  final int? frontHeightMm;
  final List<RoofModuleCalculation> calculatedModules;

  static const double _ddx = 0.52;
  static const double _ddy = 0.73;
  static const double _defaultWidthMm = 5000;
  static const double _defaultDepthMm = 3000;
  static const double _defaultHeightMm = 2500;
  static const double _humanMm = 1800;

  @override
  void paint(Canvas canvas, Size size) {
    final profile = _shapeFromText('${modelCode ?? ''} ${modelLabel ?? ''}');
    final params = _GeometryParamBag(geometryParams);
    final layout = _layoutFor(profile, params);

    final backgroundPaint = Paint()
      ..color = Color.lerp(surfaceColor, Colors.white, 0.72) ?? surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      backgroundPaint,
    );

    const pad = 12.0;
    const labelBottom = 22.0;
    const sideGap = 10.0;
    const humanGapMm = 500.0;
    final sideRect = _previewSideRect(size, pad);
    _drawPreviewSideBackground(canvas, sideRect);

    final leftReserveMm = humanGapMm + _humanMm * 0.55;
    final projDx = profile.shape == _RoofShape.lFront ? (profile.mirrorView ? -0.42 : 0.58) : _ddx;
    final projDy = profile.shape == _RoofShape.lFront ? 0.70 : _ddy;
    final projectionLeftMm = projDx < 0 ? -projDx * layout.depthMm : 0.0;
    final roofW = layout.widthMm + projDx.abs() * layout.depthMm;
    final roofTop = -layout.depthMm * projDy;
    final humanTop = layout.heightMm - _humanMm;
    final top = roofTop < humanTop ? roofTop : humanTop;
    final contentW = leftReserveMm + projectionLeftMm + roofW;
    final contentH = layout.heightMm - top;
    // Keep a real visual guard between the full roof drawing (including
    // dimension arrows/text and beam strokes) and the separated right inset.
    // The model bounds are in millimetres, but some labels/offsets are drawn
    // directly in pixels, so reserve the margin in the available canvas area.
    const mainRightGuard = 42.0;
    final availW = _max(40, sideRect.left - pad - sideGap - mainRightGuard);
    final availH = size.height - pad - labelBottom;
    final k = _min(availW / contentW, availH / contentH);
    final ox = pad + (availW - contentW * k) / 2 + leftReserveMm * k + projectionLeftMm * k;
    final oy = pad - top * k + (availH - contentH * k) / 2;

    Offset s(double xMm, double yMm, double zMm) {
      final viewX = profile.mirrorView ? layout.widthMm - xMm : xMm;
      return Offset(
        ox + (viewX + yMm * projDx) * k,
        oy + (-yMm * projDy + (layout.heightMm - zMm)) * k,
      );
    }

    final guidePaint = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dimensionPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final roofFillPaint = Paint()
      ..color = _roofCoveringFillColor()
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, sideRect.left - sideGap * 0.5, size.height));

    _drawGroundShadow(canvas, s, layout, shadowPaint);
    _drawRoofFill(canvas, s, layout, roofFillPaint);
    _drawHighlightedModule(canvas, s, layout);

    _drawWallGuides(canvas, s, layout, guidePaint);

    _drawRafters(canvas, s, layout, k);
    _drawRoofFrame(canvas, s, layout, k);
    _drawPosts(canvas, s, layout, k);
    _drawDimensions(canvas, s, params, layout, profile, dimensionPaint);

    final humanX = profile.mirrorView ? layout.widthMm : 0.0;
    _drawHuman(canvas, s(humanX, _yAt(layout.front, humanX), 0), _humanMm * k, humanGapMm * k);
    canvas.restore();

    _drawPlanInset(canvas, sideRect, layout, profile, params);
  }

  _RoofProfile _shapeFromText(String value) {
    final v = _normalize(value);
    final isLeft = v.contains('links');
    final mirrorView = isLeft;
    if (v.contains('schrag')) {
      final shape = v.contains('rinne') ? _RoofShape.angleFront : _RoofShape.angleBack;
      return _RoofProfile(shape: shape, smallPartOnLeft: false, mirrorView: mirrorView);
    }
    if (v.contains('u geteilt') || v.contains('u wandprofil')) {
      return const _RoofProfile(shape: _RoofShape.uBack, smallPartOnLeft: false);
    }
    if (v.contains('t geteilt') || v.contains('t wandprofil')) {
      return const _RoofProfile(shape: _RoofShape.tBack, smallPartOnLeft: false);
    }
    if (v.contains('l geteilt')) {
      final shape = v.contains('rinne') ? _RoofShape.lFront : _RoofShape.lBack;
      return _RoofProfile(shape: shape, smallPartOnLeft: false, mirrorView: mirrorView);
    }
    return const _RoofProfile(shape: _RoofShape.rectangle, smallPartOnLeft: false);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll('–', ' ')
      .replaceAll('—', ' ')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll('/', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  _RoofLayout _layoutFor(_RoofProfile profile, _GeometryParamBag params) {
    final mainWidth = params.value(const ['B', 'BR', 'BW'], (widthMm ?? _defaultWidthMm).toDouble());
    final mainDepth = profile.shape == _RoofShape.rectangle
        ? params.value(const ['T', 'D', 'TK'], (depthMm ?? _defaultDepthMm).toDouble())
        : params.value(const ['TK', 'T', 'D'], (depthMm ?? _defaultDepthMm).toDouble());
    final h = params.value(const ['H'], (heightMm ?? _defaultHeightMm).toDouble());

    switch (profile.shape) {
      case _RoofShape.lFront:
        return _lLayout(
          profile: profile,
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: true,
          widthPrefix: 'BR',
        );
      case _RoofShape.lBack:
        return _lLayout(
          profile: profile,
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: false,
          widthPrefix: 'BW',
        );
      case _RoofShape.angleFront:
        return _angleLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: true,
          leftShort: profile.smallPartOnLeft,
        );
      case _RoofShape.angleBack:
        return _angleLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: false,
          leftShort: profile.smallPartOnLeft,
        );
      case _RoofShape.tBack:
        return _threePartBackLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          centerIsDeep: true,
        );
      case _RoofShape.uBack:
        return _threePartBackLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          centerIsDeep: false,
        );
      case _RoofShape.rectangle:
        return _rectangleLayout(params, mainWidth, mainDepth, h);
    }
  }

  _RoofLayout _rectangleLayout(_GeometryParamBag params, double width, double depth, double height) {
    final front = [Offset.zero, Offset(width, 0)];
    final back = [Offset(0, depth), Offset(width, depth)];
    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: depth,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(index: 1, corners: [front.first, front.last, back.last, back.first]),
      ],
      rafterX: _rafterPositions(width, const []),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: 'B', start: front.first, end: front.last, offset: const Offset(0, 16)),
        _RoofDimensionLine(code: 'T', start: front.last, end: back.last, offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _lLayout({
    required _RoofProfile profile,
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool splitAtFront,
    required String widthPrefix,
  }) {
    final smallW = params.value([widthPrefix == 'BR' ? 'BR2' : 'BW2'], width * 0.42).clamp(width * 0.18, width * 0.82).toDouble();
    final bigW = params.value([widthPrefix == 'BR' ? 'BR1' : 'BW1'], width - smallW).clamp(width * 0.18, width * 0.82).toDouble();
    final total = smallW + bigW;
    final leftW = profile.smallPartOnLeft ? smallW : bigW;
    final leftDepth = profile.smallPartOnLeft
        ? params.value(const ['TK2'], depth * 0.62)
        : params.value(const ['TK1'], depth);
    final rightDepth = profile.smallPartOnLeft
        ? params.value(const ['TK1'], depth)
        : params.value(const ['TK2'], depth * 0.62);
    final d = _max(depth, _max(leftDepth, rightDepth));
    final splitX = leftW / total * width;
    final leftFrontY = splitAtFront ? d - leftDepth : 0.0;
    final rightFrontY = splitAtFront ? d - rightDepth : 0.0;
    final leftBackY = splitAtFront ? d : leftDepth;
    final rightBackY = splitAtFront ? d : rightDepth;

    final front = splitAtFront
        ? [Offset(0, leftFrontY), Offset(splitX, leftFrontY), Offset(splitX, rightFrontY), Offset(width, rightFrontY)]
        : [Offset.zero, Offset(width, 0)];
    final back = splitAtFront
        ? [Offset(0, d), Offset(width, d)]
        : [Offset(0, leftBackY), Offset(splitX, leftBackY), Offset(splitX, rightBackY), Offset(width, rightBackY)];

    final leftWidthCode = profile.smallPartOnLeft ? '${widthPrefix}2' : '${widthPrefix}1';
    final rightWidthCode = profile.smallPartOnLeft ? '${widthPrefix}1' : '${widthPrefix}2';
    final leftDepthCode = profile.smallPartOnLeft ? 'TK2' : 'TK1';
    final rightDepthCode = profile.smallPartOnLeft ? 'TK1' : 'TK2';
    final leftY = splitAtFront ? d : leftBackY;
    final rightY = splitAtFront ? d : rightBackY;
    final leftWidthY = splitAtFront ? leftFrontY : leftBackY;
    final rightWidthY = splitAtFront ? rightFrontY : rightBackY;
    final leftWidthStart = Offset(0, leftWidthY);
    final leftWidthEnd = Offset(splitX, leftWidthY);
    final rightWidthStart = Offset(splitX, rightWidthY);
    final rightWidthEnd = Offset(width, rightWidthY);

    final postPoints = _uniquePoints([front.first, ...front, front.last]);
    final blockedRafterX = [
      for (final point in postPoints)
        if (point.dx > 1 && point.dx < width - 1) point.dx,
    ];

    final leftModuleIndex = profile.mirrorView ? 2 : 1;
    final rightModuleIndex = profile.mirrorView ? 1 : 2;
    final leftModuleCorners = splitAtFront
        ? [leftWidthStart, leftWidthEnd, Offset(splitX, leftY), Offset(0, leftY)]
        : [Offset(0, 0), Offset(splitX, 0), leftWidthEnd, leftWidthStart];
    final rightModuleCorners = splitAtFront
        ? [rightWidthStart, rightWidthEnd, Offset(width, rightY), Offset(splitX, rightY)]
        : [Offset(splitX, 0), Offset(width, 0), rightWidthEnd, rightWidthStart];

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: postPoints,
      moduleAreas: [
        _RoofModuleArea(
          index: leftModuleIndex,
          corners: leftModuleCorners,
        ),
        _RoofModuleArea(
          index: rightModuleIndex,
          corners: rightModuleCorners,
        ),
      ],
      rafterX: _rafterPositions(width, [splitX], blocked: blockedRafterX),
      widthDimensionsOnFront: splitAtFront,
      dimensions: [
        _RoofDimensionLine(code: leftWidthCode, start: leftWidthStart, end: leftWidthEnd, offset: const Offset(0, 15)),
        _RoofDimensionLine(code: rightWidthCode, start: rightWidthStart, end: rightWidthEnd, offset: const Offset(0, 15)),
        _RoofDimensionLine(code: leftDepthCode, start: Offset(0, splitAtFront ? leftFrontY : 0), end: Offset(0, leftY), offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: rightDepthCode, start: Offset(width, splitAtFront ? rightFrontY : 0), end: Offset(width, rightY), offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _angleLayout({
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool splitAtFront,
    required bool leftShort,
  }) {
    final shortDepth = params.value(const ['TK2'], depth * 0.64).clamp(depth * 0.30, depth).toDouble();
    final longDepth = params.value(const ['TK1', 'TK'], depth).clamp(shortDepth, depth * 1.20).toDouble();
    final leftDepth = leftShort ? shortDepth : longDepth;
    final rightDepth = leftShort ? longDepth : shortDepth;
    final d = _max(depth, _max(leftDepth, rightDepth));
    final front = splitAtFront
        ? [Offset(0, d - leftDepth), Offset(width, d - rightDepth)]
        : [Offset.zero, Offset(width, 0)];
    final back = splitAtFront
        ? [Offset(0, d), Offset(width, d)]
        : [Offset(0, leftDepth), Offset(width, rightDepth)];

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(index: 1, corners: [front.first, front.last, back.last, back.first]),
      ],
      rafterX: _rafterPositions(width, const []),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: 'B', start: Offset(0, 0), end: Offset(width, 0), offset: const Offset(0, 16)),
        _RoofDimensionLine(code: leftShort ? 'TK2' : 'TK1', start: front.first, end: back.first, offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: leftShort ? 'TK1' : 'TK2', start: front.last, end: back.last, offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _threePartBackLayout({
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool centerIsDeep,
  }) {
    final leftWidthCode = centerIsDeep ? 'BW2' : 'BW1';
    final centerWidthCode = centerIsDeep ? 'BW1' : 'BW3';
    final rightWidthCode = centerIsDeep ? 'BW3' : 'BW2';
    final leftW = params.value([leftWidthCode], width * 0.34).clamp(width * 0.18, width * 0.55).toDouble();
    final rightW = params.value([rightWidthCode], width * 0.30).clamp(width * 0.18, width * 0.55).toDouble();
    final centerW = params.value([centerWidthCode], width - leftW - rightW).clamp(width * 0.16, width * 0.48).toDouble();
    final total = leftW + centerW + rightW;
    final x1 = leftW / total * width;
    final x2 = (leftW + centerW) / total * width;
    final deep = params.value(const ['TK1', 'TK'], depth);
    final sideLeft = params.value(const ['TK2'], depth * 0.66);
    final sideRight = params.value(const ['TK3'], depth * 0.66);
    final leftDepth = centerIsDeep ? sideLeft : deep;
    final centerDepth = centerIsDeep ? deep : params.value(const ['TK3'], depth * 0.54);
    final rightDepth = centerIsDeep ? sideRight : params.value(const ['TK2'], depth);
    final d = _max(depth, _max(leftDepth, _max(centerDepth, rightDepth)));
    final front = [Offset.zero, Offset(width, 0)];
    final back = [
      Offset(0, leftDepth),
      Offset(x1, leftDepth),
      Offset(x1, centerDepth),
      Offset(x2, centerDepth),
      Offset(x2, rightDepth),
      Offset(width, rightDepth),
    ];

    final centerDepthCode = centerIsDeep ? 'TK1' : 'TK3';
    final leftDepthCode = centerIsDeep ? 'TK2' : 'TK1';
    final rightDepthCode = centerIsDeep ? 'TK3' : 'TK2';

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(
          index: centerIsDeep ? 2 : 1,
          corners: [Offset(0, 0), Offset(x1, 0), Offset(x1, leftDepth), Offset(0, leftDepth)],
        ),
        _RoofModuleArea(
          index: centerIsDeep ? 1 : 3,
          corners: [Offset(x1, 0), Offset(x2, 0), Offset(x2, centerDepth), Offset(x1, centerDepth)],
        ),
        _RoofModuleArea(
          index: centerIsDeep ? 3 : 2,
          corners: [Offset(x2, 0), Offset(width, 0), Offset(width, rightDepth), Offset(x2, rightDepth)],
        ),
      ],
      rafterX: _rafterPositions(width, [x1, x2]),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: leftWidthCode, start: Offset(0, leftDepth), end: Offset(x1, leftDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: centerWidthCode, start: Offset(x1, centerDepth), end: Offset(x2, centerDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: rightWidthCode, start: Offset(x2, rightDepth), end: Offset(width, rightDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: leftDepthCode, start: Offset(0, 0), end: Offset(0, leftDepth), offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: centerDepthCode, start: Offset((x1 + x2) / 2, 0), end: Offset((x1 + x2) / 2, centerDepth), offset: const Offset(12, 0), hAlign: 0),
        _RoofDimensionLine(code: rightDepthCode, start: Offset(width, 0), end: Offset(width, rightDepth), offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  Color _roofCoveringFillColor() {
    final value = coveringName?.trim().toLowerCase() ?? '';
    if (value.contains('matt')) {
      return const Color(0xFFD9DDE1).withValues(alpha: 0.78);
    }
    if (value.contains('klar')) {
      return const Color(0xFFCFEAF7).withValues(alpha: 0.74);
    }
    return Colors.white.withValues(alpha: 0.26);
  }

  void _drawGroundShadow(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final outline = <Offset>[
      ...layout.front,
      for (var i = layout.back.length - 1; i >= 0; i--) layout.back[i],
    ];
    if (outline.isEmpty) return;
    const shadowShift = Offset(64, 10);
    final path = Path();
    final first = s(outline.first.dx, outline.first.dy, 0) + shadowShift;
    path.moveTo(first.dx, first.dy);
    for (final point in outline.skip(1)) {
      final p = s(point.dx, point.dy, 0) + shadowShift;
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawRoofFill(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final outline = <Offset>[
      for (final p in layout.back) s(p.dx, p.dy, layout.heightMm),
      for (var i = layout.front.length - 1; i >= 0; i--) s(layout.front[i].dx, layout.front[i].dy, layout.heightMm),
    ];
    final roof = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (final point in outline.skip(1)) {
      roof.lineTo(point.dx, point.dy);
    }
    roof.close();
    canvas.drawPath(roof, paint);
  }


  void _drawHighlightedModule(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
  ) {
    final index = highlightedModuleIndex;
    if (index == null || index <= 0) return;
    _RoofModuleArea? area;
    for (final candidate in layout.moduleAreas) {
      if (candidate.index == index) {
        area = candidate;
        break;
      }
    }
    if (area == null || area.corners.length < 3) return;

    final path = Path();
    final first = s(area.corners.first.dx, area.corners.first.dy, layout.heightMm);
    path.moveTo(first.dx, first.dy);
    for (final point in area.corners.skip(1)) {
      final projected = s(point.dx, point.dy, layout.heightMm);
      path.lineTo(projected.dx, projected.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB7F3C6).withValues(alpha: 0.36)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7FCF8E).withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawRoofFrame(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    double k,
  ) {
    for (var i = 0; i < layout.front.length - 1; i++) {
      _drawBeam(canvas, s(layout.front[i].dx, layout.front[i].dy, layout.heightMm), s(layout.front[i + 1].dx, layout.front[i + 1].dy, layout.heightMm), k, isGutter: true);
    }
    for (var i = 0; i < layout.back.length - 1; i++) {
      _drawBeam(canvas, s(layout.back[i].dx, layout.back[i].dy, layout.heightMm), s(layout.back[i + 1].dx, layout.back[i + 1].dy, layout.heightMm), k);
    }
    _drawBeam(canvas, s(layout.front.first.dx, layout.front.first.dy, layout.heightMm), s(layout.back.first.dx, layout.back.first.dy, layout.heightMm), k);
    _drawBeam(canvas, s(layout.front.last.dx, layout.front.last.dy, layout.heightMm), s(layout.back.last.dx, layout.back.last.dy, layout.heightMm), k);
  }

  void _drawWallGuides(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final points = _wallGuidePoints(layout);
    final ground = <Offset>[];
    for (final point in points) {
      final top = s(point.dx, point.dy, layout.heightMm);
      final bottom = s(point.dx, point.dy, 0);
      canvas.drawLine(top, bottom, paint);
      ground.add(bottom);
    }
    for (var i = 0; i < ground.length - 1; i++) {
      canvas.drawLine(ground[i], ground[i + 1], paint);
    }
  }

  void _drawRafters(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    double k,
  ) {
    for (final x in _effectiveRafterX(layout)) {
      final y1 = _yAt(layout.front, x);
      final y2 = _yAt(layout.back, x);
      if ((y2 - y1).abs() < 40) continue;
      _drawBeam(canvas, s(x, y1, layout.heightMm), s(x, y2, layout.heightMm), k, isRafter: true);
    }
  }

  void _drawPosts(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    double k,
  ) {
    for (final point in layout.postPoints) {
      _drawPost(canvas, s(point.dx, point.dy, layout.heightMm), s(point.dx, point.dy, 0), k);
    }
  }

  void _drawBeam(Canvas canvas, Offset a, Offset b, double _, {bool isGutter = false, bool isRafter = false}) {
    final width = isRafter ? 2.0 : 4.0;
    final shadowAlpha = isRafter ? 0.16 : (isGutter ? 0.22 : 0.20);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: shadowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.square;
    final body = Paint()
      ..color = const Color(0xFFBFC1C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = const Color(0xFFF3F4F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRafter ? 0.7 : 1.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(a + const Offset(1.2, 1.4), b + const Offset(1.2, 1.4), shadow);
    canvas.drawLine(a, b, body);
    canvas.drawLine(a - const Offset(0.4, 0.6), b - const Offset(0.4, 0.6), light);
  }

  void _drawPost(Canvas canvas, Offset top, Offset bottom, double _) {
    const width = 4.0;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.square;
    final body = Paint()
      ..color = const Color(0xFFB6B8B9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = const Color(0xFFE8E9E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(top + const Offset(1.1, 1.2), bottom + const Offset(1.1, 1.2), shadow);
    canvas.drawLine(top, bottom, body);
    canvas.drawLine(top - const Offset(0.4, 0), bottom - const Offset(0.4, 0), light);
  }

  Rect _previewSideRect(Size size, double pad) {
    final targetWidth = _min(122, _max(104, size.width * 0.27));
    final left = _max(pad + 80, size.width - pad - targetWidth);
    return Rect.fromLTWH(left, pad, _max(48, size.width - pad - left), size.height - pad * 2);
  }

  void _drawPreviewSideBackground(Canvas canvas, Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final background = Paint()
      ..color = surfaceColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      background,
    );
    final divider = Paint()
      ..color = lineColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(rect.left - 5, rect.top), Offset(rect.left - 5, rect.bottom), divider);
  }

  void _drawDimensions(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _GeometryParamBag params,
    _RoofLayout layout,
    _RoofProfile profile,
    Paint paint,
  ) {
    for (final dim in layout.dimensions) {
      if (dim.code == 'H') continue;
      if (_isWidthDimensionCode(dim.code)) {
        final normalized = _GeometryParamBag._normalizeCode(dim.code);
        late final Offset start;
        late final Offset end;
        if (layout.widthDimensionsOnFront) {
          final startRaw = s(dim.start.dx, dim.start.dy, 0);
          final endRaw = s(dim.end.dx, dim.end.dy, 0);
          const shift = Offset(0, 10);
          start = startRaw + shift;
          end = endRaw + shift;
        } else {
          final isSchraegWidth = normalized == 'B' &&
              (profile.shape == _RoofShape.angleFront || profile.shape == _RoofShape.angleBack);
          final useDimensionY = normalized.startsWith('BW') &&
              (dim.start.dy.abs() > 1e-6 || dim.end.dy.abs() > 1e-6);
          final dimYStart = useDimensionY
              ? dim.start.dy
              : (isSchraegWidth
                  ? (profile.shape == _RoofShape.angleFront ? layout.depthMm : 0.0)
                  : layout.depthMm);
          final dimYEnd = useDimensionY
              ? dim.end.dy
              : (isSchraegWidth
                  ? (profile.shape == _RoofShape.angleFront ? layout.depthMm : 0.0)
                  : layout.depthMm);
          final startRaw = s(dim.start.dx, dimYStart, 0);
          final endRaw = s(dim.end.dx, dimYEnd, 0);
          final oppositeMid = isSchraegWidth
              ? _lerp(
                  s(dim.start.dx, profile.shape == _RoofShape.angleFront ? _yAt(layout.front, dim.start.dx) : _yAt(layout.back, dim.start.dx), 0),
                  s(dim.end.dx, profile.shape == _RoofShape.angleFront ? _yAt(layout.front, dim.end.dx) : _yAt(layout.back, dim.end.dx), 0),
                  0.5,
                )
              : _lerp(
                  s(dim.start.dx, _yAt(layout.front, dim.start.dx), 0),
                  s(dim.end.dx, _yAt(layout.front, dim.end.dx), 0),
                  0.5,
                );
          final dimMid = _lerp(startRaw, endRaw, 0.5);
          final outward = dimMid - oppositeMid;
          final outwardUnit = outward.distance > 0 ? outward / outward.distance : const Offset(0, 1);
          final shift = outwardUnit * 8;
          start = startRaw + shift;
          end = endRaw + shift;
        }
        if ((end - start).distance < 18) continue;
        _dimLine(canvas, start, end, paint);
        _drawText(canvas, _paramText(params, dim.code, null), _lerp(start, end, 0.5) + const Offset(0, 10), lineColor, 10.5, isBold: true, hAlign: 0.5);
      } else {
        final start = s(dim.start.dx, dim.start.dy, layout.heightMm) + dim.offset;
        final end = s(dim.end.dx, dim.end.dy, layout.heightMm) + dim.offset;
        if ((end - start).distance < 18) continue;
        _dimLine(canvas, start, end, paint);
        _drawText(canvas, _paramText(params, dim.code, null), _lerp(start, end, 0.5) + dim.offset * 0.10, lineColor, 10.5, isBold: true, hAlign: dim.hAlign);
      }
    }
  }

  void _drawPlanInset(Canvas canvas, Rect sideRect, _RoofLayout layout, _RoofProfile profile, _GeometryParamBag params) {
    final insetWidth = _min(86, _max(48, sideRect.width - 18));
    final insetHeight = _min(68, _max(42, sideRect.height * 0.26));
    final rect = Rect.fromLTWH(
      sideRect.left + (sideRect.width - insetWidth) / 2,
      sideRect.top,
      insetWidth,
      insetHeight,
    );
    final planPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;
    final beamPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.square;
    final scale = _min(rect.width / layout.widthMm, rect.height / layout.depthMm) * 0.82;
    final usedW = layout.widthMm * scale;
    final usedH = layout.depthMm * scale;
    final left = rect.left + (rect.width - usedW) / 2;
    final top = rect.top + (rect.height - usedH) / 2;

    Offset p(Offset point) {
      final x = profile.mirrorView ? layout.widthMm - point.dx : point.dx;
      final y = layout.depthMm - point.dy;
      return Offset(left + x * scale, top + y * scale);
    }

    final outline = <Offset>[
      ...layout.front,
      for (var i = layout.back.length - 1; i >= 0; i--) layout.back[i],
    ];
    if (outline.isNotEmpty) {
      final path = Path()..moveTo(p(outline.first).dx, p(outline.first).dy);
      for (final point in outline.skip(1)) {
        final pp = p(point);
        path.lineTo(pp.dx, pp.dy);
      }
      path.close();
      canvas.drawPath(path, planPaint);
    }
    for (final x in _effectiveRafterX(layout)) {
      final a = p(Offset(x, _yAt(layout.front, x)));
      final b = p(Offset(x, _yAt(layout.back, x)));
      canvas.drawLine(a, b, beamPaint);
    }
    const insetTextGap = 14.0;
    final hCenter = Offset(rect.center.dx, rect.bottom + insetTextGap);
    _drawText(
      canvas,
      _paramEqualsText(params, 'H', heightMm),
      hCenter,
      lineColor,
      10.5,
      isBold: true,
      hAlign: 0.5,
    );
    final colorBottom = _drawColorInset(canvas, rect, hCenter.dy + insetTextGap);
    _drawSlopeInset(canvas, sideRect, colorBottom + 6);
  }

  double _drawColorInset(Canvas canvas, Rect planRect, double top) {
    final code = colorCode?.trim();
    if (code == null || code.isEmpty) return top;

    const tileHeight = 30.0;
    final tileWidth = planRect.width + 12;
    final tileRect = Rect.fromLTWH(
      planRect.center.dx - tileWidth / 2,
      top,
      tileWidth,
      tileHeight,
    );
    final background = colorSwatchColor ?? const Color(0xFFE1E3E4);
    final foreground = background.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
    final rrect = RRect.fromRectAndRadius(tileRect, const Radius.circular(7));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = background
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = lineColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _drawText(canvas, code, tileRect.center, foreground, 11.0, isBold: true, hAlign: 0.5);
    return tileRect.bottom;
  }

  void _drawSlopeInset(Canvas canvas, Rect sideRect, double top) {
    final depth = depthMm;
    final angle = roofAngleDeg;
    final rearHeight = rearHeightMm;
    final frontHeight = frontHeightMm;
    if (depth == null ||
        depth <= 0 ||
        angle == null ||
        angle < 0 ||
        rearHeight == null ||
        rearHeight <= 0 ||
        frontHeight == null ||
        frontHeight <= 0 ||
        frontHeight > rearHeight) {
      return;
    }

    final heightDifference = rearHeight - frontHeight;
    final availableWidth = _max(36, sideRect.width - 24);
    final availableHeight = sideRect.bottom - top - 24;
    if (availableHeight < 28) return;

    final maxRiseHeight = _min(54, _max(12, availableHeight - 24));
    final geometryScale = _min(
      availableWidth / depth,
      heightDifference > 0 ? maxRiseHeight / heightDifference : availableWidth / depth,
    );
    final baseLength = depth * geometryScale;
    final rise = heightDifference * geometryScale;
    final triangleTop = top + 16;
    final bottom = triangleTop + _max(rise, 3);
    final left = sideRect.center.dx - baseLength / 2;
    final leftBottom = Offset(left, bottom);
    final rightBottom = Offset(left + baseLength, bottom);
    final rightTop = Offset(rightBottom.dx, bottom - rise);

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    if (rise > 0.5) {
      final triangle = Path()
        ..moveTo(leftBottom.dx, leftBottom.dy)
        ..lineTo(rightBottom.dx, rightBottom.dy)
        ..lineTo(rightTop.dx, rightTop.dy)
        ..close();
      canvas.drawPath(triangle, fillPaint);
      canvas.drawPath(triangle, linePaint);
    } else {
      canvas.drawLine(leftBottom, rightBottom, linePaint);
    }

    const markerSize = 6.0;
    final markerTop = Offset(rightBottom.dx, rightBottom.dy - markerSize);
    final markerInner = Offset(rightBottom.dx - markerSize, rightBottom.dy - markerSize);
    final markerLeft = Offset(rightBottom.dx - markerSize, rightBottom.dy);
    canvas.drawLine(markerTop, markerInner, linePaint);
    canvas.drawLine(markerInner, markerLeft, linePaint);

    _drawText(
      canvas,
      '$angle°',
      leftBottom + const Offset(7, -9),
      accentColor,
      9.5,
      isBold: true,
      hAlign: 0,
    );
    _drawText(
      canvas,
      'T: $depth mm',
      Offset((leftBottom.dx + rightBottom.dx) / 2, bottom + 9),
      lineColor,
      8.5,
      isBold: true,
      hAlign: 0.5,
    );
    _drawText(
      canvas,
      'ΔH: $heightDifference mm',
      Offset(rightBottom.dx - 2, rightTop.dy - 8),
      lineColor,
      8.0,
      isBold: true,
      hAlign: 1,
    );
  }

  String _paramText(_GeometryParamBag params, String code, int? fallback) {
    final value = params.intValue(code) ?? fallback;
    return value == null || value <= 0 ? code : '$code $value';
  }

  String _paramEqualsText(_GeometryParamBag params, String code, int? fallback) {
    final value = params.intValue(code) ?? fallback;
    return value == null || value <= 0 ? code : '$code: $value mm';
  }

  bool _isWidthDimensionCode(String code) {
    final normalized = _GeometryParamBag._normalizeCode(code);
    return normalized == 'B' || normalized.startsWith('BR') || normalized.startsWith('BW');
  }

  void _dimLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final direction = end - start;
    final length = direction.distance;
    if (length <= 0) return;
    final unit = direction / length;
    final normal = Offset(-unit.dy, unit.dx);
    const arrow = 6.0;
    canvas.drawLine(start - unit * arrow + normal * 3.5, start + unit * arrow - normal * 3.5, paint);
    canvas.drawLine(end - unit * arrow + normal * 3.5, end + unit * arrow - normal * 3.5, paint);
  }

  void _drawHuman(Canvas canvas, Offset frontLeftGround, double heightPx, double gapPx) {
    final feetY = frontLeftGround.dy;
    final image = humanImage;
    if (image != null) {
      final aspect = image.width / image.height;
      final widthPx = heightPx * aspect;
      final rect = Rect.fromLTWH(
        frontLeftGround.dx - gapPx - widthPx,
        feetY - heightPx,
        widthPx,
        heightPx,
      );
      paintImage(
        canvas: canvas,
        rect: rect,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      return;
    }

    final silhouette = Paint()
      ..color = Colors.black.withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    final centerX = frontLeftGround.dx - gapPx - heightPx * 0.18;
    final headR = heightPx * 0.075;
    final headCenter = Offset(centerX, feetY - heightPx + headR * 1.15);
    canvas.drawCircle(headCenter, headR, silhouette);
    final body = Path()
      ..moveTo(centerX - heightPx * 0.10, feetY - heightPx * 0.80)
      ..lineTo(centerX + heightPx * 0.10, feetY - heightPx * 0.80)
      ..lineTo(centerX + heightPx * 0.15, feetY - heightPx * 0.44)
      ..lineTo(centerX + heightPx * 0.07, feetY)
      ..lineTo(centerX - heightPx * 0.02, feetY)
      ..lineTo(centerX - heightPx * 0.03, feetY - heightPx * 0.38)
      ..lineTo(centerX - heightPx * 0.12, feetY)
      ..lineTo(centerX - heightPx * 0.21, feetY)
      ..lineTo(centerX - heightPx * 0.13, feetY - heightPx * 0.44)
      ..close();
    canvas.drawPath(body, silhouette);
  }


  List<double> _effectiveRafterX(_RoofLayout layout) {
    if (calculatedModules.isEmpty || layout.moduleAreas.isEmpty) return layout.rafterX;
    final values = <double>{};
    for (final area in layout.moduleAreas) {
      final calculation = calculatedModules
          .where((entry) => entry.moduleIndex == area.index)
          .cast<RoofModuleCalculation?>()
          .firstOrNull;
      if (calculation == null || calculation.glassCount < 1 || area.corners.isEmpty) continue;
      final xs = area.corners.map((point) => point.dx).toList(growable: false);
      final minX = xs.reduce((a, b) => math.min(a, b).toDouble());
      final maxX = xs.reduce((a, b) => math.max(a, b).toDouble());
      final span = maxX - minX;
      if (span <= 0) continue;
      // A module with N glass fields needs N + 1 delimiting beam lines.
      // For offset 0/+1 modules some boundary beams belong to neighbouring
      // modules, so using beamCount here visually under-counted the glass.
      final dividerCount = calculation.glassCount + 1;
      for (var i = 0; i < dividerCount; i++) {
        values.add(minX + span * i / (dividerCount - 1));
      }
    }
    if (values.isEmpty) return layout.rafterX;
    final result = values.toList()..sort();
    return result;
  }

  List<double> _rafterPositions(double width, List<double> fixed, {List<double> blocked = const []}) {
    final count = (width / 620).round().clamp(4, 11).toInt();
    final values = <double>{};
    for (var i = 1; i < count; i++) {
      values.add(width * i / count);
    }
    for (final value in fixed) {
      if (value > 0 && value < width) values.add(value);
    }
    final out = values
        .where((value) => !blocked.any((blockedValue) => (blockedValue - value).abs() < 80))
        .toList()
      ..sort();
    return out;
  }

  List<Offset> _wallGuidePoints(_RoofLayout layout) {
    final points = <Offset>[
      for (final point in layout.back)
        if (!_hasPostAt(layout, point)) point,
      for (final point in layout.front)
        if (!_hasPostAt(layout, point)) point,
    ];
    return _uniquePoints(points);
  }

  bool _hasPostAt(_RoofLayout layout, Offset point) {
    return layout.postPoints.any((post) => (post - point).distance < 1);
  }

  List<Offset> _uniquePoints(List<Offset> points) {
    final out = <Offset>[];
    for (final point in points) {
      if (!out.any((entry) => (entry - point).distance < 1)) out.add(point);
    }
    return out;
  }

  double _yAt(List<Offset> edge, double x) {
    for (var i = 0; i < edge.length - 1; i++) {
      final a = edge[i];
      final b = edge[i + 1];
      if ((a.dx - b.dx).abs() < 1e-6) continue;
      if (x >= _min(a.dx, b.dx) - 1e-6 && x <= _max(a.dx, b.dx) + 1e-6) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + t * (b.dy - a.dy);
      }
    }
    return x > edge.first.dx ? edge.last.dy : edge.first.dy;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double fontSize, {
    bool isBold = false,
    double hAlign = 0.5,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 86);
    painter.paint(canvas, at - Offset(painter.width * hAlign, painter.height / 2));
  }

  bool _sameGeometryParams(List<RoofGeometryParam> a, List<RoofGeometryParam> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].code != b[i].code || a[i].valueMm != b[i].valueMm) return false;
    }
    return true;
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;
  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant _ModelGeometryPreviewPainter oldDelegate) {
    return oldDelegate.modelCode != modelCode ||
        oldDelegate.modelLabel != modelLabel ||
        oldDelegate.widthMm != widthMm ||
        oldDelegate.depthMm != depthMm ||
        oldDelegate.heightMm != heightMm ||
        !_sameGeometryParams(oldDelegate.geometryParams, geometryParams) ||
        oldDelegate.colorCode != colorCode ||
        oldDelegate.colorSwatchColor != colorSwatchColor ||
        oldDelegate.coveringName != coveringName ||
        oldDelegate.humanImage != humanImage ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.highlightedModuleIndex != highlightedModuleIndex ||
        oldDelegate.roofAngleDeg != roofAngleDeg ||
        oldDelegate.rearHeightMm != rearHeightMm ||
        oldDelegate.frontHeightMm != frontHeightMm ||
        oldDelegate.calculatedModules != calculatedModules;
  }
}
