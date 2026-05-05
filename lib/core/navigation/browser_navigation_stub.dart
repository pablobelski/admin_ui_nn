import 'admin_route_paths.dart';

String currentAdminResourceKey() {
  return adminResourceKeyFromLocationUri(Uri.base);
}

String adminResourceUrl(String key) {
  return adminHrefForResourceKey(key);
}

void pushAdminResourceUrl(String key) {}

void openAdminResourceInNewTab(String key) {}

void setAdminRouteListener(void Function()? listener) {}
