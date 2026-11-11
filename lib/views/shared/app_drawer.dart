import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../chat/chat_thread_list_screen.dart';
import '../jobs/job_history_screen.dart';
import '../customer/click_and_collect_history_screen.dart';
import 'confirm_dialog.dart';
import 'legal_documents_screen.dart';
import 'notifications_sheet.dart';
import 'receipt_history_sheet.dart';
import '../sales/sales_history_dashboard_screen.dart';
import 'user_avatar.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onOpenPos;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTransfers;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    this.onOpenPos,
    this.onOpenDrawer,
    this.onOpenTransfers,
  });

  Future<void> _handleLogout(BuildContext context, MotoHubViewModel vm) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'End Session & Logout?',
      message: 'Are you sure you want to log out from this terminal?',
      confirmLabel: 'Log Out',
      destructive: true,
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // Close drawer
      await vm.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final role = user?.role ?? UserRole.admin;
    final unreadNotifs = vm.branchNotifications.where((n) => !n.isRead).length;

    return Drawer(
      backgroundColor: AppPalette.mantle,
      child: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 16,
                16,
                16,
              ),
              decoration: const BoxDecoration(
                color: AppPalette.crust,
                border: Border(
                  bottom: BorderSide(color: AppPalette.surface0, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(user: user, radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Boss Arman Staff',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user?.username ?? "user"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppPalette.champagneGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          role.label.toUpperCase(),
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppPalette.surface0,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            vm.activeBranch.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  if (role == UserRole.admin) ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.space_dashboard_rounded,
                      label: 'Executive Dashboard',
                      isSelected: selectedIndex == 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(0);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.inventory_2_rounded,
                      label: 'Master Inventory',
                      badgeCount: vm.branchLowStockItems.isNotEmpty
                          ? vm.branchLowStockItems.length
                          : null,
                      isSelected: selectedIndex == 1,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(1);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.handyman_rounded,
                      label: 'Jobs & Bay Queue',
                      badgeCount: vm.pendingJobRequests.isNotEmpty
                          ? vm.pendingJobRequests.length
                          : null,
                      isSelected: selectedIndex == 2,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(2);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.manage_accounts_rounded,
                      label: 'Staff Management',
                      isSelected: selectedIndex == 3,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(3);
                      },
                    ),
                    const Divider(color: AppPalette.surface0, height: 16),
                    _buildDrawerItem(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      label: 'Customer Chats',
                      accentColor: AppPalette.champagneGold,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatThreadListScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_rounded,
                      label: 'Notifications & Alerts',
                      badgeCount: unreadNotifs > 0 ? unreadNotifs : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        NotificationsSheet.show(
                          context,
                          roleSubtitle: 'Admin Alerts',
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_rounded,
                      label: 'Job History',
                      onTap: () {
                        Navigator.of(context).pop();
                        JobHistoryScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      label: 'Click & Collect Order History',
                      onTap: () {
                        Navigator.of(context).pop();
                        ClickAndCollectHistoryScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.query_stats_rounded,
                      label: 'Daily Sales Dashboard',
                      onTap: () {
                        Navigator.of(context).pop();
                        SalesHistoryDashboardScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      label: 'Receipt & Sales History',
                      onTap: () {
                        Navigator.of(context).pop();
                        ReceiptHistorySheet.show(context);
                      },
                    ),
                    if (onOpenPos != null || onOpenDrawer != null || onOpenTransfers != null) ...[
                      const Divider(color: AppPalette.surface0, height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          'TERMINAL SHORTCUTS',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (onOpenPos != null)
                        _buildDrawerItem(
                          context,
                          icon: Icons.point_of_sale_rounded,
                          label: 'Counter POS Terminal',
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenPos!();
                          },
                        ),
                      if (onOpenDrawer != null)
                        _buildDrawerItem(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Cash Drawer & Float',
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenDrawer!();
                          },
                        ),
                      if (onOpenTransfers != null)
                        _buildDrawerItem(
                          context,
                          icon: Icons.local_shipping_rounded,
                          label: 'Inter-Branch Transfers',
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenTransfers!();
                          },
                        ),
                    ],
                  ] else if (role == UserRole.cashier) ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.shopping_bag_rounded,
                      label: 'Counter POS',
                      badgeCount: vm.cartItemCount > 0 ? vm.cartItemCount : null,
                      isSelected: selectedIndex == 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(0);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      label: 'Service Invoicing (Auto-Bill)',
                      badgeCount: vm.serviceToPosQueue.isNotEmpty
                          ? vm.serviceToPosQueue.length
                          : null,
                      isSelected: selectedIndex == 1,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(1);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Cash Drawer & Float',
                      isSelected: selectedIndex == 2,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(2);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.local_shipping_rounded,
                      label: 'Branch Transfers & Requests',
                      badgeCount: vm.incomingInTransitTransfers.isNotEmpty
                          ? vm.incomingInTransitTransfers.length
                          : null,
                      isSelected: selectedIndex == 3,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(3);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.assessment_rounded,
                      label: 'Z-Reading & Shift Audit',
                      isSelected: selectedIndex == 4,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(4);
                      },
                    ),
                    const Divider(color: AppPalette.surface0, height: 16),
                    _buildDrawerItem(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      label: 'Customer Chats',
                      accentColor: AppPalette.champagneGold,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatThreadListScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_rounded,
                      label: 'Notifications & Alerts',
                      badgeCount: unreadNotifs > 0 ? unreadNotifs : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        NotificationsSheet.show(
                          context,
                          roleSubtitle: 'Cashier Alerts',
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_rounded,
                      label: 'Job History',
                      onTap: () {
                        Navigator.of(context).pop();
                        JobHistoryScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      label: 'Click & Collect Order History',
                      onTap: () {
                        Navigator.of(context).pop();
                        ClickAndCollectHistoryScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.query_stats_rounded,
                      label: 'Daily Sales Dashboard',
                      onTap: () {
                        Navigator.of(context).pop();
                        SalesHistoryDashboardScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      label: 'Receipt & Sales History',
                      onTap: () {
                        Navigator.of(context).pop();
                        ReceiptHistorySheet.show(context);
                      },
                    ),
                  ] else if (role == UserRole.mechanic) ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.engineering_rounded,
                      label: 'Bay Kanban Board',
                      badgeCount: vm.pendingJobRequests.isNotEmpty
                          ? vm.pendingJobRequests.length
                          : null,
                      isSelected: selectedIndex == 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(0);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.build_circle_rounded,
                      label: 'Inspection & Workbench',
                      isSelected: selectedIndex == 1,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(1);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.shelves,
                      label: 'Shelf & Bin Coordinates',
                      isSelected: selectedIndex == 2,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(2);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.badge_rounded,
                      label: 'Shift Profile & Logs',
                      isSelected: selectedIndex == 3,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectTab(3);
                      },
                    ),
                    const Divider(color: AppPalette.surface0, height: 16),
                    _buildDrawerItem(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      label: 'Customer Chats',
                      accentColor: AppPalette.champagneGold,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatThreadListScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_rounded,
                      label: 'Notifications & Alerts',
                      badgeCount: unreadNotifs > 0 ? unreadNotifs : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        NotificationsSheet.show(
                          context,
                          roleSubtitle: 'Mechanic Bay & Parts Alerts',
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_rounded,
                      label: 'Job History',
                      onTap: () {
                        Navigator.of(context).pop();
                        JobHistoryScreen.push(context);
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      label: 'Receipt & Sales History',
                      onTap: () {
                        Navigator.of(context).pop();
                        ReceiptHistorySheet.show(context);
                      },
                    ),
                  ],
                  const Divider(color: AppPalette.surface0, height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'LEGAL & DATA PRIVACY',
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy (RA 10173)',
                    onTap: () {
                      Navigator.of(context).pop();
                      LegalDocumentsScreen.openPrivacyPolicy(
                        context,
                        isCustomerApp: false,
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.gavel_rounded,
                    label: 'Terms & Conditions',
                    onTap: () {
                      Navigator.of(context).pop();
                      LegalDocumentsScreen.openTermsAndConditions(
                        context,
                        isCustomerApp: false,
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    label: 'Account & Data Retention',
                    onTap: () {
                      Navigator.of(context).pop();
                      LegalDocumentsScreen.openAccountDeletionPolicy(
                        context,
                        isCustomerApp: false,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppPalette.surface0, width: 1),
                ),
              ),
              child: _buildDrawerItem(
                context,
                icon: Icons.logout_rounded,
                label: 'Log Out',
                accentColor: AppPalette.danger,
                onTap: () => _handleLogout(context, vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    int? badgeCount,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? AppPalette.champagneGold;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.surface1 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: activeColor.withValues(alpha: 0.35))
            : null,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isSelected ? activeColor : (accentColor ?? AppPalette.textMuted),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppPalette.textHigh
                : (accentColor ?? AppPalette.textHigh),
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.champagneGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: AppPalette.crust,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
