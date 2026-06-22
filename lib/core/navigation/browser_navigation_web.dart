import 'dart:js_interop';

import 'package:web/web.dart' as web;
import '../models/admin_resource.dart';
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

Map<String, String> currentAdminResourceFilters(AdminResourceDefinition resource) {
  return adminFiltersFromLocationUri(_currentWindowUri(), resource);
}

String adminResourceUrl(
    String key, {
      Map<String, String> filters = const {},
    }) {
  return adminUriForResourceKey(_currentWindowUri(), key, filters: filters).toString();
}

void pushAdminResourceUrl(
    String key, {
      Map<String, String> filters = const {},
    }) {
  final nextUrl = adminResourceUrl(key, filters: filters);
  if (web.window.location.href == nextUrl) {
    return;
  }

  web.window.history.pushState(null, '', nextUrl);
}

void openAdminResourceInNewTab(
    String key, {
      Map<String, String> filters = const {},
    }) {
  web.window.open(adminResourceUrl(key, filters: filters), '_blank');
}

void openExternalUrlInNewTab(String url) {
  final target = url.trim();
  if (target.isEmpty) return;
  web.window.open(target, '_blank');
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
