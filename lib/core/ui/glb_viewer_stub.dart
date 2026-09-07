import 'dart:typed_data';

import 'package:flutter/material.dart';

class GlbViewerFrame extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text('3D preview is available in the web application.'),
    );
  }
}
