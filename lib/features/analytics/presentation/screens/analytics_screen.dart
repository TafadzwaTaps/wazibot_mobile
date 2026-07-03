/// lib/features/analytics/presentation/screens/analytics_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/analytics/stats');
  return resp.data as Map<String, dynamic>;
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(analyticsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async => ref.invalidate(analyticsProvider),
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

class _AnalyticsDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyticsDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = DashboardStats.fromJson(data);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI grid — mirrors the same fields as the web dashboard's
        // /analytics/stats card (total_orders, total_revenue,
        // pending_orders, active_customers).
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            StatCard(
              label: 'Total Revenue',
              value: currency.format(stats.totalRevenue),
              icon: Icons.attach_money,
              color: WaziBotColors.primary,
            ),
            StatCard(
              label: 'Total Orders',
              value: stats.totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
              color: WaziBotColors.info,
            ),
            StatCard(
              label: 'Pending Orders',
              value: stats.pendingOrders.toString(),
              icon: Icons.pending_outlined,
              color: WaziBotColors.warning,
            ),
            StatCard(
              label: 'Active Customers',
              value: stats.activeCustomers.toString(),
              icon: Icons.people_outline,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // WhatsApp activity
        Text('WhatsApp Activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _StatRow(
                  label: 'Handled by AI', value: stats.aiHandled.toString()),
              const Divider(height: 16),
              _StatRow(
                  label: 'Handled by you',
                  value: stats.humanHandled.toString()),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Orders summary
        Text('Orders Summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _StatRow(
                  label: 'Total Orders', value: stats.totalOrders.toString()),
              const Divider(height: 16),
              _StatRow(
                  label: 'Paid Orders', value: stats.paidOrders.toString()),
              const Divider(height: 16),
              _StatRow(
                  label: 'Pending Orders',
                  value: stats.pendingOrders.toString()),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}


