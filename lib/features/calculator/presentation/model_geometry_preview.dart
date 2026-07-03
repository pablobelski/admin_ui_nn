import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../data/calculator_models.dart';

class ModelGeometryPreview extends StatefulWidget {
  const ModelGeometryPreview({
    super.key,
    required this.modelCode,
    required this.modelLabel,
    required this.mediaRepository,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.geometryParams = const [],
    this.colorCode,
    this.colorSwatchColor,
  });

  final String? modelCode;
  final String? modelLabel;
  final AdminResourceRepository mediaRepository;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final String? colorCode;
  final Color? colorSwatchColor;

  @override
  State<ModelGeometryPreview> createState() => _ModelGeometryPreviewState();
}

class _ModelGeometryPreviewState extends State<ModelGeometryPreview> {
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
    final label = (widget.modelLabel?.trim().isNotEmpty ?? false)
        ? widget.modelLabel!.trim()
        : ((widget.modelCode?.trim().isNotEmpty ?? false) ? widget.modelCode!.trim() : 'No model selected');
    final hasSelection = widget.modelCode?.trim().isNotEmpty ?? false;

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
              child: FutureBuilder<ui.Image?>(
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
                      humanImage: snapshot.data,
                      lineColor: colorScheme.onSurface,
                      mutedLineColor: colorScheme.onSurfaceVariant,
                      accentColor: colorScheme.primary,
                      surfaceColor: colorScheme.surface,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final bool widthDimensionsOnFront;
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
    required this.humanImage,
    required this.lineColor,
    required this.mutedLineColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  final String? modelCode;
  final String? modelLabel;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final String? colorCode;
  final Color? colorSwatchColor;
  final ui.Image? humanImage;
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;

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
      ..color = Colors.white.withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, sideRect.left - sideGap * 0.5, size.height));

    _drawGroundShadow(canvas, s, layout, shadowPaint);
    _drawRoofFill(canvas, s, layout, roofFillPaint);

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

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: postPoints,
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
    final leftW = params.value(const ['BW1'], width * 0.34).clamp(width * 0.18, width * 0.55).toDouble();
    final rightW = params.value(const ['BW2'], width * 0.30).clamp(width * 0.18, width * 0.55).toDouble();
    final centerW = params.value(const ['BW3'], width - leftW - rightW).clamp(width * 0.16, width * 0.48).toDouble();
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
      rafterX: _rafterPositions(width, [x1, x2]),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: 'BW1', start: Offset(0, leftDepth), end: Offset(x1, leftDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: 'BW3', start: Offset(x1, centerDepth), end: Offset(x2, centerDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: 'BW2', start: Offset(x2, rightDepth), end: Offset(width, rightDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: leftDepthCode, start: Offset(0, 0), end: Offset(0, leftDepth), offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: centerDepthCode, start: Offset((x1 + x2) / 2, 0), end: Offset((x1 + x2) / 2, centerDepth), offset: const Offset(12, 0), hAlign: 0),
        _RoofDimensionLine(code: rightDepthCode, start: Offset(width, 0), end: Offset(width, rightDepth), offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
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
    for (final x in layout.rafterX) {
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
      ..color = lineColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.square;
    final beamPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
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
    for (final x in layout.rafterX) {
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
    _drawColorInset(canvas, rect, hCenter.dy + insetTextGap);
  }

  void _drawColorInset(Canvas canvas, Rect planRect, double top) {
    final code = colorCode?.trim();
    if (code == null || code.isEmpty) return;

    const tileHeight = 24.0;
    final tileRect = Rect.fromLTWH(
      planRect.left,
      top,
      planRect.width,
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

    _drawText(canvas, code, tileRect.center, foreground, 9.0, isBold: true, hAlign: 0.5);
  }

  String _paramText(_GeometryParamBag params, String code, int? fallback) {
    final value = params.intValue(code) ?? fallback;
    return value == null || value <= 0 ? code : '$code $value';
  }

  String _paramEqualsText(_GeometryParamBag params, String code, int? fallback) {
    final value = params.intValue(code) ?? fallback;
    return value == null || value <= 0 ? code : '$code = $value';
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
        oldDelegate.humanImage != humanImage ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
