/// lib/core/router/app_router.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/inbox/presentation/screens/conversation_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/qr/presentation/screens/qr_screen.dart';
import '../../features/website/presentation/screens/website_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/customers/presentation/screens/customer_profile_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/crm/presentation/screens/crm_screen.dart';
import '../auth/auth_service.dart';
import '../../shared/providers/cached_providers.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const inbox = '/inbox';
  static const orders = '/orders';
  static const analytics = '/analytics';
  static const more = '/more';
  static const products = '/more/products';
  static const addProduct = '/more/products/add';
  static const qr = '/more/qr';
  static const settings = '/more/settings';
  static const scanner = '/scanner';
  static const customerProfile = '/customer/:phone';
  static const reminders = '/reminders';
  static const website = '/website';
  static const crm = '/crm';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authData = authState.valueOrNull;
      if (authState.isLoading) return null;
      final isAuthenticated = authData?.status == AuthStatus.authenticated;
      final isOnAuth = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.splash;
      if (!isAuthenticated && !isOnAuth) return Routes.login;
      if (isAuthenticated && isOnAuth) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),

      // Full-screen routes outside the shell
      GoRoute(path: Routes.scanner,
        builder: (_, __) => ScannerScreen(onScanned: (_) {})),
      GoRoute(path: '/customer/:phone',
        builder: (_, state) => CustomerProfileScreen(
            phone: state.pathParameters['phone']!)),
      GoRoute(path: Routes.reminders,
        builder: (_, __) => const RemindersScreen()),
      GoRoute(path: Routes.website,
        builder: (_, __) => const WebsiteScreen()),
      GoRoute(path: '/website',
        builder: (_, __) => const WebsiteScreen()),
      GoRoute(path: Routes.crm,
        builder: (_, __) => const CrmScreen()),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: Routes.inbox,
            builder: (_, __) => const InboxScreen(),
            routes: [
              GoRoute(
                path: ':phone',
                builder: (_, state) => ConversationScreen(
                    phone: state.pathParameters['phone']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.orders,
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailScreen(
                    orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: Routes.analytics,
              builder: (_, __) => const AnalyticsScreen()),
          GoRoute(
            path: Routes.more,
            builder: (_, __) => const _MoreScreen(),
            routes: [
              GoRoute(
                path: 'products',
                builder: (_, __) => const ProductsScreen(),
                routes: [
                  GoRoute(path: 'add',
                      builder: (_, __) => const AddProductScreen()),
                ],
              ),
              GoRoute(path: 'qr', builder: (_, __) => const QrScreen()),
              GoRoute(path: 'settings',
                  builder: (_, __) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

// ── More screen — matches Expo grouped section layout ─────────────────────────
class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);
    final remAsync = ref.watch(paymentRemindersProvider);
    final remCount = (remAsync.valueOrNull?['count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Profile card (avatar with initial + alerts badge) ───────────
          profileAsync.when(
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox.shrink(),
            data: (p) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Avatar with initial
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: WaziBotColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : 'B',
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('@${p.username}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  )),
                  // Alerts badge when reminders pending
                  if (remCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: WaziBotColors.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$remCount alert${remCount == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── BUSINESS section ────────────────────────────────────────────
          _SectionLabel('BUSINESS'),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            _MoreTile(icon: Icons.inventory_2_outlined, iconColor: WaziBotColors.primary,
                title: 'Products', subtitle: 'Manage your product catalogue',
                onTap: () => context.go(Routes.products)),
            _divider(),
            _MoreTile(icon: Icons.people_outline_rounded, iconColor: const Color(0xFF8B5CF6),
                title: 'Customers', subtitle: 'CRM — segments, spend, activity',
                onTap: () => context.push(Routes.crm)),
            _divider(),
            _MoreTile(icon: Icons.schedule_outlined, iconColor: WaziBotColors.warning,
                title: 'Reminders', subtitle: 'Pending payment reminders',
                badge: remCount > 0 ? '$remCount' : null,
                onTap: () => context.push(Routes.reminders)),
            _divider(),
            _MoreTile(icon: Icons.person_off_outlined, iconColor: WaziBotColors.error,
                title: 'Handoff', subtitle: 'Conversations waiting for you',
                onTap: () => context.go(Routes.inbox)),
          ])),
          const SizedBox(height: 20),

          // ── MARKETING section ───────────────────────────────────────────
          _SectionLabel('MARKETING'),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            _MoreTile(icon: Icons.trending_up_rounded, iconColor: WaziBotColors.success,
                title: 'Growth', subtitle: 'Automation, insights, re-engagement',
                onTap: () => context.go(Routes.settings)),
            _divider(),
            _MoreTile(icon: Icons.campaign_outlined, iconColor: WaziBotColors.primary,
                title: 'Campaigns', subtitle: 'Send bulk messages to customers',
                onTap: () => _showWebOnly(context, 'Campaign Builder')),
            _divider(),
            _MoreTile(icon: Icons.qr_code_2, iconColor: const Color(0xFF8B5CF6),
                title: 'QR Code', subtitle: 'Generate & share your store QR',
                onTap: () => context.go(Routes.qr)),
            _divider(),
            _MoreTile(icon: Icons.language_rounded, iconColor: WaziBotColors.warning,
                title: 'Website', subtitle: 'View your online store',
                onTap: () => context.push('/website')),
          ])),
          const SizedBox(height: 20),

          // ── ACCOUNT section ─────────────────────────────────────────────
          _SectionLabel('ACCOUNT'),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            _MoreTile(icon: Icons.settings_outlined, iconColor: WaziBotColors.primary,
                title: 'Settings', subtitle: 'Business profile & preferences',
                onTap: () => context.go(Routes.settings)),
          ])),
          const SizedBox(height: 20),

          // ── Sign out button ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: WaziBotColors.error),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _confirmLogout(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.logout_rounded,
                        color: WaziBotColors.error, size: 20),
                    const SizedBox(width: 8),
                    const Text('Sign Out', style: TextStyle(
                        color: WaziBotColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('WaziBot Mobile v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 0, indent: 62,
      color: Colors.white.withValues(alpha: 0.05));

  void _showWebOnly(BuildContext context, String feature) {
    showModalBottomSheet(context: context, builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.computer_outlined, size: 40, color: WaziBotColors.primary),
        const SizedBox(height: 12),
        Text('$feature is available on desktop',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Visit wazibot-api-assistant.onrender.com on your browser.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
      ]),
    ));
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You will need to sign in again.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: WaziBotColors.error))),
      ],
    ));
    if (ok == true && context.mounted) {
      ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    this.badge, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: theme.textTheme.bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: badge != null
          ? Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: WaziBotColors.warning,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(badge!,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700))),
            )
          : Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

// ── Auth state listenable ─────────────────────────────────────────────────────
class _AuthStateListenable extends ChangeNotifier {
  final Ref _ref;
  _AuthStateListenable(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}
