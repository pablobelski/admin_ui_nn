import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/pricing/presentation/price_matrix_page.dart';
import '../../features/resources/presentation/resource_page.dart';
import '../../features/rules/presentation/rule_workspace_page.dart';
import '../../features/templates/presentation/template_workspace_page.dart';
import '../auth/auth_session.dart';
import '../models/admin_resource.dart';
import '../navigation/admin_providers.dart';
import '../navigation/admin_registry.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(selectedResourceProvider);
    final selectedResource = findResourceByKey(selectedKey);
    final isNarrow = MediaQuery.sizeOf(context).width < 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurator Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                ref.watch(authSessionProvider).email ?? 'catalogs / prices / rules / refs',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: isNarrow
          ? Drawer(
              child: SafeArea(
                child: _NavigationTree(
                  selectedKey: selectedKey,
                  onSelect: (key) {
                    ref.read(selectedResourceProvider.notifier).select(key);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isNarrow)
            SizedBox(
              width: 280,
              child: Material(
                color: Colors.white,
                child: SafeArea(
                  child: _NavigationTree(
                    selectedKey: selectedKey,
                    onSelect: (key) {
                      ref.read(selectedResourceProvider.notifier).select(key);
                    },
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPage(selectedResource),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(AdminResourceDefinition resource) {
    if (resource.key == dashboardResource.key) {
      return const DashboardPage();
    }
    if (resource.key == 'price_matrices') {
      return const PriceMatrixPage(initialMode: PriceMatrixPageMode.matrices);
    }
    if (resource.key == 'price_matrix_cells') {
      return const PriceMatrixPage(initialMode: PriceMatrixPageMode.cells);
    }
    if (resource.key == 'rule_sets') {
      return const RuleWorkspacePage(initialMode: RuleWorkspaceMode.ruleSets);
    }
    if (resource.key == 'rule_matrices') {
      return const RuleWorkspacePage(initialMode: RuleWorkspaceMode.matrices);
    }
    if (resource.key == 'rule_matrix_rows') {
      return const RuleWorkspacePage(initialMode: RuleWorkspaceMode.rows);
    }
    if (resource.key == 'configurator_templates') {
      return const TemplateWorkspacePage(initialMode: TemplateWorkspaceMode.templates);
    }
    if (resource.key == 'template_modules') {
      return const TemplateWorkspacePage(initialMode: TemplateWorkspaceMode.modules);
    }
    return ResourcePage(resource: resource);
  }
}

class _NavigationTree extends StatelessWidget {
  const _NavigationTree({
    required this.selectedKey,
    required this.onSelect,
  });

  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _NavTile(
          title: dashboardResource.title,
          icon: dashboardResource.icon,
          selected: selectedKey == dashboardResource.key,
          onTap: () => onSelect(dashboardResource.key),
        ),
        const SizedBox(height: 8),
        for (final group in adminNavGroups)
          Card(
            child: ExpansionTile(
              leading: Icon(group.icon),
              title: Text(group.title),
              initiallyExpanded: group.resources.any((r) => r.key == selectedKey),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final resource in group.resources)
                  _NavTile(
                    title: resource.title,
                    icon: resource.icon,
                    selected: selectedKey == resource.key,
                    onTap: () => onSelect(resource.key),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: selected ? scheme.primaryContainer : null,
      leading: Icon(icon, size: 20),
      title: Text(title),
      onTap: onTap,
    );
  }
}
