import 'package:flutter/material.dart';
import '../shared/confirm_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../login_screen.dart';
import '../shared/barcode_scanner_modal.dart';
import '../shared/inventory_sync_chip.dart';
import '../shared/notifications_sheet.dart';
import '../shared/user_avatar.dart';
import '../shared/app_drawer.dart';
import '../../core/theme/m3e_motion.dart';

class MechanicShellScreen extends StatefulWidget {
  const MechanicShellScreen({super.key});

  @override
  State<MechanicShellScreen> createState() => _MechanicShellScreenState();
}

class _MechanicShellScreenState extends State<MechanicShellScreen> {
  int _selectedIndex = 0;
  String? _selectedWorkbenchJobId;

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
    final jobs = vm.branchJobOrders;
    final activeJobId =
        _selectedWorkbenchJobId ?? (jobs.isNotEmpty ? jobs.first.id : null);

    // 4 bottom tabs (Alerts moved to top-right AppBar beside QR Scanner)
    final pages = [
      _MechanicBayJobsBoardTab(
        onSelectForWorkbench: (jobId) {
          setState(() {
            _selectedWorkbenchJobId = jobId;
            _selectedIndex = 1;
          });
        },
      ),
      _MechanicWorkbenchTab(
        selectedJobId: activeJobId,
        onJobChanged: (id) => setState(() => _selectedWorkbenchJobId = id),
      ),
      _MechanicShelfBinHudTab(activeJobId: activeJobId),
      const _MechanicProfileLogsTab(),
    ];

    final safeIndex = _selectedIndex.clamp(0, pages.length - 1);

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
                Icons.handyman_rounded,
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
                    'Bay Workbench • ${vm.currentUser?.fullName ?? "Lance M. Aclan"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${vm.activeBranch.displayName} • ${vm.activeBayBikes.length}/${vm.maxBayCapacity} Lifts Active',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
                margin: const EdgeInsets.only(right: 4),
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
          // Moved Alerts / Notifications Bell to top-right beside QR Scanner
          const NotificationBellAction(
            roleSubtitle: 'Mechanic Bay & Parts Alerts',
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: AppDrawer(
        selectedIndex: safeIndex,
        onSelectTab: (i) {
          setState(() => _selectedIndex = i);
          if (i == 2) vm.syncInventory();
        },
      ),
      body: M3ETabSwitcher(index: safeIndex, children: pages),
    );
  }
}

// =============================================================================
// TAB 1: ACTIVE BAY JOBS BOARD (Accept Incoming Customer Jobs + 5-Stage Lifecycle)
// =============================================================================

class _MechanicBayJobsBoardTab extends StatelessWidget {
  final ValueChanged<String> onSelectForWorkbench;

  const _MechanicBayJobsBoardTab({required this.onSelectForWorkbench});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final jobs = vm.filteredBranchJobOrders;
    final pendingCount = vm.pendingJobRequests.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Read-Only Assigned Branch Banner (Mechanic is strictly locked to 1 branch; only Admin can change)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        const SizedBox(height: 14),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming Job Orders & Bay Board',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Accept Customer Bookings ➔ In Bay ➔ Parts ➔ Ready',
                  style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pendingCount > 0
                    ? AppPalette.warning.withValues(alpha: 0.16)
                    : AppPalette.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pendingCount > 0
                      ? AppPalette.warning.withValues(alpha: 0.6)
                      : AppPalette.surface0,
                ),
              ),
              child: Text(
                '$pendingCount Pending to Accept',
                style: TextStyle(
                  color: pendingCount > 0
                      ? AppPalette.warning
                      : AppPalette.champagneGold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Status Filter Chips
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
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: vm.selectedJobStatusFilter == st,
                    label: Text(st.label),
                    onSelected: (_) => vm.setSelectedJobStatusFilter(st),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Material 3 Expressive M3ECardList for Bay Job Orders
        M3ECardList(
          itemCount: jobs.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0, width: 1),
          padding: const EdgeInsets.all(14),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No Customer Job Orders in Queue',
            subtitle:
                '${vm.activeBranch.displayName} currently has no incoming customer service bookings matching this filter. When a customer books a repair in the Customer App, it will appear here for you to accept.',
          ),
          itemBuilder: (context, index) {
            final job = jobs[index];
            final step = job.status.stepIndex;
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPendingAccept
                              ? AppPalette.warning
                              : AppPalette.champagneGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${job.id} • ${job.plateNumber}',
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(job.totalEstimate),
                      style: const TextStyle(
                        color: AppPalette.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  job.bikeModel,
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${job.serviceType} • Customer: ${job.customerName} (${job.customerPhone})',
                  style: const TextStyle(
                    color: AppPalette.warmGold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.issueDescription,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),

                // 5-Stage Lifecycle Visual Progress Bar
                Row(
                  children: List.generate(JobStatus.pipelineStages.length, (idx) {
                    final active = step >= 0 && idx <= step;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppPalette.champagneGold
                              : AppPalette.surface0,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // Stage Transition Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: JobStatus.values.map((st) {
                      final selected = job.status == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(
                            st.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onSelected: (_) =>
                              vm.updateJobOrderStatus(job.id, st),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 18),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '🔒 ${job.attachedParts.length} Part(s) Locked • Labor: ${AppFormatters.currency(job.effectiveLaborFee, showDecimals: false)}',
                      style: const TextStyle(
                        color: AppPalette.textBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isPendingAccept)
                          M3EButton.filled(
                            size: M3EButtonSize.xs,
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
                                    'Accepted Job Order ${job.id} (${job.plateNumber}) into your Repair Bay!',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                            ),
                            child: const Text('Accept Job Order'),
                          ),
                        M3EButton.tonal(
                          size: M3EButtonSize.xs,
                          onPressed: () => onSelectForWorkbench(job.id),
                          icon: const Icon(Icons.build_rounded, size: 16),
                          child: const Text('Attach Parts & Labor'),
                        ),
                        M3EButton.tonal(
                          size: M3EButtonSize.xs,
                          onPressed: () async {
                            final ok = await showConfirmDialog(
                              context,
                              destructive: true,
                              title: 'Cancel / Delete Job?',
                              message:
                                  'Are you sure you want to cancel job ${job.id} for ${job.bikeModel}? It will be moved to History as Cancelled, and any locked parts will be released.',
                              confirmLabel: 'Cancel Job',
                              cancelLabel: 'Keep Job',
                            );
                            if (!ok || !context.mounted) return;
                            final success = await vm.deleteJobOrder(job.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: success ? AppPalette.success : AppPalette.danger,
                                content: Text(
                                  vm.statusMessage ??
                                      (success
                                          ? 'Job cancelled and moved to history.'
                                          : 'Failed to cancel job.'),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppPalette.danger,
                          ),
                          child: const Text(
                            'Cancel Job',
                            style: TextStyle(color: AppPalette.danger),
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
    );
  }
}

// =============================================================================
// TAB 2: PARTS ATTACHMENT ENGINE + LABOR FEE LOGGER WORKBENCH
// =============================================================================

class _MechanicWorkbenchTab extends StatefulWidget {
  final String? selectedJobId;
  final ValueChanged<String> onJobChanged;

  const _MechanicWorkbenchTab({
    required this.selectedJobId,
    required this.onJobChanged,
  });

  @override
  State<_MechanicWorkbenchTab> createState() => _MechanicWorkbenchTabState();
}

class _MechanicWorkbenchTabState extends State<_MechanicWorkbenchTab> {
  final _laborCtrl = TextEditingController();
  final _extraNoteCtrl = TextEditingController();
  final _extraFeeCtrl = TextEditingController();
  String? _syncedJobId;

  @override
  void dispose() {
    _laborCtrl.dispose();
    _extraNoteCtrl.dispose();
    _extraFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final jobs = vm.branchJobOrders;
    if (jobs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: const [
          MotoHubEmptyState(
            icon: Icons.handyman_outlined,
            title: 'Workbench Idle — No Active Bay Jobs',
            subtitle:
                'Accept an incoming customer service booking from the Bay Board tab first to lock parts from the shelf bin catalog and log service labor fees.',
          ),
        ],
      );
    }

    final currentJob = jobs.firstWhere(
      (j) => j.id == widget.selectedJobId,
      orElse: () => jobs.first,
    );

    if (_syncedJobId != currentJob.id) {
      _syncedJobId = currentJob.id;
      _laborCtrl.text = currentJob.laborFee.toStringAsFixed(0);
      _extraNoteCtrl.text = currentJob.extraRepairNote ?? '';
      _extraFeeCtrl.text = currentJob.extraRepairFee > 0
          ? currentJob.extraRepairFee.toStringAsFixed(0)
          : '';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Job Selector Dropdown
        M3ECard(
          variant: M3ECardVariant.filled,
          color: AppPalette.surface1,
          borderRadius: BorderRadius.circular(18),
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentJob.id,
              isExpanded: true,
              dropdownColor: AppPalette.mantle,
              items: jobs.map((j) {
                return DropdownMenuItem(
                  value: j.id,
                  child: Text(
                    '${j.id} • ${j.bikeModel} (${j.plateNumber}) — ${j.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) widget.onJobChanged(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Locked Parts Card + Quick Attach Buttons
        M3ECard(
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          borderRadius: BorderRadius.circular(24),
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parts Attachment & Stock Lock Engine',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Locks stock to this Job Order so Cashiers cannot sell it',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Scan QR/Barcode to Lock Part',
                    onPressed: () => BarcodeScannerModal.show(
                      context,
                      targetJobOrderId: currentJob.id,
                    ),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppPalette.champagneGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Material 3 Expressive M3ECardList for Currently Locked Parts
              M3ECardList(
                itemCount: currentJob.attachedParts.length,
                outerRadius: 18,
                innerRadius: 6,
                gap: 3,
                variant: M3ECardVariant.filled,
                color: AppPalette.crust,
                border: const BorderSide(color: AppPalette.surface0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                emptyBuilder: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.crust,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'No parts locked yet. Tap a part below or scan QR/barcode to lock.',
                    style: TextStyle(color: AppPalette.textMuted),
                  ),
                ),
                itemBuilder: (context, index) {
                  final ap = currentJob.attachedParts[index];
                  return Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: AppPalette.champagneGold,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ap.quantity}x ${ap.name}',
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${ap.sku} • 📍 ${ap.shelfCoordinates}',
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppFormatters.currency(ap.lineTotal),
                          style: const TextStyle(
                            color: AppPalette.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Release Lock',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => vm.removeAttachedPartFromJob(
                          jobId: currentJob.id,
                          partId: ap.partId,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppPalette.danger,
                          size: 18,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const Divider(height: 22),
              const Text(
                'ONE-TAP ATTACH & LOCK FROM LOCAL STOCK:',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              if (vm.allInventory.isEmpty)
                const Text(
                  'No parts in inventory yet. Add parts via Admin Inventory Catalog.',
                  style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vm.allInventory.take(6).map((part) {
                    final avail = part.availableStockFor(currentJob.branch);
                    return ActionChip(
                      avatar: Icon(
                        avail > 0 ? Icons.lock_open_rounded : Icons.block,
                        size: 15,
                        color: avail > 0
                            ? AppPalette.champagneGold
                            : AppPalette.danger,
                      ),
                      label: Text(
                        '${part.name.split(" (").first} ($avail left)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: avail > 0
                          ? () => vm.attachPartToJobOrder(
                                jobId: currentJob.id,
                                part: part,
                              )
                          : null,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Labor Fee Logger + Push to Cashier POS
        M3ECard(
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          borderRadius: BorderRadius.circular(24),
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mechanic Labor Fee Logger & Service-to-POS Push',
                style: TextStyle(
                  color: AppPalette.textHigh,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _laborCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Service Labor Fee (₱)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _extraNoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Extra Repair Recommendation (Optional)',
                        hintText: 'e.g. Replace worn drive belt',
                        prefixIcon: Icon(Icons.build_circle_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _extraFeeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '+Extra Fee (₱)',
                      ),
                    ),
                  ),
                ],
              ),
              if (currentJob.extraRepairNote != null &&
                  currentJob.extraRepairNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (currentJob.extraRepairApproved
                            ? AppPalette.success
                            : AppPalette.warning)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: currentJob.extraRepairApproved
                          ? AppPalette.success
                          : AppPalette.warning,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentJob.extraRepairApproved
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        size: 16,
                        color: currentJob.extraRepairApproved
                            ? AppPalette.success
                            : AppPalette.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentJob.extraRepairApproved
                              ? 'Customer Approved: "${currentJob.extraRepairNote}" (+${AppFormatters.currency(currentJob.extraRepairFee, showDecimals: false)}) included in bill.'
                              : 'Awaiting Customer Approval: "${currentJob.extraRepairNote}" (+${AppFormatters.currency(currentJob.extraRepairFee, showDecimals: false)})',
                          style: TextStyle(
                            color: currentJob.extraRepairApproved
                                ? AppPalette.success
                                : AppPalette.warning,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: M3EButton.tonal(
                  size: M3EButtonSize.md,
                  onPressed: () async {
                    final parsed = double.tryParse(_laborCtrl.text.trim());
                    if (parsed == null ||
                        parsed.isNaN ||
                        parsed.isInfinite ||
                        parsed < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppPalette.danger,
                          content: Text(
                            'Enter a valid non-negative labor fee.',
                            style: TextStyle(color: AppPalette.crust),
                          ),
                        ),
                      );
                      return;
                    }
                    final extraNote = _extraNoteCtrl.text.trim();
                    final extraFeeText = _extraFeeCtrl.text.trim();
                    final parsedExtraFee = extraFeeText.isEmpty
                        ? 0.0
                        : double.tryParse(extraFeeText);
                    if (parsedExtraFee == null ||
                        parsedExtraFee.isNaN ||
                        parsedExtraFee.isInfinite ||
                        parsedExtraFee < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppPalette.danger,
                          content: Text(
                            'Enter a valid non-negative extra repair fee.',
                            style: TextStyle(color: AppPalette.crust),
                          ),
                        ),
                      );
                      return;
                    }
                    await vm.updateJobLaborFee(
                      jobId: currentJob.id,
                      laborFee: parsed,
                      extraRepairNote: extraNote,
                      extraRepairFee: extraNote.isEmpty ? 0.0 : parsedExtraFee,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          vm.statusMessage ?? 'Labor & repair quote updated.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  child: const Text('Save Labor & Repair Quote'),
                ),
              ),
              const Divider(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Parts Subtotal: ${AppFormatters.currency(currentJob.partsSubtotal)}\nLabor Fee: ${AppFormatters.currency(currentJob.effectiveLaborFee)}',
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'BUNDLED POS BILL',
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        AppFormatters.currency(currentJob.totalEstimate),
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GoldGradientButton(
                label:
                    'Mark Ready & Push to POS (${AppFormatters.currency(currentJob.totalEstimate)})',
                icon: Icons.send_rounded,
                onPressed: () async {
                  await vm.updateJobOrderStatus(
                    currentJob.id,
                    JobStatus.readyForPickup,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${currentJob.id} pushed to Cashier POS Auto-Billing queue!',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 3: INVENTORY & SHELF BIN SEARCH HUD (`Rack B • Shelf 2 • Bin 04`)
// =============================================================================

class _MechanicShelfBinHudTab extends StatelessWidget {
  final String? activeJobId;

  const _MechanicShelfBinHudTab({this.activeJobId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final items = vm.filteredInventory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        SearchBar(
          hintText: 'Search part name, SKU, or Rack/Shelf/Bin...',
          backgroundColor: const WidgetStatePropertyAll(AppPalette.mantle),
          leading: const Icon(
            Icons.shelves,
            color: AppPalette.champagneGold,
          ),
          trailing: [
            IconButton(
              onPressed: () => BarcodeScannerModal.show(
                context,
                targetJobOrderId: activeJobId,
              ),
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppPalette.champagneGold,
              ),
            ),
          ],
          onChanged: vm.setInventorySearchQuery,
        ),
        const SizedBox(height: 14),
        M3ECardList(
          itemCount: items.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(14),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.shelves,
            title: 'No Shelf Bin Parts Found',
            subtitle: vm.allInventory.isEmpty
                ? 'The inventory catalog is currently empty. Add parts via the Admin Inventory Catalog to view Rack, Shelf, and Bin coordinates.'
                : 'No parts matched your search query.',
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final availHere = item.availableStockFor(vm.activeBranch);
            final lockedHere = item.lockedStockFor(vm.activeBranch);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Warehouse Shelf Coordinate HUD Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppPalette.champagneGold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 15,
                        color: AppPalette.champagneGold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.shelfCoordinates,
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'SKU: ${item.sku} • Fits: ${item.compatibleModels}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppFormatters.currency(item.price),
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${vm.activeBranch.displayName}: $availHere avail${lockedHere > 0 ? " ($lockedHere locked in bay)" : ""}',
                      style: TextStyle(
                        color: availHere > 0
                            ? AppPalette.success
                            : AppPalette.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (activeJobId != null && availHere > 0)
                      M3EButton.tonal(
                        size: M3EButtonSize.xs,
                        onPressed: () => vm.attachPartToJobOrder(
                          jobId: activeJobId!,
                          part: item,
                        ),
                        icon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                        ),
                        child: Text('Lock to $activeJobId'),
                      ),
                  ],
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
// TAB 4: ME / DAILY COMPLETED JOB HISTORY & EFFICIENCY LOGS
// =============================================================================

class _MechanicProfileLogsTab extends StatelessWidget {
  const _MechanicProfileLogsTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final myJobs = vm.branchJobOrders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        M3ECard(
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          borderRadius: BorderRadius.circular(24),
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final signOutBtn = M3EButton.outlined(
                size: M3EButtonSize.sm,
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
                child: const Text('Sign Out'),
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
                              user?.fullName ?? 'Lance M. Aclan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Lead Motorcycle & Thai Build Technician • ${vm.activeBranch.shortName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 12,
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
        const SizedBox(height: 16),
        const Text(
          'DAILY BAY TURNAROUND & JOB LOGS',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        M3ECardList(
          itemCount: myJobs.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 3,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          emptyBuilder: const MotoHubEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No Bay Job Logs Recorded Yet',
            subtitle:
                'Completed and active repair orders for this branch will be listed here.',
          ),
          itemBuilder: (context, index) {
            final j = myJobs[index];
            return M3EListItem(
              overline: 'STATUS: ${j.status.label.toUpperCase()}',
              headline: '${j.id} • ${j.bikeModel} (${j.plateNumber})',
              supportingText: '${j.serviceType} • Customer: ${j.customerName}',
              leading: const Icon(
                Icons.two_wheeler_rounded,
                color: AppPalette.champagneGold,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppFormatters.currency(j.totalEstimate),
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppPalette.danger,
                      size: 20,
                    ),
                    tooltip: 'Cancel / Delete Job Order',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        destructive: true,
                        title: 'Cancel / Delete Job?',
                        message:
                            'Are you sure you want to cancel job ${j.id} for ${j.bikeModel}? It will be moved to History as Cancelled, and any locked parts will be released.',
                        confirmLabel: 'Delete Job',
                        cancelLabel: 'Keep Job',
                      );
                      if (!ok || !context.mounted) return;
                      final success = await vm.deleteJobOrder(j.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor:
                              success ? AppPalette.surface1 : AppPalette.danger,
                          content: Text(
                            vm.statusMessage ??
                                (success
                                    ? 'Job cancelled and moved to history.'
                                    : 'Failed to cancel job.'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
