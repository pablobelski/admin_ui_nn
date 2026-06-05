import 'package:flutter/material.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/navigation/admin_registry.dart';

class CatalogItemDependencyTree extends StatefulWidget {
  const CatalogItemDependencyTree({
    super.key,
    required this.repository,
    required this.rootItemId,
    required this.onOpenCatalogItem,
  });

  final AdminResourceRepository repository;
  final String rootItemId;
  final ValueChanged<String> onOpenCatalogItem;

  @override
  State<CatalogItemDependencyTree> createState() => _CatalogItemDependencyTreeState();
}

class _CatalogItemDependencyTreeState extends State<CatalogItemDependencyTree> {
  late Future<_DependencyTreeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTree();
  }

  @override
  void didUpdateWidget(covariant CatalogItemDependencyTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootItemId != widget.rootItemId) {
      _future = _loadTree();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DependencyTreeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Dependency tree load failed: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null || data.root == null) {
          return const Center(child: Text('No dependency tree data'));
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
                    Text('Dependency tree', style: Theme.of(context).textTheme.titleMedium),
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
                    child: _TreeNodeView(
                      node: data.root!,
                      onOpenCatalogItem: widget.onOpenCatalogItem,
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

  Future<_DependencyTreeData> _loadTree() async {
    final itemRows = await widget.repository.fetchLookup(catalogItemLookup, limit: 5000);
    final labels = <String, String>{
      for (final row in itemRows)
        if ((row['id']?.toString().trim() ?? '').isNotEmpty) row['id'].toString(): _catalogItemLabel(row),
    };

    final relationResource = findResourceByKey('catalog_item_relations');
    final relationsByParent = <String, List<_RelationEdge>>{};
    final visitedParents = <String>{};
    final queue = <_QueueEntry>[_QueueEntry(widget.rootItemId, 0)];

    var relationCount = 0;
    var reachedLimit = false;
    const maxDepth = 6;
    const maxNodes = 250;

    while (queue.isNotEmpty) {
      if (visitedParents.length >= maxNodes) {
        reachedLimit = true;
        break;
      }

      final current = queue.removeAt(0);
      if (!visitedParents.add(current.itemId)) continue;
      if (current.depth >= maxDepth) continue;

      final response = await widget.repository.fetchList(
        relationResource,
        limit: 1000,
        filters: {
          'parent_catalog_item_id': current.itemId,
          'is_active': 'true',
        },
      );

      final edges = <_RelationEdge>[];
      for (final row in response.items) {
        final childId = _extractRelationId(row['child_catalog_item_id']?.toString() ?? '');
        if (childId == null || childId.isEmpty) continue;
        final relationType = row['relation_type_code']?.toString();
        edges.add(_RelationEdge(childId: childId, relationType: relationType));
        relationCount++;
        if (!visitedParents.contains(childId)) {
          queue.add(_QueueEntry(childId, current.depth + 1));
        }
      }
      edges.sort((a, b) => _labelFor(labels, a.childId).compareTo(_labelFor(labels, b.childId)));
      relationsByParent[current.itemId] = edges;
    }

    final activePath = <String>{};
    final root = _buildNode(widget.rootItemId, labels, relationsByParent, activePath);
    return _DependencyTreeData(
      root: root,
      relationCount: relationCount,
      reachedLimit: reachedLimit,
    );
  }

  _DependencyNode _buildNode(
    String itemId,
    Map<String, String> labels,
    Map<String, List<_RelationEdge>> relationsByParent,
    Set<String> activePath,
  ) {
    final isCycle = activePath.contains(itemId);
    if (isCycle) {
      return _DependencyNode(
        itemId: itemId,
        label: '${_labelFor(labels, itemId)} ↩',
        children: const [],
        relationType: null,
        isCycle: true,
      );
    }

    activePath.add(itemId);
    final children = <_DependencyNode>[
      for (final edge in relationsByParent[itemId] ?? const <_RelationEdge>[])
        _buildNode(edge.childId, labels, relationsByParent, activePath).copyWith(relationType: edge.relationType),
    ];
    activePath.remove(itemId);

    return _DependencyNode(
      itemId: itemId,
      label: _labelFor(labels, itemId),
      children: children,
      relationType: null,
      isCycle: false,
    );
  }
}

class _TreeNodeView extends StatelessWidget {
  const _TreeNodeView({
    required this.node,
    required this.onOpenCatalogItem,
    this.depth = 0,
  });

  final _DependencyNode node;
  final ValueChanged<String> onOpenCatalogItem;
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
                depth == 0 ? Icons.inventory_2_outlined : Icons.subdirectory_arrow_right_rounded,
                size: 18,
                color: node.isCycle ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onOpenCatalogItem(node.itemId),
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
              'No child catalog item relations found for this parent.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final child in node.children)
          _TreeNodeView(
            node: child,
            onOpenCatalogItem: onOpenCatalogItem,
            depth: depth + 1,
          ),
      ],
    );
  }
}

class _DependencyTreeData {
  const _DependencyTreeData({
    required this.root,
    required this.relationCount,
    required this.reachedLimit,
  });

  final _DependencyNode? root;
  final int relationCount;
  final bool reachedLimit;
}

class _DependencyNode {
  const _DependencyNode({
    required this.itemId,
    required this.label,
    required this.children,
    required this.relationType,
    required this.isCycle,
  });

  final String itemId;
  final String label;
  final List<_DependencyNode> children;
  final String? relationType;
  final bool isCycle;

  _DependencyNode copyWith({String? relationType}) {
    return _DependencyNode(
      itemId: itemId,
      label: label,
      children: children,
      relationType: relationType ?? this.relationType,
      isCycle: isCycle,
    );
  }
}

class _RelationEdge {
  const _RelationEdge({required this.childId, required this.relationType});

  final String childId;
  final String? relationType;
}

class _QueueEntry {
  const _QueueEntry(this.itemId, this.depth);

  final String itemId;
  final int depth;
}

String _catalogItemLabel(Map<String, dynamic> row) {
  final baseCode = _cleanCatalogItemText(row['base_code']);
  final shortName = _cleanCatalogItemText(row['short_name']);
  final name = _cleanCatalogItemText(row['name']);
  final profileNo = _cleanCatalogItemText(row['profile_no']);
  final systemName = _cleanCatalogItemText(row['system_name']);

  // Important: imported Excel image placeholders may accidentally end up in
  // name/short_name. Do not let technical labels like "Cellimage" become the
  // visible catalog item name in the tree.
  final preferredName = shortName ?? name ?? systemName;

  if (baseCode != null && preferredName != null && !_sameText(baseCode, preferredName)) {
    return '$baseCode · $preferredName';
  }
  if (baseCode != null && profileNo != null && !_sameText(baseCode, profileNo)) {
    return '$baseCode · $profileNo';
  }
  if (baseCode != null) return baseCode;
  if (profileNo != null && preferredName != null && !_sameText(profileNo, preferredName)) {
    return '$profileNo · $preferredName';
  }
  if (preferredName != null) return preferredName;
  if (profileNo != null) return profileNo;
  return row['id']?.toString() ?? 'Catalog item';
}

String? _cleanCatalogItemText(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;

  final compact = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '');
  const technicalPlaceholders = {
    'cellimage',
    'cellimageobject',
    'imagefile',
    'imageobject',
  };
  if (technicalPlaceholders.contains(compact) || compact.startsWith('cellimage')) {
    return null;
  }
  if (text.startsWith('Instance of ') || text.startsWith('{') || text.startsWith('[')) {
    return null;
  }
  return text;
}

bool _sameText(String a, String b) => _normalizeText(a) == _normalizeText(b);

String _normalizeText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ').trim();
}

String _labelFor(Map<String, String> labels, String id) => labels[id] ?? id;

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
