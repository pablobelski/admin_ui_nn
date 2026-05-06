import 'dart:math' as math;

import 'package:flutter/material.dart';

const double adminRowNumberColumnWidth = 80;

class AdminListFooter extends StatelessWidget {
  const AdminListFooter({
    super.key,
    required this.offset,
    required this.limit,
    required this.pageItemCount,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int offset;
  final int limit;
  final int pageItemCount;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pageIndex = _pageIndex(offset, limit);
    final lastPageIndex = _lastPageIndex(total, limit);
    final progress = _progressCount(
      offset: offset,
      limit: limit,
      pageItemCount: pageItemCount,
      total: total,
    );

    return Row(
      children: [
        Text('Rows: $progress / total: $total'),
        const SizedBox(width: 16),
        Text('Page: $pageIndex / $lastPageIndex'),
        const Spacer(),
        OutlinedButton(
          onPressed: onPrevious,
          child: const Text('Prev'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onNext,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class AdminTableHeaderCell extends StatelessWidget {
  const AdminTableHeaderCell({
    super.key,
    required this.label,
    this.width,
    this.flex,
    this.align = TextAlign.left,
  });

  final String label;
  final double? width;
  final int? flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

class AdminTableValueCell extends StatelessWidget {
  const AdminTableValueCell({
    super.key,
    required this.value,
    this.width,
    this.flex,
    this.strong = false,
    this.align = TextAlign.left,
  });

  final String value;
  final double? width;
  final int? flex;
  final bool strong;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      value,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: strong
          ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
          : null,
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

class AdminRowNumberHeader extends StatelessWidget {
  const AdminRowNumberHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminTableHeaderCell(
      label: '#',
      width: adminRowNumberColumnWidth,
      align: TextAlign.left,
    );
  }
}

class AdminRowNumberCell extends StatelessWidget {
  const AdminRowNumberCell({
    super.key,
    required this.index,
    this.offset = 0,
  });

  final int index;
  final int offset;

  @override
  Widget build(BuildContext context) {
    return AdminTableValueCell(
      value: '${offset + index + 1}',
      width: adminRowNumberColumnWidth,
      align: TextAlign.left,
    );
  }
}

bool adminListHasNextPage({
  required int offset,
  required int limit,
  required int pageItemCount,
  required int total,
}) {
  if (total > 0) {
    return offset + pageItemCount < total;
  }
  return pageItemCount >= limit;
}

int _pageIndex(int offset, int limit) {
  if (limit <= 0) return 0;
  return offset ~/ limit;
}

int _lastPageIndex(int total, int limit) {
  if (total <= 0 || limit <= 0) return 0;
  return (total - 1) ~/ limit;
}

int _progressCount({
  required int offset,
  required int limit,
  required int pageItemCount,
  required int total,
}) {
  if (total <= 0) return 0;
  final isFirstPage = offset <= 0;
  final isLastPage = offset + pageItemCount >= total || pageItemCount < limit;
  if (isFirstPage && !isLastPage) return 0;
  if (isLastPage) return math.min(offset + pageItemCount, total);
  return math.min(offset, total);
}
