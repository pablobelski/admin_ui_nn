import 'package:flutter/material.dart';

class HorizontalScrollArea extends StatefulWidget {
  const HorizontalScrollArea({
    super.key,
    required this.child,
    this.thumbVisibility = true,
  });

  final Widget child;
  final bool thumbVisibility;

  @override
  State<HorizontalScrollArea> createState() => _HorizontalScrollAreaState();
}

class _HorizontalScrollAreaState extends State<HorizontalScrollArea> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: widget.thumbVisibility,
      interactive: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}

class BidirectionalScrollArea extends StatefulWidget {
  const BidirectionalScrollArea({
    super.key,
    required this.child,
    this.thumbVisibility = true,
  });

  final Widget child;
  final bool thumbVisibility;

  @override
  State<BidirectionalScrollArea> createState() => _BidirectionalScrollAreaState();
}

class _BidirectionalScrollAreaState extends State<BidirectionalScrollArea> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: widget.thumbVisibility,
      interactive: true,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: widget.thumbVisibility,
        interactive: true,
        notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
