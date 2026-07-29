import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../data/configurator_template_repository.dart';

class TemplateWorkspaceState {
  const TemplateWorkspaceState({
    this.templateQuery = '',
    this.moduleQuery = '',
    this.productFamilyId = '',
    this.roofModelId = '',
    this.selectedTemplateId,
    this.selectedModuleId,
    this.offset = 0,
    this.limit = 30,
  });

  final String templateQuery;
  final String moduleQuery;
  final String productFamilyId;
  final String roofModelId;
  final String? selectedTemplateId;
  final String? selectedModuleId;
  final int offset;
  final int limit;

  Map<String, String> get activeFilters => <String, String>{
        if (productFamilyId.isNotEmpty) 'product_family_id': productFamilyId,
        if (roofModelId.isNotEmpty) 'roof_model_id': roofModelId,
      };

  TemplateWorkspaceState copyWith({
    String? templateQuery,
    String? moduleQuery,
    String? productFamilyId,
    String? roofModelId,
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
      productFamilyId: productFamilyId ?? this.productFamilyId,
      roofModelId: roofModelId ?? this.roofModelId,
      selectedTemplateId: clearTemplate ? null : (selectedTemplateId ?? this.selectedTemplateId),
      selectedModuleId: clearModule ? null : (selectedModuleId ?? this.selectedModuleId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class TemplateWorkspaceNotifier extends Notifier<TemplateWorkspaceState> {
  @override
  TemplateWorkspaceState build() {
    final filters = currentAdminResourceFilters(findResourceByKey('configurator_templates'));
    return TemplateWorkspaceState(
      productFamilyId: filters['product_family_id'] ?? '',
      roofModelId: filters['roof_model_id'] ?? '',
    );
  }

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

  void setTemplateFilter(String key, String? value) {
    final normalizedValue = value?.trim() ?? '';
    TemplateWorkspaceState nextState;
    if (key == 'product_family_id') {
      nextState = state.copyWith(
        productFamilyId: normalizedValue,
        offset: 0,
        clearTemplate: true,
        clearModule: true,
      );
    } else if (key == 'roof_model_id') {
      nextState = state.copyWith(
        roofModelId: normalizedValue,
        offset: 0,
        clearTemplate: true,
        clearModule: true,
      );
    } else {
      nextState = state;
    }
    state = nextState;
    ref
        .read(resourceBrowserProvider('configurator_templates').notifier)
        .openWithFilters(nextState.activeFilters, updateUrl: false);
    pushAdminResourceUrl('configurator_templates', filters: nextState.activeFilters);
  }

  void applyNavigationFilters(Map<String, String> filters) {
    final productFamilyId = filters['product_family_id'] ?? '';
    final roofModelId = filters['roof_model_id'] ?? '';
    if (productFamilyId == state.productFamilyId && roofModelId == state.roofModelId) {
      return;
    }
    state = state.copyWith(
      productFamilyId: productFamilyId,
      roofModelId: roofModelId,
      offset: 0,
      clearTemplate: true,
      clearModule: true,
    );
  }

  void clearTemplateFilters() {
    state = state.copyWith(
      templateQuery: '',
      productFamilyId: '',
      roofModelId: '',
      offset: 0,
      clearTemplate: true,
      clearModule: true,
    );
    ref
        .read(resourceBrowserProvider('configurator_templates').notifier)
        .openWithFilters(const <String, String>{}, updateUrl: false);
    pushAdminResourceUrl('configurator_templates');
  }

  void resetModuleFilters() {
    state = state.copyWith(moduleQuery: '', clearModule: true);
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
    productFamilyId: browserState.productFamilyId,
    roofModelId: browserState.roofModelId,
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

class TemplateDependentLayerFocusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final templateDependentLayerFocusProvider =
    NotifierProvider.autoDispose<TemplateDependentLayerFocusNotifier, bool>(
  TemplateDependentLayerFocusNotifier.new,
);
