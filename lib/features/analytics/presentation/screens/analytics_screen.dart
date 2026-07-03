/// lib/features/analytics/presentation/screens/analytics_screen.dart
/// Full parity with web loadAnalyticsCharts() + loadHandoffStats()
/// + loadRepeatCustomerStat() + loadSatisfactionScore()
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use cachedAnalyticsProvider (not the stale analyticsProvider)
    final analyticsAsync = ref.watch(cachedAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              ref.invalidate(cachedAnalyticsProvider);
              ref.invalidate(repeatCustomersProvider);
              ref.invalidate(satisfactionProvider);
              ref.invalidate(topCustomersProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          await Haptics.refresh();
          ref.invalidate(cachedAnalyticsProvider);
          ref.invalidate(repeatCustomersProvider);
          ref.invalidate(satisfactionProvider);
          ref.invalidate(topCustomersProvider);
        },
        child: analyticsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: ShimmerList(count: 6, itemHeight: 100),
          ),
          error: (e, _) => Center(child: Text(apiErrorMessage(e))),
          data: (data) => _AnalyticsDashboard(data: data),
        ),
      ),
    );
  }
}

class _AnalyticsDashboard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _AnalyticsDashboard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = DashboardStats.fromJson(data);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    final List<Widget> children = [
      // ── Row 1: key KPIs
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          StatCard(label: 'Total Orders',
              value: stats.totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
              color: WaziBotColors.primary),
          StatCard(label: 'Total Revenue',
              value: currency.format(stats.totalRevenue),
              icon: Icons.attach_money,
              color: WaziBotColors.success),
          StatCard(label: 'AI Handled',
              value: stats.aiHandled.toString(),
              icon: Icons.smart_toy_outlined,
              color: WaziBotColors.info),
          StatCard(label: 'Pending Orders',
              value: stats.pendingOrders.toString(),
              icon: Icons.hourglass_empty_outlined,
              color: WaziBotColors.warning),
        ],
      ),
      const SizedBox(height: 20),

      // ── Health score
      Text('Business Health Score', style: theme.textTheme.titleMedium),
      const SizedBox(height: 10),
      _HealthBar(score: stats.healthScore),
      const SizedBox(height: 20),

      // ── Repeat rate + Satisfaction row
      const _RepeatSatisfactionRow(),
      const SizedBox(height: 20),

      // ── WhatsApp activity
      Text('WhatsApp Activity', style: theme.textTheme.titleMedium),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _StatRow(label: 'AI Handled', value: stats.aiHandled.toString()),
            const Divider(height: 16),
            _StatRow(label: 'Agent Handled', value: stats.humanHandled.toString()),
            const Divider(height: 16),
            _StatRow(label: 'Active Customers', value: stats.activeCustomers.toString()),
            const Divider(height: 16),
            _StatRow(label: 'Paid Orders', value: stats.paidOrders.toString()),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      // ── Top customers
      const _TopCustomersSection(),
      const SizedBox(height: 20),
    ];

    // Weekly chart — only when data present
    final weeklyData = data['weekly_revenue'];
    if (weeklyData != null) {
      children.addAll([
        Text('Weekly Revenue', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _WeeklyChart(
          data: (weeklyData as List).map((v) => (v as num).toDouble()).toList(),
        ),
        const SizedBox(height: 20),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}
// ── Repeat rate + Satisfaction ─────────────────────────────────────────────────
class _RepeatSatisfactionRow extends ConsumerWidget {
  const _RepeatSatisfactionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatAsync = ref.watch(repeatCustomersProvider);
    final satAsync = ref.watch(satisfactionProvider);
    return Row(children: [
      Expanded(child: repeatAsync.when(
        loading: () => const LoadingShimmer(height: 90),
        error: (_, __) => const SizedBox.shrink(),
        data: (d) => _MiniStatCard(
          label: 'Repeat Rate',
          value: '${(d['repeat_rate_pct'] as num?)?.toStringAsFixed(0) ?? '0'}%',
          sub: '${d['repeat_customers'] ?? 0} of ${d['total_customers'] ?? 0} reordered',
          icon: Icons.repeat_rounded,
          color: WaziBotColors.primary,
        ),
      )),
      const SizedBox(width: 10),
      Expanded(child: satAsync.when(
        loading: () => const LoadingShimmer(height: 90),
        error: (_, __) => const SizedBox.shrink(),
        data: (d) {
          final avg = d['avg_rating'];
          return _MiniStatCard(
            label: 'Satisfaction',
            value: avg != null ? '$avg/5' : 'No data',
            sub: '${d['rated_count'] ?? 0} ratings',
            icon: Icons.star_outline_rounded,
            color: WaziBotColors.warning,
          );
        },
      )),
    ]);
  }
}

// ── Top customers section ─────────────────────────────────────────────────────
class _TopCustomersSection extends ConsumerWidget {
  const _TopCustomersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final topAsync = ref.watch(topCustomersProvider);
    return topAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (customers) {
        if (customers.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top Customers', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: customers.take(5).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: WaziBotColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        (c.name ?? c.phone).isNotEmpty
                            ? (c.name ?? c.phone)[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11,
                            color: WaziBotColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c.name ?? c.phone,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(currency.format(c.totalSpent),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: WaziBotColors.primary)),
                  ]),
                )).toList(),
              ),
            ),
          ),
        ]);
      },
    );
  }
}


class _MiniStatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _MiniStatCard({required this.label, required this.value,
      required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8, color: theme.colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: color)),
        const SizedBox(height: 2),
        Text(sub, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

class _HealthBar extends StatelessWidget {
  final double score;
  const _HealthBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (score / 100).clamp(0.0, 1.0);
    final color = score >= 75 ? WaziBotColors.success
        : score >= 50 ? WaziBotColors.warning : WaziBotColors.error;
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(score >= 75 ? 'Excellent' : score >= 50 ? 'Good' : 'Needs attention',
              style: theme.textTheme.titleSmall?.copyWith(color: color)),
          Text('${score.toInt()}/100',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color))),
      ]),
    ));
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
      Text(value, style: theme.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<double> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: SizedBox(height: 160,
        child: BarChart(BarChartData(
          maxY: maxVal * 1.2,
          barGroups: List.generate(data.length, (i) => BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(
              toY: data[i], color: WaziBotColors.primary, width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)))],
          )),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (v, _) => Text(days[v.toInt() % days.length],
                  style: TextStyle(fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant)))),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outline, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
        )),
      ),
    ));
  }
}
