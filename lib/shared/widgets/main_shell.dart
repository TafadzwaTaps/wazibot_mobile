/// lib/shared/widgets/main_shell.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/cached_providers.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home,
        label: 'Home', path: '/home'),
    _Tab(icon: Icons.inbox_outlined, activeIcon: Icons.inbox,
        label: 'Inbox', path: '/inbox'),
    _Tab(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long,
        label: 'Orders', path: '/orders'),
    _Tab(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart,
        label: 'Analytics', path: '/analytics'),
    _Tab(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view,
        label: 'More', path: '/more'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentIndex = _currentIndex(context);

    // Unread conversations count for Inbox badge
    final conversations = ref.watch(cachedConversationsProvider(null));
    final unreadCount = conversations.valueOrNull
        ?.where((c) => c.hasUnread).length ?? 0;

    // Payment reminders count for Home badge  
    final reminders = ref.watch(paymentRemindersProvider);
    final remCount = (reminders.valueOrNull?['count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(
              color: theme.colorScheme.outline, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          destinations: [
            // Home — badge when reminders pending
            NavigationDestination(
              icon: Badge(
                isLabelVisible: remCount > 0,
                label: Text('$remCount'),
                backgroundColor: WaziBotColors.warning,
                child: const Icon(Icons.home_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: remCount > 0,
                label: Text('$remCount'),
                backgroundColor: WaziBotColors.warning,
                child: const Icon(Icons.home),
              ),
              label: 'Home',
            ),
            // Inbox — badge for unread conversations
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.inbox),
              ),
              label: 'Inbox',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'More',
            ),
          ],
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
