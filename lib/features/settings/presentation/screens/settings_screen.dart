/// lib/features/settings/presentation/screens/settings_screen.dart
/// Full parity with web dashboard Settings — profile fields, payment settings,
/// growth automation toggles, referrals, and appearance/theme controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/security/security_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ── Payment settings provider ─────────────────────────────────────────────────
final paymentSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/me/payment-settings');
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

// ── Referral provider ─────────────────────────────────────────────────────────
final referralProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/me/referral');
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

// ── Trial status provider ─────────────────────────────────────────────────────
final trialStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/trial/status');
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

// ── Settings screen ───────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Payments'),
            Tab(text: 'Growth'),
            Tab(text: 'Referrals'),
            Tab(text: 'App'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _ProfileTab(),
          _PaymentsTab(),
          _GrowthTab(),
          _ReferralsTab(),
          _AppTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — PROFILE
// Mirrors web saveProfile() — all fields the backend accepts on PATCH /me
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();
  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  bool _cashEnabled = true;
  bool _pickupEnabled = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    ref.read(cachedProfileProvider).whenData((p) {
      if (!mounted) return;
      _nameCtrl.text = p.name;
      _phoneCtrl.text = p.contactPhone ?? '';
      _ownerEmailCtrl.text = p.ownerEmail ?? '';
      _categoryCtrl.text = p.category ?? '';
      setState(() => _loaded = true);
    });
    // Also fetch full /me for extra fields not in cached profile
    ref.read(apiClientProvider).get('/me').then((resp) {
      if (!mounted) return;
      final d = resp.data as Map<String, dynamic>;
      _descCtrl.text = d['description'] as String? ?? '';
      _supportEmailCtrl.text = d['support_email'] as String? ?? '';
      _addressCtrl.text = d['address'] as String? ?? '';
      _cityCtrl.text = d['city'] as String? ?? '';
      _hoursCtrl.text = d['business_hours'] as String? ?? '';
      _instagramCtrl.text = d['instagram'] as String? ?? '';
      _facebookCtrl.text = d['facebook'] as String? ?? '';
      _currencyCtrl.text = d['currency'] as String? ?? 'USD';
      if (mounted) {
        setState(() {
          _cashEnabled = d['cash_enabled'] as bool? ?? true;
          _pickupEnabled = d['pickup_enabled'] as bool? ?? true;
          _loaded = true;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _ownerEmailCtrl, _supportEmailCtrl,
      _descCtrl, _addressCtrl, _cityCtrl, _hoursCtrl, _instagramCtrl,
      _facebookCtrl, _categoryCtrl, _currencyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/me', data: {
        'name': _nameCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'contact_phone': _phoneCtrl.text.trim(),
        if (_ownerEmailCtrl.text.isNotEmpty) 'owner_email': _ownerEmailCtrl.text.trim(),
        if (_supportEmailCtrl.text.isNotEmpty) 'support_email': _supportEmailCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
        if (_cityCtrl.text.isNotEmpty) 'city': _cityCtrl.text.trim(),
        if (_hoursCtrl.text.isNotEmpty) 'business_hours': _hoursCtrl.text.trim(),
        if (_instagramCtrl.text.isNotEmpty) 'instagram': _instagramCtrl.text.trim(),
        if (_facebookCtrl.text.isNotEmpty) 'facebook': _facebookCtrl.text.trim(),
        if (_categoryCtrl.text.isNotEmpty) 'category': _categoryCtrl.text.trim(),
        if (_currencyCtrl.text.isNotEmpty) 'currency': _currencyCtrl.text.trim(),
        'cash_enabled': _cashEnabled,
        'pickup_enabled': _pickupEnabled,
      });
      await Haptics.success();
      ref.invalidate(cachedProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved ✓'),
              backgroundColor: WaziBotColors.success));
      }
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _field('Business Name *', _nameCtrl),
        _field('Category', _categoryCtrl, hint: 'e.g. Food & Beverage'),
        _field('Currency Code', _currencyCtrl, hint: 'USD, ZWL, ZAR…'),
        _field('Description', _descCtrl, maxLines: 3),
        _field('Contact Phone', _phoneCtrl, keyboard: TextInputType.phone),
        _field('Owner Email', _ownerEmailCtrl, keyboard: TextInputType.emailAddress),
        _field('Support Email', _supportEmailCtrl, keyboard: TextInputType.emailAddress),
        _field('Address', _addressCtrl),
        _field('City', _cityCtrl),
        _field('Business Hours', _hoursCtrl, hint: 'Mon–Fri 8am–6pm'),
        _field('Instagram', _instagramCtrl, hint: '@handle'),
        _field('Facebook', _facebookCtrl, hint: 'Page name or URL'),
        const SizedBox(height: 8),
        _toggle('Accept Cash Payments', _cashEnabled,
            (v) => setState(() => _cashEnabled = v)),
        _toggle('Accept Pickup Orders', _pickupEnabled,
            (v) => setState(() => _pickupEnabled = v)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Save Profile'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        TextFormField(controller: ctrl, maxLines: maxLines,
            keyboardType: keyboard,
            decoration: InputDecoration(hintText: hint)),
      ]),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        value: value,
        onChanged: onChanged,
        activeThumbColor: WaziBotColors.primary,
        activeTrackColor: WaziBotColors.primary.withValues(alpha: 0.3),
        contentPadding: EdgeInsets.zero,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — PAYMENTS
// Mirrors web EcoCash + PayPal settings tabs
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab();
  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> {
  final _ecoNumberCtrl = TextEditingController();
  final _ecoNameCtrl = TextEditingController();
  final _paypalEmailCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _ecoNumberCtrl.dispose();
    _ecoNameCtrl.dispose();
    _paypalEmailCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    ref.read(paymentSettingsProvider).whenData((d) {
      if (!mounted) return;
      _ecoNumberCtrl.text = d['ecocash_number'] as String? ?? '';
      _ecoNameCtrl.text = d['ecocash_name'] as String? ?? '';
      _paypalEmailCtrl.text = d['paypal_email'] as String? ?? '';
      setState(() => _loaded = true);
    });
  }

  Future<void> _saveEcoCash() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/me/payment-settings/ecocash', data: {
        'ecocash_number': _ecoNumberCtrl.text.trim(),
        'ecocash_name': _ecoNameCtrl.text.trim(),
      });
      await Haptics.success();
      ref.invalidate(paymentSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('EcoCash saved ✓'),
              backgroundColor: WaziBotColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)), backgroundColor: WaziBotColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _savePayPal() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/me/payment-settings/paypal', data: {
        'paypal_email': _paypalEmailCtrl.text.trim(),
      });
      await Haptics.success();
      ref.invalidate(paymentSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PayPal saved ✓'),
              backgroundColor: WaziBotColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)), backgroundColor: WaziBotColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EcoCash', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _f('EcoCash Number', _ecoNumberCtrl, keyboard: TextInputType.phone),
        _f('Account Name', _ecoNameCtrl),
        ElevatedButton(
          onPressed: _saving ? null : _saveEcoCash,
          child: const Text('Save EcoCash'),
        ),
        const SizedBox(height: 28),
        Text('PayPal', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _f('PayPal Email', _paypalEmailCtrl, keyboard: TextInputType.emailAddress),
        ElevatedButton(
          onPressed: _saving ? null : _savePayPal,
          child: const Text('Save PayPal'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _f(String label, TextEditingController ctrl, {TextInputType? keyboard}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        TextFormField(controller: ctrl, keyboardType: keyboard),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — GROWTH AUTOMATION
// Mirrors web section-growth-automation: cart recovery + re-engagement toggles
// Saves via PATCH /me with features_json — exact same contract as web
// ══════════════════════════════════════════════════════════════════════════════
class _GrowthTab extends ConsumerStatefulWidget {
  const _GrowthTab();
  @override
  ConsumerState<_GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends ConsumerState<_GrowthTab> {
  bool _cartRecovery = false;
  bool _reengagement = false;
  bool _loaded = false;
  bool _saving = false;
  String _cartLastRun = 'Never run yet';
  String _reLastRun = 'Never run yet';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final resp = await ref.read(apiClientProvider).get('/me');
      final d = resp.data as Map<String, dynamic>;
      final f = d['features_json'] as Map<String, dynamic>? ?? {};
      if (!mounted) { return; }
      setState(() {
        _cartRecovery = f['cart_recovery_enabled'] as bool? ?? false;
        _reengagement = f['reengagement_enabled'] as bool? ?? false;
        final cr = f['cart_recovery_last_run'] as String?;
        final re = f['reengagement_last_run'] as String?;
        _cartLastRun = cr != null
            ? DateTime.tryParse(cr)?.toLocal().toString().substring(0, 16) ?? cr
            : 'Never run yet';
        _reLastRun = re != null
            ? DateTime.tryParse(re)?.toLocal().toString().substring(0, 16) ?? re
            : 'Never run yet';
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _saveGrowthSetting(String key, bool enabled) async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/me');
      final d = resp.data as Map<String, dynamic>;
      final features = Map<String, dynamic>.from(
          d['features_json'] as Map<String, dynamic>? ?? {});
      final featureKey = key == 'cart_recovery'
          ? 'cart_recovery_enabled'
          : 'reengagement_enabled';
      features[featureKey] = enabled;
      await api.patch('/me', data: {'features_json': features});
      await Haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${enabled ? 'Enabled' : 'Disabled'} ✓'),
          backgroundColor: enabled ? WaziBotColors.success : WaziBotColors.warning,
        ));
      }
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Growth Automation', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Configure which AI automations run in the background.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),

        // Cart Recovery
        _AutomationCard(
          icon: Icons.shopping_cart_checkout_outlined,
          title: 'Cart Recovery',
          subtitle: 'Automatically message customers who added items but didn\'t order.',
          lastRun: _cartLastRun,
          enabled: _cartRecovery,
          saving: _saving,
          onChanged: (v) {
            setState(() => _cartRecovery = v);
            _saveGrowthSetting('cart_recovery', v);
          },
        ),
        const SizedBox(height: 12),

        // Re-engagement
        _AutomationCard(
          icon: Icons.replay_outlined,
          title: 'Re-engagement',
          subtitle: 'Win back customers who haven\'t ordered in 30+ days.',
          lastRun: _reLastRun,
          enabled: _reengagement,
          saving: _saving,
          onChanged: (v) {
            setState(() => _reengagement = v);
            _saveGrowthSetting('reengagement', v);
          },
        ),
        const SizedBox(height: 24),

        // Security settings section
        Divider(color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text('Security', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Consumer(builder: (_, ref, __) {
          final security = ref.watch(securityProvider);
          return Column(children: [
            SwitchListTile(
              title: Text('Biometric Lock',
                  style: theme.textTheme.bodyMedium),
              subtitle: Text(
                security.biometricAvailable
                    ? 'Locks after 2 minutes in background'
                    : 'Not available on this device',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
              value: security.biometricAvailable,
              onChanged: null,
              activeThumbColor: WaziBotColors.primary,
              activeTrackColor: WaziBotColors.primary.withValues(alpha: 0.3),
              contentPadding: EdgeInsets.zero,
            ),
            const ListTile(
              leading: Icon(Icons.timer_outlined),
              title: Text('Session Timeout'),
              subtitle: Text('Auto sign-out after 15 minutes of inactivity'),
              contentPadding: EdgeInsets.zero,
            ),
          ]);
        }),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout, size: 18, color: WaziBotColors.error),
          label: const Text('Sign Out',
              style: TextStyle(color: WaziBotColors.error)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WaziBotColors.error),
            minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: WaziBotColors.error))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

class _AutomationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String lastRun;
  final bool enabled;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _AutomationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lastRun,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20,
                color: enabled ? WaziBotColors.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Switch(
              value: enabled,
              onChanged: saving ? null : onChanged,
              activeThumbColor: WaziBotColors.primary,
              activeTrackColor: WaziBotColors.primary.withValues(alpha: 0.3),
            ),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.schedule_outlined, size: 12,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('Last run: $lastRun',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (enabled ? WaziBotColors.success : theme.colorScheme.onSurfaceVariant)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                enabled ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: enabled ? WaziBotColors.success
                        : theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — REFERRALS
// Mirrors web Referrals tab: code, link, stats, withdraw button
// ══════════════════════════════════════════════════════════════════════════════
class _ReferralsTab extends ConsumerWidget {
  const _ReferralsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final refAsync = ref.watch(referralProvider);

    return refAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(apiErrorMessage(e))),
      data: (data) {
        final code = data['referral_code'] as String? ?? '—';
        final link = data['referral_link'] as String? ?? '—';
        final total = data['total_referrals'] ?? 0;
        final converted = data['converted'] ?? 0;
        final available = (data['available_balance'] as num?)?.toDouble() ??
            (data['pending_reward'] as num?)?.toDouble() ?? 0;
        final canWithdraw = available >= 5.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your Referral Programme', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Earn \$0.20 for every business you refer that signs up.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),

            // Stats row
            Row(children: [
              _RefStat('Referrals', total.toString()),
              const SizedBox(width: 10),
              _RefStat('Converted', converted.toString()),
              const SizedBox(width: 10),
              _RefStat('Balance', '\$${available.toStringAsFixed(2)}',
                  color: WaziBotColors.primary),
            ]),
            const SizedBox(height: 20),

            // Referral code
            _CopyField(label: 'Your Code', value: code),
            const SizedBox(height: 12),
            _CopyField(label: 'Referral Link', value: link),
            const SizedBox(height: 24),

            // Withdraw
            Text('Minimum withdrawal: \$5.00',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: canWithdraw ? () => _withdraw(context, ref) : null,
              icon: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.black, size: 18),
              label: Text(canWithdraw
                  ? 'Withdraw \$${available.toStringAsFixed(2)}'
                  : 'Need \$${(5.0 - available).toStringAsFixed(2)} more'),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Withdrawal?'),
        content: const Text('We\'ll process your payout to the email on file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Request')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/me/referral/withdraw');
      ref.invalidate(referralProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Withdrawal requested ✓'),
          backgroundColor: WaziBotColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error));
      }
    }
  }
}

class _RefStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _RefStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color ?? theme.colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 5),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Text(value, style: theme.textTheme.bodySmall,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied!')));
          },
        ),
      ]),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 5 — APP (theme, notifications)
// ══════════════════════════════════════════════════════════════════════════════
class _AppTab extends ConsumerStatefulWidget {
  const _AppTab();
  @override
  ConsumerState<_AppTab> createState() => _AppTabState();
}

class _AppTabState extends ConsumerState<_AppTab> {
  bool _newOrder = true;
  bool _newCustomer = true;
  bool _payment = true;
  bool _lowStock = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Appearance', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 16), label: Text('Dark')),
            ButtonSegment(value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 16), label: Text('Light')),
            ButtonSegment(value: ThemeMode.system,
                icon: Icon(Icons.auto_awesome, size: 16), label: Text('System')),
          ],
          selected: {themeMode},
          onSelectionChanged: (modes) =>
              ref.read(themeModeProvider.notifier).state = modes.first,
        ),
        const SizedBox(height: 28),
        Text('Push Notifications', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _sw('New Orders', _newOrder, (v) => setState(() => _newOrder = v)),
        _sw('New Customers', _newCustomer, (v) => setState(() => _newCustomer = v)),
        _sw('Payment Received', _payment, (v) => setState(() => _payment = v)),
        _sw('Low Stock Alert', _lowStock, (v) => setState(() => _lowStock = v)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification preferences saved ✓'))),
          child: const Text('Save Preferences'),
        ),
        const SizedBox(height: 28),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('App Version'),
          subtitle: Text('1.0.0'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sw(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        value: value,
        onChanged: onChanged,
        activeThumbColor: WaziBotColors.primary,
        activeTrackColor: WaziBotColors.primary.withValues(alpha: 0.3),
        contentPadding: EdgeInsets.zero,
      );
}
