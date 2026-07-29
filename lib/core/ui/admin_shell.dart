import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/calculator/presentation/calculator_workspace_page.dart';
import '../../features/pricing/presentation/price_matrix_page.dart';
import '../../features/references/presentation/reference_workspace_page.dart';
import '../../features/resources/presentation/resource_page.dart';
import '../../features/rules/presentation/rule_workspace_page.dart';
import '../../features/templates/presentation/template_workspace_page.dart';
import '../auth/auth_session.dart';
import '../models/admin_resource.dart';
import '../navigation/admin_providers.dart';
import '../navigation/admin_registry.dart';
import '../navigation/admin_route_paths.dart';
import '../navigation/browser_navigation.dart';
import 'top_notification.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  void initState() {
    super.initState();
    setAdminRouteListener(() {
      if (!mounted) {
        return;
      }
      ref.read(selectedResourceProvider.notifier).syncFromBrowserLocation();
    });
  }

  @override
  void dispose() {
    setAdminRouteListener(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    final selectedKey = ref.watch(selectedResourceProvider);
    final selectedResource = findResourceByKey(selectedKey);
    final effectiveResource = canRoleAccessAdminResource(authSession.roleCode, selectedResource)
        ? selectedResource
        : dashboardResource;
    final effectiveSelectedKey = effectiveResource.key;
    final isNarrow = MediaQuery.sizeOf(context).width < 1100;
    final userDisplayName = _firstNonEmpty(
      authSession.contactName,
      authSession.fullName,
      authSession.email,
    );
    final organizationDisplayName = authSession.organizationName?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurator Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userDisplayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (organizationDisplayName.isNotEmpty)
                    Text(
                      organizationDisplayName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Change password',
            onPressed: () => _showChangeOwnPasswordDialog(context),
            icon: const Icon(Icons.password_rounded),
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
                  selectedKey: effectiveSelectedKey,
                  roleCode: authSession.roleCode,
                  onSelect: (key) {
                    ref.read(selectedResourceProvider.notifier).select(key);
                    Navigator.of(context).pop();
                  },
                  onOpenInNewTab: (key) => openAdminResourceInNewTab(key),
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
                    selectedKey: effectiveSelectedKey,
                    roleCode: authSession.roleCode,
                    onSelect: (key) {
                      ref.read(selectedResourceProvider.notifier).select(key);
                    },
                    onOpenInNewTab: (key) => openAdminResourceInNewTab(key),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPage(effectiveResource),
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
    if (resource.key == 'calculator_workspace') {
      return const CalculatorWorkspacePage();
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
    if (resource.key == 'reference_domains') {
      return const ReferenceWorkspacePage(initialMode: ReferenceWorkspaceMode.domains);
    }
    if (resource.key == 'reference_values') {
      return const ReferenceWorkspacePage(initialMode: ReferenceWorkspaceMode.referenceValues);
    }
    if (resource.key == 'configurator_templates') {
      return const TemplateWorkspacePage(initialMode: TemplateWorkspaceMode.templates);
    }
    if (resource.key == 'template_modules') {
      return const TemplateWorkspacePage(initialMode: TemplateWorkspaceMode.modules);
    }
    return ResourcePage(resource: resource);
  }

  Future<void> _showChangeOwnPasswordDialog(BuildContext context) async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ChangeOwnPasswordDialog(),
    );
    if (payload == null) return;

    try {
      await ref.read(apiClientProvider).postJson(
        '/api/auth/change-password',
        body: {
          'current_password': payload['current_password'],
          'new_password': payload['new_password'],
        },
      );
      if (!context.mounted) return;
      showTopNotification(
        context,
        'Password changed.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      showTopNotification(
        context,
        'Password change failed: $error',
        type: TopNotificationType.error,
      );
    }
  }
}

String _firstNonEmpty(String? first, String? second, String? fallback) {
  for (final value in [first, second, fallback]) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) return normalized;
  }
  return 'User';
}

class _ChangeOwnPasswordDialog extends StatefulWidget {
  const _ChangeOwnPasswordDialog();

  @override
  State<_ChangeOwnPasswordDialog> createState() => _ChangeOwnPasswordDialogState();
}

class _ChangeOwnPasswordDialogState extends State<_ChangeOwnPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters',
                ),
                validator: (value) {
                  final requiredMessage = _required(value);
                  if (requiredMessage != null) return requiredMessage;
                  if (value!.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeatPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repeat new password'),
                validator: (value) {
                  final requiredMessage = _required(value);
                  if (requiredMessage != null) return requiredMessage;
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'current_password': _currentPasswordController.text,
      'new_password': _newPasswordController.text,
    });
  }
}

class _NavigationTree extends StatelessWidget {
  const _NavigationTree({
    required this.selectedKey,
    required this.roleCode,
    required this.onSelect,
    required this.onOpenInNewTab,
  });

  final String selectedKey;
  final String? roleCode;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenInNewTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _NavTile(
          resourceKey: dashboardResource.key,
          title: dashboardResource.title,
          icon: dashboardResource.icon,
          selected: selectedKey == dashboardResource.key,
          onTap: () => onSelect(dashboardResource.key),
          onOpenInNewTab: () => onOpenInNewTab(dashboardResource.key),
        ),
        const SizedBox(height: 8),
        for (final group in _navigationGroupsForUi())
          if (_visibleResources(group).isNotEmpty)
          Card(
            child: ExpansionTile(
              leading: Icon(group.icon),
              title: Text(group.title),
              initiallyExpanded: _visibleResources(group).any((r) => r.key == selectedKey),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final resource in _visibleResources(group))
                  _NavTile(
                    resourceKey: resource.key,
                    title: resource.title,
                    icon: resource.icon,
                    selected: selectedKey == resource.key,
                    onTap: () => onSelect(resource.key),
                    onOpenInNewTab: () => onOpenInNewTab(resource.key),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<AdminResourceDefinition> _visibleResources(AdminNavGroup group) {
    return group.resources
        .where((resource) => resource.showInNavigation)
        .where((resource) => canRoleAccessAdminResource(roleCode, resource))
        .toList(growable: false);
  }
}


const _catalogSectionResourceKeys = {
  'catalog_item_types',
  'catalog_item_relations',
};

List<AdminNavGroup> _navigationGroupsForUi() {
  final catalogSectionResources = <AdminResourceDefinition>[
    for (final group in adminNavGroups)
      for (final resource in group.resources)
        if (_catalogSectionResourceKeys.contains(resource.key)) resource,
  ];

  return [
    for (final group in adminNavGroups)
      if (group.key == 'system_settings')
        AdminNavGroup(
          key: group.key,
          title: group.title,
          icon: group.icon,
          resources: group.resources
              .where((resource) => !_catalogSectionResourceKeys.contains(resource.key))
              .toList(growable: false),
        )
      else if (group.key == 'catalog')
        AdminNavGroup(
          key: group.key,
          title: group.title,
          icon: group.icon,
          resources: [
            ...catalogSectionResources,
            ...group.resources.where(
              (resource) => !_catalogSectionResourceKeys.contains(resource.key),
            ),
          ],
        )
      else
        group,
  ];
}

enum _NavTileMenuAction { open, openInNewTab, copyLink }

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.resourceKey,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.onOpenInNewTab,
  });

  final String resourceKey;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenInNewTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          onOpenInNewTab();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => _showContextMenu(context, details),
        child: Tooltip(
          message: adminHrefForResourceKey(resourceKey),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: selected ? scheme.primaryContainer : null,
            leading: Icon(icon, size: 20),
            title: Text(title),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, TapDownDetails details) async {
    final action = await showMenu<_NavTileMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: _NavTileMenuAction.open,
          child: Text('Open'),
        ),
        const PopupMenuItem(
          value: _NavTileMenuAction.openInNewTab,
          child: Text('Open in new tab'),
        ),
        PopupMenuItem(
          value: _NavTileMenuAction.copyLink,
          child: const Text('Copy link'),
        ),
      ],
    );

    switch (action) {
      case _NavTileMenuAction.open:
        onTap();
        break;
      case _NavTileMenuAction.openInNewTab:
        onOpenInNewTab();
        break;
      case _NavTileMenuAction.copyLink:
        await Clipboard.setData(ClipboardData(text: adminResourceUrl(resourceKey)));
        break;
      case null:
        break;
    }
  }
}
