/// lib/shared/models/business_models.dart
///
/// All models matched EXACTLY to WaziBot backend field names.
/// Backend source verified:
///
///  /analytics/stats  → total_orders, paid_orders, total_revenue,
///                      pending_orders, active_customers, ai_handled, human_handled
///  /orders           → id, status, total_price, customer_phone, customer_name,
///                      items(JSON), notes, created_at, payment_status,
///                      fulfillment_method, delivery_address
///  /chat/conversations → customer_id, phone, last_seen, unread_count,
///                        last_message, last_direction, last_message_at
///  /chat/messages/:id  → id, text, direction(incoming/outgoing), sender_type,
///                        is_read, status, created_at
///  /products         → id, name, price, description, image_url, stock,
///                      is_active, category, currency
///  /me               → id, name, owner_username, owner_email, contact_phone,
///                      logo_url, website_url, store_url, plan, billing_status,
///                      is_active, trial_ends_at
library;

// ── BusinessProfile ───────────────────────────────────────────────────────────
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
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        username: json['owner_username'] as String? ?? '',
        ownerEmail: json['owner_email'] as String?,
        contactPhone: json['contact_phone'] as String?,
        category: json['category'] as String?,
        logoUrl: json['logo_url'] as String?,
        websiteUrl: json['website_url'] as String?,
        storeUrl: json['store_url'] as String?,
        plan: json['plan'] as String? ?? 'free',
        billingStatus: json['billing_status'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        trialEndsAt: json['trial_ends_at'] as String?,
      );

  String get displayPlan {
    const names = {
      'free': 'Free',
      'growth': 'Growth',
      'pro': 'Pro',
      'enterprise': 'Enterprise',
    };
    return names[plan.toLowerCase()] ?? plan;
  }

  bool get isOnTrial =>
      trialEndsAt != null &&
      DateTime.tryParse(trialEndsAt!)?.isAfter(DateTime.now()) == true;
}

// ── DashboardStats ────────────────────────────────────────────────────────────
class DashboardStats {
  final int totalOrders;
  final int paidOrders;
  final double totalRevenue;
  final int pendingOrders;
  final int activeCustomers;
  final int aiHandled;
  final int humanHandled;
  final double healthScore;
  final int qrScans;
  final double conversionRate;
  final int conversations;

  const DashboardStats({
    this.totalOrders = 0,
    this.paidOrders = 0,
    this.totalRevenue = 0,
    this.pendingOrders = 0,
    this.activeCustomers = 0,
    this.aiHandled = 0,
    this.humanHandled = 0,
    this.healthScore = 0,
    this.qrScans = 0,
    this.conversionRate = 0,
    this.conversations = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final totalOrders = _i(json['total_orders']);
    final paidOrders = _i(json['paid_orders']);
    final aiHandled = _i(json['ai_handled']);
    final humanHandled = _i(json['human_handled']);

    double healthScore = _d(json['health_score']);
    if (healthScore == 0 && totalOrders > 0) {
      final convRate = paidOrders / totalOrders;
      healthScore =
          ((convRate * 60) + (aiHandled > 0 ? 20 : 0) + 20).clamp(0.0, 100.0);
    }

    return DashboardStats(
      totalOrders: totalOrders,
      paidOrders: paidOrders,
      totalRevenue: _d(json['total_revenue']),
      pendingOrders: _i(json['pending_orders']),
      activeCustomers: _i(json['active_customers']),
      aiHandled: aiHandled,
      humanHandled: humanHandled,
      healthScore: healthScore,
      qrScans: _i(json['qr_scans']),
      conversionRate:
          totalOrders > 0 ? (paidOrders / totalOrders * 100) : 0,
      conversations: _i(json['conversations']) > 0
          ? _i(json['conversations'])
          : aiHandled + humanHandled,
    );
  }

  int get todayOrders => pendingOrders;
  double get todayRevenue => totalRevenue;

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
}

// ── Order ─────────────────────────────────────────────────────────────────────
class Order {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String status;     // normalised: new|preparing|completed|cancelled
  final String rawStatus;  // original backend value
  final double total;
  final String? paymentStatus;
  final String? currency;
  final String? notes;
  final List<OrderItem> items;
  final String createdAt;
  final String? fulfillmentMethod; // 'delivery' | 'pickup'
  final String? deliveryAddress;

  const Order({
    required this.id,
    required this.customerId,
    required this.status,
    required this.rawStatus,
    required this.total,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.paymentStatus,
    this.currency,
    this.notes,
    this.items = const [],
    this.fulfillmentMethod,
    this.deliveryAddress,
  });

  /// True when this is a delivery order with an address — show Navigate button.
  bool get isDelivery =>
      fulfillmentMethod == 'delivery' &&
      deliveryAddress != null &&
      deliveryAddress!.trim().isNotEmpty;

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'pending';
    return Order(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_phone']?.toString() ??
          json['customer_id']?.toString() ?? '',
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      status: _normalise(rawStatus),
      rawStatus: rawStatus,
      total: (json['total_price'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['payment_status'] as String?,
      currency: json['currency'] as String?,
      notes: json['notes'] as String?,
      items: _parseItems(json['items']),
      createdAt: json['created_at'] as String? ?? '',
      fulfillmentMethod: json['fulfillment_method'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
    );
  }

  static String _normalise(String s) => const {
        'pending': 'new',
        'confirmed': 'new',
        'awaiting_payment': 'new',
        'pending_cash': 'new',
        'payment_review': 'preparing',
        'preparing': 'preparing',
        'completed': 'completed',
        'delivered': 'completed',
        'cancelled': 'cancelled',
        'refunded': 'cancelled',
      }[s] ??
      s;

  static List<OrderItem> _parseItems(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
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
        productName: json['name'] as String? ??
            json['product_name'] as String? ?? '',
        quantity: (json['qty'] as num?)?.toInt() ??
            (json['quantity'] as num?)?.toInt() ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

// ── Product ───────────────────────────────────────────────────────────────────
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
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        stock: (json['stock'] as num?)?.toInt(),
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

// ── Conversation ──────────────────────────────────────────────────────────────
class Conversation {
  final String customerId;
  final String phone;
  final String? customerName;
  final String? lastMessage;
  final String? lastMessageAt;
  final String? lastDirection;
  final bool isAiPaused;
  final int unreadCount;

  const Conversation({
    required this.customerId,
    required this.phone,
    this.customerName,
    this.lastMessage,
    this.lastMessageAt,
    this.lastDirection,
    this.isAiPaused = false,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        customerId: json['customer_id']?.toString() ?? '',
        phone: json['phone'] as String? ?? '',
        customerName: json['customer_name'] as String? ??
            json['name'] as String?,
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] as String? ??
            json['last_seen'] as String?,
        lastDirection: json['last_direction'] as String?,
        isAiPaused: json['ai_paused'] as bool? ?? false,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );
}

// ── Message ───────────────────────────────────────────────────────────────────
class Message {
  final String id;
  final String direction;
  final String content;
  final String? type;
  final String? senderType;
  final bool isRead;
  final String createdAt;

  const Message({
    required this.id,
    required this.direction,
    required this.content,
    required this.createdAt,
    this.type,
    this.senderType,
    this.isRead = true,
  });

  bool get isInbound => direction == 'incoming';
  bool get isAiSent => senderType == 'ai';
  bool get isAgentSent => senderType == 'agent';

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        content: json['text'] as String? ??
            json['message'] as String? ??
            json['content'] as String? ?? '',
        direction: json['direction'] as String? ?? 'incoming',
        type: json['type'] as String?,
        senderType: json['sender_type'] as String?,
        isRead: json['is_read'] as bool? ?? true,
        createdAt: json['created_at'] as String? ?? '',
      );
}

// ── Customer (CRM) ────────────────────────────────────────────────────────────
class Customer {
  final String phone;
  final String? name;
  final double totalSpent;
  final int orderCount;
  final String? lastSeen;
  final String? segment;

  const Customer({
    required this.phone,
    this.name,
    this.totalSpent = 0,
    this.orderCount = 0,
    this.lastSeen,
    this.segment,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        phone: json['phone'] as String? ?? '',
        name: json['customer_name'] as String? ??
            json['name'] as String?,
        totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
        orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
        lastSeen: json['last_seen'] as String?,
        segment: json['segment'] as String?,
      );
}

// ── LowStockProduct ───────────────────────────────────────────────────────────
class LowStockProduct {
  final int id;
  final String name;
  final int stock;
  final int? threshold;

  const LowStockProduct({
    required this.id,
    required this.name,
    required this.stock,
    this.threshold,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) =>
      LowStockProduct(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        threshold: (json['threshold'] as num?)?.toInt(),
      );
}
