import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:html' as html;

void configureWebApp() {
  usePathUrlStrategy();
}

void hideMurkotHtmlBoot() {
  final el = html.document.getElementById('murkot-boot');
  if (el == null) return;
  if (el.dataset['hiding'] == '1') return;
  el.dataset['hiding'] = '1';
  el.style.transition = 'opacity .35s ease';
  el.style.opacity = '0';
  Future<void>.delayed(const Duration(milliseconds: 380), el.remove);
}
