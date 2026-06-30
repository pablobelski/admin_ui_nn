part of 'calculator_workspace_page.dart';

class _ModelGeometryPreview extends StatelessWidget {
  const _ModelGeometryPreview({
    required this.modelCode,
    required this.modelLabel,
    this.widthMm,
    this.depthMm,
    this.heightMm,
  });

  final String? modelCode;
  final String? modelLabel;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = (modelLabel?.trim().isNotEmpty ?? false)
        ? modelLabel!.trim()
        : ((modelCode?.trim().isNotEmpty ?? false) ? modelCode!.trim() : 'No model selected');
    final hasSelection = modelCode?.trim().isNotEmpty ?? false;

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
              child: CustomPaint(
                painter: _ModelGeometryPreviewPainter(
                  modelCode: modelCode,
                  modelLabel: modelLabel,
                  widthMm: widthMm,
                  depthMm: depthMm,
                  heightMm: heightMm,
                  lineColor: colorScheme.onSurface,
                  mutedLineColor: colorScheme.onSurfaceVariant,
                  accentColor: colorScheme.primary,
                  surfaceColor: colorScheme.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top-view footprint families that match the model list in the Google Sheet (cell B4 /
// AnfangDaten column U). Left/right handed variants are produced by mirroring a base shape.
enum _RoofShape { rectangle, lFront, lBack, uBack, tBack, angleFront, angleBack }

class _ModelGeometryPreviewPainter extends CustomPainter {
  const _ModelGeometryPreviewPainter({
    required this.modelCode,
    required this.modelLabel,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
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
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;

  // Plan space: x = 0..1 left->right, y = 0..1 front (gutter) -> back (wall).
  static const double _cut = 0.38; // depth of a step / notch / chamfer
  static const double _split = 0.58; // split position for L-shapes
  static const double _midA = 0.34; // middle notch bounds for U / T shapes
  static const double _midB = 0.66;
  static const double _ddx = 0.52; // screen direction of +depth (x component)
  static const double _ddy = 0.74; // screen direction of +depth (y component, upwards)

  @override
  void paint(Canvas canvas, Size size) {
    final (shape, mirror) = _shapeFromText('${modelCode ?? ''} ${modelLabel ?? ''}');
    var front = _frontEdge(shape);
    var back = _backEdge(shape);
    if (mirror) {
      front = _mirrorEdge(front);
      back = _mirrorEdge(back);
    }

    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rafterStroke = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final accentStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final humanStroke = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = surfaceColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Real dimensions (mm) drive the on-screen aspect ratio; fall back to typical values.
    final wMm = (widthMm ?? 4000).toDouble();
    final dMm = (depthMm ?? 3000).toDouble();
    final hMm = (heightMm ?? 2500).toDouble();
    const humanMm = 1800.0;

    const pad = 10.0;
    const labelBottom = 22.0;
    const leftMm = 880.0; // ground reserved on the left for the human + height label
    final availW = size.width - 2 * pad;
    final availH = size.height - pad - labelBottom;

    final structW = wMm + _ddx * dMm;
    final topA = -dMm * _ddy; // highest roof point (back, on screen)
    final topB = hMm - humanMm; // top of the human's head, measured from the ground
    final top = topA < topB ? topA : topB;
    final contentH = hMm - top; // ground-front is the lowest point (vy = hMm)
    final contentW = leftMm + structW;
    final kw = availW / contentW;
    final kh = availH / contentH;
    final k = kw < kh ? kw : kh; // px per mm, isotropic

    final ox = pad + (availW - contentW * k) / 2 + leftMm * k;
    final oy = pad - top * k + (availH - contentH * k) / 2;

    Offset s(double x, double y, double z) => Offset(
          ox + (x * wMm + y * dMm * _ddx) * k,
          oy + (-y * dMm * _ddy + (hMm - z)) * k,
        );

    // Footprint outline at roof level: back edge left->right, then front edge right->left.
    final outline = <Offset>[
      for (final p in back) s(p.dx, p.dy, hMm),
      for (var i = front.length - 1; i >= 0; i--) s(front[i].dx, front[i].dy, hMm),
    ];
    final roof = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (final o in outline.skip(1)) {
      roof.lineTo(o.dx, o.dy);
    }
    roof.close();
    canvas.drawPath(roof, fillPaint);

    // Rafters run front->back, evenly spaced across the width (~ one every 600 mm).
    final rafters = (wMm / 600).round().clamp(4, 12);
    for (var i = 1; i < rafters; i++) {
      final x = i / rafters;
      canvas.drawLine(s(x, _yAt(front, x), hMm), s(x, _yAt(back, x), hMm), rafterStroke);
    }

    canvas.drawPath(roof, stroke);

    // Posts at the four bounding corners of the footprint.
    final corners = <Offset>[
      Offset(0, _yAt(front, 0)),
      Offset(1, _yAt(front, 1)),
      Offset(0, _yAt(back, 0)),
      Offset(1, _yAt(back, 1)),
    ];
    for (final c in corners) {
      canvas.drawLine(s(c.dx, c.dy, hMm), s(c.dx, c.dy, 0), stroke);
    }

    _drawHuman(canvas, s(0, _yAt(front, 0), 0), humanMm * k, leftMm * k, humanStroke);
    _drawDimensions(canvas, s, front, back, hMm, accentStroke);
  }

  (_RoofShape, bool) _shapeFromText(String value) {
    final v = _normalize(value);
    if (v.contains('schrag')) {
      final right = v.contains('rechts');
      final shape = v.contains('rinne') ? _RoofShape.angleFront : _RoofShape.angleBack;
      return (shape, !right); // base edge models the "rechts" variant
    }
    if (v.contains('u geteilt')) return (_RoofShape.uBack, false);
    if (v.contains('t geteilt')) return (_RoofShape.tBack, false);
    if (v.contains('l geteilt')) {
      final right = v.contains('rechts');
      final shape = v.contains('rinne') ? _RoofShape.lFront : _RoofShape.lBack;
      return (shape, !right);
    }
    return (_RoofShape.rectangle, false);
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

  // Base (non-mirrored) gutter/front edge, left -> right.
  List<Offset> _frontEdge(_RoofShape shape) {
    switch (shape) {
      case _RoofShape.lFront:
        return const [Offset(0, 0), Offset(_split, 0), Offset(_split, _cut), Offset(1, _cut)];
      case _RoofShape.angleFront:
        return const [Offset(0, 0), Offset(1, _cut)];
      case _RoofShape.rectangle:
      case _RoofShape.lBack:
      case _RoofShape.uBack:
      case _RoofShape.tBack:
      case _RoofShape.angleBack:
        return const [Offset(0, 0), Offset(1, 0)];
    }
  }

  // Base (non-mirrored) wall/back edge, left -> right.
  List<Offset> _backEdge(_RoofShape shape) {
    switch (shape) {
      case _RoofShape.lBack:
        return const [Offset(0, 1), Offset(_split, 1), Offset(_split, 1 - _cut), Offset(1, 1 - _cut)];
      case _RoofShape.uBack:
        return const [
          Offset(0, 1),
          Offset(_midA, 1),
          Offset(_midA, 1 - _cut),
          Offset(_midB, 1 - _cut),
          Offset(_midB, 1),
          Offset(1, 1),
        ];
      case _RoofShape.tBack:
        return const [
          Offset(0, 1 - _cut),
          Offset(_midA, 1 - _cut),
          Offset(_midA, 1),
          Offset(_midB, 1),
          Offset(_midB, 1 - _cut),
          Offset(1, 1 - _cut),
        ];
      case _RoofShape.angleBack:
        return const [Offset(0, 1), Offset(1, 1 - _cut)];
      case _RoofShape.rectangle:
      case _RoofShape.lFront:
      case _RoofShape.angleFront:
        return const [Offset(0, 1), Offset(1, 1)];
    }
  }

  List<Offset> _mirrorEdge(List<Offset> edge) {
    final out = <Offset>[];
    for (var i = edge.length - 1; i >= 0; i--) {
      out.add(Offset(1 - edge[i].dx, edge[i].dy));
    }
    return out;
  }

  // Depth (y) of an edge at a given x, by linear interpolation along its monotone-x polyline.
  double _yAt(List<Offset> edge, double x) {
    for (var i = 0; i < edge.length - 1; i++) {
      final a = edge[i];
      final b = edge[i + 1];
      if (a.dx == b.dx) continue; // vertical step
      if (x >= a.dx - 1e-6 && x <= b.dx + 1e-6) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + t * (b.dy - a.dy);
      }
    }
    return x > edge.first.dx ? edge.last.dy : edge.first.dy;
  }

  void _drawHuman(Canvas canvas, Offset frontLeftGround, double h, double leftPx, Paint paint) {
    final cx = frontLeftGround.dx - leftPx * 0.60;
    final feet = frontLeftGround.dy;
    final headTop = feet - h;
    final r = h * 0.11;
    canvas.drawCircle(Offset(cx, headTop + r), r, paint);
    final neck = headTop + 2 * r;
    final hip = feet - h * 0.42;
    canvas.drawLine(Offset(cx, neck), Offset(cx, hip), paint); // torso
    canvas.drawLine(Offset(cx, hip), Offset(cx - h * 0.14, feet), paint); // legs
    canvas.drawLine(Offset(cx, hip), Offset(cx + h * 0.14, feet), paint);
    final shoulder = neck + h * 0.10;
    canvas.drawLine(Offset(cx, shoulder), Offset(cx - h * 0.15, shoulder + h * 0.18), paint); // arms
    canvas.drawLine(Offset(cx, shoulder), Offset(cx + h * 0.15, shoulder + h * 0.18), paint);
  }

  void _drawDimensions(
    Canvas canvas,
    Offset Function(double, double, double) s,
    List<Offset> front,
    List<Offset> back,
    double hMm,
    Paint paint,
  ) {
    final frontLeftGround = s(0, _yAt(front, 0), 0);
    final frontRightGround = s(1, _yAt(front, 1), 0);
    final backRightGround = s(1, _yAt(back, 1), 0);
    final frontLeftTop = s(0, _yAt(front, 0), hMm);

    // Width below the front edge.
    _dimLine(canvas, frontLeftGround + const Offset(0, 10), frontRightGround + const Offset(0, 10), paint);
    _drawText(canvas, _dimText(widthMm, 'Breite'), _lerp(frontLeftGround, frontRightGround, 0.5) + const Offset(0, 18), accentColor, 11);

    // Depth along the right edge.
    _dimLine(canvas, frontRightGround + const Offset(12, 0), backRightGround + const Offset(12, 0), paint);
    _drawText(canvas, _dimText(depthMm, 'Tiefe'), _lerp(frontRightGround, backRightGround, 0.5) + const Offset(26, 0), accentColor, 11);

    // Height along the front-left post, label to the right (empty area under the roof).
    _dimLine(canvas, frontLeftTop, frontLeftGround, paint);
    _drawText(canvas, _dimText(heightMm, 'Höhe'), _lerp(frontLeftTop, frontLeftGround, 0.5) + const Offset(6, 0), accentColor, 11, hAlign: 0);
  }

  String _dimText(int? mm, String fallback) => mm != null ? '$mm mm' : fallback;

  void _dimLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final direction = end - start;
    final length = direction.distance;
    if (length > 0) {
      final unit = direction / length;
      final normal = Offset(-unit.dy, unit.dx);
      canvas.drawLine(start - unit * 4 + normal * 4, start + unit * 4 - normal * 4, paint);
      canvas.drawLine(end - unit * 4 + normal * 4, end + unit * 4 - normal * 4, paint);
    }
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
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width * hAlign, painter.height / 2));
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  @override
  bool shouldRepaint(covariant _ModelGeometryPreviewPainter oldDelegate) {
    return oldDelegate.modelCode != modelCode ||
        oldDelegate.modelLabel != modelLabel ||
        oldDelegate.widthMm != widthMm ||
        oldDelegate.depthMm != depthMm ||
        oldDelegate.heightMm != heightMm ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
