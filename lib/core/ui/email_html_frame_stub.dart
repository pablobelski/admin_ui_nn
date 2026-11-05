import 'package:flutter/material.dart';

class EmailHtmlFrame extends StatelessWidget {
  const EmailHtmlFrame({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Email HTML preview is available in the web app.'));
  }
}
