import 'package:flutter/material.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/navigation/admin_registry.dart';

class OrganizationRelationTree extends StatefulWidget {
  const OrganizationRelationTree({
    super.key,
    required this.repository,
    required this.rootOrganizationId,
    required this.onOpenOrganization,
  });

  final AdminResourceRepository repository;
  final String rootOrganizationId;
  final ValueChanged<String> onOpenOrganization;

  @override
  State<OrganizationRelationTree> createState() => _OrganizationRelationTreeState();
}

class _OrganizationRelationTreeState extends State<OrganizationRelationTree> {
  late Future<_OrganizationTreeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTree();
  }

  @override
  void didUpdateWidget(covariant OrganizationRelationTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootOrganizationId != widget.rootOrganizationId) {
      _future = _loadTree();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OrganizationTreeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Organization tree load failed: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null || data.root == null) {
          return const Center(child: Text('No organization tree data'));
        }

        return Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Organization tree', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${data.relationCount} relation(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: _OrganizationTreeNodeView(
                      node: data.root!,
                      onOpenOrganization: widget.onOpenOrganization,
                    ),
                  ),
                ),
                if (data.reachedLimit) ...[
                  const Divider(height: 24),
                  Text(
                    'Tree is truncated to keep the admin UI responsive.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_OrganizationTreeData> _loadTree() async {
    final organizationRows = await widget.repository.fetchLookup(organizationLookup, limit: 5000);
    final labels = <String, String>{
      for (final row in organizationRows)
        if ((row['id']?.toString().trim() ?? '').isNotEmpty) row['id'].toString(): _organizationLabel(row),
    };

    final relationResource = findResourceByKey('organization_relations');
    final relationsByParent = <String, List<_OrganizationRelationEdge>>{};
    final visitedParents = <String>{};
    final queue = <_OrganizationQueueEntry>[_OrganizationQueueEntry(widget.rootOrganizationId, 0)];

    var relationCount = 0;
    var reachedLimit = false;
    const maxDepth = 8;
    const maxNodes = 250;

    while (queue.isNotEmpty) {
      if (visitedParents.length >= maxNodes) {
        reachedLimit = true;
        break;
      }

      final current = queue.removeAt(0);
      if (!visitedParents.add(current.organizationId)) continue;
      if (current.depth >= maxDepth) continue;

      final response = await widget.repository.fetchList(
        relationResource,
        limit: 1000,
        filters: {
          'parent_organization_id': current.organizationId,
        },
      );

      final edges = <_OrganizationRelationEdge>[];
      for (final row in response.items) {
        if (!_isCurrentRelation(row)) continue;
        final childId = _extractRelationId(row['child_organization_id']?.toString() ?? '');
        if (childId == null || childId.isEmpty) continue;
        final relationType = row['relation_type']?.toString();
        edges.add(_OrganizationRelationEdge(childId: childId, relationType: relationType));
        relationCount++;
        if (!visitedParents.contains(childId)) {
          queue.add(_OrganizationQueueEntry(childId, current.depth + 1));
        }
      }
      edges.sort((a, b) => _labelFor(labels, a.childId).compareTo(_labelFor(labels, b.childId)));
      relationsByParent[current.organizationId] = edges;
    }

    final activePath = <String>{};
    final root = _buildNode(widget.rootOrganizationId, labels, relationsByParent, activePath);
    return _OrganizationTreeData(
      root: root,
      relationCount: relationCount,
      reachedLimit: reachedLimit,
    );
  }

  _OrganizationNode _buildNode(
    String organizationId,
    Map<String, String> labels,
    Map<String, List<_OrganizationRelationEdge>> relationsByParent,
    Set<String> activePath,
  ) {
    final isCycle = activePath.contains(organizationId);
    if (isCycle) {
      return _OrganizationNode(
        organizationId: organizationId,
        label: '${_labelFor(labels, organizationId)} ↩',
        children: const [],
        relationType: null,
        isCycle: true,
      );
    }

    activePath.add(organizationId);
    final children = <_OrganizationNode>[
      for (final edge in relationsByParent[organizationId] ?? const <_OrganizationRelationEdge>[])
        _buildNode(edge.childId, labels, relationsByParent, activePath).copyWith(relationType: edge.relationType),
    ];
    activePath.remove(organizationId);

    return _OrganizationNode(
      organizationId: organizationId,
      label: _labelFor(labels, organizationId),
      children: children,
      relationType: null,
      isCycle: false,
    );
  }
}

class _OrganizationTreeNodeView extends StatelessWidget {
  const _OrganizationTreeNodeView({
    required this.node,
    required this.onOpenOrganization,
    this.depth = 0,
  });

  final _OrganizationNode node;
  final ValueChanged<String> onOpenOrganization;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 22.0, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                depth == 0 ? Icons.domain_rounded : Icons.subdirectory_arrow_right_rounded,
                size: 18,
                color: node.isCycle ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onOpenOrganization(node.organizationId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      node.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              if (node.relationType != null && node.relationType!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(node.relationType!),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
        ),
        if (node.children.isEmpty && depth == 0)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 8),
            child: Text(
              'No child organization relations found for this parent.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final child in node.children)
          _OrganizationTreeNodeView(
            node: child,
            onOpenOrganization: onOpenOrganization,
            depth: depth + 1,
          ),
      ],
    );
  }
}

class _OrganizationTreeData {
  const _OrganizationTreeData({
    required this.root,
    required this.relationCount,
    required this.reachedLimit,
  });

  final _OrganizationNode? root;
  final int relationCount;
  final bool reachedLimit;
}

class _OrganizationNode {
  const _OrganizationNode({
    required this.organizationId,
    required this.label,
    required this.children,
    required this.relationType,
    required this.isCycle,
  });

  final String organizationId;
  final String label;
  final List<_OrganizationNode> children;
  final String? relationType;
  final bool isCycle;

  _OrganizationNode copyWith({String? relationType}) {
    return _OrganizationNode(
      organizationId: organizationId,
      label: label,
      children: children,
      relationType: relationType ?? this.relationType,
      isCycle: isCycle,
    );
  }
}

class _OrganizationRelationEdge {
  const _OrganizationRelationEdge({required this.childId, required this.relationType});

  final String childId;
  final String? relationType;
}

class _OrganizationQueueEntry {
  const _OrganizationQueueEntry(this.organizationId, this.depth);

  final String organizationId;
  final int depth;
}

String _organizationLabel(Map<String, dynamic> row) {
  final displayName = _cleanText(row['display_name']);
  final legalName = _cleanText(row['legal_name']);
  final type = _cleanText(row['organization_type']);
  final website = _cleanText(row['website']);

  final name = displayName ?? legalName ?? website;
  if (name != null && legalName != null && !_sameText(name, legalName)) {
    return '$name · $legalName';
  }
  if (name != null && type != null) return '$name · $type';
  if (name != null) return name;
  return row['id']?.toString() ?? 'Organization';
}

String? _cleanText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _sameText(String a, String b) => _normalizeText(a) == _normalizeText(b);

String _normalizeText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ').trim();
}

String _labelFor(Map<String, String> labels, String id) => labels[id] ?? id;

bool _isCurrentRelation(Map<String, dynamic> row) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final validFrom = _parseDateOnly(row['valid_from']);
  if (validFrom != null && validFrom.isAfter(today)) return false;
  final validTo = _parseDateOnly(row['valid_to']);
  return validTo == null || !validTo.isBefore(today);
}

DateTime? _parseDateOnly(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
}

String? _extractRelationId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final matches = uuidPattern.allMatches(trimmed).toList(growable: false);
  if (matches.isNotEmpty) {
    return matches.last.group(0)!;
  }
  return trimmed;
}
