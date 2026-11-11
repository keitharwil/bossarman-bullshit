import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/confirm_dialog.dart';
import '../checkout/checkout_screen.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/m3e_motion.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../login_screen.dart';
import '../shared/barcode_scanner_modal.dart';
import '../shared/inventory_sync_chip.dart';
import '../shared/notifications_sheet.dart';
import '../shared/receipt_preview_modal.dart';
import '../shared/user_avatar.dart';
import '../shared/reservation_queue_section.dart';
import '../shared/app_drawer.dart';

class CashierShellScreen extends StatefulWidget {
  const CashierShellScreen({super.key});

  @override
  State<CashierShellScreen> createState() => _CashierShellScreenState();
}

class _CashierShellScreenState extends State<CashierShellScreen> {
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final tabs = [
      const CashierPosTabView(),
      const _CashierServiceBillingTab(),
      const CashierDrawerTabView(),
      const CashierTransfersTabView(),
      const _CashierShiftProfileTab(),
    ];

    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Open Menu',
            icon: const Icon(
              Icons.menu_rounded,
              color: AppPalette.champagneGold,
              size: 24,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.surface1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppPalette.champagneGold.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppPalette.champagneGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POS & Drawer • ${vm.currentUser?.fullName ?? "Keith Umali"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${vm.activeBranch.displayName} (${vm.activeBranch.terminalId})',
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
          ],
        ),
        actions: [
          // Assigned Branch Badge (Locked — Only Admin can change assignment)
          Tooltip(
            message:
                'Assigned Branch: ${vm.activeBranch.displayName} (Only Admin can change assignment)',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Assigned to ${vm.activeBranch.displayName}. Only the Admin can change your branch assignment.',
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.mantle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppPalette.champagneGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: AppPalette.champagneGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vm.activeBranch.shortName,
                      style: const TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const InventorySyncChip(compact: true),
          const NotificationBellAction(
            roleSubtitle: 'Cashier POS, Drawer & Transfer Alerts',
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: AppDrawer(
        selectedIndex: safeIndex,
        onSelectTab: (i) {
          setState(() => _selectedIndex = i);
          if (i == 0) vm.syncInventory();
        },
      ),
      body: M3ETabSwitcher(index: safeIndex, children: tabs),
    );
  }
}

// =============================================================================
// TAB 1: RETAIL POS + TOTAL SALES CARD (Physical Cash vs. GCash Vault)
// =============================================================================

class CashierPosTabView extends StatelessWidget {
  const CashierPosTabView({super.key});

  void _openCheckoutModal(BuildContext context) {
    final vm = context.read<MotoHubViewModel>();
    if (vm.cart.isEmpty) return;
    CheckoutScreen.push(context);
  }

  static void _showReceiptDialog(BuildContext context, PosTransaction tx) {
    ReceiptPreviewModal.show(context, tx);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final items = vm.filteredInventory;
    final isBranchLocked = vm.currentUser != null &&
        (vm.currentUser!.role == UserRole.cashier ||
            vm.currentUser!.role == UserRole.mechanic);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              if (!isBranchLocked)
                SegmentedButton<BranchId>(
                  segments: const [
                    ButtonSegment(
                      value: BranchId.patimbao,
                      label: SlidingMarqueeText(text: 'Branch 1: Patimbao'),
                      icon: Icon(Icons.storefront_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: BranchId.pedroGuevara,
                      label: SlidingMarqueeText(text: 'Branch 2: P. Guevara'),
                      icon: Icon(Icons.location_on_outlined, size: 16),
                    ),
                  ],
                  selected: {vm.activeBranch},
                  onSelectionChanged: (set) => vm.switchBranch(set.first),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.mantle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppPalette.champagneGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: AppPalette.champagneGold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assigned Branch: ${vm.activeBranch.displayName} (${vm.activeBranch.terminalId}) • Only Admin can change assignment',
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Total Sales Card: Strict separation of Physical Cash in Drawer vs. GCash Vault
              Card.filled(
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
                              'SHIFT GROSS REVENUE TRACKER',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.currency(vm.branchTodayGross),
                            style: const TextStyle(
                              color: AppPalette.champagneGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppPalette.crust,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppPalette.success.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.point_of_sale_rounded,
                                        size: 14,
                                        color: AppPalette.success,
                                      ),
                                      SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          'Physical Cash in Drawer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppPalette.textMuted,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppFormatters.currency(
                                        vm.branchPhysicalCashInDrawer,
                                      ),
                                      style: const TextStyle(
                                        color: AppPalette.success,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppPalette.crust,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppPalette.champagneGold
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.phonelink_ring_rounded,
                                        size: 14,
                                        color: AppPalette.champagneGold,
                                      ),
                                      SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          'GCash Digital Vault',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppPalette.textMuted,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppFormatters.currency(
                                        vm.branchGcashVaultTotal,
                                      ),
                                      style: const TextStyle(
                                        color: AppPalette.champagneGold,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Material 3 SearchBar + Barcode Scanner Button
              SearchBar(
                hintText: 'Search Thai parts, oils, bolts, or scan barcode...',
                backgroundColor:
                    const WidgetStatePropertyAll(AppPalette.mantle),
                leading: const Icon(
                  Icons.search_rounded,
                  color: AppPalette.champagneGold,
                ),
                trailing: [
                  IconButton(
                    tooltip: 'Scan SKU Barcode',
                    onPressed: () => BarcodeScannerModal.show(
                      context,
                      autoAddToPosCart: true,
                    ),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppPalette.champagneGold,
                    ),
                  ),
                ],
                onChanged: vm.setInventorySearchQuery,
              ),
              const SizedBox(height: 10),

              // Category Pills
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MotoHubViewModel.categories.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = MotoHubViewModel.categories[index];
                    return FilterChip(
                      selected: vm.selectedPosCategory == cat,
                      label: Text(cat),
                      onSelected: (_) => vm.setSelectedPosCategory(cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Product Catalog List with Material 3 Expressive M3ECardList
              M3ECardList(
                itemCount: items.length,
                outerRadius: 24,
                innerRadius: 6,
                gap: 4,
                variant: M3ECardVariant.filled,
                color: AppPalette.mantle,
                border: const BorderSide(color: AppPalette.surface0),
                padding: const EdgeInsets.all(12),
                emptyBuilder: MotoHubEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: vm.allInventory.isEmpty
                      ? 'No POS Catalog Items Registered Yet'
                      : 'No Matching Parts Found',
                  subtitle: vm.allInventory.isEmpty
                      ? 'The store inventory catalog starts clean. Ask Admin Boss Arman to register parts in the Master Inventory tab.'
                      : 'No parts matched your current search or category filter.',
                  actionLabel: vm.inventorySearchQuery.isNotEmpty
                      ? 'Reset Filter'
                      : null,
                  onAction: vm.inventorySearchQuery.isNotEmpty
                      ? () => vm.setInventorySearchQuery('')
                      : null,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final avail = item.availableStockFor(vm.activeBranch);
                  final locked = item.lockedStockFor(vm.activeBranch);

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item.sku}  •  📍 ${item.shelfCoordinates}',
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Available: $avail units${locked > 0 ? " ($locked Locked in Bay)" : ""}',
                              style: TextStyle(
                                color: avail > 0
                                    ? AppPalette.success
                                    : AppPalette.danger,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(item.price),
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: AppPalette.champagneGold,
                                  size: 18,
                                ),
                                tooltip: 'Request Inter-Branch Transfer',
                                onPressed: isBranchLocked
                                    ? null
                                    : () => CashierTransfersTabView.showRequestTransferSheet(
                                          context,
                                          vm,
                                          initialItem: item,
                                        ),
                              ),
                              const SizedBox(width: 4),
                              M3EButton.tonal(
                                size: M3EButtonSize.xs,
                                onPressed: avail > 0
                                    ? () => vm.addToCart(item)
                                    : isBranchLocked
                                        ? null
                                        : () => CashierTransfersTabView.showRequestTransferSheet(
                                              context,
                                              vm,
                                              initialItem: item,
                                            ),
                                icon: Icon(
                                  avail > 0
                                      ? Icons.add_shopping_cart_rounded
                                      : isBranchLocked
                                          ? Icons.block_rounded
                                          : Icons.swap_horiz_rounded,
                                  size: 16,
                                ),
                                child: Text(
                                  avail > 0
                                      ? 'Add'
                                      : isBranchLocked
                                          ? 'No Stock'
                                          : 'Request Stock',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Interactive Active Cart Drawer Bar
        if (vm.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: AppPalette.surface1,
              border: Border(
                top: BorderSide(color: AppPalette.champagneGold, width: 1.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.cart.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = vm.cart[index];
                      return Chip(
                        label: Text(
                          '${c.quantity}x ${c.item.name.split(" (").first}',
                        ),
                        onDeleted: () =>
                            vm.updateCartQuantity(c.item.id, c.quantity - 1),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vm.cartItemCount} Item(s) in Counter Cart',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          AppFormatters.currency(vm.cartTotal),
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: vm.clearCart,
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 6),
                        M3EButton.filled(
                          size: M3EButtonSize.sm,
                          onPressed: () => _openCheckoutModal(context),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          child: const Text('Checkout Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// TAB 2: SERVICE-TO-POS AUTO-BILLING QUEUE
// =============================================================================

class _CashierServiceBillingTab extends StatelessWidget {
  const _CashierServiceBillingTab();

  Future<void> _billServiceJob(
    BuildContext context,
    MotoHubViewModel vm,
    JobOrder job,
    PaymentMethod method,
  ) async {
    final tx = await vm.processServiceJobCheckout(
      job: job,
      paymentMethod: method,
      amountTendered: job.totalEstimate,
      gcashRef: method == PaymentMethod.gcash ? 'GC-SVC-${job.id}' : null,
    );
    if (!context.mounted) return;
    if (tx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            vm.statusMessage ?? 'Service billing failed.',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      return;
    }
    CashierPosTabView._showReceiptDialog(context, tx);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final queueList = vm.branchJobOrders
        .where((j) => !j.isBilled && j.status != JobStatus.completed)
        .toList()
      ..sort((a, b) {
        final aReady = a.status == JobStatus.readyForPickup ? 0 : 1;
        final bReady = b.status == JobStatus.readyForPickup ? 0 : 1;
        if (aReady != bReady) return aReady.compareTo(bReady);
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        const ReservationQueueSection(),
        const SizedBox(height: 22),
        const Text(
          'Service-to-POS Auto-Billing Queue',
          style: TextStyle(
            color: AppPalette.textHigh,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'One-tap atomic checkout combining mechanic-locked parts + labor fees.',
          style: TextStyle(color: AppPalette.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        M3ECardList(
          itemCount: queueList.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(16),
          emptyBuilder: const MotoHubEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Unbilled Service Job Orders',
            subtitle:
                'When a mechanic marks a repair ticket Ready for Pickup, it automatically queues here with locked parts and labor bundled.',
          ),
          itemBuilder: (context, index) {
            final job = queueList[index];
            final isReadyToBill = job.status == JobStatus.readyForPickup;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${job.id} • ${job.plateNumber}',
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isReadyToBill
                                ? AppPalette.success
                                : AppPalette.warning)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.status.label,
                        style: TextStyle(
                          color: isReadyToBill
                              ? AppPalette.success
                              : AppPalette.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${job.bikeModel} — ${job.customerName}',
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Mechanic: ${job.assignedMechanic} • ${job.serviceType}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 20),
                ...job.attachedParts.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${p.quantity}x ${p.name}',
                            style: const TextStyle(
                              color: AppPalette.textBody,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.currency(p.lineTotal),
                          style: const TextStyle(
                            color: AppPalette.textHigh,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mechanic Service Labor Fee:',
                      style: TextStyle(
                        color: AppPalette.textBody,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(job.effectiveLaborFee),
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL ITEMIZED BILL:',
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(job.totalEstimate),
                      style: const TextStyle(
                        color: AppPalette.success,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isReadyToBill)
                  Row(
                    children: [
                      Expanded(
                        child: M3EButton.filled(
                          size: M3EButtonSize.sm,
                          onPressed: () => _billServiceJob(
                            context,
                            vm,
                            job,
                            PaymentMethod.cash,
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Bill via Cash'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: M3EButton.tonal(
                          size: M3EButtonSize.sm,
                          onPressed: () => _billServiceJob(
                            context,
                            vm,
                            job,
                            PaymentMethod.gcash,
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Bill via GCash'),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.surface0),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.handyman_outlined,
                          size: 16,
                          color: AppPalette.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'In Service Bay (${job.status.label}) — POS checkout unlocks once Mechanic marks Ready for Pickup.',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

// =============================================================================
// TAB 3: THE DRAWER (Float, Petty Cash Out, Denomination Counter & Shortage Override)
// =============================================================================

/// Ordered denomination constants for cashier drawer physical cash count:
/// Bills: ₱1,000, ₱500, ₱200, ₱100, ₱50, ₱20 (Bill / Coin)
/// Coins: ₱10, ₱5, ₱1
const List<int> kCashDrawerBillDenominations = [1000, 500, 200, 100, 50, 20];
const List<int> kCashDrawerCoinDenominations = [10, 5, 1];
const List<int> kCashDrawerAllDenominations = [1000, 500, 200, 100, 50, 20, 10, 5, 1];

/// Pure greedy breakdown of a peso amount across standard denominations:
/// [1000, 500, 200, 100, 50, 20, 10, 5, 1].
///
/// Any amount <= 0 is treated as 0 (all counts 0). Leftover centavos are ignored (truncated to whole pesos).
/// The remainder in whole pesos is always 0 because ₱1 is included in the list.
Map<int, int> calculateGreedyDenominations(double expected) {
  final Map<int, int> result = {
    for (final d in kCashDrawerAllDenominations) d: 0,
  };

  if (expected <= 0) {
    return result;
  }

  int rem = expected.toInt();

  for (final denom in kCashDrawerAllDenominations) {
    if (rem >= denom) {
      result[denom] = rem ~/ denom;
      rem %= denom;
    }
  }

  return result;
}

class CashierDrawerTabView extends StatefulWidget {
  const CashierDrawerTabView({super.key});

  @override
  State<CashierDrawerTabView> createState() => _CashierDrawerTabViewState();
}

class _CashierDrawerTabViewState extends State<CashierDrawerTabView> {
  // Initialized to 0 so a fresh shift starts with ₱0.00 counted cash (no mock counts).
  final Map<int, int> _denomCounts = {
    for (final d in kCashDrawerAllDenominations) d: 0,
  };

  double get _countedTotal {
    double total = 0;
    _denomCounts.forEach((denom, count) {
      total += denom * count;
    });
    return total;
  }

  void _resetCounts() {
    setState(() {
      for (final d in kCashDrawerAllDenominations) {
        _denomCounts[d] = 0;
      }
    });
  }

  String _getDenomLabel(int denom) {
    switch (denom) {
      case 1000:
        return '₱1,000 Bill';
      case 500:
        return '₱500 Bill';
      case 200:
        return '₱200 Bill';
      case 100:
        return '₱100 Bill';
      case 50:
        return '₱50 Bill';
      case 20:
        return '₱20 Bill / Coin';
      case 10:
        return '₱10 Coin';
      case 5:
        return '₱5 Coin';
      case 1:
        return '₱1 Coin';
      default:
        return '₱$denom';
    }
  }

  Future<void> _showEditCountDialog(int denom) async {
    final current = _denomCounts[denom] ?? 0;
    final controller = TextEditingController(text: current == 0 ? '' : '$current');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.mantle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.surface1),
        ),
        title: Text(
          'Set ${_getDenomLabel(denom)} Quantity',
          style: const TextStyle(
            color: AppPalette.textHigh,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5), // max 99,999
          ],
          style: const TextStyle(
            color: AppPalette.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: AppPalette.textMuted),
            helperText: 'Max: 99,999 (empty = 0)',
            helperStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            prefixIcon: const Icon(Icons.pin_rounded, color: AppPalette.champagneGold),
            filled: true,
            fillColor: AppPalette.surface1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppPalette.surface0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppPalette.champagneGold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.champagneGold,
              foregroundColor: AppPalette.crust,
            ),
            onPressed: () {
              final text = controller.text.trim();
              final val = text.isEmpty ? 0 : int.tryParse(text) ?? 0;
              final clamped = val.clamp(0, 99999);
              Navigator.of(ctx).pop(clamped);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && mounted) {
      setState(() {
        _denomCounts[denom] = result;
      });
    }
  }

  Future<void> _showCashoutDialog(BuildContext context, MotoHubViewModel vm) async {
    final availableCash = vm.branchPhysicalCashInDrawer;
    if (availableCash <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Cannot record Cashout: Physical cash in ${vm.activeBranch.shortName} drawer is ${AppFormatters.currency(availableCash)}.',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final currentDrawerCash = vm.branchPhysicalCashInDrawer;
        return AlertDialog(
          title: const Text('Record Cashout'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppPalette.success.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: AppPalette.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Physical Cash in Drawer: ${AppFormatters.currency(currentDrawerCash)}',
                          style: const TextStyle(
                            color: AppPalette.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  validator: (v) =>
                      AppValidators.requiredField(v, 'Expense description'),
                  decoration: const InputDecoration(
                    labelText: 'Shop Supply / Cashout Reason',
                    hintText: 'e.g., Carburetor Cleaner & Shop Rags',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    final baseErr = AppValidators.positiveAmount(val);
                    if (baseErr != null) return baseErr;
                    final parsed = double.tryParse((val ?? '').trim()) ?? 0;
                    final liveDrawer = vm.branchPhysicalCashInDrawer;
                    if (parsed > liveDrawer) {
                      return 'Exceeds physical cash in drawer (${AppFormatters.currency(liveDrawer)})';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount (₱)',
                    hintText: '150.00',
                    helperText:
                        'Max allowed: ${AppFormatters.currency(currentDrawerCash)}',
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
                final amount = double.tryParse(amtCtrl.text.trim()) ?? 0;
                if (amount > vm.branchPhysicalCashInDrawer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppPalette.danger,
                      content: Text(
                        'Cashout (${AppFormatters.currency(amount)}) cannot exceed physical cash in drawer (${AppFormatters.currency(vm.branchPhysicalCashInDrawer)}).',
                        style: const TextStyle(color: AppPalette.crust),
                      ),
                    ),
                  );
                  return;
                }
                final ok = await vm.recordCashout(
                  description: reasonCtrl.text.trim(),
                  amount: amount,
                );
                if (!ctx.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppPalette.danger,
                      content: Text(
                        vm.statusMessage ??
                            'Cashout rejected: exceeds physical cash in drawer.',
                        style: const TextStyle(color: AppPalette.crust),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cashout (${AppFormatters.currency(amount)}) deducted from drawer. Remaining cash: ${AppFormatters.currency(vm.branchPhysicalCashInDrawer)}.',
                    ),
                  ),
                );
              },
              child: const Text('Deduct from Drawer'),
            ),
          ],
        );
      },
    );
    reasonCtrl.dispose();
    amtCtrl.dispose();
  }

  Future<void> _handleReconcileAudit(BuildContext context, MotoHubViewModel vm) async {
    final expected = vm.branchPhysicalCashInDrawer;
    final counted = _countedTotal;
    final variance = counted - expected;

    if (variance < 0) {
      // Defensive Guard: Cash Drawer Shortage Alert requiring Admin Override!
      final adminPassCtrl = TextEditingController();
      String? errorText;

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.gpp_maybe_rounded, color: AppPalette.danger),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cash Drawer Shortage Alert!',
                    style: TextStyle(color: AppPalette.danger),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physical count (${AppFormatters.currency(counted)}) is SHORT by ${AppFormatters.currency(variance.abs())} compared to system expected cash (${AppFormatters.currency(expected)}).',
                    style: const TextStyle(color: AppPalette.textBody),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Admin Override Required (Boss Arman Password: admin123):',
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: adminPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Admin Override Password',
                      errorText: errorText,
                      prefixIcon:
                          const Icon(Icons.admin_panel_settings_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Recount Bills'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.danger,
                  foregroundColor: AppPalette.crust,
                ),
                onPressed: () async {
                  if (!vm.verifyAdminOverridePassword(adminPassCtrl.text)) {
                    setDialogState(() {
                      errorText = 'Invalid Admin password (use admin123)';
                    });
                    return;
                  }
                  await vm.logShiftReconciliationAudit(
                    countedCash: counted,
                    expectedCash: expected,
                    adminOverrideBy: 'Boss Arman Sarita',
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  _resetCounts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Shortage audit logged with Boss Arman Admin Override.',
                      ),
                    ),
                  );
                },
                child: const Text('Authorize Shortage Override'),
              ),
            ],
          ),
        ),
      );
      adminPassCtrl.dispose();
    } else {
      await vm.logShiftReconciliationAudit(
        countedCash: counted,
        expectedCash: expected,
      );
      _resetCounts();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            variance == 0
                ? 'Exact Match! ₱0.00 Variance Audit Logged.'
                : 'Shift Audit Logged (Overage: +${AppFormatters.currency(variance)}).',
          ),
        ),
      );
    }
  }

  Widget _buildDenomRow(int denom) {
    final count = _denomCounts[denom] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 95,
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppPalette.surface1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _getDenomLabel(denom),
                style: const TextStyle(
                  color: AppPalette.champagneGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            onPressed: count > 0
                ? () => setState(
                      () => _denomCounts[denom] = count - 1,
                    )
                : null,
            icon: const Icon(Icons.remove, size: 15),
          ),
          Tooltip(
            message: 'Tap to type quantity directly',
            child: InkWell(
              onTap: () => _showEditCountDialog(denom),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                constraints: const BoxConstraints(minWidth: 32),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.surface1.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppPalette.surface0,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            onPressed: () =>
                setState(() => _denomCounts[denom] = (count + 1).clamp(0, 99999)),
            icon: const Icon(Icons.add, size: 15),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                AppFormatters.currency((denom * count).toDouble()),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppPalette.textHigh,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final expected = vm.branchPhysicalCashInDrawer;
    final variance = _countedTotal - expected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Drawer Summary Header (Responsive Wrap for 360dp widths)
        Card.filled(
          color: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppPalette.surface1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPECTED PHYSICAL CASH (${vm.activeBranch.shortName.toUpperCase()})',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppFormatters.currency(expected),
                        style: const TextStyle(
                          color: AppPalette.success,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => vm.addMorningFloat(500),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('+₱500 Starting Cash'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showCashoutDialog(context, vm),
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      label: const Text('Cashout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cash Count (₱1000, ₱500, ₱200, ₱100, ₱50, ₱20, ₱10, ₱5, ₱1)
        Card.filled(
          color: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppPalette.surface1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Cash Count',
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (vm.currentUser?.role == UserRole.admin)
                      TextButton(
                        onPressed: () {
                          final filled = calculateGreedyDenominations(expected);
                          setState(() {
                            _denomCounts.addAll(filled);
                          });
                        },
                        child: const Text('Auto-fill (admin only)'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bills Section Header (₱1,000 to ₱20)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(
                    'BILLS',
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...kCashDrawerBillDenominations.map(_buildDenomRow),

                // Coins Section Header (₱10 to ₱1)
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 6),
                  child: Text(
                    'COINS',
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...kCashDrawerCoinDenominations.map(_buildDenomRow),

                const Divider(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Counted Total: ${AppFormatters.currency(_countedTotal)}',
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (variance >= 0 ? AppPalette.success : AppPalette.danger)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Over / Short: ${variance > 0 ? "+" : ""}${AppFormatters.currency(variance)}',
                        style: TextStyle(
                          color: variance >= 0
                              ? AppPalette.success
                              : AppPalette.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GoldGradientButton(
                  label: variance < 0
                      ? 'Submit Shortage Audit (Admin Override)'
                      : 'Close Shift & Reconcile',
                  icon: Icons.verified_user_outlined,
                  onPressed: () => _handleReconcileAudit(context, vm),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Real-Time Cash Ledger (Material 3 Expressive M3ECardList)
        const Text(
          'REAL-TIME CASH DRAWER LEDGER',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        M3ECardList(
          itemCount: vm.branchCashLedger.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 3,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No Cash Drawer Entries Yet',
            subtitle:
                'Tap "+₱500 Starting Cash" to log your opening drawer cash fund or complete a POS transaction.',
            actionLabel: 'Add ₱500 Starting Cash',
            onAction: () => vm.addMorningFloat(500),
          ),
          itemBuilder: (context, index) {
            final entry = vm.branchCashLedger[index];
            final isPositive = entry.amount >= 0;
            final isAdmin = vm.currentUser?.role == UserRole.admin;
            return Dismissible(
              key: ValueKey('cash_ledger_${entry.id}'),
              direction: isAdmin ? DismissDirection.horizontal : DismissDirection.none,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppPalette.danger.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppPalette.danger,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Dismiss Entry',
                      style: TextStyle(
                        color: AppPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppPalette.danger.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dismiss Entry',
                      style: TextStyle(
                        color: AppPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppPalette.danger,
                      size: 20,
                    ),
                  ],
                ),
              ),
              confirmDismiss: (_) async {
                if (!isAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppPalette.danger,
                      content: Text('Access denied: Only Admins can modify cash flow records.'),
                    ),
                  );
                  return false;
                }
                return await showConfirmDialog(
                  context,
                  title: 'Dismiss Cash Ledger Entry?',
                  message:
                      'Remove entry "${entry.description}" (${isPositive ? "+" : ""}${AppFormatters.currency(entry.amount)}) from this active drawer view?',
                  confirmLabel: 'Dismiss',
                  destructive: true,
                );
              },
              onDismissed: (_) async {
                await vm.deleteCashLedgerEntry(entry.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppPalette.surface1,
                      content: Text('Dismissed cash entry "${entry.description}".'),
                    ),
                  );
                }
              },
              child: M3EListItem(
                overline:
                    '${entry.type.label.toUpperCase()} • ${AppFormatters.timeOnly(entry.createdAt)}',
                headline: entry.description,
                supportingText: 'Logged by ${entry.staffName}',
                leading: CircleAvatar(
                  backgroundColor: isPositive
                      ? AppPalette.success.withValues(alpha: 0.14)
                      : AppPalette.danger.withValues(alpha: 0.14),
                  child: Icon(
                    isPositive
                        ? Icons.call_received_rounded
                        : Icons.call_made_rounded,
                    color: isPositive ? AppPalette.success : AppPalette.danger,
                    size: 18,
                  ),
                ),
                trailing: Text(
                  '${isPositive ? "+" : ""}${AppFormatters.currency(entry.amount)}',
                  style: TextStyle(
                    color: isPositive ? AppPalette.success : AppPalette.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 4: NOTIFICATIONS & INTER-BRANCH TRANSFER CONFIRMATIONS
// =============================================================================

class CashierTransfersTabView extends StatelessWidget {
  const CashierTransfersTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final transfers = vm.allTransfers
        .where((t) =>
            t.toBranch == vm.activeBranch || t.fromBranch == vm.activeBranch)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text(
          'Shipments & Delivery Handshake • ${vm.activeBranch.shortName}',
          style: const TextStyle(
            color: AppPalette.textHigh,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Monitoring transfers for ${vm.activeBranch.displayName}. Tap [Confirm Delivery] on incoming shipments to credit local stock.',
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        GoldGradientButton(
          label: 'Request Stock from Other Branch',
          icon: Icons.swap_horiz_rounded,
          onPressed: () => showRequestTransferSheet(context, vm),
        ),
        const SizedBox(height: 14),
        M3ECardList(
          itemCount: transfers.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(14),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'No Transfers for ${vm.activeBranch.shortName}',
            subtitle:
                'Stock transfers involving ${vm.activeBranch.displayName} will appear here for delivery confirmation.',
          ),
          itemBuilder: (context, index) {
            final trf = transfers[index];
            final isTransit = trf.status == TransferStatus.inTransit;
            final isIncomingHere = trf.toBranch == vm.activeBranch;
            final isPending = trf.status == TransferStatus.pendingApproval;
            final isRejected = trf.status == TransferStatus.rejected;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${trf.id} • ${trf.sku}',
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isTransit
                            ? AppPalette.warning.withValues(alpha: 0.16)
                            : (isPending
                                ? AppPalette.warmGold.withValues(alpha: 0.16)
                                : (isRejected
                                    ? AppPalette.danger.withValues(alpha: 0.16)
                                    : AppPalette.success.withValues(alpha: 0.16))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trf.status.label,
                        style: TextStyle(
                          color: isTransit
                              ? AppPalette.warning
                              : (isPending
                                  ? AppPalette.warmGold
                                  : (isRejected
                                      ? AppPalette.danger
                                      : AppPalette.success)),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${trf.quantity}x ${trf.partName}',
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trf.fromBranch.shortName} ➔ ${trf.toBranch.shortName}  •  Initiated by ${trf.initiatedBy}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (trf.status == TransferStatus.pendingApproval &&
                    (trf.fromBranch == vm.activeBranch ||
                        vm.currentUser?.role == UserRole.admin)) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                          side: const BorderSide(color: AppPalette.danger),
                        ),
                        onPressed: () =>
                            showRejectTransferDialog(context, vm, trf),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject Request'),
                      ),
                      const SizedBox(width: 8),
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
                if (isTransit && isIncomingHere) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: M3EButton.filled(
                      size: M3EButtonSize.xs,
                      onPressed: () => vm.confirmStockTransferReceipt(trf),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      child: const Text('Confirm Receipt & Restock'),
                    ),
                  ),
                ],
                if ((trf.status == TransferStatus.pendingApproval ||
                        (isTransit &&
                            vm.currentUser?.role == UserRole.admin)) &&
                    (vm.currentUser?.role == UserRole.admin ||
                        trf.fromBranch == vm.activeBranch ||
                        trf.toBranch == vm.activeBranch)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppPalette.danger,
                      ),
                      onPressed: () async {
                        final yes = await showConfirmDialog(
                          context,
                          title: 'Cancel Transfer?',
                          message: isTransit
                              ? 'Cancel in-transit transfer ${trf.id}? ${trf.quantity}x ${trf.partName} will be returned to ${trf.fromBranch.shortName} stock.'
                              : 'Cancel transfer request ${trf.id} (${trf.quantity}x ${trf.partName})?',
                          confirmLabel: 'Cancel Transfer',
                          destructive: true,
                        );
                        if (!yes || !context.mounted) return;
                        final ok = await vm.cancelStockTransfer(trf);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor:
                                ok ? AppPalette.success : AppPalette.danger,
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
                      label: const Text('Cancel Transfer'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  static Future<void> showRejectTransferDialog(
    BuildContext context,
    MotoHubViewModel vm,
    StockTransfer trf,
  ) async {
    final reasonCtrl =
        TextEditingController(text: 'Insufficient source shelf buffer');
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Stock Transfer Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfer ${trf.id}: ${trf.quantity}x ${trf.partName}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Needed for active repair in bay',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.danger),
            onPressed: () => Navigator.of(ctx).pop(reasonCtrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !context.mounted) return;

    final yes = await showConfirmDialog(
      context,
      title: 'Reject Transfer?',
      message:
          'Reject transfer ${trf.id} (${trf.quantity}x ${trf.partName})?\nReason: ${reason.isEmpty ? '—' : reason}',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!yes || !context.mounted) return;

    final ok = await vm.rejectStockTransfer(trf, reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Transfer request rejected.'
              : (vm.statusMessage ?? 'Failed to reject transfer.'),
        ),
      ),
    );
  }

  static void showRequestTransferSheet(
    BuildContext context,
    MotoHubViewModel vm, {
    InventoryItem? initialItem,
  }) {
    final targetBranch = vm.activeBranch == BranchId.patimbao
        ? BranchId.patimbao
        : BranchId.pedroGuevara;
    final otherBranch = targetBranch == BranchId.patimbao
        ? BranchId.pedroGuevara
        : BranchId.patimbao;

    final activeItems =
        vm.allInventory.where((i) => !i.isDeleted).toList();
    InventoryItem? selectedItem = initialItem ??
        (activeItems.isNotEmpty ? activeItems.first : null);
    final qtyCtrl = TextEditingController(text: '2');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final otherAvail = selectedItem?.availableStockFor(otherBranch) ?? 0;
            final currentAvail =
                selectedItem?.availableStockFor(targetBranch) ?? 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.swap_horiz_rounded,
                                  color: AppPalette.champagneGold, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Request Inter-Branch Transfer',
                                style: TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Request stock to be transferred from ${otherBranch.displayName} into ${targetBranch.displayName}.',
                        style: const TextStyle(
                            color: AppPalette.textMuted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 16),

                      // Part Selector
                      const Text(
                        'Select Motorcycle Part / Consumable',
                        style: TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppPalette.surface0,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppPalette.surface2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<InventoryItem>(
                            value: selectedItem,
                            isExpanded: true,
                            dropdownColor: AppPalette.surface0,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppPalette.champagneGold),
                            items: activeItems.map((item) {
                              return DropdownMenuItem<InventoryItem>(
                                value: item,
                                child: Text(
                                  '${item.name} (${item.sku})',
                                  style: const TextStyle(
                                    color: AppPalette.textHigh,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (item) {
                              if (item != null) {
                                setSheetState(() {
                                  selectedItem = item;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Stock Comparison Card
                      if (selectedItem != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppPalette.surface1,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppPalette.champagneGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Source (${otherBranch.shortName}):',
                                    style: const TextStyle(
                                        color: AppPalette.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    '$otherAvail available',
                                    style: TextStyle(
                                      color: otherAvail > 0
                                          ? AppPalette.success
                                          : AppPalette.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Destination (${targetBranch.shortName}):',
                                    style: const TextStyle(
                                        color: AppPalette.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    '$currentAvail currently in stock',
                                    style: const TextStyle(
                                      color: AppPalette.textHigh,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedItem!.shelfCoordinates.isNotEmpty) ...[
                                const Divider(color: AppPalette.surface2, height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.shelves,
                                        size: 14, color: AppPalette.champagneGold),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Shelf Location: ${selectedItem!.shelfCoordinates}',
                                      style: const TextStyle(
                                          color: AppPalette.textMuted, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Quantity Input
                      TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final parsed = int.tryParse(v?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a positive quantity';
                          }
                          if (selectedItem != null && parsed > otherAvail) {
                            return 'Cannot request $parsed: only $otherAvail available at ${otherBranch.shortName}';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Quantity to Request',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      GoldGradientButton(
                        label: 'Send Transfer Request to ${otherBranch.shortName}',
                        icon: Icons.send_rounded,
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          if (selectedItem == null) return;
                          final qty = int.parse(qtyCtrl.text.trim());
                          final ok = await vm.requestStockTransfer(
                            item: selectedItem!,
                            fromBranch: otherBranch,
                            toBranch: targetBranch,
                            quantity: qty,
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor:
                                  ok ? AppPalette.surface1 : AppPalette.danger,
                              content: Text(
                                ok
                                    ? 'Transfer request sent to ${otherBranch.displayName} for approval.'
                                    : (vm.statusMessage ??
                                        'Failed to send transfer request.'),
                                style: const TextStyle(color: AppPalette.textHigh),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// TAB 5: ME / SHIFT PROFILE & Z-READING REPORT GENERATOR
// =============================================================================

class _CashierShiftProfileTab extends StatelessWidget {
  const _CashierShiftProfileTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Card.filled(
          color: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppPalette.surface1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;
                final signOutBtn = OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: 'You will need to sign in again to continue.',
                      confirmLabel: 'Sign Out',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    await vm.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign Out'),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          user: user,
                          radius: 26,
                          isEditable: true,
                          onEditPhoto: () =>
                              UserAvatar.showPhotoPickerSheet(context),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Keith Arwil P. Umali',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Lead Cashier • ${vm.activeBranch.displayName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 14),
                          signOutBtn,
                        ],
                      ],
                    ),
                    if (isCompact) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: signOutBtn,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Z-Reading Report Card
        Card.filled(
          color: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppPalette.surface1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'OFFICIAL Z-READING SHIFT REPORT',
                      style: TextStyle(
                        color: AppPalette.champagneGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      vm.activeBranch.terminalId,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _ZRow(
                  label: 'Opening Starting Cash',
                  value: AppFormatters.currency(vm.branchMorningFloat),
                ),
                _ZRow(
                  label: 'Gross Cash Sales (Retail + Service)',
                  value: AppFormatters.currency(vm.branchCashSalesTotal),
                ),
                _ZRow(
                  label: 'GCash Digital Vault Collections',
                  value: AppFormatters.currency(vm.branchGcashVaultTotal),
                ),
                _ZRow(
                  label: 'Less: Cashouts',
                  value:
                      '-${AppFormatters.currency(vm.branchCashoutTotal)}',
                ),
                const Divider(height: 24),
                _ZRow(
                  label: 'TOTAL GROSS SHIFT REVENUE',
                  value: AppFormatters.currency(vm.branchTodayGross),
                  highlight: true,
                ),
                _ZRow(
                  label: 'EXPECTED PHYSICAL CASH IN DRAWER',
                  value: AppFormatters.currency(vm.branchPhysicalCashInDrawer),
                  highlight: true,
                ),
                const SizedBox(height: 14),
                GoldGradientButton(
                  label: 'Generate & Export Z-Reading Audit Slip',
                  icon: Icons.print_outlined,
                  onPressed: () async {
                    final record = await vm.generateZReadingReport(
                      actualPhysicalCash: vm.branchPhysicalCashInDrawer,
                      reconciliationNote: 'Shift reconciliation via Cashier Profile',
                    );
                    if (!context.mounted) return;
                    if (record == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppPalette.danger,
                          content: Text(
                            vm.statusMessage ?? 'Z-Reading failed to save.',
                            style: const TextStyle(color: AppPalette.crust),
                          ),
                        ),
                      );
                      return;
                    }
                    _showZReadingReceipt(context, record);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Saved Z-Reading History (immutable audit trail)
        const Text(
          'SAVED Z-READING HISTORY',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        M3ECardList(
          itemCount: vm.branchZReadings.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 3,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          emptyBuilder: const MotoHubEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Z-Readings Archived Yet',
            subtitle:
                'Tap "Generate & Export Z-Reading Audit Slip" to permanently archive this shift\'s totals for owner/BIR review.',
          ),
          onTap: (index) =>
              _showZReadingReceipt(context, vm.branchZReadings[index]),
          itemBuilder: (context, index) {
            final z = vm.branchZReadings[index];
            return M3EListItem(
              overline:
                  '${z.id} • ${AppFormatters.dateTimeShort(z.generatedAt)}',
              headline:
                  'Gross ${AppFormatters.currency(z.totalGrossRevenue)} • ${z.totalTransactions} txn',
              supportingText:
                  'Drawer: ${AppFormatters.currency(z.expectedPhysicalCash)} • By ${z.generatedBy}',
              leading: const CircleAvatar(
                backgroundColor: AppPalette.surface1,
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: AppPalette.champagneGold,
                  size: 18,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textMuted,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ZRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ZRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlight ? AppPalette.textHigh : AppPalette.textMuted,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                fontSize: highlight ? 13.5 : 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  color: highlight ? AppPalette.champagneGold : AppPalette.textHigh,
                  fontWeight: FontWeight.w800,
                  fontSize: highlight ? 15 : 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


void _showZReadingReceipt(BuildContext context, ZReadingRecord z) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded,
              color: AppPalette.champagneGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Z-Reading ${z.id}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BOSS ARMAN MOTOHUB',
                style: TextStyle(
                    color: AppPalette.champagneGold,
                    fontWeight: FontWeight.w800)),
            Text(z.branch.fullAddress,
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 11)),
            Text('Terminal: ${z.terminalId}',
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 11)),
            Text('Cashier: ${z.generatedBy}',
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 11)),
            Text('Generated: ${AppFormatters.dateTimeShort(z.generatedAt)}',
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 11)),
            const Divider(height: 20),
            _ZRow(
                label: 'Opening Starting Cash',
                value: AppFormatters.currency(z.morningFloat)),
            _ZRow(
                label: 'Gross Cash Sales',
                value: AppFormatters.currency(z.grossCashSales)),
            _ZRow(
                label: 'GCash Digital Vault',
                value: AppFormatters.currency(z.gcashVaultCollections)),
            _ZRow(
                label: 'Less: Cashouts',
                value: '-${AppFormatters.currency(z.cashoutOutflows)}'),
            const Divider(height: 20),
            _ZRow(
                label: 'TOTAL GROSS REVENUE',
                value: AppFormatters.currency(z.totalGrossRevenue),
                highlight: true),
            _ZRow(
                label: 'EXPECTED PHYSICAL CASH',
                value: AppFormatters.currency(z.expectedPhysicalCash),
                highlight: true),
            if (z.actualPhysicalCash > 0) ...[
              _ZRow(
                label: 'ACTUAL COUNTED CASH',
                value: AppFormatters.currency(z.actualPhysicalCash),
              ),
              _ZRow(
                label: 'RECONCILIATION VARIANCE',
                value: z.cashDiscrepancy == 0
                    ? 'EXACT MATCH (₱0.00)'
                    : AppFormatters.currency(z.cashDiscrepancy),
                highlight: z.cashDiscrepancy != 0,
              ),
            ],
            const Divider(height: 20),
            Text('Transactions: ${z.totalTransactions}',
                style: const TextStyle(
                    color: AppPalette.textMuted, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}