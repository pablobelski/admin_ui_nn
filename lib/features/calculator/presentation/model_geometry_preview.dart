part of 'calculator_workspace_page.dart';

class _ModelGeometryPreview extends StatelessWidget {
  const _ModelGeometryPreview({
    required this.modelCode,
    required this.modelLabel,
  });

  final String? modelCode;
  final String? modelLabel;

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
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                  ? 'Simple generated scheme for $label.'
                  : 'Select a model to show a simple generated scheme.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter: _ModelGeometryPreviewPainter(
                  modelCode: modelCode,
                  modelLabel: modelLabel,
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

enum _ModelGeometryKind {
  rectangle,
  saddle,
  gable,
  trapezoid,
  withGable,
  custom,
  polygon,
}

class _ModelGeometryPreviewPainter extends CustomPainter {
  const _ModelGeometryPreviewPainter({
    required this.modelCode,
    required this.modelLabel,
    required this.lineColor,
    required this.mutedLineColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  final String? modelCode;
  final String? modelLabel;
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final kind = _modelGeometryKind(modelCode, modelLabel);
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thinStroke = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final accentStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = surfaceColor.withValues(alpha: 0.44)
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _ModelGeometryKind.saddle:
        _drawSaddle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.gable:
        _drawGable(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.trapezoid:
        _drawTrapezoid(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.withGable:
        _drawWithGable(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.custom:
        _drawCustom(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.polygon:
        _drawPolygon(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.rectangle:
        _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
    }

    _drawMiniTopView(canvas, size, kind, stroke, thinStroke);
  }

  _ModelGeometryKind _modelGeometryKind(String? code, String? label) {
    final value = _normalizeModelText('${code ?? ''} ${label ?? ''}');
    if (value.trim().isEmpty) return _ModelGeometryKind.rectangle;
    if (value.contains('satteldach') || value.contains('sattel')) return _ModelGeometryKind.saddle;
    if (value.contains('giebeldach')) return _ModelGeometryKind.gable;
    if (value.contains('mit giebel')) return _ModelGeometryKind.withGable;
    if (value.contains('trapez')) return _ModelGeometryKind.trapezoid;
    if (value.contains('nach mass') || value.contains('custom') || value.contains('sonder')) return _ModelGeometryKind.custom;
    if (value.contains('vieleck') || value.contains('polygon')) return _ModelGeometryKind.polygon;
    return _ModelGeometryKind.rectangle;
  }

  String _normalizeModelText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  void _drawRectangle(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final roof = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    _drawPerspectiveGrid(canvas, points, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawSaddle(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final backRidge = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.14);
    final frontRidge = Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.18);
    final leftPlane = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(backRidge.dx, backRidge.dy)
      ..lineTo(frontRidge.dx, frontRidge.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    final rightPlane = Path()
      ..moveTo(backRidge.dx, backRidge.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(frontRidge.dx, frontRidge.dy)
      ..close();
    canvas.drawPath(leftPlane, fillPaint);
    canvas.drawPath(rightPlane, fillPaint);
    canvas.drawPath(leftPlane, stroke);
    canvas.drawPath(rightPlane, stroke);
    canvas.drawLine(backRidge, frontRidge, accentStroke);
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      final left = _lerp(points.frontLeft, points.backLeft, t);
      final right = _lerp(points.frontRight, points.backRight, t);
      final ridge = _lerp(frontRidge, backRidge, t);
      canvas.drawLine(left, ridge, thinStroke);
      canvas.drawLine(ridge, right, thinStroke);
    }
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawGable(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final top = Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.24);
    final backTop = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.20);
    final roof = Path()
      ..moveTo(points.frontLeft.dx, points.frontLeft.dy)
      ..lineTo(top.dx, top.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(backTop.dx, backTop.dy)
      ..lineTo(points.backLeft.dx, points.backLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    canvas.drawLine(top, backTop, accentStroke);
    canvas.drawLine(points.frontLeft, points.backLeft, thinStroke);
    canvas.drawLine(points.frontRight, points.backRight, thinStroke);
    canvas.drawLine(points.backLeft, backTop, thinStroke);
    canvas.drawLine(backTop, points.backRight, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawTrapezoid(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints(
      frontLeft: Offset(size.width * 0.26, size.height * 0.36),
      frontRight: Offset(size.width * 0.72, size.height * 0.36),
      backLeft: Offset(size.width * 0.40, size.height * 0.14),
      backRight: Offset(size.width * 0.84, size.height * 0.17),
    );
    final roof = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    _drawPerspectiveGrid(canvas, points, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawWithGable(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
    final points = _PerspectivePoints.fromSize(size);
    final peak = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.17);
    canvas.drawLine(points.backLeft, peak, accentStroke);
    canvas.drawLine(peak, points.backRight, accentStroke);
    canvas.drawLine(peak, Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.12), thinStroke);
  }

  void _drawCustom(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
    final rect = Rect.fromLTWH(size.width * 0.38, size.height * 0.36, size.width * 0.22, size.height * 0.18);
    _drawDashedRect(canvas, rect, accentStroke);
    _drawText(canvas, 'nach Maß', Offset(rect.left, rect.bottom + 8), accentColor, 11);
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final polygon = <Offset>[
      Offset(size.width * 0.22, size.height * 0.62),
      Offset(size.width * 0.18, size.height * 0.42),
      Offset(size.width * 0.36, size.height * 0.26),
      Offset(size.width * 0.68, size.height * 0.28),
      Offset(size.width * 0.84, size.height * 0.48),
      Offset(size.width * 0.72, size.height * 0.68),
    ];
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, stroke);
    for (var i = 0; i < polygon.length; i++) {
      canvas.drawLine(polygon[i], polygon[(i + 2) % polygon.length], thinStroke);
    }
    _drawDimensionLine(canvas, polygon[0] + const Offset(0, 28), polygon[5] + const Offset(0, 28), 'Länge', accentStroke);
    _drawDimensionLine(canvas, polygon[4] + const Offset(22, 0), polygon[5] + const Offset(22, 0), 'Tiefe', accentStroke);
  }

  void _drawPerspectiveGrid(Canvas canvas, _PerspectivePoints points, Paint thinStroke) {
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      canvas.drawLine(_lerp(points.frontLeft, points.backLeft, t), _lerp(points.frontRight, points.backRight, t), thinStroke);
    }
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      canvas.drawLine(_lerp(points.frontLeft, points.frontRight, t), _lerp(points.backLeft, points.backRight, t), thinStroke);
    }
  }

  double _postHeight(Size size) => size.height * 0.52;

  void _drawPosts(Canvas canvas, Size size, _PerspectivePoints points, Paint stroke) {
    final height = _postHeight(size);
    for (final point in [points.frontLeft, points.frontRight, points.backLeft, points.backRight]) {
      canvas.drawLine(point, point + Offset(0, height), stroke);
    }
  }

  void _drawDimensions(Canvas canvas, Size size, _PerspectivePoints points, Paint accentStroke) {
    final postHeight = _postHeight(size);
    _drawDimensionLine(
      canvas,
      points.frontLeft + Offset(0, postHeight + 16),
      points.frontRight + Offset(0, postHeight + 16),
      'Länge',
      accentStroke,
    );
    _drawDimensionLine(
      canvas,
      points.frontRight + Offset(20, postHeight + 6),
      points.backRight + Offset(20, postHeight + 6),
      'Tiefe',
      accentStroke,
    );
    _drawDimensionLine(
      canvas,
      points.frontLeft + const Offset(-24, 0),
      points.frontLeft + Offset(-24, postHeight),
      'Höhe',
      accentStroke,
    );
  }

  void _drawDimensionLine(Canvas canvas, Offset start, Offset end, String label, Paint paint) {
    canvas.drawLine(start, end, paint);
    final direction = end - start;
    final length = direction.distance;
    if (length > 0) {
      final unit = direction / length;
      final normal = Offset(-unit.dy, unit.dx);
      canvas.drawLine(start - unit * 5 + normal * 5, start + unit * 5 - normal * 5, paint);
      canvas.drawLine(end - unit * 5 + normal * 5, end + unit * 5 - normal * 5, paint);
    }
    _drawText(canvas, label, _lerp(start, end, 0.5) + const Offset(0, 6), accentColor, 16, isBold: true);
  }

  void _drawMiniTopView(Canvas canvas, Size size, _ModelGeometryKind kind, Paint stroke, Paint thinStroke) {
    final rect = Rect.fromLTWH(8, 8, 86, 42);
    if (kind == _ModelGeometryKind.trapezoid) {
      final path = Path()
        ..moveTo(rect.left + 14, rect.bottom)
        ..lineTo(rect.left + 26, rect.top)
        ..lineTo(rect.right, rect.top + 4)
        ..lineTo(rect.right - 8, rect.bottom)
        ..close();
      canvas.drawPath(path, stroke);
      return;
    }
    if (kind == _ModelGeometryKind.polygon) {
      final path = Path()
        ..moveTo(rect.left + 6, rect.bottom - 8)
        ..lineTo(rect.left + 4, rect.top + 12)
        ..lineTo(rect.left + 22, rect.top)
        ..lineTo(rect.right - 12, rect.top + 2)
        ..lineTo(rect.right, rect.top + 22)
        ..lineTo(rect.right - 18, rect.bottom)
        ..close();
      canvas.drawPath(path, stroke);
      return;
    }
    canvas.drawRect(rect, stroke);
    for (var i = 1; i <= 6; i++) {
      final x = rect.left + rect.width * i / 7;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thinStroke);
    }
    if (kind == _ModelGeometryKind.saddle || kind == _ModelGeometryKind.gable || kind == _ModelGeometryKind.withGable) {
      canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), stroke);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    var drawn = 0.0;
    const dash = 7.0;
    const gap = 5.0;
    while (drawn < length) {
      final next = (drawn + dash).clamp(0, length).toDouble();
      canvas.drawLine(start + unit * drawn, start + unit * next, paint);
      drawn += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool isBold = false,
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
    painter.paint(canvas, offset - Offset(painter.width / 2, painter.height / 2));
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  @override
  bool shouldRepaint(covariant _ModelGeometryPreviewPainter oldDelegate) {
    return oldDelegate.modelCode != modelCode ||
        oldDelegate.modelLabel != modelLabel ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

class _PerspectivePoints {
  const _PerspectivePoints({
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
  });

  factory _PerspectivePoints.fromSize(Size size) {
    return _PerspectivePoints(
      frontLeft: Offset(size.width * 0.24, size.height * 0.34),
      frontRight: Offset(size.width * 0.72, size.height * 0.34),
      backLeft: Offset(size.width * 0.34, size.height * 0.12),
      backRight: Offset(size.width * 0.82, size.height * 0.12),
    );
  }

  final Offset frontLeft;
  final Offset frontRight;
  final Offset backLeft;
  final Offset backRight;
}

