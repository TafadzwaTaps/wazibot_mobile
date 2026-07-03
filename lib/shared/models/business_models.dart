/// lib/shared/models/business_models.dart
library;

class BusinessProfile {
  final int id;
  final String name;
  final String username;
  final String? ownerEmail;
  final String? contactPhone;
  final String? category;
  final String? logoUrl;
  final String? websiteUrl;
  final String? storeUrl;
  final String plan;
  final String? billingStatus;
  final bool isActive;
  final String? trialEndsAt;

  const BusinessProfile({
    required this.id,
    required this.name,
    required this.username,
    this.ownerEmail,
    this.contactPhone,
    this.category,
    this.logoUrl,
    this.websiteUrl,
    this.storeUrl,
    this.plan = 'free',
    this.billingStatus,
    this.isActive = true,
    this.trialEndsAt,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        username: json['owner_username'] as String? ?? '',
        ownerEmail: json['owner_email'] as String?,
        contactPhone: json['contact_phone'] as String?,
        category: json['category'] as String?,
        logoUrl: json['logo_url'] as String?,
        websiteUrl: json['website_url'] as String?,
        storeUrl: json['store_url'] as String?,
        plan: json['subscription_tier'] as String? ?? 'free',
        billingStatus: json['billing_status'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        trialEndsAt: json['trial_ends_at'] as String?,
      );

  String get displayPlan {
    final p = plan.toLowerCase();
    const names = {
      'free': 'Free',
      'growth': 'Growth',
      'pro': 'Pro',
      'enterprise': 'Enterprise',
    };
    return names[p] ?? p;
  }

  bool get isOnTrial =>
      trialEndsAt != null &&
      DateTime.tryParse(trialEndsAt!)?.isAfter(DateTime.now()) == true;
}

/// Mirrors the real shape returned by GET /analytics/stats on the web
/// backend (crud/analytics.py::get_business_stats / get_business_stats_cached).
/// There is no health score, QR scan count, or conversion rate on the
/// backend today — the web dashboard doesn't show those either.
class DashboardStats {
  final int totalOrders;
  final int paidOrders;
  final double totalRevenue;
  final int pendingOrders;
  final int activeCustomers;
  final int aiHandled;
  final int humanHandled;

  const DashboardStats({
    this.totalOrders = 0,
    this.paidOrders = 0,
    this.totalRevenue = 0,
    this.pendingOrders = 0,
    this.activeCustomers = 0,
    this.aiHandled = 0,
    this.humanHandled = 0,
  });

  /// Share of conversations handled by AI vs. a human, 0-1. Useful for a
  /// simple progress bar; not a backend field itself.
  double get aiHandledShare {
    final total = aiHandled + humanHandled;
    return total == 0 ? 0 : aiHandled / total;
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalOrders: _i(json['total_orders']),
        paidOrders: _i(json['paid_orders']),
        totalRevenue: _d(json['total_revenue']),
        pendingOrders: _i(json['pending_orders']),
        activeCustomers: _i(json['active_customers']),
        aiHandled: _i(json['ai_handled']),
        humanHandled: _i(json['human_handled']),
      );

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
}

class Order {
  final String id;
  // Orders don't carry a customer_id on the backend, only customer_phone —
  // kept for compatibility with any code still reading it.
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  // Real values seen on the web dashboard: pending | confirmed | preparing
  // | new | completed | delivered | cancelled.
  final String status;
  final double total;
  final String? currency;
  final String? notes;
  final List<OrderItem> items;
  final String createdAt;

  const Order({
    required this.id,
    required this.customerId,
    required this.status,
    required this.total,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.currency,
    this.notes,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id']?.toString() ?? '',
        customerId: (json['customer_id'] ?? json['customer_phone'])?.toString() ?? '',
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
        status: json['status'] as String? ?? 'pending',
        total: (json['total_price'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class OrderItem {
  final String productName;
  final int quantity;
  final double price;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productName: json['product_name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

class Product {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final int? stock;
  final bool isActive;
  final String? category;
  final String? currency;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.stock,
    this.isActive = true,
    this.category,
    this.currency,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        stock: json['stock'] as int?,
        isActive: json['is_active'] as bool? ?? true,
        category: json['category'] as String?,
        currency: json['currency'] as String? ?? 'USD',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        if (description != null) 'description': description,
        if (stock != null) 'stock': stock,
        if (category != null) 'category': category,
      };
}

class Conversation {
  final String phone;
  final String? customerName;
  final String? lastMessage;
  final String? lastMessageAt;
  final bool isAiPaused;
  final bool hasUnread;
  final int unreadCount;

  const Conversation({
    required this.phone,
    this.customerName,
    this.lastMessage,
    this.lastMessageAt,
    this.isAiPaused = false,
    this.hasUnread = false,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final unread = json['unread_count'] as int? ?? 0;
    return Conversation(
      phone: json['phone'] as String? ?? '',
      // The backend doesn't return a customer name on conversations today
      // (web inbox falls back to showing the phone number too).
      customerName: json['customer_name'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      // Real field is `in_handoff` (true while a human agent has taken over).
      isAiPaused: json['in_handoff'] as bool? ?? false,
      // No boolean flag on the backend — derive it from unread_count.
      hasUnread: unread > 0,
      unreadCount: unread,
    );
  }
}

class Message {
  final String id;
  final String direction; // inbound | outbound
  final String content;
  final String? type;
  final String createdAt;

  const Message({
    required this.id,
    required this.direction,
    required this.content,
    required this.createdAt,
    this.type,
  });

  bool get isInbound => direction == 'inbound';

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        direction: json['direction'] as String? ?? 'inbound',
        // Real column is `text`, not `content`.
        content: json['text'] as String? ?? '',
        type: json['type'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
