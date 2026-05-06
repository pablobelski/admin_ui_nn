import '../models/admin_resource.dart';
import 'browser_navigation_stub.dart'
if (dart.library.js_interop) 'browser_navigation_web.dart' as impl;

String currentAdminResourceKey() {
    return impl.currentAdminResourceKey();
}

Map<String, String> currentAdminResourceFilters(AdminResourceDefinition resource) {
    return impl.currentAdminResourceFilters(resource);
}

String adminResourceUrl(
    String key, {
        Map<String, String> filters = const {},
    }) {
    return impl.adminResourceUrl(key, filters: filters);
}

void pushAdminResourceUrl(
    String key, {
        Map<String, String> filters = const {},
    }) {
    impl.pushAdminResourceUrl(key, filters: filters);
}

void openAdminResourceInNewTab(
    String key, {
        Map<String, String> filters = const {},
    }) {
    impl.openAdminResourceInNewTab(key, filters: filters);
}

void setAdminRouteListener(void Function()? listener) {
    impl.setAdminRouteListener(listener);
}
