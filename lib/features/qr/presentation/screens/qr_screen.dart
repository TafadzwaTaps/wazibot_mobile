/// lib/features/qr/presentation/screens/qr_screen.dart
///
/// Matches the Expo QR Code screen:
///  - Large QR code with business name + tagline
///  - Store URL card with Copy URL + Share buttons
///  - WhatsApp Keyword card with Copy keyword
///  - Print tip at bottom
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/cached_providers.dart';

class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});

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
      appBar: AppBar(title: const Text('QR Code')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (profile) {
          final slug = _slug(profile.name);
          final storeUrl = '$_base/store/$slug';
          final keyword =
              'START ${profile.name.toUpperCase().replaceAll(' ', '-')}';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 20),

              // Header
              Text(profile.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Share your store with customers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),

              // QR code — white background card, teal modules (matches Expo)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: WaziBotColors.primary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: storeUrl,
                  version: QrVersions.auto,
                  size: 240,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1a8f6f), // teal — matches Expo
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1a8f6f),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Store URL card
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Store URL', style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(storeUrl,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: WaziBotColors.primary),
                      maxLines: 2),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: storeUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied!')));
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy URL'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WaziBotColors.primary,
                        side: BorderSide(
                            color: WaziBotColors.primary.withValues(alpha: 0.4)),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => Share.share(
                          'Order from ${profile.name}:\n$storeUrl'),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WaziBotColors.primary,
                        side: BorderSide(
                            color: WaziBotColors.primary.withValues(alpha: 0.4)),
                      ),
                    )),
                  ]),
                ]),
              )),
              const SizedBox(height: 12),

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
                  const SizedBox(height: 4),
                  Text('Customers send this to start a chat',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: keyword));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Keyword copied!')));
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy keyword'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WaziBotColors.primary,
                        side: BorderSide(
                            color: WaziBotColors.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ]),
              )),
              const SizedBox(height: 12),

              // Print tip
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.qr_code_scanner_outlined,
                      size: 18, color: WaziBotColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Print & place on your counter, receipts, and packaging to get customers scanning.',
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
