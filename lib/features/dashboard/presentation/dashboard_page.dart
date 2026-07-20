import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_providers.dart';

final _currency = NumberFormat.currency(
  locale: 'de_DE',
  symbol: '€',
  decimalDigits: 0,
);
final _integer = NumberFormat.decimalPattern('de_DE');
final _date = DateFormat('dd.MM.yyyy');
final _dateTime = DateFormat('dd.MM.yyyy HH:mm');

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _days = 30;

  Future<void> _refresh() async {
    await ref.refresh(dashboardProvider(_days).future);
  }

  void _openResource(
    String resourceKey, {
    Map<String, String> filters = const {},
  }) {
    ref
        .read(selectedResourceProvider.notifier)
        .select(resourceKey, filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider(_days));

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DashboardError(
        error: error,
        onRetry: () => ref.invalidate(dashboardProvider(_days)),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                data: data,
                selectedDays: _days,
                onDaysChanged: (value) => setState(() => _days = value),
                onRefresh: () => ref.invalidate(dashboardProvider(_days)),
              ),
              const SizedBox(height: 16),
              _QuickLinks(onOpenResource: _openResource),
              const SizedBox(height: 16),
              _KpiGrid(
                summary: data.summary,
                onOpenQuotes: () => _openResource('quotes'),
                onOpenOrganizations: () => _openResource('organizations'),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                leftFlex: 2,
                left: _ActivitySection(points: data.activity),
                right: _QualitySection(
                  summary: data.summary,
                  onOpenCalculator: () => _openResource('calculator_workspace'),
                  onOpenDocuments: () => _openResource('generated_documents'),
                ),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                left: _TopCustomersSection(
                  customers: data.topCustomers,
                  onOpenCustomer: (id) =>
                      _openResource('organizations', filters: {'id': id}),
                  onOpenAll: () => _openResource('organizations'),
                ),
                right: _PipelineSection(
                  summary: data.summary,
                  statuses: data.statuses,
                  onOpenStatus: (status) =>
                      _openResource('quotes', filters: {'status_code': status}),
                  onOpenCalculator: () => _openResource('calculator_workspace'),
                  onOpenQuotes: () => _openResource('quotes'),
                  onOpenFailedJobs: () => _openResource(
                    'integration_jobs',
                    filters: const {'status_code': 'failed'},
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _RecentQuotesSection(
                quotes: data.recentQuotes,
                onOpenQuote: (id) =>
                    _openResource('quotes', filters: {'id': id}),
                onOpenAll: () => _openResource('quotes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.data,
    required this.selectedDays,
    required this.onDaysChanged,
    required this.onRefresh,
  });

  final DashboardData data;
  final int selectedDays;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final periodText = data.periodFrom == null || data.periodTo == null
        ? 'Selected period'
        : '${_date.format(data.periodFrom!.toLocal())} – ${_date.format(data.periodTo!.toLocal())}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business overview',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$periodText · compared with the previous ${data.days} days',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {selectedDays},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onDaysChanged(selection.first),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh dashboard',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );

        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            controls,
          ],
        );
      },
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.onOpenResource});

  final void Function(String resourceKey) onOpenResource;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => onOpenResource('calculator_workspace'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New calculation'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => onOpenResource('quotes'),
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('Quotes'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => onOpenResource('organizations'),
          icon: const Icon(Icons.apartment_outlined),
          label: const Text('Organizations'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => onOpenResource('generated_documents'),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generated documents'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => onOpenResource('integration_jobs'),
          icon: const Icon(Icons.sync_outlined),
          label: const Text('Integration jobs'),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.summary,
    required this.onOpenQuotes,
    required this.onOpenOrganizations,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenQuotes;
  final VoidCallback onOpenOrganizations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1400
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              height: 150,
              child: _KpiCard(
                label: 'Quote volume (net)',
                value: _currency.format(summary.quoteValueNet),
                subtitle: 'Gross ${_currency.format(summary.quoteValueGross)}',
                icon: Icons.euro_rounded,
                trend: _change(
                  summary.quoteValueNet,
                  summary.previousQuoteValueNet,
                ),
                onTap: onOpenQuotes,
              ),
            ),
            SizedBox(
              width: width,
              height: 150,
              child: _KpiCard(
                label: 'Saved quotes',
                value: _integer.format(summary.quoteCount),
                subtitle: 'Commercial calculations in the period',
                icon: Icons.request_quote_outlined,
                trend: _change(
                  summary.quoteCount.toDouble(),
                  summary.previousQuoteCount.toDouble(),
                ),
                onTap: onOpenQuotes,
              ),
            ),
            SizedBox(
              width: width,
              height: 150,
              child: _KpiCard(
                label: 'Average priced quote (net)',
                value: _currency.format(summary.averageQuoteNet),
                subtitle: 'Quotes with a calculated amount',
                icon: Icons.analytics_outlined,
                trend: _change(
                  summary.averageQuoteNet,
                  summary.previousAverageQuoteNet,
                ),
                onTap: onOpenQuotes,
              ),
            ),
            SizedBox(
              width: width,
              height: 150,
              child: _KpiCard(
                label: 'Active customers',
                value: _integer.format(summary.activeCustomerCount),
                subtitle: 'Unique buyer organizations',
                icon: Icons.groups_2_outlined,
                trend: _change(
                  summary.activeCustomerCount.toDouble(),
                  summary.previousActiveCustomerCount.toDouble(),
                ),
                onTap: onOpenOrganizations,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.trend,
    required this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final double? trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: scheme.onPrimaryContainer,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _TrendBadge(value: trend),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final isNew = value == null;
    final positive = (value ?? 0) >= 0;
    final color = isNew
        ? Theme.of(context).colorScheme.primary
        : positive
        ? const Color(0xFF16794B)
        : Theme.of(context).colorScheme.error;
    final background = color.withValues(alpha: 0.10);
    final label = isNew
        ? 'New'
        : '${positive ? '+' : ''}${value!.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.left,
    required this.right,
    this.leftFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1050) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.points});

  final List<DashboardActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quote activity',
      subtitle:
          'Net volume by period; the number above each bar is the quote count',
      child: SizedBox(
        height: 250,
        child: points.isEmpty
            ? const _EmptyState(message: 'No quote activity in this period')
            : _ActivityChart(points: points),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.points});

  final List<DashboardActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxAmount = points.fold<double>(
      0,
      (current, point) => math.max(current, point.netAmount).toDouble(),
    );
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math
            .max(constraints.maxWidth, points.length * 45.0)
            .toDouble();
        final slotWidth = chartWidth / points.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final point in points)
                  SizedBox(
                    width: slotWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            '${point.quoteCount}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, barConstraints) {
                                final ratio = maxAmount == 0
                                    ? 0.0
                                    : point.netAmount / maxAmount;
                                final height = point.netAmount == 0
                                    ? 2.0
                                    : math
                                          .max(
                                            4.0,
                                            barConstraints.maxHeight * ratio,
                                          )
                                          .toDouble();
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Tooltip(
                                    message:
                                        '${_activityDate(point.bucket)}\n'
                                        '${point.quoteCount} quotes · ${_currency.format(point.netAmount)} net',
                                    child: Container(
                                      width: math
                                          .max(8.0, slotWidth - 8)
                                          .toDouble(),
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: point.netAmount == 0
                                            ? scheme.outlineVariant
                                            : scheme.primary,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _activityDate(point.bucket),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QualitySection extends StatelessWidget {
  const _QualitySection({
    required this.summary,
    required this.onOpenCalculator,
    required this.onOpenDocuments,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Calculation quality',
      subtitle: 'Project-specific health and document coverage',
      child: Column(
        children: [
          _ProgressMetric(
            label: 'Valid calculations',
            value:
                '${summary.validCalculationCount} / ${summary.calculationCount}',
            percent: summary.validCalculationRate,
            color: const Color(0xFF16794B),
          ),
          const SizedBox(height: 18),
          _ProgressMetric(
            label: 'Quotes with generated document',
            value: '${summary.quotesWithDocument} / ${summary.quoteCount}',
            percent: summary.documentCoverageRate,
            color: scheme.primary,
          ),
          const Divider(height: 28),
          _CompactActionRow(
            icon: Icons.warning_amber_rounded,
            label: 'Runs with missing prices',
            value: '${summary.priceGapRunCount}',
            color: summary.priceGapRunCount > 0
                ? scheme.error
                : const Color(0xFF16794B),
            onTap: onOpenCalculator,
          ),
          _CompactActionRow(
            icon: Icons.rule_folder_outlined,
            label: 'Runs with warnings',
            value: '${summary.warningRunCount}',
            color: summary.warningRunCount > 0
                ? const Color(0xFFB36B00)
                : const Color(0xFF16794B),
            onTap: onOpenCalculator,
          ),
          _CompactActionRow(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Documents generated',
            value: '${summary.generatedDocumentCount}',
            color: scheme.primary,
            onTap: onOpenDocuments,
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final String value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '$value · ${percent.toStringAsFixed(1)}%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (percent / 100).clamp(0.0, 1.0).toDouble(),
          minHeight: 8,
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ],
    );
  }
}

class _TopCustomersSection extends StatelessWidget {
  const _TopCustomersSection({
    required this.customers,
    required this.onOpenCustomer,
    required this.onOpenAll,
  });

  final List<DashboardCustomer> customers;
  final ValueChanged<String> onOpenCustomer;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Top customers',
      subtitle: 'By net quote volume in the selected period',
      trailing: TextButton(
        onPressed: onOpenAll,
        child: const Text('All organizations'),
      ),
      child: customers.isEmpty
          ? const SizedBox(
              height: 180,
              child: _EmptyState(message: 'No customers in this period'),
            )
          : Column(
              children: [
                for (var index = 0; index < customers.length; index++) ...[
                  _CustomerRow(
                    rank: index + 1,
                    customer: customers[index],
                    onTap: () =>
                        onOpenCustomer(customers[index].organizationId),
                  ),
                  if (index < customers.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.rank,
    required this.customer,
    required this.onTap,
  });

  final int rank;
  final DashboardCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.secondaryContainer,
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.organizationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${customer.quoteCount} quotes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _currency.format(customer.netAmount),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PipelineSection extends StatelessWidget {
  const _PipelineSection({
    required this.summary,
    required this.statuses,
    required this.onOpenStatus,
    required this.onOpenCalculator,
    required this.onOpenQuotes,
    required this.onOpenFailedJobs,
  });

  final DashboardSummary summary;
  final List<DashboardStatus> statuses;
  final ValueChanged<String> onOpenStatus;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenQuotes;
  final VoidCallback onOpenFailedJobs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Pipeline & attention',
      subtitle: 'Quote stages and items that need review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statuses.isEmpty)
            const SizedBox(
              height: 72,
              child: _EmptyState(message: 'No quote statuses in this period'),
            )
          else
            for (final status in statuses)
              _StatusRow(
                status: status,
                total: summary.quoteCount,
                onTap: () => onOpenStatus(status.code),
              ),
          const Divider(height: 24),
          _CompactActionRow(
            icon: Icons.error_outline_rounded,
            label: 'Calculations requiring attention',
            value: '${summary.attentionCalculationCount}',
            color: summary.attentionCalculationCount > 0
                ? scheme.error
                : const Color(0xFF16794B),
            onTap: onOpenCalculator,
          ),
          _CompactActionRow(
            icon: Icons.person_search_outlined,
            label: 'Quotes without buyer',
            value: '${summary.missingBuyerCount}',
            color: summary.missingBuyerCount > 0
                ? const Color(0xFFB36B00)
                : const Color(0xFF16794B),
            onTap: onOpenQuotes,
          ),
          _CompactActionRow(
            icon: Icons.sync_problem_outlined,
            label: 'Failed integration jobs',
            value: '${summary.failedIntegrationJobCount}',
            color: summary.failedIntegrationJobCount > 0
                ? scheme.error
                : const Color(0xFF16794B),
            subtitle: summary.openIntegrationJobCount > 0
                ? '${summary.openIntegrationJobCount} pending or running'
                : null,
            onTap: onOpenFailedJobs,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.total,
    required this.onTap,
  });

  final DashboardStatus status;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status.code);
    final ratio = total == 0 ? 0.0 : status.quoteCount / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(
                _titleCase(status.code),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text(
                '${status.quoteCount}',
                textAlign: TextAlign.end,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RecentQuotesSection extends StatelessWidget {
  const _RecentQuotesSection({
    required this.quotes,
    required this.onOpenQuote,
    required this.onOpenAll,
  });

  final List<DashboardQuote> quotes;
  final ValueChanged<String> onOpenQuote;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent quotes',
      subtitle: 'Latest saved commercial calculations in the selected period',
      trailing: TextButton.icon(
        onPressed: onOpenAll,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('All quotes'),
      ),
      child: quotes.isEmpty
          ? const SizedBox(
              height: 160,
              child: _EmptyState(message: 'No quotes in this period'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 42,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 26,
                columns: const [
                  DataColumn(label: Text('Quote')),
                  DataColumn(label: Text('Kommission')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Net'), numeric: true),
                  DataColumn(label: Text('Saved')),
                ],
                rows: [
                  for (final quote in quotes)
                    DataRow(
                      onSelectChanged: (_) => onOpenQuote(quote.id),
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              quote.quoteNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Text(
                              quote.externalName.isEmpty
                                  ? '—'
                                  : quote.externalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Text(
                              quote.buyerName.isEmpty ? '—' : quote.buyerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_StatusBadge(code: quote.statusCode)),
                        DataCell(Text(_currency.format(quote.netAmount))),
                        DataCell(Text(_formatDateTime(quote.createdAt))),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _titleCase(code),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dashboard could not be loaded',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double? _change(double current, double previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return (current - previous) * 100 / previous;
}

String _activityDate(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('dd.MM').format(value.toLocal());
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return _dateTime.format(value.toLocal());
}

String _titleCase(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Unknown';
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'calculated':
      return const Color(0xFF2457C5);
    case 'approved':
      return const Color(0xFF16794B);
    case 'sent':
      return const Color(0xFF007C83);
    case 'cancelled':
      return Theme.of(context).colorScheme.error;
    case 'archived':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF7A5C00);
  }
}
