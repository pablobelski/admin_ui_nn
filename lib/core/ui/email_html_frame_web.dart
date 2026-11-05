import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class EmailHtmlFrame extends StatefulWidget {
  const EmailHtmlFrame({super.key, required this.html});

  final String html;

  @override
  State<EmailHtmlFrame> createState() => _EmailHtmlFrameState();
}

class _EmailHtmlFrameState extends State<EmailHtmlFrame> {
  web.HTMLIFrameElement? _frame;

  void _updateHtml() {
    _frame?.setAttribute('srcdoc', '<!doctype html><meta charset="utf-8">'
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
        'img-src data: https: http:; style-src \'unsafe-inline\'; font-src data: https:; '
        'base-uri \'none\'; form-action \'none\'">${widget.html}');
  }

  @override
  void didUpdateWidget(covariant EmailHtmlFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _updateHtml();
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        _frame = element as web.HTMLIFrameElement;
        _frame!
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = '0'
          ..style.backgroundColor = '#ffffff'
          ..setAttribute('title', 'Email preview')
          ..setAttribute('sandbox', '')
          ..setAttribute('referrerpolicy', 'no-referrer');
        _updateHtml();
      },
    );
  }
}
