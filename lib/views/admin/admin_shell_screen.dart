import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../shared/confirm_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../cashier/cashier_shell_screen.dart';
import '../shared/barcode_scanner_modal.dart';
import '../shared/inventory_sync_chip.dart';
import '../shared/notifications_sheet.dart';
import 'add_staff_screen.dart';
import 'part_barcode_generator_screen.dart';
import '../checkout/checkout_screen.dart';
import '../sales/sales_history_dashboard_screen.dart';
import '../customer/click_and_collect_history_screen.dart';
import '../shared/app_drawer.dart';
import '../../core/theme/m3e_motion.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MotoHubViewModel>().syncDeviceBinding();
        context.read<MotoHubViewModel>().requestNotificationPermission();
      }
    });
  }

  void _openQuickPosSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Direct Counter POS • Admin Terminal'),
          ),
          body: const CashierPosTabView(),
        ),
      ),
    );
  }

  void _openQuickDrawerSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Cash Drawer & Shift Audit • Admin Override'),
          ),
          body: const CashierDrawerTabView(),
        ),
      ),
    );
  }

  void _openQuickTransfersSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Branch Transfers & Stock Requests'),
          ),
          body: const CashierTransfersTabView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final patimbaoTransit = vm.inTransitCountForBranch(BranchId.patimbao);
    final guevaraTransit = vm.inTransitCountForBranch(BranchId.pedroGuevara);

    final pages = [
      _AdminExecutiveDashboardTab(
        onNavigateTab: (idx) {
          setState(() => _selectedIndex = idx);
          if (idx == 1) vm.syncInventory();
        },
        onOpenPos: () => _openQuickPosSheet(context),
        onOpenDrawer: () => _openQuickDrawerSheet(context),
        onOpenTransfers: () => _openQuickTransfersSheet(context),
      ),
      const _AdminMasterInventoryTab(),
      const _AdminJobsKanbanTab(),
      const AddStaffScreen(),
    ];

    final safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(134),
        child: Container(
          decoration: const BoxDecoration(
            color: AppPalette.crust,
            border: Border(
              bottom: BorderSide(color: AppPalette.surface0, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title Row + Offline Sync Toggle + QR Scanner + Notifications Badge
                  Row(
                    children: [
                      Builder(
                        builder: (drawerCtx) => IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          tooltip: 'Open Menu',
                          icon: const Icon(Icons.menu_rounded, color: AppPalette.champagneGold, size: 22),
                          onPressed: () => Scaffold.of(drawerCtx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                AppPalette.champagneGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/admin_logo.png',
                          errorBuilder: (_, e, s) => const Icon(
                            Icons.handyman_rounded,
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
                              'Boss Arman MotoHub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              vm.activeBranch.fullAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const InventorySyncChip(compact: true),
                      const NotificationBellAction(
                        roleSubtitle: 'Admin Executive & Branch Alerts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Material 3 Expressive M3ESegmentedButton for Branch 1 vs Branch 2
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<BranchId>(
                      segments: [
                        ButtonSegment<BranchId>(
                          value: BranchId.patimbao,
                          icon: const Icon(Icons.storefront_rounded, size: 16),
                          label: SlidingMarqueeText(
                            text: patimbaoTransit > 0
                                ? 'Branch 1: Patimbao ($patimbaoTransit)'
                                : 'Branch 1: Patimbao',
                          ),
                        ),
                        ButtonSegment<BranchId>(
                          value: BranchId.pedroGuevara,
                          icon: const Icon(Icons.storefront_rounded, size: 16),
                          label: SlidingMarqueeText(
                            text: guevaraTransit > 0
                                ? 'Branch 2: P. Guevara ($guevaraTransit)'
                                : 'Branch 2: P. Guevara',
                          ),
                        ),
                      ],
                      selected: {vm.activeBranch},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) vm.switchBranch(set.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: AppDrawer(
        selectedIndex: safeIndex,
        onSelectTab: (idx) {
          setState(() => _selectedIndex = idx);
          if (idx == 1) vm.syncInventory();
        },
        onOpenPos: () => _openQuickPosSheet(context),
        onOpenDrawer: () => _openQuickDrawerSheet(context),
        onOpenTransfers: () => _openQuickTransfersSheet(context),
      ),
      body: M3ETabSwitcher(index: safeIndex, children: pages),
    );
  }
}

// =============================================================================
// TAB 1: EXECUTIVE DASHBOARD
// =============================================================================

class _AdminExecutiveDashboardTab extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onOpenPos;
  final VoidCallback onOpenDrawer;
  final VoidCallback? onOpenTransfers;

  const _AdminExecutiveDashboardTab({
    required this.onNavigateTab,
    required this.onOpenPos,
    required this.onOpenDrawer,
    this.onOpenTransfers,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final bayBikes = vm.activeBayBikes;
    final bayProgress =
        (bayBikes.length / vm.maxBayCapacity).clamp(0.0, 1.0);
    final incomingTransfers = vm.incomingInTransitTransfers;
    final lowStock = vm.branchLowStockItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // 2-Column Executive Metrics: "Today's Gross" + "Bikes in Bay"
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric 1: Today's Gross (Cash vs. GCash breakdown & live badge)
            Expanded(
              child: Card.filled(
                color: AppPalette.mantle,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => SalesHistoryDashboardScreen.push(
                    context,
                    branchFilter: vm.activeBranch,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                          const Flexible(
                            child: Text(
                              "TODAY'S GROSS",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppPalette.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: vm.branchTodayGross,
                        ),
                        duration: const Duration(milliseconds: 700),
                        curve: const Cubic(0.05, 0.7, 0.1, 1.0),
                        builder: (context, value, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormatters.currency(value),
                            style: const TextStyle(
                              color: AppPalette.champagneGold,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cash Sales:',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              AppFormatters.currency(
                                vm.branchCashSalesTotal,
                                showDecimals: false,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.success,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'GCash Vault:',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              AppFormatters.currency(
                                vm.branchGcashVaultTotal,
                                showDecimals: false,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            const SizedBox(width: 12),

            // Metric 2: Bikes in Bay (Active bay capacity progress gauge)
            Expanded(
              child: Card.filled(
                color: AppPalette.mantle,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'BIKES IN BAY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.warning.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(bayProgress * 100).toInt()}% Cap',
                              style: const TextStyle(
                                color: AppPalette.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${bayBikes.length}',
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' / ${vm.maxBayCapacity} Lifts',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: bayProgress,
                          minHeight: 7,
                          backgroundColor: AppPalette.surface0,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppPalette.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${vm.serviceToPosQueue.length} Ready for POS Billing',
                        style: const TextStyle(
                          color: AppPalette.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (vm.pendingJobRequests.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${vm.pendingJobRequests.length} awaiting acceptance',
                          style: const TextStyle(
                            color: AppPalette.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Actions Hub: [POS], [Inventory], [Scan], [Drawer]
        const Text(
          'QUICK ACTIONS HUB',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                label: 'POS',
                icon: Icons.point_of_sale_rounded,
                isPrimary: true,
                onTap: onOpenPos,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
                onTap: () => onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                label: 'Scan',
                icon: Icons.qr_code_scanner_rounded,
                onTap: () => BarcodeScannerModal.show(
                  context,
                  autoAddToPosCart: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                label: 'Drawer',
                icon: Icons.account_balance_wallet_outlined,
                onTap: onOpenDrawer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Shift Drawer Balance Audit Card
        Card.filled(
          color: AppPalette.mantle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: AppPalette.champagneGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Drawer Audit • ${vm.activeBranch.shortName}',
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Starting Cash: ${AppFormatters.currency(vm.branchMorningFloat, showDecimals: false)}  |  Cashout: -${AppFormatters.currency(vm.branchCashoutTotal, showDecimals: false)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: vm.branchPhysicalCashInDrawer,
                        ),
                        duration: const Duration(milliseconds: 550),
                        curve: const Cubic(0.05, 0.7, 0.1, 1.0),
                        builder: (context, value, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.currency(value),
                            style: const TextStyle(
                              color: AppPalette.success,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Physical Cash Expected',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pending Inter-Branch Transfer Requests (One-Tap [Approve & Dispatch] or [Reject])
        if (vm.pendingApprovalTransfers.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: AppPalette.warmGold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'PENDING TRANSFER REQUESTS (${vm.pendingApprovalTransfers.length})',
                  style: const TextStyle(
                    color: AppPalette.warmGold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (onOpenTransfers != null)
                TextButton(
                  onPressed: onOpenTransfers,
                  child: const Text('Transfers Hub →', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...vm.pendingApprovalTransfers.map((trf) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card.filled(
                color: AppPalette.surface1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppPalette.warmGold.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trf.id} • ${trf.quantity}x ${trf.partName}',
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${trf.fromBranch.shortName} ➔ ${trf.toBranch.shortName} • Req by ${trf.initiatedBy}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPalette.danger,
                              side: const BorderSide(color: AppPalette.danger),
                            ),
                            onPressed: () =>
                                CashierTransfersTabView.showRejectTransferDialog(
                                  context,
                                  vm,
                                  trf,
                                ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject'),
                          ),
                          M3EButton.filled(
                            size: M3EButtonSize.xs,
                            onPressed: () async {
                              final ok = await vm.approveStockTransfer(trf);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Approved transfer ${trf.id}. Stock dispatched to in-transit.'
                                        : (vm.statusMessage ??
                                            'Transfer approval failed.'),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            child: const Text('Approve & Dispatch'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        // Incoming In-Transit Shipments (One-Tap [Confirm Delivery])
        if (incomingTransfers.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppPalette.warning,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'IN-TRANSIT SHIPMENTS TO ${vm.activeBranch.shortName.toUpperCase()} (${incomingTransfers.length})',
                  style: const TextStyle(
                    color: AppPalette.warning,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (onOpenTransfers != null)
                TextButton(
                  onPressed: onOpenTransfers,
                  child: const Text('Transfers Hub →', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...incomingTransfers.map((trf) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card.filled(
                color: AppPalette.surface1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppPalette.warning.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trf.id} • ${trf.quantity}x ${trf.partName}',
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'From ${trf.fromBranch.shortName} • By ${trf.initiatedBy}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger, size: 18),
                            tooltip: 'Delete Transfer Record',
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Delete Transfer Record?',
                                message: 'Permanently remove stock transfer ${trf.id} (${trf.partName}) from history? This cannot be undone.',
                                confirmLabel: 'Delete',
                                destructive: true,
                              );
                              if (ok && context.mounted) {
                                await vm.deleteStockTransfer(trf.id);
                              }
                            },
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppPalette.danger,
                            ),
                            onPressed: () async {
                              final yes = await showConfirmDialog(
                                context,
                                title: 'Cancel Transfer?',
                                message:
                                    'Cancel in-transit transfer ${trf.id}? ${trf.quantity}x ${trf.partName} will be returned to ${trf.fromBranch.shortName} stock.',
                                confirmLabel: 'Cancel Transfer',
                                destructive: true,
                              );
                              if (!yes || !context.mounted) return;
                              final ok = await vm.cancelStockTransfer(trf);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: ok
                                      ? AppPalette.success
                                      : AppPalette.danger,
                                  content: Text(
                                    ok
                                        ? 'Transfer ${trf.id} cancelled.'
                                        : (vm.statusMessage ??
                                            'Failed to cancel transfer.'),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.block_rounded, size: 16),
                            label: const Text('Cancel'),
                          ),
                          FilledButton.icon(
                            onPressed: () => vm.confirmTransferDelivery(trf),
                            icon: const Icon(Icons.inventory_rounded, size: 16),
                            label: const Text('Confirm Delivery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        // Low-Stock & Overstock Operational Alerts with One-Tap Transfer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'STOCK HEALTH & REPLENISHMENT ALERTS',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNavigateTab(1),
              child: const Text('Master Inventory →'),
            ),
          ],
        ),
        if (lowStock.isEmpty)
          MotoHubEmptyState(
            icon: vm.allInventory.isEmpty
                ? Icons.inventory_2_outlined
                : Icons.verified_outlined,
            title: vm.allInventory.isEmpty
                ? 'Inventory Catalog Starts Clean'
                : 'All Branch Stock Levels Healthy',
            subtitle: vm.allInventory.isEmpty
                ? 'No motorcycle parts have been added yet. Open the Master Inventory tab to register SKUs and initial branch stock.'
                : 'No low-stock threshold alerts for ${vm.activeBranch.shortName}.',
            actionLabel:
                vm.allInventory.isEmpty ? 'Open Master Inventory' : null,
            onAction:
                vm.allInventory.isEmpty ? () => onNavigateTab(1) : null,
          )
        else ...[
          ...lowStock.map((item) {
            final otherBranch = vm.activeBranch == BranchId.patimbao
                ? BranchId.pedroGuevara
                : BranchId.patimbao;
            final otherAvail = item.availableStockFor(otherBranch);
            final availHere = item.availableStockFor(vm.activeBranch);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card.filled(
                color: AppPalette.mantle,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _AdminMasterInventoryTab._showAddEditPartDialog(context, item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppPalette.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppPalette.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${vm.activeBranch.shortName}: $availHere left (${item.shortShelfCoordinates}) • ${otherBranch.shortName} has $otherAvail',
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (otherAvail >= 2)
                          Flexible(
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                              onPressed: () {
                                vm.initiateStockTransfer(
                                  item: item,
                                  fromBranch: otherBranch,
                                  toBranch: vm.activeBranch,
                                  quantity: 2,
                                );
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Pull 2 (${otherBranch.shortName})'),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                              onPressed: () => _AdminMasterInventoryTab._showAddEditPartDialog(context, item),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Restock'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 12),

        // Real-Time Repair Bay Progress Feed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'LIVE REPAIR BAY QUEUE',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNavigateTab(2),
              child: const Text('Open Kanban Board →'),
            ),
          ],
        ),
        if (vm.activeBranchJobOrders.isEmpty)
          MotoHubEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No Incoming Repair Jobs in Queue',
            subtitle:
                'Customer service bookings for ${vm.activeBranch.displayName} will appear here for Admin or Mechanic acceptance into the repair bay.',
            actionLabel: 'Open Jobs & Orders Hub',
            onAction: () => onNavigateTab(2),
          )
        else
          ...vm.activeBranchJobOrders.take(4).map((job) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _JobOrderSummaryCard(job: job),
            );
          }),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppPalette.goldActionGradient : null,
          color: isPrimary ? null : AppPalette.mantle,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: AppPalette.surface0, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? AppPalette.crust : AppPalette.champagneGold,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPrimary ? AppPalette.crust : AppPalette.textHigh,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobOrderSummaryCard extends StatelessWidget {
  final JobOrder job;

  const _JobOrderSummaryCard({required this.job});

  Color _statusColor(JobStatus status) {
    switch (status) {
      case JobStatus.received:
        return AppPalette.textBody;
      case JobStatus.inBay:
        return AppPalette.champagneGold;
      case JobStatus.waitingForParts:
        return AppPalette.danger;
      case JobStatus.readyForPickup:
        return AppPalette.warning;
      case JobStatus.completed:
        return AppPalette.success;
      case JobStatus.cancelled:
        return AppPalette.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MotoHubViewModel>();
    final sColor = _statusColor(job.status);
    final isPendingAccept = job.status == JobStatus.received;

    return Card.filled(
      color: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.surface1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${job.id} • ${job.plateNumber}',
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isPendingAccept
                        ? 'Pending Acceptance'
                        : job.status.label,
                    style: TextStyle(
                      color: sColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              job.bikeModel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Customer: ${job.customerName}  •  Mechanic: ${job.assignedMechanic}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${job.attachedParts.length} Locked Part(s) + Labor • ${AppFormatters.currency(job.totalEstimate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.champagneGold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isPendingAccept)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      if (vm.activeBayBikes.length >= vm.maxBayCapacity) {
                        final proceed = await showConfirmDialog(
                          context,
                          title: 'Lifts at Full Capacity',
                          message: 'All lifts are in use. Accept anyway?',
                          confirmLabel: 'Accept Anyway',
                        );
                        if (!proceed || !context.mounted) return;
                      }
                      final ok = await vm.acceptJobOrder(job.id);
                      if (!context.mounted || !ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Accepted Job Order ${job.id} (${job.plateNumber}) into Repair Bay.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                    ),
                    label: const Text('Accept Job Order'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.champagneGold,
                    side: BorderSide(
                      color: AppPalette.champagneGold.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showAdminEditLaborDialog(context, vm, job),
                  icon: const Icon(Icons.handyman_outlined, size: 15),
                  label: Text(job.laborFee <= 0 ? 'Set Labor' : 'Labor: ₱${job.laborFee.toStringAsFixed(0)}'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.danger,
                    side: const BorderSide(color: AppPalette.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      destructive: true,
                      title: 'Delete Job Order?',
                      message:
                          'Are you sure you want to delete job ${job.id} for ${job.bikeModel}? It will be moved to History as Cancelled, releasing any locked parts.',
                      confirmLabel: 'Delete Job',
                      cancelLabel: 'Keep Job',
                    );
                    if (!ok || !context.mounted) return;
                    final success = await vm.deleteJobOrder(job.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: success ? AppPalette.success : AppPalette.danger,
                        content: Text(
                          vm.statusMessage ?? (success ? 'Job deleted and moved to history.' : 'Failed to delete job.'),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: MASTER INVENTORY HUB (Comparison Table + Shelf Bin + Transfer Modal)
// =============================================================================

class _AdminMasterInventoryTab extends StatelessWidget {
  const _AdminMasterInventoryTab();

  Future<void> _showTransferDialog(BuildContext context, InventoryItem item) async {
    final vm = context.read<MotoHubViewModel>();
    BranchId fromBranch = item.availableStockFor(BranchId.pedroGuevara) >=
            item.availableStockFor(BranchId.patimbao)
        ? BranchId.pedroGuevara
        : BranchId.patimbao;
    BranchId toBranch = fromBranch == BranchId.patimbao
        ? BranchId.pedroGuevara
        : BranchId.patimbao;
    final qtyCtrl = TextEditingController(text: '2');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Initiate Inter-Branch Transfer'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shelf Coordinates: ${item.shelfCoordinates}',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<BranchId>(
                      segments: const [
                        ButtonSegment(
                          value: BranchId.patimbao,
                          label: SlidingMarqueeText(text: 'From Patimbao'),
                        ),
                        ButtonSegment(
                          value: BranchId.pedroGuevara,
                          label: SlidingMarqueeText(text: 'From P. Guevara'),
                        ),
                      ],
                      selected: {fromBranch},
                      onSelectionChanged: (set) {
                        setModalState(() {
                          fromBranch = set.first;
                          toBranch = fromBranch == BranchId.patimbao
                              ? BranchId.pedroGuevara
                              : BranchId.patimbao;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Destination: ${toBranch.displayName} (Available at source: ${item.availableStockFor(fromBranch)})',
                      style: const TextStyle(
                        color: AppPalette.textBody,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      validator: AppValidators.positiveQuantity,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to Transfer',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final qty = int.parse(qtyCtrl.text.trim());
                    final ok = await vm.initiateStockTransfer(
                      item: item,
                      fromBranch: fromBranch,
                      toBranch: toBranch,
                      quantity: qty,
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor:
                            ok ? AppPalette.mantle : AppPalette.danger,
                        content: Text(vm.statusMessage ?? ''),
                      ),
                    );
                  },
                  child: const Text('Dispatch Shipment'),
                ),
              ],
            );
          },
        );
      },
    );
    qtyCtrl.dispose();
  }

  static Future<void> _showAddEditPartDialog(BuildContext context, [InventoryItem? existing]) async {
    final vm = context.read<MotoHubViewModel>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(0) : '',
    );
    final patStockCtrl = TextEditingController(
      text: existing != null ? '${existing.stockPatimbao}' : '0',
    );
    final pgvStockCtrl = TextEditingController(
      text: existing != null ? '${existing.stockPedroGuevara}' : '0',
    );
    final rackCtrl = TextEditingController(text: existing?.rack ?? 'Rack A');
    final shelfCtrl = TextEditingController(text: existing?.shelf ?? 'Shelf 1');
    final binCtrl = TextEditingController(text: existing?.bin ?? 'Bin 01');
    String category = existing?.category ?? 'CVT Tuning';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null
                        ? 'Add New Motorcycle Part / Thai Accessory'
                        : 'Edit Part & Stock Levels',
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    maxLength: AppValidators.maxPartNameLength,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppValidators.maxPartNameLength,
                      ),
                    ],
                    validator: AppValidators.partName,
                    decoration: const InputDecoration(
                      labelText: 'Part Name (max 50 chars)',
                      hintText: 'e.g. Motul 300V 10W-40 1L',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: skuCtrl,
                          maxLength: AppValidators.maxSkuLength,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppValidators.maxSkuLength,
                            ),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9\-_/]'),
                            ),
                          ],
                          validator: (v) => AppValidators.sku(
                            v,
                            existingSkus: vm.allInventory
                                .where((i) => i.id != existing?.id)
                                .map((i) => i.sku),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'SKU (max 24)',
                            hintText: 'e.g. MTL-300V-1L',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: barcodeCtrl,
                          maxLength: AppValidators.maxBarcodeLength,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppValidators.maxBarcodeLength,
                            ),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9\-]'),
                            ),
                          ],
                          validator: (v) => AppValidators.barcode(
                            v,
                            existingBarcodes: vm.allInventory
                                .where((i) => i.id != existing?.id)
                                .map((i) => i.barcode),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Barcode (max 20)',
                            hintText: 'e.g. 88501001',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: category,
                          dropdownColor: AppPalette.mantle,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: MotoHubViewModel.categories
                              .where((c) => c != 'All')
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) category = v;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (v) => AppValidators.positiveAmount(v),
                          decoration: const InputDecoration(
                            labelText: 'Retail Price (₱)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: patStockCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: AppValidators.nonNegativeInt,
                              decoration: const InputDecoration(
                                labelText: 'Patimbao Stock',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [1, 5, 10, 20].map((delta) {
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                  label: Text('+$delta', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  onPressed: () {
                                    final current = int.tryParse(patStockCtrl.text.trim()) ?? 0;
                                    patStockCtrl.text = (current + delta).clamp(0, 99999).toString();
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: pgvStockCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: AppValidators.nonNegativeInt,
                              decoration: const InputDecoration(
                                labelText: 'P. Guevara Stock',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [1, 5, 10, 20].map((delta) {
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                  label: Text('+$delta', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  onPressed: () {
                                    final current = int.tryParse(pgvStockCtrl.text.trim()) ?? 0;
                                    pgvStockCtrl.text = (current + delta).clamp(0, 99999).toString();
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: rackCtrl,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppValidators.maxStorageCoordLength,
                            ),
                          ],
                          validator: (v) =>
                              AppValidators.storageCoordinate(v, 'Rack'),
                          decoration: const InputDecoration(labelText: 'Rack'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: shelfCtrl,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppValidators.maxStorageCoordLength,
                            ),
                          ],
                          validator: (v) =>
                              AppValidators.storageCoordinate(v, 'Shelf'),
                          decoration: const InputDecoration(labelText: 'Shelf'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: binCtrl,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppValidators.maxStorageCoordLength,
                            ),
                          ],
                          validator: (v) =>
                              AppValidators.storageCoordinate(v, 'Bin'),
                          decoration: const InputDecoration(labelText: 'Bin'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GoldGradientButton(
                    label: 'Save to Master Inventory',
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                      final patStock =
                          int.tryParse(patStockCtrl.text.trim()) ?? 0;
                      final pgvStock =
                          int.tryParse(pgvStockCtrl.text.trim()) ?? 0;

                      final newItem = InventoryItem(
                        id: existing?.id ??
                            'PRT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                        sku: skuCtrl.text.trim().toUpperCase(),
                        barcode: barcodeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        category: category,
                        price: price,
                        costPrice: price * 0.72,
                        stockPatimbao: patStock,
                        stockPedroGuevara: pgvStock,
                        lockedPatimbao: existing?.lockedPatimbao ?? 0,
                        lockedPedroGuevara: existing?.lockedPedroGuevara ?? 0,
                        rack: rackCtrl.text.trim(),
                        shelf: shelfCtrl.text.trim(),
                        bin: binCtrl.text.trim(),
                        compatibleModels: existing?.compatibleModels ??
                            'Universal Thai / Scooter',
                        isDeleted: existing?.isDeleted ?? false,
                      );
                      final ok = await vm.addOrUpdateInventoryItem(newItem);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              vm.statusMessage ??
                                  'Saved ${newItem.name} to Master Inventory.',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppPalette.danger,
                            content: Text(
                              vm.statusMessage ??
                                  'Failed to save inventory item.',
                              style: const TextStyle(color: AppPalette.crust),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.champagneGold,
                        side: const BorderSide(color: AppPalette.champagneGold),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        PartBarcodeGeneratorScreen.navigate(context, existing);
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text(
                        'GENERATE QR / BARCODE TAG',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.danger,
                        side: const BorderSide(color: AppPalette.danger),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Delete Stock Item?',
                          message:
                              'Are you sure you want to delete "${existing.name}" (${existing.sku})? This soft-deletes the part from active inventory and POS while preserving past transaction records.',
                          confirmLabel: 'Delete Part',
                          destructive: true,
                        );
                        if (confirmed == true) {
                          final ok = await vm.deleteInventoryItem(existing.id);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${existing.name}" from inventory.'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppPalette.danger,
                                content: Text(vm.statusMessage ?? 'Failed to delete inventory item.'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger),
                      label: const Text(
                        'DELETE PART FROM INVENTORY',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    nameCtrl.dispose();
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    patStockCtrl.dispose();
    pgvStockCtrl.dispose();
    rackCtrl.dispose();
    shelfCtrl.dispose();
    binCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final items = vm.filteredInventory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Material 3 SearchAnchor + SearchBar + Add Part Button
        Row(
          children: [
            Expanded(
              child: SearchAnchor(
                builder: (context, controller) {
                  return SearchBar(
                    controller: controller,
                    hintText: 'Search SKU, Thai parts, or Rack/Bin...',
                    backgroundColor:
                        const WidgetStatePropertyAll(AppPalette.mantle),
                    leading: const Icon(
                      Icons.search_rounded,
                      color: AppPalette.champagneGold,
                    ),
                    trailing: [
                      IconButton(
                        tooltip: 'Scan QR/Barcode',
                        onPressed: () => BarcodeScannerModal.show(context),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppPalette.champagneGold,
                        ),
                      ),
                    ],
                    onChanged: vm.setInventorySearchQuery,
                  );
                },
                suggestionsBuilder: (context, controller) {
                  final q = controller.text.toLowerCase();
                  final matches = vm.allInventory.where(
                    (i) =>
                        i.name.toLowerCase().contains(q) ||
                        i.sku.toLowerCase().contains(q),
                  );
                  return matches.map((item) {
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.sku} • ${item.shelfCoordinates}',
                      ),
                      trailing: Text(AppFormatters.currency(item.price)),
                      onTap: () {
                        controller.closeView(item.name);
                        vm.setInventorySearchQuery(item.name);
                      },
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _showAddEditPartDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Part'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Category FilterChips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MotoHubViewModel.categories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = MotoHubViewModel.categories[index];
              final selected = vm.selectedPosCategory == cat;
              return FilterChip(
                selected: selected,
                label: Text(cat),
                onSelected: (_) => vm.setSelectedPosCategory(cat),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        if (items.isEmpty)
          MotoHubEmptyState(
            icon: Icons.inventory_2_outlined,
            title: vm.allInventory.isEmpty
                ? 'Master Inventory Catalog is Empty'
                : 'No Matching Inventory SKUs',
            subtitle: vm.allInventory.isEmpty
                ? 'Start your clean production database by adding motorcycle parts, Thai accessories, and shelf bin coordinates across Branch 1 and Branch 2.'
                : 'No parts matched the active search query or category filter.',
            actionLabel: '+ Add First Inventory Part',
            onAction: () => _showAddEditPartDialog(context),
          )
        else ...[
          // Comparison Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.surface0),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'PART / DETAILS',
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${vm.activeBranch.shortName.toUpperCase()} STOCK',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 80,
                  child: Text(
                    'ACTIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Real-Time Inventory Rows (M3ECardList)
          M3ECardList(
            itemCount: items.length,
            outerRadius: 24,
            innerRadius: 6,
            gap: 4,
            variant: M3ECardVariant.filled,
            color: AppPalette.mantle,
            border: const BorderSide(color: AppPalette.surface0),
            padding: const EdgeInsets.all(12),
            onTap: (index) => _showAddEditPartDialog(context, items[index]),
            itemBuilder: (context, index) {
              final item = items[index];
              final otherBranch = vm.activeBranch == BranchId.patimbao
                  ? BranchId.pedroGuevara
                  : BranchId.patimbao;
              final activeAvail = item.availableStockFor(vm.activeBranch);
              final activeLocked = vm.activeBranch == BranchId.patimbao
                  ? item.lockedPatimbao
                  : item.lockedPedroGuevara;
              final activeHealth = item.healthFor(vm.activeBranch);
              final otherAvail = item.availableStockFor(otherBranch);

              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: AppPalette.champagneGold,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                item.shelfCoordinates,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.sku} • ${AppFormatters.currency(item.price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${otherBranch.shortName}: $otherAvail in-stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: otherAvail > 0
                                ? AppPalette.textMuted
                                : AppPalette.danger.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Active Branch Stock Cell
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: _StockBadgePill(
                        available: activeAvail,
                        locked: activeLocked,
                        health: activeHealth,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Actions: 2-Row Compact Redesign (~76-80px width)
                  SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Edit / Restock Part',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              onPressed: () => _showAddEditPartDialog(context, item),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: AppPalette.champagneGold,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Generate QR/Barcode Tag',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              onPressed: () =>
                                  PartBarcodeGeneratorScreen.navigate(context, item),
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                color: AppPalette.champagneGold,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Initiate Inter-Branch Transfer',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              onPressed: () => _showTransferDialog(context, item),
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                color: AppPalette.champagneGold,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Delete Part',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              onPressed: () async {
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Delete Stock Item?',
                                  message:
                                      'Are you sure you want to delete "${item.name}" (${item.sku})? This permanently deletes the part from inventory while preserving past transaction records.',
                                  confirmLabel: 'Delete Part',
                                  destructive: true,
                                );
                                if (confirmed == true) {
                                  final ok = await vm.deleteInventoryItem(item.id);
                                  if (context.mounted && ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Deleted "${item.name}" from inventory.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppPalette.danger,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _StockBadgePill extends StatelessWidget {
  final int available;
  final int locked;
  final StockHealth health;

  const _StockBadgePill({
    required this.available,
    required this.locked,
    required this.health,
  });

  Color get _color {
    switch (health) {
      case StockHealth.criticalOut:
        return AppPalette.danger;
      case StockHealth.lowStock:
        return AppPalette.warning;
      case StockHealth.healthy:
        return AppPalette.success;
      case StockHealth.overStock:
        return AppPalette.champagneGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _color.withValues(alpha: 0.5)),
          ),
          child: Text(
            '$available',
            style: TextStyle(
              color: _color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          locked > 0 ? '$locked Locked' : health.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: locked > 0 ? AppPalette.warning : AppPalette.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 3: JOBS & ORDERS HUB (Accept Incoming Customer Job Orders & Click-and-Collect Orders)
// =============================================================================

class _AdminJobsKanbanTab extends StatefulWidget {
  const _AdminJobsKanbanTab();

  @override
  State<_AdminJobsKanbanTab> createState() => _AdminJobsKanbanTabState();
}

class _AdminJobsKanbanTabState extends State<_AdminJobsKanbanTab> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final jobs = vm.filteredBranchJobOrders;
    final pendingJobsCount = vm.pendingJobRequests.length;
    final clickCollectOrders = vm.clickCollectOrders
        .where((o) => o.pickupBranch == vm.activeBranch)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jobs & Orders Acceptance Hub • ${vm.activeBranch.shortName}',
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Accept incoming Customer Service Bookings & Click-and-Collect Orders',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pendingJobsCount > 0
                    ? AppPalette.warning.withValues(alpha: 0.16)
                    : AppPalette.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pendingJobsCount > 0
                      ? AppPalette.warning.withValues(alpha: 0.6)
                      : AppPalette.surface0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 15,
                    color: pendingJobsCount > 0
                        ? AppPalette.warning
                        : AppPalette.champagneGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$pendingJobsCount Pending Acceptance',
                    style: TextStyle(
                      color: pendingJobsCount > 0
                          ? AppPalette.warning
                          : AppPalette.champagneGold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Incoming Customer Click & Collect Orders Queue (Material 3 Expressive M3ECardList)
        // Incoming Customer Click & Collect Orders Queue
        Row(
          children: [
            const Expanded(
              child: Text(
                'INCOMING CLICK & COLLECT PART ORDERS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => ClickAndCollectHistoryScreen.push(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.surface1,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.surface2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: AppPalette.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'History (${clickCollectOrders.length})',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (clickCollectOrders.any((o) => o.isCompleted || o.isCancelled || o.isExpired)) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete All Past Reservations?',
                    message:
                        'Permanently delete all completed, cancelled, and expired reservation records? Active reservations will not be affected.',
                    confirmLabel: 'Delete All Past',
                    destructive: true,
                  );
                  if (confirmed && context.mounted) {
                    final count = await vm.deleteAllPastClickAndCollectHistory();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppPalette.success,
                          content: Text('Cleared $count past reservation record(s).'),
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 14, color: AppPalette.danger),
                      SizedBox(width: 4),
                      Text(
                        'Delete Past',
                        style: TextStyle(
                          color: AppPalette.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (clickCollectOrders.isEmpty)
          Card.filled(
            color: AppPalette.mantle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.surface0),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: AppPalette.champagneGold,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Active Click & Collect Reservations',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customer parts reserved via the Rider App will appear here for confirmation, pickup readiness, and POS handoff.',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          M3ECardList(
            itemCount: clickCollectOrders.length,
            outerRadius: 24,
            innerRadius: 6,
            gap: 4,
            variant: M3ECardVariant.filled,
            color: AppPalette.mantle,
            border: const BorderSide(color: AppPalette.surface0),
            padding: const EdgeInsets.all(14),
            itemBuilder: (context, index) {
              final order = clickCollectOrders[index];
              Color statusColor;
              if (order.isCompleted) {
                statusColor = AppPalette.textMuted;
              } else if (order.isReady) {
                statusColor = AppPalette.success;
              } else if (order.isConfirmed) {
                statusColor = AppPalette.champagneGold;
              } else if (order.isCancelled || order.isExpired) {
                statusColor = AppPalette.danger;
              } else {
                statusColor = AppPalette.warning; // Pending
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.id} • ${order.quantity}x ${order.partName}',
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Customer: ${order.customerName} (${order.customerPhone}) • ${AppFormatters.currency(order.totalAmount)}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (order.canStaffConfirm)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () async {
                            final ok = await vm.confirmClickAndCollectOrder(order.id);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppPalette.success,
                                  content: Text('Confirmed reservation ${order.id}.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                          ),
                          child: const Text('Confirm'),
                        ),
                      if (order.canStaffMarkReady)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () async {
                            final ok = await vm.markReadyClickAndCollectOrder(order.id);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppPalette.success,
                                  content: Text('Reservation ${order.id} marked Ready for Pickup.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                          ),
                          child: const Text('Mark Ready'),
                        ),
                      if (order.canStaffComplete)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () {
                            final ok = vm.handoffReservationToPos(order);
                            if (ok && context.mounted) {
                              CheckoutScreen.push(context);
                            }
                          },
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 16,
                          ),
                          child: const Text('Tender in POS'),
                        ),
                      if (!order.isCancelled && !order.isCompleted && !order.isExpired)
                        M3EButton.tonal(
                          size: M3EButtonSize.xs,
                          onPressed: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Cancel Reservation?',
                              message:
                                  'Cancel reservation ${order.id} for ${order.customerName}? Held stock will be released.',
                              confirmLabel: 'Cancel Reservation',
                              destructive: true,
                            );
                            if (confirmed && context.mounted) {
                              final ok = await vm.cancelClickAndCollectOrder(order.id);
                              if (context.mounted && ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cancelled reservation ${order.id}.'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppPalette.danger,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppPalette.danger),
                          ),
                        ),
                      M3EButton.tonal(
                        size: M3EButtonSize.xs,
                        onPressed: () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Delete Reservation Record?',
                            message:
                                'Permanently delete record ${order.id} for ${order.customerName}? This action cannot be undone.',
                            confirmLabel: 'Delete Record',
                            destructive: true,
                          );
                          if (confirmed && context.mounted) {
                            final ok = await vm.deleteClickAndCollectOrder(order.id);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reservation record ${order.id} deleted.'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppPalette.danger,
                        ),
                        child: const Text(
                          'Delete Record',
                          style: TextStyle(color: AppPalette.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

        // 5-Stage Lifecycle FilterChips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChip(
                selected: vm.selectedJobStatusFilter == null,
                label: Text('All (${vm.branchJobOrders.length})'),
                onSelected: (_) => vm.setSelectedJobStatusFilter(null),
              ),
              const SizedBox(width: 8),
              ...JobStatus.values.map((st) {
                final count =
                    vm.branchJobOrders.where((j) => j.status == st).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: vm.selectedJobStatusFilter == st,
                    label: Text('${st.label} ($count)'),
                    onSelected: (_) => vm.setSelectedJobStatusFilter(st),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Material 3 Expressive M3ECardList for Job Orders
        M3ECardList(
          itemCount: jobs.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(14),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No Customer Job Orders in Queue',
            subtitle:
                'No repair job orders found for ${vm.activeBranch.displayName} in this stage. When customers book a service appointment in the Customer App, it will appear here to be accepted.',
          ),
          itemBuilder: (context, index) {
            final job = jobs[index];
            final isPendingAccept = job.status == JobStatus.received;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.surface1,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${job.id} • ${job.plateNumber}',
                            style: const TextStyle(
                              color: AppPalette.champagneGold,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Lift: ${job.assignedMechanic}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.warmGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.currency(job.totalEstimate),
                      style: const TextStyle(
                        color: AppPalette.success,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${job.bikeModel} — ${job.serviceType}',
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      job.laborFee <= 0
                          ? 'Labor: TBD + Parts: ${AppFormatters.currency(job.partsSubtotal, showDecimals: false)}'
                          : 'Labor: ${AppFormatters.currency(job.laborFee, showDecimals: false)} + Parts: ${AppFormatters.currency(job.partsSubtotal, showDecimals: false)}',
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showAdminEditLaborDialog(context, vm, job),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppPalette.champagneGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined, size: 12, color: AppPalette.champagneGold),
                            const SizedBox(width: 4),
                            Text(
                              job.laborFee <= 0 ? 'Set Labor' : 'Change Labor',
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${job.customerName} (${job.customerPhone}) • ${job.preferredSchedule}',
                  style: const TextStyle(
                    color: AppPalette.warmGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.issueDescription,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                if (job.attachedParts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: job.attachedParts
                        .map(
                          (p) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.crust,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppPalette.surface0),
                            ),
                            child: Text(
                              '🔒 ${p.quantity}x ${p.name} (${AppFormatters.currency(p.lineTotal, showDecimals: false)})',
                              style: const TextStyle(
                                color: AppPalette.textBody,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),

                // Primary Accept Button for Incoming Customer Job Orders
                if (isPendingAccept) ...[
                  SizedBox(
                    width: double.infinity,
                    child: M3EButton.filled(
                      size: M3EButtonSize.sm,
                      onPressed: () async {
                        if (vm.activeBayBikes.length >= vm.maxBayCapacity) {
                          final proceed = await showConfirmDialog(
                            context,
                            title: 'Lifts at Full Capacity',
                            message: 'All lifts are in use. Accept anyway?',
                            confirmLabel: 'Accept Anyway',
                          );
                          if (!proceed || !context.mounted) return;
                        }
                        final ok = await vm.acceptJobOrder(job.id);
                        if (!context.mounted || !ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Accepted Job Order ${job.id} (${job.plateNumber}) into Repair Bay!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      child: const Text('Accept Job Order into Bay'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Interactive 5-Stage Lifecycle Stepper Controls
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: JobStatus.values.map((st) {
                      final isCurrent = job.status == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: isCurrent,
                          label: Text(
                            st.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          onSelected: (_) =>
                              vm.updateJobOrderStatus(job.id, st),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.danger,
                      side: const BorderSide(color: AppPalette.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        destructive: true,
                        title: 'Delete Job Order?',
                        message:
                            'Are you sure you want to delete job ${job.id} for ${job.bikeModel}? It will be moved to History as Cancelled, releasing any locked parts.',
                        confirmLabel: 'Delete Job',
                        cancelLabel: 'Keep Job',
                      );
                      if (!ok || !context.mounted) return;
                      final success = await vm.deleteJobOrder(job.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: success ? AppPalette.success : AppPalette.danger,
                          content: Text(
                            vm.statusMessage ?? (success ? 'Job deleted and moved to history.' : 'Failed to delete job.'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Job'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showAdminEditLaborDialog(
  BuildContext context,
  MotoHubViewModel vm,
  JobOrder job,
) async {
  final laborCtrl = TextEditingController(
    text: job.laborFee.toStringAsFixed(0),
  );
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppPalette.surface1),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.handyman_rounded,
            color: AppPalette.champagneGold,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Change Labor Fee • ${job.id}',
              style: const TextStyle(
                color: AppPalette.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${job.bikeModel} (${job.plateNumber}) • Customer: ${job.customerName}',
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: laborCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: AppPalette.champagneGold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                labelText: 'Labor Fee',
                prefixText: '₱ ',
                suffixText: 'PHP',
                helperText: 'Admin adjustable labor rate for this repair job',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a labor fee';
                }
                final val = double.tryParse(v.trim());
                if (val == null || val < 0) {
                  return 'Enter a valid non-negative amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppPalette.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.champagneGold,
            foregroundColor: AppPalette.crust,
          ),
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final newFee =
                double.tryParse(laborCtrl.text.trim()) ?? job.laborFee;
            Navigator.of(ctx).pop();
            final success = await vm.updateJobLaborFee(
              jobId: job.id,
              laborFee: newFee,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor:
                    success ? AppPalette.success : AppPalette.danger,
                content: Text(
                  success
                      ? 'Updated labor fee for ${job.id} to ₱${newFee.toStringAsFixed(2)}.'
                      : (vm.statusMessage ?? 'Failed to update labor fee.'),
                ),
              ),
            );
          },
          child: const Text(
            'Save Labor Fee',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
