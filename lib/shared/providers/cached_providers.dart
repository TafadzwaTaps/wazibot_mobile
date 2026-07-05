/// lib/shared/providers/cached_providers.dart
///
/// Data providers for every screen.
/// All reads go through the CacheService (SWR pattern).
/// All writes go through SyncEngine.enqueueWrite for offline support.
///
/// Field mapping is done here using the backend-accurate models
/// in business_models.dart.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_models.dart';
import '../../core/api/api_client.dart';
import '../../core/cache/cache_service.dart';
import '../../core/connectivity/connectivity_service.dart';

// ── Business profile ──────────────────────────────────────────────────────────
final cachedProfileProvider = FutureProvider<BusinessProfile>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);

  if (!isOnline) {
    final stale = cache.getStale(CacheService.kProfile);
    if (stale != null) {
      return BusinessProfile.fromJson(
          Map<String, dynamic>.from(stale as Map));
    }
    throw Exception('Offline — no cached profile');
  }

  try {
    final resp = await api.get('/me');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(CacheService.kProfile, data, ttl: CacheService.ttlLong);
    return BusinessProfile.fromJson(data);
  } catch (e) {
    final stale = cache.getStale(CacheService.kProfile);
    if (stale != null) {
      return BusinessProfile.fromJson(
          Map<String, dynamic>.from(stale as Map));
    }
    rethrow;
  }
});

// ── Analytics stats ───────────────────────────────────────────────────────────
final cachedAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);

  if (!isOnline) {
    final stale = cache.getStale(CacheService.kAnalytics);
    if (stale != null) return Map<String, dynamic>.from(stale as Map);
    return _emptyStats();
  }

  try {
    final resp = await api.get('/analytics/stats');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(CacheService.kAnalytics, data,
        ttl: CacheService.ttlShort);
    return data;
  } catch (e) {
    final stale = cache.getStale(CacheService.kAnalytics);
    if (stale != null) return Map<String, dynamic>.from(stale as Map);
    return _emptyStats();
  }
});

Map<String, dynamic> _emptyStats() => const {
      'total_orders': 0,
      'paid_orders': 0,
      'total_revenue': 0.0,
      'pending_orders': 0,
      'active_customers': 0,
      'ai_handled': 0,
      'human_handled': 0,
    };

// ── Orders ────────────────────────────────────────────────────────────────────
final cachedOrdersProvider =
    FutureProvider.family<List<Order>, String?>((ref, status) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);
  final cacheKey = '${CacheService.kOrders}_${status ?? 'all'}';

  if (!isOnline) {
    final stale = cache.getStale(cacheKey) ??
        cache.getStale(CacheService.kOrders);
    if (stale != null) return _parseOrders(stale, status);
    return [];
  }

  try {
    final params = <String, dynamic>{};
    if (status != null && status != 'all') params['status'] = status;
    final resp = await api.get('/orders', params: params);
    final list = resp.data is List
        ? resp.data as List
        : (resp.data['orders'] as List? ?? []);
    await cache.set(cacheKey, list, ttl: CacheService.ttlShort);
    return _parseOrders(list, null); // already filtered by server
  } catch (e) {
    final stale = cache.getStale(cacheKey) ??
        cache.getStale(CacheService.kOrders);
    if (stale != null) return _parseOrders(stale, status);
    rethrow;
  }
});

List<Order> _parseOrders(dynamic raw, String? filterStatus) {
  if (raw is! List) return [];
  final orders = raw
      .whereType<Map>()
      .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  if (filterStatus == null || filterStatus == 'all') return orders;
  // Client-side filter when using full cached list as fallback
  return orders
      .where((o) => o.status == filterStatus || o.rawStatus == filterStatus)
      .toList();
}

// ── Single order ──────────────────────────────────────────────────────────────
final orderDetailProvider =
    FutureProvider.family<Order, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);

  try {
    // Try dedicated endpoint first
    final resp = await api.get('/orders/$id');
    if (resp.data is Map) {
      return Order.fromJson(resp.data as Map<String, dynamic>);
    }
  } catch (_) {}

  // Fallback: find in cached full list
  final cache = ref.read(cacheServiceProvider);
  final stale = cache.getStale(CacheService.kOrders);
  if (stale is List) {
    final found = stale.whereType<Map>().firstWhere(
      (e) => e['id']?.toString() == id,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      return Order.fromJson(Map<String, dynamic>.from(found));
    }
  }

  // Last resort: fetch all orders
  final resp = await api.get('/orders');
  final list = resp.data is List
      ? resp.data as List
      : (resp.data['orders'] as List? ?? []);
  final found = list.whereType<Map>().firstWhere(
    (e) => e['id']?.toString() == id,
    orElse: () => throw Exception('Order $id not found'),
  );
  return Order.fromJson(Map<String, dynamic>.from(found));
});

// ── Products ──────────────────────────────────────────────────────────────────
final cachedProductsProvider =
    FutureProvider<List<Product>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);

  if (!isOnline) {
    final stale = cache.getStale(CacheService.kProducts);
    if (stale != null) return _parseProducts(stale);
    return [];
  }

  try {
    final resp = await api.get('/products');
    final list = resp.data as List? ?? [];
    await cache.set(CacheService.kProducts, list,
        ttl: CacheService.ttlMedium);
    return _parseProducts(list);
  } catch (e) {
    final stale = cache.getStale(CacheService.kProducts);
    if (stale != null) return _parseProducts(stale);
    rethrow;
  }
});

List<Product> _parseProducts(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

// ── Conversations ─────────────────────────────────────────────────────────────
final cachedConversationsProvider =
    FutureProvider.family<List<Conversation>, String?>((ref, search) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);

  if (!isOnline && search == null) {
    final stale = cache.getStale(CacheService.kConversations);
    if (stale != null) return _parseConversations(stale);
    return [];
  }

  try {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final resp = await api.get('/chat/conversations', params: params);
    final list = resp.data as List? ?? [];
    if (search == null) {
      await cache.set(CacheService.kConversations, list,
          ttl: CacheService.ttlShort);
    }
    return _parseConversations(list);
  } catch (e) {
    if (search == null) {
      final stale = cache.getStale(CacheService.kConversations);
      if (stale != null) return _parseConversations(stale);
    }
    rethrow;
  }
});

List<Conversation> _parseConversations(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

// ── Messages for a conversation ───────────────────────────────────────────────
final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, phone) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  final cacheKey = 'messages_$phone';

  // Get customer_id from conversation
  String customerId = phone;
  try {
    final convResp = await api.get('/chat/conversations/$phone');
    final data = convResp.data;
    if (data is Map) {
      customerId = data['customer_id']?.toString() ?? phone;

      // Try messages from conversation response first
      final msgs = data['messages'];
      if (msgs is List && msgs.isNotEmpty) {
        final parsed = _parseMessages(msgs);
        await cache.set(cacheKey, msgs, ttl: CacheService.ttlShort);
        return parsed;
      }
    }
  } catch (_) {}

  // Fetch messages by customer_id
  try {
    final resp = await api.get('/chat/messages/$customerId');
    final list = resp.data as List? ?? [];
    await cache.set(cacheKey, list, ttl: CacheService.ttlShort);

    // Mark as read
    try {
      await api.post('/chat/read/$customerId');
    } catch (_) {}

    return _parseMessages(list);
  } catch (e) {
    final stale = cache.getStale(cacheKey);
    if (stale != null) return _parseMessages(stale);
    rethrow;
  }
});

List<Message> _parseMessages(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

// ── Customers (CRM) ───────────────────────────────────────────────────────────
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const cacheKey = 'crm_customers';

  try {
    // Use CRM segments endpoint which has richer data
    final resp = await api.get('/crm/segments/all');
    final list = resp.data as List? ?? [];
    await cache.set(cacheKey, list, ttl: CacheService.ttlMedium);
    return list
        .whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    // Fallback to basic customers list
    try {
      final resp = await api.get('/chat/customers');
      final list = resp.data as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      final stale = cache.getStale(cacheKey);
      if (stale is List) {
        return stale
            .whereType<Map>()
            .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      rethrow;
    }
  }
});

// ── Low stock ────────────────────────────────────────────────────────────────
final lowStockProductsProvider =
    FutureProvider<List<LowStockProduct>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const cacheKey = 'low_stock';

  try {
    final resp = await api.get('/analytics/low-stock');
    final list = resp.data as List? ?? [];
    await cache.set(cacheKey, list, ttl: CacheService.ttlMedium);
    return list
        .whereType<Map>()
        .map((e) => LowStockProduct.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    final stale = cache.getStale(cacheKey);
    if (stale is List) {
      return stale
          .whereType<Map>()
          .map((e) => LowStockProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
});

// ── Top customers ─────────────────────────────────────────────────────────────
final topCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const cacheKey = 'top_customers';

  try {
    final resp = await api.get('/analytics/top-customers');
    final list = resp.data as List? ?? [];
    await cache.set(cacheKey, list, ttl: CacheService.ttlMedium);
    return list
        .whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    final stale = cache.getStale(cacheKey);
    if (stale is List) {
      return stale
          .whereType<Map>()
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
});

// ── Cache age helper ─────────────────────────────────────────────────────────
final cacheAgeProvider = Provider.family<String?, String>((ref, key) {
  final cache = ref.watch(cacheServiceProvider);
  final age = cache.age(key);
  if (age == null) return null;
  if (age.inSeconds < 30) return 'Just synced';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
});

// ── Overview extras (mirrors web dashboard loadOverviewExtras) ────────────────

/// GET /analytics/acquisition → funnel: qr_scans, whatsapp_clicks,
/// conversations_started, orders, conversion_rate, today{...}, this_month{...}
final acquisitionProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'acquisition';
  try {
    final resp = await api.get('/analytics/acquisition');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlShort);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {
      'qr_scans': 0, 'whatsapp_clicks': 0,
      'conversations_started': 0, 'orders': 0,
      'conversion_rate': 0,
      'today': {'qr_scans': 0, 'whatsapp_clicks': 0, 'conversations_started': 0},
    };
  }
});

/// GET /analytics/repeat-customers → {total_customers, repeat_customers, repeat_rate_pct}
final repeatCustomersProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'repeat_customers';
  try {
    final resp = await api.get('/analytics/repeat-customers');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlMedium);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {'total_customers': 0, 'repeat_customers': 0, 'repeat_rate_pct': 0.0};
  }
});

/// GET /analytics/satisfaction → {avg_rating, rated_count, total_customers}
final satisfactionProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'satisfaction';
  try {
    final resp = await api.get('/analytics/satisfaction');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlMedium);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {'avg_rating': null, 'rated_count': 0, 'total_customers': 0};
  }
});

/// GET /health/status → {overall: green|yellow|red, checks: {whatsapp, ai, database, payments, ...}}
final healthStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'health_status';
  try {
    final resp = await api.get('/health/status');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlShort);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {'overall': 'unknown', 'checks': {}};
  }
});

/// GET /crm/segments → {vip, loyal, regular, new, prospect, total}
final crmSegmentsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'crm_segments';
  try {
    final resp = await api.get('/crm/segments');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlMedium);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {'vip': 0, 'loyal': 0, 'regular': 0, 'new': 0, 'prospect': 0, 'total': 0};
  }
});

/// GET /payments/reminders/pending → {count, orders:[...]}
final paymentRemindersProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'payment_reminders';
  try {
    final resp = await api.get('/payments/reminders/pending');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlShort);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {'count': 0, 'orders': []};
  }
});

/// Product count from cached products list
final productCountProvider = Provider<int>((ref) {
  final products = ref.watch(cachedProductsProvider);
  return products.valueOrNull?.length ?? 0;
});

// ── Today's Business Briefing ─────────────────────────────────────────────────
/// Combines profile, stats, orders, conversations, low stock, acquisition,
/// repeat customers and payment reminders into the data the home screen's
/// "Today's Business Briefing" needs. Resilient by design — any individual
/// source failing does not break the whole briefing (each sub-provider
/// already falls back to cache/safe-defaults internally).
class BriefingData {
  final BusinessProfile? profile;
  final DashboardStats? stats;
  final List<Order>? orders;
  final List<Conversation>? conversations;
  final List<LowStockProduct>? lowStock;
  final Map<String, dynamic>? acquisition;
  final Map<String, dynamic>? repeatCustomers;
  final Map<String, dynamic>? paymentReminders;

  const BriefingData({
    this.profile,
    this.stats,
    this.orders,
    this.conversations,
    this.lowStock,
    this.acquisition,
    this.repeatCustomers,
    this.paymentReminders,
  });
}

final briefingDataProvider = Provider<BriefingData>((ref) {
  final profile = ref.watch(cachedProfileProvider).valueOrNull;
  final statsMap = ref.watch(cachedAnalyticsProvider).valueOrNull;
  final stats = statsMap != null ? DashboardStats.fromJson(statsMap) : null;
  final orders = ref.watch(cachedOrdersProvider(null)).valueOrNull;
  final conversations =
      ref.watch(cachedConversationsProvider(null)).valueOrNull;
  final lowStock = ref.watch(lowStockProductsProvider).valueOrNull;
  final acquisition = ref.watch(acquisitionProvider).valueOrNull;
  final repeatCustomers = ref.watch(repeatCustomersProvider).valueOrNull;
  final paymentReminders = ref.watch(paymentRemindersProvider).valueOrNull;

  return BriefingData(
    profile: profile,
    stats: stats,
    orders: orders,
    conversations: conversations,
    lowStock: lowStock,
    acquisition: acquisition,
    repeatCustomers: repeatCustomers,
    paymentReminders: paymentReminders,
  );
});

/// True while the core briefing inputs (profile + stats) are still loading.
/// We don't block on every single source — just the two essential ones —
/// so the briefing renders quickly rather than waiting on the slowest call.
final briefingIsLoadingProvider = Provider<bool>((ref) {
  final profileLoading = ref.watch(cachedProfileProvider).isLoading;
  final statsLoading = ref.watch(cachedAnalyticsProvider).isLoading;
  return profileLoading || statsLoading;
});

// ── Trial status (GET /trial/status) ─────────────────────────────────────────
/// Mirrors web loadTrialBanner — trial_active, billing_status, trial_ends_at
final trialStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'trial_status';
  try {
    final resp = await api.get('/trial/status');
    final data = resp.data as Map<String, dynamic>;
    await cache.set(key, data, ttl: CacheService.ttlLong);
    return data;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is Map) return Map<String, dynamic>.from(stale);
    return {};
  }
});

// ── Growth insights (GET /insights/growth) ────────────────────────────────────
/// Mirrors web renderGrowthCard — quick_wins:[{title, value, priority}]
final growthInsightsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  const key = 'growth_insights';
  try {
    final resp = await api.get('/insights/growth');
    final data = resp.data as Map<String, dynamic>;
    final wins = (data['quick_wins'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await cache.set(key, wins, ttl: CacheService.ttlMedium);
    return wins;
  } catch (_) {
    final stale = cache.getStale(key);
    if (stale is List) {
      return stale.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
});
