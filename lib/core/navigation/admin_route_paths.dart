import '../models/admin_resource.dart';
import 'admin_registry.dart';

const _resourceRoutePrefix = '/resources/';
const _resourceQueryParameter = 'resource';
const _filterQueryPrefix = 'filter_';

String adminPathForResourceKey(String key) {
  if (key == dashboardResource.key) {
    return '/dashboard';
  }
  return '$_resourceRoutePrefix${Uri.encodeComponent(key)}';
}

String adminHrefForResourceKey(
    String key, {
      Map<String, String> filters = const {},
    }) {
  final safeKey = isKnownAdminResourceKey(key) ? key : dashboardResource.key;
  final queryParameters = <String, String>{
    _resourceQueryParameter: safeKey,
    for (final entry in filters.entries)
      if (entry.value.trim().isNotEmpty) '$_filterQueryPrefix${entry.key}': entry.value.trim(),
  };
  return '?${Uri(queryParameters: queryParameters).query}';
}

Uri adminUriForResourceKey(
    Uri currentUri,
    String key, {
      Map<String, String> filters = const {},
    }) {
  final safeKey = isKnownAdminResourceKey(key) ? key : dashboardResource.key;
  final nextQuery = Map<String, String>.from(currentUri.queryParameters)
    ..removeWhere((key, _) => key.startsWith(_filterQueryPrefix));
  nextQuery[_resourceQueryParameter] = safeKey;

  for (final entry in filters.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      nextQuery['$_filterQueryPrefix${entry.key}'] = value;
    }
  }

  return currentUri.replace(
    queryParameters: nextQuery,
    fragment: '',
  );
}

Map<String, String> adminFiltersFromLocationUri(Uri uri, AdminResourceDefinition resource) {
  final acceptedFilterKeys = <String>{
    for (final filter in resource.listFilters) filter.key,
    for (final sourceResource in allResources)
      for (final action in sourceResource.detailActions)
        if (action.targetResourceKey == resource.key) action.filterKey,
    for (final sourceResource in allResources)
      for (final action in sourceResource.detailActions)
        if (action.targetResourceKey == resource.key) ...action.extraFilters.keys,
  };
  if (acceptedFilterKeys.isEmpty) return const {};

  final filters = <String, String>{};
  for (final filterKey in acceptedFilterKeys) {
    final value = uri.queryParameters['$_filterQueryPrefix$filterKey'];
    if (value != null && value.trim().isNotEmpty) {
      filters[filterKey] = value.trim();
    }
  }
  return filters;
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
