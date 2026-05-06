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

  @override
  void didUpdateWidget(covariant ResizableSplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.axis != widget.axis) {
      _fraction = null;
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
        final minFirst = widget.minFirstFraction.clamp(0.05, 0.9).toDouble();
        final maxFirst = (1 - widget.minSecondFraction).clamp(minFirst, 0.95).toDouble();
        final fraction = (_fraction ?? widget.initialFraction).clamp(minFirst, maxFirst).toDouble();
        final firstExtent = availableExtent * fraction;
        final secondExtent = availableExtent - firstExtent;

        void updateFraction(DragUpdateDetails details) {
          final delta = widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
          setState(() {
            _fraction = ((firstExtent + delta) / availableExtent).clamp(minFirst, maxFirst).toDouble();
          });
        }

        return Flex(
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
              onDragUpdate: updateFraction,
            ),
            SizedBox(
              width: widget.axis == Axis.horizontal ? secondExtent : null,
              height: widget.axis == Axis.vertical ? secondExtent : null,
              child: widget.second,
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
    this.onDragUpdate,
  });

  final Axis axis;
  final double extent;
  final GestureDragUpdateCallback? onDragUpdate;

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

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal ? widget.onDragUpdate : null,
        onVerticalDragUpdate: isHorizontal ? null : widget.onDragUpdate,
        child: SizedBox(
          width: isHorizontal ? widget.extent : null,
          height: isHorizontal ? null : widget.extent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: isHorizontal ? (_hovered ? 3 : 1) : 44,
              height: isHorizontal ? 44 : (_hovered ? 3 : 1),
              decoration: BoxDecoration(
                color: _hovered ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
