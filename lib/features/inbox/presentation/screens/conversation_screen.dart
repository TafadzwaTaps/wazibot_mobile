/// lib/features/inbox/presentation/screens/conversation_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String phone;
  const ConversationScreen({super.key, required this.phone});

  @override
  ConsumerState<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/chat/send', data: {
        'phone': widget.phone,
        'message': text,
      });
      _msgCtrl.clear();
      ref.invalidate(messagesProvider(widget.phone));
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Resolves the conversation's customer_id from the cached conversations
  /// list (matched by phone), then sends a pre-written quick-reply message.
  /// Mirrors the web inbox's "Quick Actions" bar (qaRepeatLastOrder,
  /// qaRequestPayment, qaMarkPaid, qaCreateDelivery) using the same backend
  /// contract: POST /chat/send with {customer_id, text}.
  Future<void> _sendQuickReply(String text, String successMessage) async {
    final convs = ref.read(cachedConversationsProvider(null)).valueOrNull;
    final conv = convs?.firstWhere(
      (c) => c.phone == widget.phone,
      orElse: () => Conversation(customerId: '', phone: widget.phone),
    );
    final customerId = conv?.customerId;
    if (customerId == null || customerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not find this conversation — try again.'),
          backgroundColor: WaziBotColors.error,
        ));
      }
      return;
    }

    Haptics.light();
    setState(() => _isSending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/chat/send', data: {
        'customer_id': customerId,
        'text': text,
      });
      ref.invalidate(messagesProvider(widget.phone));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMessage),
          backgroundColor: WaziBotColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Looks up an unpaid order for this customer (used by "Request Payment"
  /// and "Mark as Paid" quick replies) — same logic as the web's
  /// qaRequestPayment / qaMarkPaid functions.
  Future<Map<String, dynamic>?> _findPendingOrderForCustomer() async {
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/payments/reminders/pending');
      final orders = (resp.data['orders'] as List?) ?? [];
      final match = orders.cast<Map<String, dynamic>>().firstWhere(
        (o) => o['customer_phone'] == widget.phone,
        orElse: () => <String, dynamic>{},
      );
      return match.isEmpty ? null : match;
    } catch (_) {
      return null;
    }
  }

  Future<void> _quickRepeatOrder() => _sendQuickReply(
        "🔄 *Repeating your last order*\n\nJust reply *yes* to confirm and I'll add it to your cart!",
        'Repeat order message sent',
      );

  Future<void> _quickRequestPayment() async {
    final order = await _findPendingOrderForCustomer();
    String msg =
        "💳 *Payment Reminder*\n\nYou have a pending payment. Please complete your payment to confirm your order.";
    if (order != null) {
      final total =
          (order['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final method =
          (order['payment_method'] as String? ?? 'payment').replaceAll('_', ' ');
      msg =
          "💳 *Payment Due*\n\n📦 Order: *ORDER-${order['order_id']}*\n💰 Amount: *\$$total*\n📱 Method: *$method*\n\nPlease complete your payment to confirm your order. Reply *paid* once done.";
    }
    await _sendQuickReply(msg, 'Payment request sent');
  }

  Future<void> _quickMarkPaid() async {
    final order = await _findPendingOrderForCustomer();
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No pending orders found for this customer'),
      ));
      return;
    }
    final total = (order['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mark ORDER-${order['order_id']} as paid?'),
        content: Text('Amount: \$$total'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    Haptics.medium();
    try {
      final api = ref.read(apiClientProvider);
      final orderId = order['order_id'];
      await api.post('/payments/reminders/$orderId/nudge?dry_run=false');
      await api.post('/payments/manual/confirm', data: {
        'order_id': orderId,
        'reference': 'ORDER-$orderId',
        'amount': order['total_price'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ORDER-$orderId marked as paid'),
          backgroundColor: WaziBotColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    }
  }

  /// Mirrors web qaGenerateInvoice — finds most recent order and sends invoice message
  Future<void> _quickGenerateInvoice() async {
    final order = await _findPendingOrderForCustomer();
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No recent orders found for this customer')));
      return;
    }
    final orderId = order['order_id'];
    await _sendQuickReply(
      '🧾 *Invoice for ORDER-$orderId*\n\nHere is a summary of your order. Reply *paid* once payment is complete.',
      'Invoice sent for ORDER-$orderId',
    );
  }

  Future<void> _quickDeliveryRequest() => _sendQuickReply(
        "🚚 *Delivery Confirmation*\n\nPlease send your *full delivery address* (street, suburb, city) and we'll arrange delivery for your order.",
        'Delivery request sent',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msgsAsync = ref.watch(messagesProvider(widget.phone));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.phone, style: theme.textTheme.titleMedium),
            Text('WhatsApp',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          // AI / Agent mode toggle
          Consumer(builder: (_, ref, __) {
            final convAsync = ref.watch(
                cachedConversationsProvider(null));
            final conv = convAsync.valueOrNull?.firstWhere(
              (c) => c.phone == widget.phone,
              orElse: () => Conversation(
                  customerId: '', phone: widget.phone),
            );
            final isPaused = conv?.isAiPaused ?? false;
            return Tooltip(
              message: isPaused ? 'AI paused — tap to resume' : 'AI active — tap to pause',
              child: IconButton(
                icon: Icon(
                  isPaused ? Icons.smart_toy_outlined : Icons.support_agent_outlined,
                  color: isPaused ? WaziBotColors.warning : WaziBotColors.primary,
                ),
                onPressed: () async {
                  try {
                    final api = ref.read(apiClientProvider);
                    // POST handoff request to pause AI / release to resume
                    if (!isPaused) {
                      await api.post(
                          '/chat/handoff/${conv?.customerId ?? widget.phone}/request',
                          data: {});
                    } else {
                      await api.post(
                          '/chat/handoff/${conv?.customerId ?? widget.phone}/release');
                    }
                    Haptics.medium();
                    ref.invalidate(cachedConversationsProvider(null));
                  } catch (_) {}
                },
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Customer profile',
            onPressed: () =>
                context.push('/customer/${widget.phone}'),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Mark resolved',
            onPressed: () async {
              try {
                final api = ref.read(apiClientProvider);
                await api.post(
                    '/chat/conversations/${widget.phone}/close');
                if (context.mounted) context.pop();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: msgsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(count: 6, itemHeight: 60),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(apiErrorMessage(e),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref
                          .invalidate(messagesProvider(widget.phone)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (msgs) => msgs.isEmpty
                  ? Center(
                      child: Text('No messages yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) =>
                          _MessageBubble(msg: msgs[i]),
                    ),
            ),
          ),
          _QuickActionsBar(
            onRepeatOrder: _quickRepeatOrder,
            onRequestPayment: _quickRequestPayment,
            onMarkPaid: _quickMarkPaid,
            onDeliveryRequest: _quickDeliveryRequest,
            onGenerateInvoice: _quickGenerateInvoice,
            disabled: _isSending,
          ),
          _MessageBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions bar ──────────────────────────────────────────────────────────
/// Pre-written, one-tap messages for the most common WhatsApp-business
/// situations — mirrors the web inbox's Quick Actions bar exactly
/// (Repeat Order, Request Payment, Mark Paid, Send Delivery Request).
/// Keeps the conversation screen feeling like WhatsApp Business: fast,
/// no typing required for routine replies.
class _QuickActionsBar extends StatelessWidget {
  final VoidCallback onRepeatOrder;
  final VoidCallback onRequestPayment;
  final VoidCallback onMarkPaid;
  final VoidCallback onDeliveryRequest;
  final VoidCallback onGenerateInvoice;
  final bool disabled;

  const _QuickActionsBar({
    required this.onRepeatOrder,
    required this.onRequestPayment,
    required this.onMarkPaid,
    required this.onDeliveryRequest,
    required this.onGenerateInvoice,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      (Icons.replay_outlined, 'Repeat order', onRepeatOrder),
      (Icons.payments_outlined, 'Request payment', onRequestPayment),
      (Icons.check_circle_outline, 'Mark paid', onMarkPaid),
      (Icons.local_shipping_outlined, 'Delivery request', onDeliveryRequest),
      (Icons.receipt_outlined, 'Send invoice', onGenerateInvoice),
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (icon, label, onTap) = actions[i];
          return ActionChip(
            avatar: Icon(icon, size: 14, color: WaziBotColors.primary),
            label: Text(label, style: const TextStyle(fontSize: 11)),
            onPressed: disabled ? null : onTap,
            backgroundColor:
                WaziBotColors.primary.withValues(alpha: 0.08),
            side: BorderSide(
                color: WaziBotColors.primary.withValues(alpha: 0.25)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = !msg.isInbound;

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOut
                ? WaziBotColors.primary.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isOut ? 14 : 2),
              bottomRight: Radius.circular(isOut ? 2 : 14),
            ),
            border: Border.all(
              color: isOut
                  ? WaziBotColors.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.outline,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOut && msg.isAiSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.smart_toy_outlined, size: 10,
                        color: WaziBotColors.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Text('AI', style: TextStyle(
                        fontSize: 9,
                        color: WaziBotColors.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (!isOut && msg.isAgentSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.support_agent_outlined, size: 10,
                        color: WaziBotColors.warning.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Text('Agent', style: TextStyle(
                        fontSize: 9,
                        color: WaziBotColors.warning.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              Text(msg.content,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 3),
              Text(
                _formatTime(msg.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String ts) {
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    return DateFormat.jm().format(dt.toLocal());
  }
}

class _MessageBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Type a message...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isSending
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: WaziBotColors.primary),
                )
              : Material(
                  color: WaziBotColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.send_rounded,
                          color: Colors.black, size: 20),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
