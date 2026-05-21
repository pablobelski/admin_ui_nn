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
        final previewFraction = _previewFraction == null
            ? null
            : _previewFraction!.clamp(minFirst, maxFirst).toDouble();

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
                    child: ClipRect(child: widget.first),
                  ),
                  _SplitPaneDivider(
                    axis: widget.axis,
                    extent: widget.dividerExtent,
                    dragging: previewFraction != null,
                    onDragStart: startDrag,
                    onDragUpdate: updateDrag,
                    onDragEnd: (_) => endDrag(),
                    onDragCancel: cancelDrag,
                  ),
                  SizedBox(
                    width: widget.axis == Axis.horizontal ? secondExtent : null,
                    height: widget.axis == Axis.vertical ? secondExtent : null,
                    child: ClipRect(child: widget.second),
                  ),
                ],
              ),
            ),
            if (previewFraction != null)
              _SplitPanePreviewDivider(
                axis: widget.axis,
                extent: widget.dividerExtent,
                position: availableExtent * previewFraction,
              ),
          ],
        );
      },
    );
  }
}

class _SplitPaneDivider extends StatefulWidget {
  const _SplitPaneDivider({
    required this.axis,
    required this.extent,
    this.dragging = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final Axis axis;
  final double extent;
  final bool dragging;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;

  @override
  State<_SplitPaneDivider> createState() => _SplitPaneDividerState();
}

class _SplitPaneDividerState extends State<_SplitPaneDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHorizontal = widget.axis == Axis.horizontal;
    final cursor = isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow;
    final active = _hovered || widget.dragging;

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: isHorizontal ? widget.onDragStart : null,
        onHorizontalDragUpdate: isHorizontal ? widget.onDragUpdate : null,
        onHorizontalDragEnd: isHorizontal ? widget.onDragEnd : null,
        onHorizontalDragCancel: isHorizontal ? widget.onDragCancel : null,
        onVerticalDragStart: isHorizontal ? null : widget.onDragStart,
        onVerticalDragUpdate: isHorizontal ? null : widget.onDragUpdate,
        onVerticalDragEnd: isHorizontal ? null : widget.onDragEnd,
        onVerticalDragCancel: isHorizontal ? null : widget.onDragCancel,
        child: SizedBox(
          width: isHorizontal ? widget.extent : null,
          height: isHorizontal ? null : widget.extent,
          child: Center(
            child: Container(
              width: isHorizontal ? (active ? 3 : 1) : 44,
              height: isHorizontal ? 44 : (active ? 3 : 1),
              decoration: BoxDecoration(
                color: active ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitPanePreviewDivider extends StatelessWidget {
  const _SplitPanePreviewDivider({
    required this.axis,
    required this.extent,
    required this.position,
  });

  final Axis axis;
  final double extent;
  final double position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHorizontal = axis == Axis.horizontal;

    final indicator = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    if (isHorizontal) {
      return Positioned(
        left: position + (extent / 2) - 1.5,
        top: 0,
        bottom: 0,
        width: 3,
        child: indicator,
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      top: position + (extent / 2) - 1.5,
      height: 3,
      child: indicator,
    );
  }
}
