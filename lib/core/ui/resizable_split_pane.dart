import 'package:flutter/material.dart';

class ResizableSplitPane extends StatefulWidget {
  const ResizableSplitPane({
    super.key,
    required this.first,
    required this.second,
    this.axis = Axis.horizontal,
    this.initialFraction = 0.5,
    this.minFirstFraction = 0.2,
    this.minSecondFraction = 0.2,
    this.dividerExtent = 16,
  });

  final Widget first;
  final Widget second;
  final Axis axis;
  final double initialFraction;
  final double minFirstFraction;
  final double minSecondFraction;
  final double dividerExtent;

  @override
  State<ResizableSplitPane> createState() => _ResizableSplitPaneState();
}

class _ResizableSplitPaneState extends State<ResizableSplitPane> {
  double? _fraction;
  double? _previewFraction;
  double? _dragStartFirstExtent;
  double? _dragStartGlobalPosition;

  @override
  void didUpdateWidget(covariant ResizableSplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.axis != widget.axis ||
        oldWidget.initialFraction != widget.initialFraction ||
        oldWidget.minFirstFraction != widget.minFirstFraction ||
        oldWidget.minSecondFraction != widget.minSecondFraction) {
      _fraction = null;
      _previewFraction = null;
      _dragStartFirstExtent = null;
      _dragStartGlobalPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalExtent = widget.axis == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        if (!totalExtent.isFinite || totalExtent <= widget.dividerExtent) {
          return Flex(
            direction: widget.axis,
            children: [
              Expanded(child: widget.first),
              _SplitPaneDivider(axis: widget.axis, extent: widget.dividerExtent),
              Expanded(child: widget.second),
            ],
          );
        }

        final availableExtent = totalExtent - widget.dividerExtent;
        final minFirst = widget.minFirstFraction.clamp(0.0, 0.9).toDouble();
        final maxFirst = (1 - widget.minSecondFraction).clamp(minFirst, 1.0).toDouble();
        final fraction = (_fraction ?? widget.initialFraction).clamp(minFirst, maxFirst).toDouble();
        final firstExtent = availableExtent * fraction;
        final secondExtent = availableExtent - firstExtent;
        final previewFraction = _previewFraction?.clamp(minFirst, maxFirst).toDouble();

        double globalAxisPosition(Offset position) {
          return widget.axis == Axis.horizontal ? position.dx : position.dy;
        }

        void startDrag(DragStartDetails details) {
          setState(() {
            _dragStartFirstExtent = firstExtent;
            _dragStartGlobalPosition = globalAxisPosition(details.globalPosition);
            _previewFraction = fraction;
          });
        }

        void updateDrag(DragUpdateDetails details) {
          final startFirstExtent = _dragStartFirstExtent;
          final startGlobalPosition = _dragStartGlobalPosition;
          if (startFirstExtent == null || startGlobalPosition == null) return;

          final delta = globalAxisPosition(details.globalPosition) - startGlobalPosition;
          setState(() {
            _previewFraction = ((startFirstExtent + delta) / availableExtent).clamp(minFirst, maxFirst).toDouble();
          });
        }

        void endDrag() {
          setState(() {
            _fraction = (_previewFraction ?? fraction).clamp(minFirst, maxFirst).toDouble();
            _previewFraction = null;
            _dragStartFirstExtent = null;
            _dragStartGlobalPosition = null;
          });
        }

        void cancelDrag() {
          setState(() {
            _previewFraction = null;
            _dragStartFirstExtent = null;
            _dragStartGlobalPosition = null;
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Flex(
                direction: widget.axis,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: widget.axis == Axis.horizontal ? firstExtent : null,
                    height: widget.axis == Axis.vertical ? firstExtent : null,
                    child: widget.first,
                  ),
                  _SplitPaneDivider(
                    axis: widget.axis,
                    extent: widget.dividerExtent,
                    onDragStart: startDrag,
                    onDragUpdate: updateDrag,
                    onDragEnd: (_) => endDrag(),
                    onDragCancel: cancelDrag,
                  ),
                  SizedBox(
                    width: widget.axis == Axis.horizontal ? secondExtent : null,
                    height: widget.axis == Axis.vertical ? secondExtent : null,
                    child: widget.second,
                  ),
                ],
              ),
            ),
            if (previewFraction != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SplitPreviewPainter(
                      axis: widget.axis,
                      fraction: previewFraction,
                      dividerExtent: widget.dividerExtent,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SplitPaneDivider extends StatelessWidget {
  const _SplitPaneDivider({
    required this.axis,
    required this.extent,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final Axis axis;
  final double extent;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: isHorizontal ? onDragStart : null,
        onHorizontalDragUpdate: isHorizontal ? onDragUpdate : null,
        onHorizontalDragEnd: isHorizontal ? onDragEnd : null,
        onHorizontalDragCancel: isHorizontal ? onDragCancel : null,
        onVerticalDragStart: isHorizontal ? null : onDragStart,
        onVerticalDragUpdate: isHorizontal ? null : onDragUpdate,
        onVerticalDragEnd: isHorizontal ? null : onDragEnd,
        onVerticalDragCancel: isHorizontal ? null : onDragCancel,
        child: SizedBox(
          width: isHorizontal ? extent : double.infinity,
          height: isHorizontal ? double.infinity : extent,
          child: Center(
            child: Container(
              width: isHorizontal ? 4 : 32,
              height: isHorizontal ? 32 : 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitPreviewPainter extends CustomPainter {
  const _SplitPreviewPainter({
    required this.axis,
    required this.fraction,
    required this.dividerExtent,
  });

  final Axis axis;
  final double fraction;
  final double dividerExtent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    if (axis == Axis.horizontal) {
      final x = (size.width - dividerExtent) * fraction;
      canvas.drawRect(Rect.fromLTWH(x, 0, dividerExtent, size.height), paint);
    } else {
      final y = (size.height - dividerExtent) * fraction;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, dividerExtent), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplitPreviewPainter oldDelegate) {
    return oldDelegate.axis != axis ||
        oldDelegate.fraction != fraction ||
        oldDelegate.dividerExtent != dividerExtent;
  }
}
