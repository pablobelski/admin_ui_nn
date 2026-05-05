import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'admin_route_paths.dart';

JSFunction? _hashChangeListener;
JSFunction? _popStateListener;

Uri _currentWindowUri() {
  // Do not use Uri.base here: in Flutter Web it can be resolved from
  // <base href=...> and lose the current browser hash/query. For admin
  // deep links opened in a new tab we need the real window URL.
  return Uri.parse(web.window.location.href);
}

String currentAdminResourceKey() {
  return adminResourceKeyFromLocationUri(_currentWindowUri());
}

String adminResourceUrl(String key) {
  return adminUriForResourceKey(_currentWindowUri(), key).toString();
}

void pushAdminResourceUrl(String key) {
  final nextUrl = adminResourceUrl(key);
  if (web.window.location.href == nextUrl) {
    return;
  }

  web.window.history.pushState(null, '', nextUrl);
}

void openAdminResourceInNewTab(String key) {
  web.window.open(adminResourceUrl(key), '_blank');
}

void setAdminRouteListener(void Function()? listener) {
  if (_hashChangeListener != null) {
    web.window.removeEventListener('hashchange', _hashChangeListener);
  }
  if (_popStateListener != null) {
    web.window.removeEventListener('popstate', _popStateListener);
  }
  _hashChangeListener = null;
  _popStateListener = null;

  if (listener == null) {
    return;
  }

  _hashChangeListener = ((web.Event _) => listener()).toJS;
  _popStateListener = ((web.Event _) => listener()).toJS;
  web.window.addEventListener('hashchange', _hashChangeListener);
  web.window.addEventListener('popstate', _popStateListener);
}
