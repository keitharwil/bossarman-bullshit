import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../core/services/notification_service.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../chat/chat_conversation_screen.dart';

/// Top-Right AppBar Notification Bell with Material 3 Expressive `M3EBadge`
/// shared across Admin, Cashier, Mechanic (beside QR), and Customer shells.
class NotificationBellAction extends StatelessWidget {
  final String roleSubtitle;

  const NotificationBellAction({
    super.key,
    required this.roleSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final unread = vm.branchNotifications
        .where((n) => !n.isRead)
        .length;

    return IconButton(
      tooltip: 'Notifications & Alerts ($unread unread)',
      onPressed: () => NotificationsSheet.show(
        context,
        roleSubtitle: roleSubtitle,
      ),
      icon: M3EBadge(
        count: unread > 0 ? unread : null,
        backgroundColor: AppPalette.warning,
        foregroundColor: AppPalette.crust,
        child: Icon(
          unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_outlined,
          color: unread > 0 ? AppPalette.champagneGold : AppPalette.textBody,
        ),
      ),
    );
  }
}

/// Material 3 Expressive Notification Center Bottom Sheet (`M3ECardList` + `M3EListItem`)
/// for Admin, Cashier, Mechanic, and Customer portals.
class NotificationsSheet extends StatefulWidget {
  final String roleSubtitle;

  const NotificationsSheet({
    super.key,
    required this.roleSubtitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String roleSubtitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (_) => NotificationsSheet(roleSubtitle: roleSubtitle),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  String _selectedCategory = 'all';

  Future<void> _dismissNotification(
    MotoHubViewModel vm,
    AppNotificationItem notif,
  ) async {
    await vm.removeNotification(notif.id);
  }

  Future<void> _dismissAllVisible(
    MotoHubViewModel vm,
    List<AppNotificationItem> items,
  ) async {
    if (items.isEmpty) return;
    for (final n in items) {
      await vm.removeNotification(n.id);
    }
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'service':
      case 'job_order':
        return Icons.handyman_rounded;
      case 'transfer':
        return Icons.local_shipping_rounded;
      case 'drawer':
        return Icons.account_balance_wallet_rounded;
      case 'reservation':
      case 'booking':
        return Icons.shopping_bag_rounded;
      case 'staff':
        return Icons.badge_rounded;
      case 'low_stock':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _accentForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'service':
      case 'job_order':
        return AppPalette.champagneGold;
      case 'transfer':
        return AppPalette.warning;
      case 'drawer':
        return AppPalette.success;
      case 'reservation':
      case 'booking':
        return AppPalette.warmGold;
      case 'staff':
        return AppPalette.champagneGold;
      case 'low_stock':
        return AppPalette.danger;
      default:
        return AppPalette.champagneGold;
    }
  }

  bool _matchesSelectedCategory(String itemCategory) {
    if (_selectedCategory == 'all') return true;
    final c = itemCategory.toLowerCase();
    if (_selectedCategory == 'service') {
      return c == 'service' || c == 'job_order';
    }
    if (_selectedCategory == 'reservation') {
      return c == 'reservation' || c == 'booking';
    }
    return c == _selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final allNotifs = vm.branchNotifications;
    final filtered = allNotifs
        .where((n) => _matchesSelectedCategory(n.category))
        .toList();
    final unreadCount = allNotifs.where((n) => !n.isRead).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.surface0,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row (Compact & responsive across 320dp-360dp)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppPalette.champagneGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: M3EBadge(
                      count: unreadCount > 0 ? unreadCount : null,
                      backgroundColor: AppPalette.warning,
                      foregroundColor: AppPalette.crust,
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppPalette.champagneGold,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Center',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.roleSubtitle} • ${vm.activeBranch.shortName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    IconButton(
                      tooltip: 'Read All',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => vm.markAllNotificationsRead(),
                      icon: const Icon(
                        Icons.done_all_rounded,
                        color: AppPalette.champagneGold,
                        size: 20,
                      ),
                    ),
                  if (filtered.isNotEmpty)
                    IconButton(
                      tooltip: 'Dismiss All Visible',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _dismissAllVisible(vm, filtered),
                      icon: const Icon(
                        Icons.clear_all_rounded,
                        color: AppPalette.textMuted,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('all', 'All (${allNotifs.length})'),
                    const SizedBox(width: 8),
                    _buildCategoryChip('service', 'Service Bay'),
                    const SizedBox(width: 8),
                    _buildCategoryChip('transfer', 'Stock Transfers'),
                    const SizedBox(width: 8),
                    _buildCategoryChip('reservation', 'Click & Collect'),
                    const SizedBox(width: 8),
                    _buildCategoryChip('drawer', 'Drawer Audit'),
                    const SizedBox(width: 8),
                    _buildCategoryChip('staff', 'Staff & Branch'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Material 3 Expressive Card List of Notifications (Swipe right or tap button to dismiss)
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        controller: scrollController,
                        children: const [
                          SizedBox(height: 24),
                          MotoHubEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'No Notifications in Queue',
                            subtitle:
                                'Real-time alerts for bay job acceptances, customer extra repair approvals, cross-branch stock dispatches, and Click & Collect orders appear here automatically.',
                          ),
                        ],
                      )
                    : M3ECardList.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        outerRadius: 24,
                        innerRadius: 6,
                        gap: 3,
                        variant: M3ECardVariant.filled,
                        border: const BorderSide(
                          color: AppPalette.surface0,
                          width: 1,
                        ),
                        colorBuilder: (index) {
                          final AppNotificationItem n = filtered[index];
                          return n.isRead
                              ? AppPalette.crust
                              : AppPalette.surface1;
                        },
                        onTap: (index) {
                          final notif = filtered[index];
                          vm.markAllNotificationsRead(notif.id);
                          Navigator.of(context).pop();
                          NotificationRouter.routeNotification(context, notif);
                        },
                        itemBuilder: (context, index) {
                          final AppNotificationItem n = filtered[index];
                          final accent = _accentForCategory(n.category);
                          return Dismissible(
                            key: ValueKey('notif_${n.id}'),
                            direction: DismissDirection.startToEnd,
                            onDismissed: (_) => _dismissNotification(vm, n),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppPalette.danger.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.swipe_right_rounded,
                                    color: AppPalette.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Dismiss Notification',
                                    style: TextStyle(
                                      color: AppPalette.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                vm.markNotificationRead(n.id);
                                if (n.category == 'chat') {
                                  final threadId = n.payload?['refId'] as String?;
                                  if (threadId != null && threadId.isNotEmpty) {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatConversationScreen(
                                          threadId: threadId,
                                          recipientName: n.title.replaceFirst('New message from ', ''),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }
                                Navigator.of(context).pop();
                                NotificationRouter.routeNotification(context, n);
                              },
                              child: M3EListItem(
                                overline:
                                    '${n.category.toUpperCase()} • ${AppFormatters.relativeTime(n.createdAt)}',
                                headline: n.title,
                                supportingText: n.message,
                                selected: !n.isRead,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Icon(
                                    _iconForCategory(n.category),
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!n.isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.champagneGold
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: AppPalette.champagneGold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 18,
                                        color: AppPalette.inactive,
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Dismiss notification',
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _dismissNotification(vm, n),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppPalette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final selected = _selectedCategory == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _selectedCategory = value),
    );
  }
}
