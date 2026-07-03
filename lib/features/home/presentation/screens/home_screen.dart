/// lib/features/home/presentation/screens/home_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final businessProfileProvider = FutureProvider<BusinessProfile>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/me');
  return BusinessProfile.fromJson(resp.data as Map<String, dynamic>);
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/analytics/stats');
  return DashboardStats.fromJson(resp.data as Map<String, dynamic>);
});

// ── Screen ────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(businessProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          ref.invalidate(businessProfileProvider);
          ref.invalidate(dashboardStatsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── App bar ───────────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              expandedHeight: 0,
              title: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: WaziBotColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                Text('WaziBot',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface)),
              ]),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.go(Routes.settings),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Business header ───────────────────────────────────────
                  profileAsync.when(
                    loading: () => _BusinessHeaderShimmer(),
                    error: (e, _) => _ErrorCard(message: apiErrorMessage(e)),
                    data: (profile) => _BusinessHeader(profile: profile),
                  ),
                  const SizedBox(height: 20),

                  // ── Stats ─────────────────────────────────────────────────
                  Text('Overview', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),

                  statsAsync.when(
                    loading: () => _StatsGridShimmer(),
                    error: (e, _) => _ErrorCard(message: apiErrorMessage(e)),
                    data: (stats) => _StatsGrid(stats: stats),
                  ),
                  const SizedBox(height: 20),

                  // ── AI vs human handled ────────────────────────────────────
                  statsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) => _HandledByCard(stats: stats),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick actions ─────────────────────────────────────────
                  Text('Quick Actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _QuickActions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Business header ───────────────────────────────────────────────────────────
class _BusinessHeader extends StatelessWidget {
  final BusinessProfile profile;
  const _BusinessHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _greeting();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WaziBotColors.primary.withOpacity(0.15),
            WaziBotColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: WaziBotColors.primary.withOpacity(0.25), width: 1),
      ),
      child: Row(children: [
        // Avatar/logo
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: WaziBotColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: WaziBotColors.primary.withOpacity(0.4), width: 1),
          ),
          child: const Icon(Icons.store_outlined,
              color: WaziBotColors.primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              Text(profile.name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                _PlanBadge(plan: profile.displayPlan, isOnTrial: profile.isOnTrial),
                if (profile.isOnTrial) ...[
                  const SizedBox(width: 8),
                  Text(_trialDaysLeft(profile.trialEndsAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: WaziBotColors.warning)),
                ],
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  String _trialDaysLeft(String? trialEndsAt) {
    if (trialEndsAt == null) return '';
    final end = DateTime.tryParse(trialEndsAt);
    if (end == null) return '';
    final days = end.difference(DateTime.now()).inDays;
    if (days < 0) return 'Trial expired';
    return '$days days left in trial';
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  final bool isOnTrial;
  const _PlanBadge({required this.plan, required this.isOnTrial});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: WaziBotColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: WaziBotColors.primary.withOpacity(0.4), width: 1),
      ),
      child: Text(
        isOnTrial ? '$plan (Trial)' : plan,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: WaziBotColors.primary,
        ),
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return GridView.count(
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
    );
  }
}

// ── AI vs human handled card ────────────────────────────────────────────────
class _HandledByCard extends StatelessWidget {
  final DashboardStats stats;
  const _HandledByCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats.aiHandled + stats.humanHandled;
    final share = stats.aiHandledShare;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI vs. human handled',
                    style: theme.textTheme.titleMedium),
                Text(total == 0 ? '—' : '${(share * 100).toInt()}% AI',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: WaziBotColors.primary)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : share,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor:
                    const AlwaysStoppedAnimation(WaziBotColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${stats.aiHandled} handled by AI',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Text('${stats.humanHandled} handled by you',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QA(Icons.receipt_long_outlined, 'Orders', WaziBotColors.info,
          () => context.go(Routes.orders)),
      _QA(Icons.inbox_outlined, 'Inbox', WaziBotColors.primary,
          () => context.go(Routes.inbox)),
      _QA(Icons.qr_code_2, 'Scan QR', const Color(0xFF8B5CF6),
          () => context.go(Routes.qr)),
      _QA(Icons.share_outlined, 'Share Store', WaziBotColors.warning,
          () => _shareStore(ref)),
      _QA(Icons.open_in_browser_outlined, 'Website', WaziBotColors.error,
          () => _openWebsite(ref)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((a) => _QuickActionButton(qa: a)).toList(),
    );
  }

  void _shareStore(WidgetRef ref) {
    // share_plus integration
  }

  void _openWebsite(WidgetRef ref) {
    // url_launcher integration
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}

class _QuickActionButton extends StatelessWidget {
  final _QA qa;
  const _QuickActionButton({required this.qa});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.of(context).size.width - 52) / 3;

    return GestureDetector(
      onTap: qa.onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline, width: 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: qa.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(qa.icon, color: qa.color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(qa.label,
              style: theme.textTheme.labelMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Shimmers ──────────────────────────────────────────────────────────────────
class _BusinessHeaderShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const LoadingShimmer(height: 84);
}

class _StatsGridShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: List.generate(4, (_) => const LoadingShimmer()),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.error_outline,
            color: theme.colorScheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer))),
      ]),
    );
  }
}
