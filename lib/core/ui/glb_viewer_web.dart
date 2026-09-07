import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class GlbViewerFrame extends StatefulWidget {
  const GlbViewerFrame({
    super.key,
    required this.bytes,
    required this.embedMode,
    required this.localPath,
    this.externalUrl,
    this.iframeHtml,
  });

  final Uint8List bytes;
  final String embedMode;
  final String localPath;
  final String? externalUrl;
  final String? iframeHtml;

  @override
  State<GlbViewerFrame> createState() => _GlbViewerFrameState();
}

class _GlbViewerFrameState extends State<GlbViewerFrame> {
  static int _nextViewId = 0;

  late String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant GlbViewerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.embedMode != widget.embedMode ||
        oldWidget.localPath != widget.localPath ||
        oldWidget.externalUrl != widget.externalUrl ||
        oldWidget.iframeHtml != widget.iframeHtml) {
      _releaseObjectUrl();
      _registerView();
    }
  }

  void _registerView() {
    final mode = widget.embedMode.trim().toLowerCase();
    final externalUrl = widget.externalUrl?.trim() ?? '';
    final iframeHtml = widget.iframeHtml?.trim() ?? '';
    final localPath = widget.localPath.trim().isEmpty
        ? 'glb-viewer.html'
        : widget.localPath.trim();

    _viewType = 'glb-viewer-${DateTime.now().microsecondsSinceEpoch}-${_nextViewId++}';
    if (mode == 'local' ||
        (mode == 'external_url' && externalUrl.isEmpty) ||
        (mode == 'iframe' && iframeHtml.isEmpty)) {
      _objectUrl = _createObjectUrl(widget.bytes);
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.display = 'block';
      iframe.setAttribute('allowfullscreen', 'true');

      if (mode == 'external_url' && externalUrl.isNotEmpty) {
        iframe.src = externalUrl;
      } else if (mode == 'iframe' && iframeHtml.isNotEmpty) {
        iframe.setAttribute('srcdoc', iframeHtml);
      } else {
        iframe.src = localPath;
        iframe.addEventListener(
          'load',
          ((web.Event event) {
            final modelUrl = _objectUrl;
            if (modelUrl == null || modelUrl.isEmpty) return;
            iframe.contentWindow?.postMessage(
              modelUrl.toJS,
              web.window.location.origin.toJS,
            );
          }).toJS,
        );
      }
      return iframe;
    });
  }

  String _createObjectUrl(Uint8List bytes) {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'model/gltf-binary'),
    );
    return web.URL.createObjectURL(blob);
  }

  void _releaseObjectUrl() {
    final objectUrl = _objectUrl;
    if (objectUrl == null) return;
    web.URL.revokeObjectURL(objectUrl);
    _objectUrl = null;
  }

  @override
  void dispose() {
    _releaseObjectUrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey(_viewType),
      viewType: _viewType,
    );
  }
}
