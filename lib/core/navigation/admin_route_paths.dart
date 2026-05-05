import 'admin_registry.dart';

const _resourceRoutePrefix = '/resources/';
const _resourceQueryParameter = 'resource';

String adminPathForResourceKey(String key) {
  if (key == dashboardResource.key) {
    return '/dashboard';
  }
  return '$_resourceRoutePrefix${Uri.encodeComponent(key)}';
}

String adminHrefForResourceKey(String key) {
  final safeKey = isKnownAdminResourceKey(key) ? key : dashboardResource.key;
  return '?$_resourceQueryParameter=${Uri.encodeQueryComponent(safeKey)}';
}

Uri adminUriForResourceKey(Uri currentUri, String key) {
  final safeKey = isKnownAdminResourceKey(key) ? key : dashboardResource.key;
  final nextQuery = Map<String, String>.from(currentUri.queryParameters);
  nextQuery[_resourceQueryParameter] = safeKey;

  return currentUri.replace(
    queryParameters: nextQuery,
    fragment: '',
  );
}

String adminResourceKeyFromLocationUri(Uri uri) {
  // Query parameter routes are preferred because Flutter Web treats #/... as
  // its own Navigator route and can rewrite unknown hashes to #/ before this
  // state provider reads them.
  final queryResourceKey = uri.queryParameters[_resourceQueryParameter];
  if (queryResourceKey != null && isKnownAdminResourceKey(queryResourceKey)) {
    return queryResourceKey;
  }

  // Optional support for deployments that later add a server-side fallback to
  // index.html and use clean paths like /resources/organizations.
  if (uri.path.isNotEmpty && uri.path != '/') {
    final keyFromPath = adminResourceKeyFromPath(uri.path);
    if (keyFromPath != null) {
      return keyFromPath;
    }
  }

  // Backward-compatible fallback for older links generated as #/resources/...
  final keyFromFragment = adminResourceKeyFromPath(uri.fragment);
  if (keyFromFragment != null) {
    return keyFromFragment;
  }

  return dashboardResource.key;
}

String? adminResourceKeyFromPath(String rawPath) {
  if (rawPath.isEmpty || rawPath == '/') {
    return dashboardResource.key;
  }

  final path = rawPath.startsWith('/') ? rawPath : '/$rawPath';
  if (path == '/dashboard') {
    return dashboardResource.key;
  }

  if (!path.startsWith(_resourceRoutePrefix)) {
    return null;
  }

  final encodedKey = path.substring(_resourceRoutePrefix.length).split('/').first;
  final key = Uri.decodeComponent(encodedKey);
  if (!isKnownAdminResourceKey(key)) {
    return null;
  }

  return key;
}

bool isKnownAdminResourceKey(String key) {
  return allResources.any((resource) => resource.key == key);
}
