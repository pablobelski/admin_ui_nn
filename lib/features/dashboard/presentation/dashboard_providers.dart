import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final dashboardProvider = FutureProvider.autoDispose.family<DashboardData, int>(
  (ref, days) {
    return ref.watch(dashboardRepositoryProvider).fetch(days: days);
  },
);
