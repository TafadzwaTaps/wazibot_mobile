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
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/customers/presentation/screens/customer_profile_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/crm/presentation/screens/crm_screen.dart';
import '../auth/auth_service.dart';

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

// ── More screen ───────────────────────────────────────────────────────────────
class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tiles = [
      _MoreTile(Icons.inventory_2_outlined, 'Products',
          'Manage your catalogue', () => context.go(Routes.products)),
      _MoreTile(Icons.people_outline, 'Customers (CRM)',
          'Segments, profiles, history', () => context.push(Routes.crm)),
      _MoreTile(Icons.schedule_outlined, 'Payment Reminders',
          'Chase unpaid orders', () => context.push(Routes.reminders)),
      _MoreTile(Icons.qr_code_2, 'Marketing QR',
          'Share your store link', () => context.go(Routes.qr)),
      _MoreTile(Icons.settings_outlined, 'Settings',
          'Profile, payments, growth', () => context.go(Routes.settings)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: tiles.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: WaziBotColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(t.icon, color: WaziBotColors.primary, size: 20)),
              title: Text(t.title, style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(t.sub, style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
              onTap: t.action,
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _MoreTile {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback action;
  const _MoreTile(this.icon, this.title, this.sub, this.action);
}

// ── Auth state listenable ─────────────────────────────────────────────────────
class _AuthStateListenable extends ChangeNotifier {
  final Ref _ref;
  _AuthStateListenable(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}
