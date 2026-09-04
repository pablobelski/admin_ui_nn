import 'package:flutter/material.dart';

import '../../../core/http/api_client.dart';
import '../../../core/ui/top_notification.dart';
import '../data/calculator_repository.dart';

final Map<String, List<QuoteStatusTransitionOption>>
    _quoteStatusTransitionsCache = {};

class QuoteStatusButton extends StatefulWidget {
  const QuoteStatusButton({
    super.key,
    required this.quoteId,
    required this.statusCode,
    required this.repository,
    this.prominent = false,
    this.headerPlate = false,
    this.onCompleted,
  });

  final String quoteId;
  final String statusCode;
  final CalculatorRepository repository;
  final bool prominent;
  final bool headerPlate;
  final Future<void> Function(QuoteStatusChangeResult result)? onCompleted;

  @override
  State<QuoteStatusButton> createState() => _QuoteStatusButtonState();
}

class _QuoteStatusButtonState extends State<QuoteStatusButton> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _busy = false;
  late String _statusCode = widget.statusCode;

  @override
  void didUpdateWidget(covariant QuoteStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusCode != widget.statusCode) {
      _statusCode = widget.statusCode;
    }
  }

  String get _displayStatus {
    final normalized = _statusCode.trim();
    if (normalized.isEmpty) return 'Status';
    return normalized;
  }

  String _cacheKey(String statusCode) =>
      '${widget.quoteId.trim()}:${statusCode.trim().toLowerCase()}';

  Future<String?> _showTransitionsMenu(
    List<QuoteStatusTransitionOption> transitions,
  ) async {
    final anchorContext = _anchorKey.currentContext;
    final overlayState = Overlay.of(context);
    if (anchorContext == null) return null;
    final anchor = anchorContext.findRenderObject();
    final overlay = overlayState.context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox) return null;

    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    return showMenu<String>(
      context: context,
      position: position,
      items: transitions.isEmpty
          ? const [
              PopupMenuItem<String>(
                enabled: false,
                child: Text('No available status transitions'),
              ),
            ]
          : [
              for (final transition in transitions)
                PopupMenuItem<String>(
                  value: transition.statusCode,
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 17),
                      const SizedBox(width: 9),
                      Text(
                        transition.label.trim().isEmpty
                            ? transition.statusCode
                            : transition.label,
                      ),
                    ],
                  ),
                ),
            ],
    );
  }

  Future<void> _open() async {
    if (_busy || widget.quoteId.trim().isEmpty) return;
    try {
      var transitions = _quoteStatusTransitionsCache[_cacheKey(_statusCode)];
      if (transitions == null) {
        setState(() => _busy = true);
        final available =
            await widget.repository.fetchQuoteStatusTransitions(widget.quoteId);
        if (!mounted) return;
        if (available.statusCode.trim().isNotEmpty) {
          _statusCode = available.statusCode;
        }
        transitions = available.transitions;
        _quoteStatusTransitionsCache[_cacheKey(_statusCode)] = transitions;
        setState(() => _busy = false);
      }

      final targetStatus = await _showTransitionsMenu(transitions);
      if (!mounted || targetStatus == null) return;

      setState(() => _busy = true);
      final result = await widget.repository.changeQuoteStatus(
        widget.quoteId,
        targetStatus,
      );
      if (!mounted) return;
      _statusCode = result.statusCode;
      _quoteStatusTransitionsCache[_cacheKey(result.statusCode)] =
          result.transitions;
      setState(() {});
      await widget.onCompleted?.call(result);
      if (!mounted) return;
      showTopNotification(
        context,
        'Quote status changed: ${result.previousStatusCode} → ${result.statusCode}.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.displayMessage : '$error';
      showTopNotification(
        context,
        'Quote status change failed: $message',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Widget _indicator() => _busy
      ? const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.arrow_drop_down_rounded, size: 19);

  @override
  Widget build(BuildContext context) {
    final canPress = !_busy && widget.quoteId.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    Widget button;
    if (widget.headerPlate) {
      button = SizedBox(
        height: 40,
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: canPress ? _open : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 112),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _displayStatus,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconTheme(
                    data: IconThemeData(color: colorScheme.onPrimaryContainer),
                    child: _indicator(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (widget.prominent) {
      button = SizedBox(
        width: 136,
        height: 36,
        child: OutlinedButton(
          onPressed: canPress ? _open : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _displayStatus,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 3),
              _indicator(),
            ],
          ),
        ),
      );
    } else {
      button = OutlinedButton(
        onPressed: canPress ? _open : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_displayStatus),
            const SizedBox(width: 4),
            _indicator(),
          ],
        ),
      );
    }

    return Tooltip(
      message: 'Change quote status',
      child: KeyedSubtree(key: _anchorKey, child: button),
    );
  }
}
