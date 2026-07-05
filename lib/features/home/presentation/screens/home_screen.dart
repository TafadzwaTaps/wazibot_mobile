/// lib/features/home/presentation/screens/home_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/providers/cached_providers.dart';

// ── Screen ────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);
    final statsAsync = ref.watch(cachedAnalyticsProvider).whenData(DashboardStats.fromJson);

    return Scaffold(
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          ref.invalidate(cachedProfileProvider);
          ref.invalidate(cachedAnalyticsProvider);
          ref.invalidate(repeatCustomersProvider);
          ref.invalidate(satisfactionProvider);
          ref.invalidate(trialStatusProvider);
          ref.invalidate(growthInsightsProvider);
          ref.invalidate(cachedProductsProvider);
          ref.invalidate(cachedOrdersProvider(null));
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

                  // ── Repeat Rate + Satisfaction row ────────────────────
                  const _RepeatSatisfactionRow(),
                  const SizedBox(height: 20),

                  // ── Business Health (mirrors web loadHealthWidget) ─────────
                  const _BusinessHealthWidget(),
                  const SizedBox(height: 20),

                  // ── Growth Insights (mirrors web renderGrowthCard) ─────────
                  const _GrowthInsightsCard(),
                  const SizedBox(height: 20),

                  // ── Store link banner ──────────────────────────────────────
                  const _StoreLinkBanner(),
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
            WaziBotColors.primary.withValues(alpha: 0.15),
            WaziBotColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: WaziBotColors.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(children: [
        // Avatar/logo
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: WaziBotColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: WaziBotColors.primary.withValues(alpha: 0.4), width: 1),
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
        color: WaziBotColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: WaziBotColors.primary.withValues(alpha: 0.4), width: 1),
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
    final share = total > 0 ? stats.aiHandled / total : 0.0;

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
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QA(Icons.receipt_long_outlined, 'Orders', WaziBotColors.info,
          () => context.go(Routes.orders)),
      _QA(Icons.inbox_outlined, 'Inbox', WaziBotColors.primary,
          () => context.go(Routes.inbox)),
      _QA(Icons.qr_code_2, 'QR Code', const Color(0xFF8B5CF6),
          () => context.go(Routes.qr)),
      _QA(Icons.share_outlined, 'Share Store', WaziBotColors.warning,
          () => _share(context, ref)),
      _QA(Icons.open_in_browser_outlined, 'Website', WaziBotColors.error,
          () => context.push('/website')),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((a) => _QuickActionButton(qa: a)).toList(),
    );
  }

  static Future<void> _share(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(cachedProfileProvider).valueOrNull;
    if (profile == null) return;
    final slug = _buildSlug(profile.name);
    final storeUrl =
        'https://wazibot-api-assistant.onrender.com/store/$slug';
    await Share.share('Order from ${profile.name}:\n$storeUrl');
  }

  static String _buildSlug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+'), '')
      .replaceAll(RegExp(r'-+$'), '');
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
              color: qa.color.withValues(alpha: 0.15),
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

// ── Repeat Rate + Satisfaction row ───────────────────────────────────────────
/// Mirrors web stat-repeat-rate and stat-satisfaction elements on the overview.
class _RepeatSatisfactionRow extends ConsumerWidget {
  const _RepeatSatisfactionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repeatAsync = ref.watch(repeatCustomersProvider);
    final satAsync = ref.watch(satisfactionProvider);

    return Row(children: [
      // Repeat rate card
      Expanded(child: Card(
        child: Padding(padding: const EdgeInsets.all(14), child:
          repeatAsync.when(
            loading: () => const LoadingShimmer(height: 60),
            error: (_, __) => const SizedBox(height: 60),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.repeat_rounded, size: 13, color: WaziBotColors.primary),
                  const SizedBox(width: 5),
                  Text('REPEAT RATE', style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 6),
                Text(
                  _fmtRate(d['repeat_rate_pct']),
                  style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w700, color: WaziBotColors.primary),
                ),
                Text(
                  d['repeat_customers'] != null
                      ? '${d['repeat_customers']} of ${d['total_customers']} reordered'
                      : 'No data yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      )),
      const SizedBox(width: 10),
      // Satisfaction card
      Expanded(child: Card(
        child: Padding(padding: const EdgeInsets.all(14), child:
          satAsync.when(
            loading: () => const LoadingShimmer(height: 60),
            error: (_, __) => const SizedBox(height: 60),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.star_outline_rounded, size: 13,
                      color: WaziBotColors.warning),
                  const SizedBox(width: 5),
                  Text('SATISFACTION', style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 6),
                Text(
                  d['avg_rating'] != null
                      ? '${(d['avg_rating'] as num).toStringAsFixed(1)} / 5'
                      : '—',
                  style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w700, color: WaziBotColors.warning),
                ),
                Text(
                  (d['rated_count'] as num?)?.toInt() == 0 || d['rated_count'] == null
                      ? 'No ratings yet'
                      : '${d['rated_count']} rating${d['rated_count'] == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      )),
    ]);
  }

  static String _fmtRate(dynamic v) {
    if (v == null) return '0%';
    final n = (v as num).toDouble();
    if (n.isNaN || n.isInfinite) return '0%';
    return '${n.toStringAsFixed(0)}%';
  }
}

// ── Business Health widget ────────────────────────────────────────────────────
/// Mirrors web loadHealthWidget exactly:
/// 4 checks — WhatsApp, Products, Payment, First Order → score X/4
class _BusinessHealthWidget extends ConsumerWidget {
  const _BusinessHealthWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);
    final productsAsync = ref.watch(cachedProductsProvider);
    final ordersAsync = ref.watch(cachedOrdersProvider(null));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Business Health', style: theme.textTheme.titleMedium),
      const SizedBox(height: 10),
      profileAsync.when(
        loading: () => const LoadingShimmer(height: 160),
        error: (_, __) => const SizedBox.shrink(),
        data: (profile) {
          final products = productsAsync.valueOrNull ?? [];
          final orders = ordersAsync.valueOrNull ?? [];

          final checks = [
            _HealthCheck(
              label: 'WhatsApp Connected',
              ok: profile.contactPhone != null && profile.contactPhone!.isNotEmpty,
              guidance: 'Add your WhatsApp number in Settings → Profile.',
              route: Routes.settings,
            ),
            _HealthCheck(
              label: 'Products Added',
              ok: products.isNotEmpty,
              guidance: 'Add at least one product so customers can order.',
              route: Routes.products,
            ),
            _HealthCheck(
              label: 'Payment Method Configured',
              ok: profile.ownerEmail != null || profile.contactPhone != null,
              guidance: 'Add a payment method in Settings → Payments.',
              route: Routes.settings,
            ),
            _HealthCheck(
              label: 'First Order Received',
              ok: orders.isNotEmpty,
              guidance: 'Share your store link to get your first order.',
              route: Routes.qr,
            ),
          ];

          final score = checks.where((c) => c.ok).length;
          final allOk = score == 4;
          final scoreColor = allOk ? WaziBotColors.success : WaziBotColors.warning;

          return Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Score header
              Row(children: [
                Text('$score/4', style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.w800, color: scoreColor)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(allOk ? '✅ All systems go!' : '${4 - score} item${4 - score > 1 ? 's' : ''} need attention',
                      style: theme.textTheme.titleSmall?.copyWith(color: scoreColor)),
                  Text(allOk
                      ? 'Your AI employee is fully configured.'
                      : 'Complete these steps to go fully live.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ]),
              const SizedBox(height: 14),
              ...checks.map((c) => _HealthCheckRow(check: c, theme: theme)),
            ]),
          ));
        },
      ),
    ]);
  }
}

class _HealthCheck {
  final String label;
  final bool ok;
  final String guidance;
  final String route;
  const _HealthCheck({
    required this.label, required this.ok,
    required this.guidance, required this.route,
  });
}

class _HealthCheckRow extends StatelessWidget {
  final _HealthCheck check;
  final ThemeData theme;
  const _HealthCheckRow({required this.check, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: check.ok ? null : () => context.go(check.route),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: check.ok
                ? theme.colorScheme.surfaceContainerHighest
                : WaziBotColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: check.ok
                  ? theme.colorScheme.outline
                  : WaziBotColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(children: [
            Icon(check.ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 18,
                color: check.ok ? WaziBotColors.success : WaziBotColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: check.ok ? FontWeight.w500 : FontWeight.w700)),
                if (!check.ok)
                  Text(check.guidance, style: theme.textTheme.bodySmall?.copyWith(
                      color: WaziBotColors.warning, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            )),
            if (!check.ok)
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

// ── Growth Insights card ──────────────────────────────────────────────────────
/// Mirrors web renderGrowthCard — shows quick wins from /insights/growth
class _GrowthInsightsCard extends ConsumerWidget {
  const _GrowthInsightsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(growthInsightsProvider);

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (wins) {
        if (wins.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Growth Insights', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(child: Column(
            children: wins.take(3).map((w) {
              final isHigh = w['priority'] == 'high';
              return ListTile(
                leading: Text(isHigh ? '🔴' : '🟡',
                    style: const TextStyle(fontSize: 18)),
                title: Text(w['title'] as String? ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(w['value'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                dense: true,
              );
            }).toList(),
          )),
        ]);
      },
    );
  }
}

// ── Store link banner ─────────────────────────────────────────────────────────
/// Mirrors web showShareStoreBanner — lets owner share their store URL
/// Generated from business name slug: /store/{slug}
class _StoreLinkBanner extends ConsumerWidget {
  const _StoreLinkBanner();

  static const _baseUrl = 'https://wazibot-api-assistant.onrender.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        // Build the store slug from business name — same logic as web
        final slug = profile.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        final storeUrl = '$_baseUrl/store/$slug';

        return Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.storefront_outlined,
                  size: 18, color: WaziBotColors.primary),
              const SizedBox(width: 8),
              Text('Your Store Link', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Text(storeUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: WaziBotColors.primary,
                      fontFamily: 'monospace'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Share.share(
                  'Order from ${profile.name} on WhatsApp:\n$storeUrl',
                ),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WaziBotColors.primary,
                  side: BorderSide(
                      color: WaziBotColors.primary.withValues(alpha: 0.4)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                icon: const Icon(Icons.open_in_browser_outlined, size: 16),
                label: const Text('Open'),
              )),
            ]),
          ]),
        ));
      },
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
