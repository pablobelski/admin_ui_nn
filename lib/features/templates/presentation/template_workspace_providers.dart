import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/configurator_template_repository.dart';

class TemplateWorkspaceState {
  const TemplateWorkspaceState({
    this.templateQuery = '',
    this.moduleQuery = '',
    this.selectedTemplateId,
    this.selectedModuleId,
    this.offset = 0,
    this.limit = 30,
  });

  final String templateQuery;
  final String moduleQuery;
  final String? selectedTemplateId;
  final String? selectedModuleId;
  final int offset;
  final int limit;

  TemplateWorkspaceState copyWith({
    String? templateQuery,
    String? moduleQuery,
    String? selectedTemplateId,
    String? selectedModuleId,
    int? offset,
    int? limit,
    bool clearTemplate = false,
    bool clearModule = false,
  }) {
    return TemplateWorkspaceState(
      templateQuery: templateQuery ?? this.templateQuery,
      moduleQuery: moduleQuery ?? this.moduleQuery,
      selectedTemplateId: clearTemplate ? null : (selectedTemplateId ?? this.selectedTemplateId),
      selectedModuleId: clearModule ? null : (selectedModuleId ?? this.selectedModuleId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class TemplateWorkspaceNotifier extends Notifier<TemplateWorkspaceState> {
  @override
  TemplateWorkspaceState build() => const TemplateWorkspaceState();

  void setTemplateQuery(String value) {
    state = state.copyWith(
      templateQuery: value,
      offset: 0,
      clearTemplate: true,
      clearModule: true,
    );
  }

  void setModuleQuery(String value) {
    state = state.copyWith(moduleQuery: value, clearModule: true);
  }

  void selectTemplate(String? id) {
    state = state.copyWith(selectedTemplateId: id, clearModule: true);
  }

  void selectModule(String? id) {
    state = state.copyWith(selectedModuleId: id);
  }

  void nextPage() {
    state = state.copyWith(
      offset: state.offset + state.limit,
      clearTemplate: true,
      clearModule: true,
    );
  }

  void previousPage() {
    final nextOffset = state.offset - state.limit;
    state = state.copyWith(
      offset: nextOffset < 0 ? 0 : nextOffset,
      clearTemplate: true,
      clearModule: true,
    );
  }
}

final configuratorTemplateRepositoryProvider = Provider<ConfiguratorTemplateRepository>((ref) {
  return ConfiguratorTemplateRepository(ref.watch(apiClientProvider));
});

final templateWorkspaceProvider =
    NotifierProvider.autoDispose<TemplateWorkspaceNotifier, TemplateWorkspaceState>(
  TemplateWorkspaceNotifier.new,
);

final configuratorTemplateListProvider =
    FutureProvider.autoDispose<ConfiguratorTemplateListResponse>((ref) async {
  final browserState = ref.watch(templateWorkspaceProvider);
  final repository = ref.watch(configuratorTemplateRepositoryProvider);
  return repository.fetchTemplates(
    query: browserState.templateQuery,
    limit: browserState.limit,
    offset: browserState.offset,
  );
});

final selectedConfiguratorTemplateProvider =
    FutureProvider.autoDispose<ConfiguratorTemplate?>((ref) async {
  final browserState = ref.watch(templateWorkspaceProvider);
  final id = browserState.selectedTemplateId;
  if (id == null || id.isEmpty) return null;
  final repository = ref.watch(configuratorTemplateRepositoryProvider);
  return repository.fetchTemplate(id);
});

final templateModulesProvider =
    FutureProvider.autoDispose<TemplateModuleListResponse?>((ref) async {
  final browserState = ref.watch(templateWorkspaceProvider);
  final templateId = browserState.selectedTemplateId;
  if (templateId == null || templateId.isEmpty) return null;
  final repository = ref.watch(configuratorTemplateRepositoryProvider);
  return repository.fetchModules(
    configuratorTemplateId: templateId,
    query: browserState.moduleQuery,
  );
});

final selectedTemplateModuleProvider =
    FutureProvider.autoDispose<TemplateModule?>((ref) async {
  final browserState = ref.watch(templateWorkspaceProvider);
  final id = browserState.selectedModuleId;
  if (id == null || id.isEmpty) return null;
  final repository = ref.watch(configuratorTemplateRepositoryProvider);
  return repository.fetchModule(id);
});
