import '../models/admin_resource.dart';
import 'admin_route_paths.dart';

String currentAdminResourceKey() {
  return adminResourceKeyFromLocationUri(Uri.base);
}

Map<String, String> currentAdminResourceFilters(AdminResourceDefinition resource) {
  return adminFiltersFromLocationUri(Uri.base, resource);
}

String adminResourceUrl(
    String key, {
      Map<String, String> filters = const {},
    }) {
  return adminHrefForResourceKey(key, filters: filters);
}

void pushAdminResourceUrl(
    String key, {
      Map<String, String> filters = const {},
    }) {}

void openAdminResourceInNewTab(
    String key, {
      Map<String, String> filters = const {},
    }) {}

void openExternalUrlInNewTab(String url) {}

void setAdminRouteListener(void Function()? listener) {}