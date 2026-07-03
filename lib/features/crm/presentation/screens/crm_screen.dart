/// lib/features/crm/presentation/screens/crm_screen.dart
/// Full parity with web section-crm: segment cards, customer table, drawer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

// ── CRM data provider (mirrors web loadCrm: /crm/segments + /crm/segments/all) ─
final crmSegmentCountsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/crm/segments');
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return {'vip': 0, 'loyal': 0, 'new': 0, 'total': 0};
  }
});

final crmAllCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/crm/segments/all');
    final list = resp.data as List? ?? [];
    return list.whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return [];
  }
});

final crmInactiveCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/crm/inactive?days=30');
    final list = resp.data as List? ?? [];
    return list.length;
  } catch (_) {
    return 0;
  }
});

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segAsync = ref.watch(crmSegmentCountsProvider);
    final customersAsync = ref.watch(crmAllCustomersProvider);
    final inactiveAsync = ref.watch(crmInactiveCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              ref.invalidate(crmSegmentCountsProvider);
              ref.invalidate(crmAllCustomersProvider);
              ref.invalidate(crmInactiveCountProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          await Haptics.refresh();
          ref.invalidate(crmSegmentCountsProvider);
          ref.invalidate(crmAllCustomersProvider);
          ref.invalidate(crmInactiveCountProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Segment count cards (mirrors web crm-count-vip/loyal/new/inactive)
            segAsync.when(
              loading: () => const _GridShimmer(),
              error: (_, __) => const SizedBox.shrink(),
              data: (seg) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
                children: [
                  _SegCard('VIP', seg['vip'] ?? 0, WaziBotColors.warning,
                      Icons.star_rounded, 'High value customers'),
                  _SegCard('Loyal', seg['loyal'] ?? 0, WaziBotColors.primary,
                      Icons.favorite_rounded, 'Regular buyers'),
                  _SegCard('New', seg['new'] ?? 0, WaziBotColors.success,
                      Icons.person_add_outlined, 'First-time customers'),
                  inactiveAsync.when(
                    loading: () => const _SegCard('Inactive', 0, WaziBotColors.error,
                        Icons.person_off_outlined, 'No orders in 30d'),
                    error: (_, __) => const _SegCard('Inactive', 0, WaziBotColors.error,
                        Icons.person_off_outlined, 'No orders in 30d'),
                    data: (count) => _SegCard('Inactive', count, WaziBotColors.error,
                        Icons.person_off_outlined, 'No orders in 30d'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Customer table (mirrors web crm-table-body)
            Text('All Customers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            customersAsync.when(
              loading: () => const ShimmerList(count: 5, itemHeight: 70),
              error: (e, _) => Center(child: Text(apiErrorMessage(e))),
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(
                    child: Padding(padding: EdgeInsets.all(32),
                      child: Text('No customers yet — start chatting on WhatsApp!')));
                }
                return Column(
                  children: customers
                      .map((c) => _CustomerTile(customer: c))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GridShimmer extends StatelessWidget {
  const _GridShimmer();
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.0,
    children: List.generate(4, (_) => const LoadingShimmer(height: 70)),
  );
}

class _SegCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String sub;
  const _SegCard(this.label, this.count, this.color, this.icon, this.sub);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 4),
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: color)),
        Text(sub, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant, fontSize: 9),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

// ── Customer tile with drawer ─────────────────────────────────────────────────
class _CustomerTile extends ConsumerStatefulWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  ConsumerState<_CustomerTile> createState() => _CustomerTileState();
}

class _CustomerTileState extends ConsumerState<_CustomerTile> {
  final _nameCtrl = TextEditingController();
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.customer.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _segLabel(Customer c) {
    if (c.orderCount > 5 && c.totalSpent > 100) return 'VIP';
    if (c.orderCount > 2) return 'Loyal';
    if (c.orderCount == 1) return 'New';
    if (c.orderCount == 0) return 'Prospect';
    return 'Regular';
  }

  Color _segColor(String seg) => switch (seg) {
    'VIP' => WaziBotColors.warning,
    'Loyal' => WaziBotColors.primary,
    'New' => WaziBotColors.success,
    _ => WaziBotColors.info,
  };

  void _openDrawer() {
    final seg = _segLabel(widget.customer);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(radius: 22,
                backgroundColor: WaziBotColors.primary.withValues(alpha: 0.15),
                child: Text((widget.customer.name ?? widget.customer.phone)[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18, color: WaziBotColors.primary,
                        fontWeight: FontWeight.w700))),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.customer.name ?? widget.customer.phone,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(widget.customer.phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _dStat('Orders', widget.customer.orderCount.toString()),
              const SizedBox(width: 10),
              _dStat('Spent', currency.format(widget.customer.totalSpent)),
              const SizedBox(width: 10),
              _dStat('Segment', seg,
                  color: _segColor(seg)),
            ]),
            const SizedBox(height: 16),
            // Edit name
            Text('Display Name', style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextFormField(controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Customer name'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _savingName ? null : () async {
                  setState(() => _savingName = true);
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.patch(
                      '/crm/customers/${Uri.encodeComponent(widget.customer.phone)}/name',
                      data: {'customer_name': _nameCtrl.text.trim()},
                    );
                    ref.invalidate(crmAllCustomersProvider);
                    if (mounted) {
                      if (context.mounted) Navigator.pop(context);
                    }
                  } catch (_) {}
                  setState(() => _savingName = false);
                },
                child: const Text('Save'),
              ),
            ]),
            const SizedBox(height: 20),
            // Open in inbox
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/inbox/${widget.customer.phone}');
              },
              icon: const Icon(Icons.chat_outlined, size: 16),
              label: const Text('Open Conversation'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dStat(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: color ?? theme.colorScheme.onSurface)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seg = _segLabel(widget.customer);
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: WaziBotColors.primary.withValues(alpha: 0.15),
          child: Text(
            (widget.customer.name ?? widget.customer.phone).isNotEmpty
                ? (widget.customer.name ?? widget.customer.phone)[0].toUpperCase()
                : '?',
            style: const TextStyle(color: WaziBotColors.primary,
                fontWeight: FontWeight.w700)),
        ),
        title: Text(widget.customer.name ?? widget.customer.phone,
            style: theme.textTheme.bodyMedium),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _segColor(seg).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4)),
            child: Text(seg, style: TextStyle(fontSize: 9,
                color: _segColor(seg), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Text('${widget.customer.orderCount} orders',
              style: theme.textTheme.bodySmall),
        ]),
        trailing: Text(currency.format(widget.customer.totalSpent),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: WaziBotColors.primary)),
        onTap: () { Haptics.light(); _openDrawer(); },
      ),
    );
  }
}
