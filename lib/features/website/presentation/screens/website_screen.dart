/// lib/features/website/presentation/screens/website_screen.dart
///
/// Matches the Expo "Website" screen exactly:
///  - Store URL display
///  - 4 action buttons: Open Store, Copy URL, Share, WhatsApp Link
///  - WhatsApp keyword card
///  - "Edit design on desktop" note
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/cached_providers.dart';

class WebsiteScreen extends ConsumerWidget {
  const WebsiteScreen({super.key});

  static const _base = 'https://wazibot-api-assistant.onrender.com';

  static String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+'), '')
      .replaceAll(RegExp(r'-+$'), '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Website')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (profile) {
          final slug = _slug(profile.name);
          final storeUrl = '$_base/store/$slug';
          final keyword = 'START ${profile.name.toUpperCase().replaceAll(' ', '-')}';
          final waUrl = 'https://wa.me/447774128484?text=${Uri.encodeComponent(keyword)}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 16),

              // Globe icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: WaziBotColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.language_rounded,
                    color: WaziBotColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(profile.name, style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Your WhatsApp store',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 28),

              // Store URL card
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Store URL', style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(storeUrl,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: WaziBotColors.primary)),
                ]),
              )),
              const SizedBox(height: 14),

              // 4 action buttons (2×2 grid — matches Expo screenshot)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _ActionTile(
                    icon: Icons.open_in_new_rounded,
                    label: 'Open Store',
                    color: WaziBotColors.primary,
                    onTap: () async {
                      final uri = Uri.parse(storeUrl);
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  _ActionTile(
                    icon: Icons.copy_rounded,
                    label: 'Copy URL',
                    color: WaziBotColors.info,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: storeUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied!')));
                    },
                  ),
                  _ActionTile(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => Share.share(
                        'Order from ${profile.name}:\n$storeUrl'),
                  ),
                  _ActionTile(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp Link',
                    color: WaziBotColors.success,
                    onTap: () async {
                      final uri = Uri.parse(waUrl);
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // WhatsApp Keyword card
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WhatsApp Keyword',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(keyword,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: WaziBotColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: keyword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Keyword copied!')));
                    },
                    child: Row(children: [
                      const Icon(Icons.copy_outlined,
                          size: 14, color: WaziBotColors.primary),
                      const SizedBox(width: 4),
                      Text('Copy keyword',
                          style: TextStyle(
                              fontSize: 13,
                              color: WaziBotColors.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              )),
              const SizedBox(height: 14),

              // Tip card
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'To edit your website design, visit WaziBot on desktop.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: WaziBotColors.primary),
                  )),
                ]),
              )),
              const SizedBox(height: 32),
            ]),
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
