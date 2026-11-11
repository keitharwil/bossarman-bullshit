import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/confirm_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/create_job_order_sheet.dart';
import '../shared/legal_documents_screen.dart';
import '../shared/notifications_sheet.dart';
import 'customer_auth_screen.dart';
import '../shared/user_avatar.dart';
import '../jobs/job_history_screen.dart';
import 'click_and_collect_history_screen.dart';
import '../chat/chat_conversation_screen.dart';
import '../chat/chat_thread_list_screen.dart';
import '../../core/theme/m3e_motion.dart';

class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
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
    final user = vm.currentUser;
    final displayName =
        (user != null && user.fullName.trim().isNotEmpty)
            ? user.fullName
            : 'Rider';

    final tabs = [
      _CustomerLiveRepairTrackerTab(
        onExploreParts: () => setState(() => _selectedIndex = 1),
      ),
      const _CustomerClickAndCollectTab(),
      const _CustomerProfileTab(),
    ];

    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppPalette.surface1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppPalette.champagneGold.withValues(alpha: 0.4),
                ),
              ),
              child: Image.asset(
                'assets/images/customer_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.two_wheeler_rounded,
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
                  Text(
                    'Rider Portal • $displayName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Boss Arman MotoHub • Santa Cruz, Laguna',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          M3EButton.tonal(
            size: M3EButtonSize.xs,
            onPressed: () => CreateJobOrderSheet.show(
              context,
              defaultCustomerName: user?.fullName ?? '',
              defaultCustomerUsername: user?.username ?? '',
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 15),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Book Service'),
            ),
          ),
          IconButton(
            tooltip: 'Messages & Support',
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppPalette.champagneGold,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatThreadListScreen()),
            ),
          ),
          const NotificationBellAction(
            roleSubtitle: 'Rider Service & Order Alerts',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: M3ETabSwitcher(index: safeIndex, children: tabs),
      bottomNavigationBar: M3ENavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        autoLayout: false,
        layout: M3ENavBarLayout.compact,
        wideDestinationWidth: 168,
        backgroundColor: AppPalette.mantle,
        indicatorColor: AppPalette.surface1,
        destinations: [
          M3ENavigationBarDestination(
            icon: const Icon(Icons.track_changes_outlined),
            selectedIcon: const Icon(Icons.track_changes_rounded),
            label: 'Service Tracker',
            badgeCount:
                vm.customerJobOrders.isNotEmpty ? vm.customerJobOrders.length : null,
          ),
          const M3ENavigationBarDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Click & Collect',
          ),
          M3ENavigationBarDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: 'My Garage',
            badgeCount: vm.customerClickCollectOrders.isNotEmpty
                ? vm.customerClickCollectOrders.length
                : null,
          ),
        ],
      ),
    );
  }
}

class _CustomerLiveRepairTrackerTab extends StatelessWidget {
  final VoidCallback? onExploreParts;

  const _CustomerLiveRepairTrackerTab({this.onExploreParts});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final jobs = vm.customerJobOrders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Branch Selector (Material 3 Expressive M3ESegmentedButton)
        SegmentedButton<BranchId>(
          segments: const [
            ButtonSegment<BranchId>(
              value: BranchId.patimbao,
              label: SlidingMarqueeText(text: 'Branch 1: Patimbao'),
              icon: Icon(Icons.storefront_rounded, size: 16),
            ),
            ButtonSegment<BranchId>(
              value: BranchId.pedroGuevara,
              label: SlidingMarqueeText(text: 'Branch 2: P. Guevara'),
              icon: Icon(Icons.location_on_outlined, size: 16),
            ),
          ],
          selected: {vm.activeBranch},
          onSelectionChanged: (set) {
            if (set.isNotEmpty) vm.setActiveBranch(set.first);
          },
        ),
        const SizedBox(height: 14),

        GoldGradientButton(
          label: '+ Schedule New Service Appointment',
          icon: Icons.calendar_today_rounded,
          onPressed: () => CreateJobOrderSheet.show(
            context,
            defaultCustomerName: user?.fullName ?? '',
            defaultCustomerUsername: user?.username ?? '',
          ),
        ),
        const SizedBox(height: 12),

        // Quick Genuine Parts & Accessories Banner
        Card.filled(
          color: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppPalette.champagneGold.withValues(alpha: 0.35),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onExploreParts,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppPalette.champagneGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppPalette.champagneGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Genuine Parts & Tuning',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Badge(
                              label: Text('In Stock'),
                              backgroundColor: AppPalette.surface2,
                              textColor: AppPalette.champagneGold,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vm.allInventory.length} items available • Reserve with Click & Collect',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppPalette.champagneGold,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'LIVE BAY REPAIR STATUS TRACKER',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),

        // Material 3 Expressive M3ECardList for Live Repair Status
        M3ECardList(
          itemCount: jobs.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(16),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.build_circle_outlined,
            title: 'No Active Service Appointments',
            subtitle:
                'You have no active motorcycle repair tickets yet. Book a bay appointment at Patimbao or Pedro Guevara Ave to track live repair progress.',
            actionLabel: 'Book Service Appointment',
            onAction: () => CreateJobOrderSheet.show(
              context,
              defaultCustomerName: user?.fullName ?? '',
              defaultCustomerUsername: user?.username ?? '',
            ),
          ),
          itemBuilder: (context, index) {
            final job = jobs[index];
            final currentStep = job.status.stepIndex;
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.champagneGold),
                      ),
                      child: Text(
                        job.status.label,
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  job.bikeModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${job.branch.displayName} • Mechanic: ${job.assignedMechanic}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),

                // 5-Stage Progress Bar
                Row(
                  children: List.generate(JobStatus.pipelineStages.length, (i) {
                    final reached = currentStep >= 0 && i <= currentStep;
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 6,
                            decoration: BoxDecoration(
                              color: reached
                                  ? AppPalette.success
                                  : AppPalette.surface0,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              JobStatus.pipelineStages[i].label.split(' ').first,
                              style: TextStyle(
                                color: reached
                                    ? AppPalette.textHigh
                                    : AppPalette.inactive,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const Divider(height: 22),

                // Itemized Parts & Labor Breakdown
                ...job.attachedParts.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${p.quantity}x ${p.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.textBody,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    const Expanded(
                      child: Text(
                        'Service Labor Fee:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.effectiveLaborFee > 0
                          ? AppFormatters.currency(job.effectiveLaborFee)
                          : 'To be assessed by mechanic',
                      style: TextStyle(
                        color: job.effectiveLaborFee > 0
                            ? AppPalette.champagneGold
                            : AppPalette.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: job.effectiveLaborFee > 0 ? 14 : 12,
                      ),
                    ),
                  ],
                ),

                // Extra Repair Approval Prompt
                if (job.extraRepairNote != null &&
                    !job.extraRepairApproved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.warning),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mechanic Recommendation: ${job.extraRepairNote}',
                          style: const TextStyle(
                            color: AppPalette.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () async {
                            await vm.approveCustomerExtraRepair(job.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  vm.statusMessage ??
                                      'Approved extra repair for ${job.id}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.thumb_up_alt_outlined,
                            size: 16,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Approve Extra Repair (+${AppFormatters.currency(job.extraRepairFee, showDecimals: false)})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (job.assignedMechanic != 'Unassigned' &&
                        job.status != JobStatus.completed &&
                        job.status != JobStatus.cancelled)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.champagneGold,
                          side: const BorderSide(color: AppPalette.champagneGold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final customerId = user?.id ?? user?.username ?? 'customer';
                          final mechanicId = job.mechanicId ??
                              job.assignedMechanic.replaceAll(' ', '_').toLowerCase();
                          final threadId = '${customerId}_${job.id}_$mechanicId';
                          final staffList = vm.staffList;
                          final mechanicStaff = staffList.where((s) =>
                              s.id == mechanicId ||
                              s.fullName.trim().toLowerCase() ==
                                  job.assignedMechanic.trim().toLowerCase()).firstOrNull;
                          final mechanicUsername = mechanicStaff?.username;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                threadId: threadId,
                                recipientName: job.assignedMechanic,
                                recipientUsername: mechanicUsername,
                                recipientRole: 'mechanic',
                                jobOrderId: job.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Message Mechanic'),
                      )
                    else
                      const SizedBox.shrink(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.danger,
                        side: const BorderSide(color: AppPalette.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final ok = await showConfirmDialog(
                          context,
                          destructive: true,
                          title: 'Delete Service Job?',
                          message:
                              'Are you sure you want to delete job ${job.id} for ${job.bikeModel}? It will be automatically moved to your Repair History.',
                          confirmLabel: 'Delete Job',
                          cancelLabel: 'Keep Job',
                        );
                        if (!ok || !context.mounted) return;
                        final success = await vm.deleteCustomerJobBooking(job.id);
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

class _CustomerClickAndCollectTab extends StatelessWidget {
  const _CustomerClickAndCollectTab();

  Future<void> _reservePartModal(
    BuildContext context,
    MotoHubViewModel vm,
    InventoryItem item,
  ) async {
    BranchId selectedBranch = vm.activeBranch;
    if (item.availableStockFor(selectedBranch) <= 0) {
      selectedBranch = selectedBranch == BranchId.patimbao
          ? BranchId.pedroGuevara
          : BranchId.patimbao;
    }

    int qty = 1;
    final qtyController = TextEditingController(text: '1');
    String phoneInput = '';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            final maxAvail = item.availableStockFor(selectedBranch);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Click & Collect Reservation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.name} • ${AppFormatters.currency(item.price)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<BranchId>(
                        segments: [
                          ButtonSegment<BranchId>(
                            value: BranchId.patimbao,
                            label: SlidingMarqueeText(
                              text:
                                  'Patimbao (${item.availableStockFor(BranchId.patimbao)})',
                            ),
                          ),
                          ButtonSegment<BranchId>(
                            value: BranchId.pedroGuevara,
                            label: SlidingMarqueeText(
                              text:
                                  'P. Guevara (${item.availableStockFor(BranchId.pedroGuevara)})',
                            ),
                          ),
                        ],
                        selected: {selectedBranch},
                        onSelectionChanged: (set) {
                          if (set.isEmpty) return;
                          setModalState(() {
                            selectedBranch = set.first;
                            final branchMax = item.availableStockFor(selectedBranch);
                            if (qty > branchMax && branchMax > 0) {
                              qty = branchMax;
                              qtyController.text = '$qty';
                            } else if (branchMax <= 0) {
                              qty = 0;
                              qtyController.text = '0';
                            } else if (qty <= 0 && branchMax > 0) {
                              qty = 1;
                              qtyController.text = '1';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        onChanged: (v) => phoneInput = v,
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: AppValidators.philippineMobileNumber,
                        decoration: const InputDecoration(
                          labelText: 'Pickup Mobile Number (11 digits)',
                          hintText: '09171234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reserve Quantity:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppPalette.textHigh,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  maxAvail > 0
                                      ? '$maxAvail available in stock'
                                      : 'Out of stock at this branch',
                                  style: TextStyle(
                                    color: maxAvail > 0
                                        ? AppPalette.textMuted
                                        : AppPalette.danger,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppPalette.surface0,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppPalette.champagneGold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 20,
                                  tooltip: 'Decrease',
                                  onPressed: qty > 1
                                      ? () {
                                          setModalState(() {
                                            qty--;
                                            qtyController.text = '$qty';
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                Container(
                                  width: 58,
                                  alignment: Alignment.center,
                                  child: TextFormField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      color: AppPalette.champagneGold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val);
                                      setModalState(() {
                                        if (parsed == null || parsed <= 0) {
                                          qty = 1;
                                        } else if (parsed > maxAvail && maxAvail > 0) {
                                          qty = maxAvail;
                                          qtyController.text = '$maxAvail';
                                          qtyController.selection = TextSelection.fromPosition(
                                            TextPosition(offset: qtyController.text.length),
                                          );
                                        } else {
                                          qty = parsed;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 20,
                                  tooltip: 'Increase',
                                  onPressed: qty < maxAvail
                                      ? () {
                                          setModalState(() {
                                            qty++;
                                            qtyController.text = '$qty';
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoldGradientButton(
                        label:
                            'Confirm Reservation (${AppFormatters.currency(item.price * qty)})',
                        icon: Icons.shopping_bag_outlined,
                        onPressed: (maxAvail > 0 && qty > 0)
                            ? () {
                                if (formKey.currentState?.validate() ?? false) {
                                  Navigator.of(sheetCtx).pop(true);
                                }
                              }
                            : null,
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

    final phone = phoneInput.trim();
    final finalMax = item.availableStockFor(selectedBranch);
    final finalQty = (int.tryParse(qtyController.text) ?? qty).clamp(1, finalMax > 0 ? finalMax : 1);
    qtyController.dispose();
    if (confirmed != true || !context.mounted) return;

    final order = await vm.createClickAndCollectOrder(
      part: item,
      quantity: finalQty,
      pickupBranch: selectedBranch,
      customerPhone: phone,
    );

    if (!context.mounted) return;
    if (order != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserved ${qty}x ${item.name} (${order.id}) at ${selectedBranch.shortName}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            vm.statusMessage ?? 'Failed to reserve part.',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final items = vm.filteredInventory;

    return RefreshIndicator(
      color: AppPalette.champagneGold,
      backgroundColor: AppPalette.mantle,
      onRefresh: () => vm.syncInventory(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: SearchBar(
                  hintText: 'Search parts & reserve for Click & Collect...',
                  backgroundColor:
                      const WidgetStatePropertyAll(AppPalette.mantle),
                  leading: const Icon(
                    Icons.search_rounded,
                    color: AppPalette.champagneGold,
                  ),
                  onChanged: vm.setInventorySearchQuery,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Reservation History',
                style: IconButton.styleFrom(
                  backgroundColor: AppPalette.mantle,
                  foregroundColor: AppPalette.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppPalette.surface0),
                  ),
                ),
                icon: const Icon(Icons.history_rounded),
                onPressed: () => ClickAndCollectHistoryScreen.push(context),
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
              icon: Icons.inventory_2_outlined,
              title: 'No Catalog Items Found',
              subtitle: vm.allInventory.isEmpty
                  ? 'The store inventory catalog is currently empty. Pull down to refresh or check back as parts are stocked.'
                  : 'No parts matched your current search query or category filter.',
              actionLabel: vm.allInventory.isEmpty
                  ? 'Refresh Catalog'
                  : (vm.inventorySearchQuery.isNotEmpty ||
                          vm.selectedPosCategory != 'All'
                      ? 'Reset Filters'
                      : null),
              onAction: vm.allInventory.isEmpty
                  ? () => vm.syncInventory()
                  : () {
                      vm.setInventorySearchQuery('');
                      vm.setSelectedPosCategory('All');
                    },
            ),
          itemBuilder: (context, index) {
            final item = items[index];
            final patAvail = item.availableStockFor(BranchId.patimbao);
            final pgvAvail = item.availableStockFor(BranchId.pedroGuevara);
            final totalAvail = patAvail + pgvAvail;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormatters.currency(item.price),
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Compatible: ${item.compatibleModels}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.crust,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Branch 1 (Patimbao): ${patAvail > 0 ? "$patAvail In-Stock" : "Out of Stock"}',
                        style: TextStyle(
                          color: patAvail > 0
                              ? AppPalette.success
                              : AppPalette.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.crust,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Branch 2 (P. Guevara): ${pgvAvail > 0 ? "$pgvAvail In-Stock" : "Out of Stock"}',
                        style: TextStyle(
                          color: pgvAvail > 0
                              ? AppPalette.success
                              : AppPalette.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: M3EButton.filled(
                    size: M3EButtonSize.xs,
                    onPressed: totalAvail > 0
                        ? () => _reservePartModal(context, vm, item)
                        : null,
                    icon: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Reserve Click & Collect'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
      ),
    );
  }
}

class _CustomerProfileTab extends StatelessWidget {
  const _CustomerProfileTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final reservations = vm.customerClickCollectOrders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
              final signOutButton = M3EButton.outlined(
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
                    MaterialPageRoute(
                      builder: (_) => const CustomerAuthScreen(),
                    ),
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
                        radius: 28,
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
                              user?.fullName ?? 'Registered Rider',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user?.username ?? "rider"} • ${user?.email ?? ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auth Provider: ${(user?.authProvider ?? "password").toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 14),
                        signOutButton,
                      ],
                    ],
                  ),
                  if (isCompact) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: signOutButton,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MY CLICK & COLLECT RESERVATIONS',
              style: TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.champagneGold,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => ClickAndCollectHistoryScreen.push(context),
              icon: const Icon(Icons.history_rounded, size: 14),
              label: Text(
                'Full History (${reservations.length})',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        M3ECardList(
          itemCount: reservations.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 3,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          emptyBuilder: const MotoHubEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Click & Collect Orders Yet',
            subtitle:
                'Parts you reserve in the Click & Collect tab will appear here with your pickup reference number and branch status.',
          ),
          itemBuilder: (context, index) {
            final order = reservations[index];
            final Color statusColor;
            if (order.isReady) {
              statusColor = AppPalette.success;
            } else if (order.isConfirmed) {
              statusColor = const Color(0xFF007DFE);
            } else if (order.isPending) {
              statusColor = AppPalette.warning;
            } else if (order.isCompleted) {
              statusColor = AppPalette.textMuted;
            } else {
              statusColor = AppPalette.danger;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppPalette.surface1,
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppPalette.champagneGold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order.id} • ${order.pickupBranch.shortName.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.quantity}x ${order.partName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    order.status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.currency(order.totalAmount),
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (order.canCustomerCancel) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final ok = await showConfirmDialog(
                            context,
                            destructive: true,
                            title: 'Cancel Reservation?',
                            message:
                                'Are you sure you want to cancel your reservation for ${order.quantity}x ${order.partName}? Your held stock will be released.',
                            confirmLabel: 'Cancel Reservation',
                            cancelLabel: 'Keep Reservation',
                          );
                          if (!ok || !context.mounted) return;
                          final success = await vm.cancelClickAndCollectOrder(order.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: success ? AppPalette.success : AppPalette.danger,
                              content: Text(
                                vm.statusMessage ?? (success ? 'Reservation cancelled.' : 'Failed to cancel reservation.'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: const Text(
                          'Cancel Reservation',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ] else if (order.isCompleted || order.isCancelled || order.isExpired) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final ok = await showConfirmDialog(
                            context,
                            destructive: true,
                            title: 'Delete from History?',
                            message:
                                'Permanently remove past reservation ${order.id} from your history? This action cannot be undone.',
                            confirmLabel: 'Delete Record',
                            cancelLabel: 'Keep Record',
                          );
                          if (!ok || !context.mounted) return;
                          final success = await vm.deleteClickAndCollectOrder(order.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: success ? AppPalette.success : AppPalette.danger,
                              content: Text(
                                vm.statusMessage ?? (success ? 'Reservation removed from history.' : 'Failed to delete record.'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text(
                          'Delete from History',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        // Account Settings & Soft Deletion Card (Feature D)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.mantle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppPalette.surface1,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppPalette.champagneGold, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ACCOUNT PREFERENCES & PRIVACY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppPalette.champagneGold, size: 18),
                ),
                title: const Text('Update Profile Picture', style: TextStyle(color: AppPalette.textHigh, fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Change avatar photo or use initials', style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.textMuted),
                onTap: () => UserAvatar.showPhotoPickerSheet(context),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppPalette.champagneGold, size: 18),
                ),
                title: const Text('Repair History', style: TextStyle(color: AppPalette.textHigh, fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('View your completed and past repairs', style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.textMuted),
                onTap: () => JobHistoryScreen.push(context),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: AppPalette.champagneGold, size: 18),
                ),
                title: const Text('Reservation History', style: TextStyle(color: AppPalette.textHigh, fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('View and manage Click & Collect reservations', style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.textMuted),
                onTap: () => ClickAndCollectHistoryScreen.push(context),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppPalette.champagneGold, size: 18),
                ),
                title: const Text('Direct Messages & Support', style: TextStyle(color: AppPalette.textHigh, fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Chat with Admin support or your assigned mechanic', style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.textMuted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatThreadListScreen()),
                ),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppPalette.champagneGold,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Privacy Policy (RA 10173)',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'How MotoHub Rider collects, uses, and protects your data',
                  style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.textMuted,
                ),
                onTap: () => LegalDocumentsScreen.openPrivacyPolicy(
                  context,
                  isCustomerApp: true,
                ),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.surface1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: AppPalette.champagneGold,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  user?.termsAcceptedVersion != null
                      ? 'Accepted ${user!.termsAcceptedVersion}'
                      : 'Service booking, Click & Collect, and store policies',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.textMuted,
                ),
                onTap: () => LegalDocumentsScreen.openTermsAndConditions(
                  context,
                  isCustomerApp: true,
                ),
              ),
              const Divider(color: AppPalette.surface0, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: AppPalette.danger, size: 18),
                ),
                title: const Text('Delete Account', style: TextStyle(color: AppPalette.danger, fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: const Text('Permanently remove account credentials and data', style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.danger),
                onTap: () {
                  if (user != null) {
                    _showDeleteAccountDialog(context, user, vm);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    StaffAccount user,
    MotoHubViewModel vm,
  ) {
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    final isGoogleUser = user.authProvider == 'google' ||
        user.password.startsWith('AUTH_PROVIDER_GOOGLE_');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppPalette.danger, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppPalette.danger, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your customer account and revoke access.',
                  style: TextStyle(color: AppPalette.textHigh, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Deleted Immediately: Your profile record, login credentials, photo, and push notification bindings.\n'
                  '• Retained for Legal/Tax Audit: Completed store receipts (OR) and financial ledgers are preserved as anonymized business records.\n'
                  '• ${isGoogleUser ? 'Please type "DELETE" below to confirm permanent deletion:' : 'Please enter your current account password to verify identity:'}',
                  style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: !isGoogleUser && obscurePassword,
                  style: const TextStyle(color: AppPalette.textHigh),
                  decoration: InputDecoration(
                    hintText: isGoogleUser
                        ? 'Type DELETE to confirm'
                        : 'Enter your password',
                    hintStyle: const TextStyle(color: AppPalette.textMuted),
                    filled: true,
                    fillColor: AppPalette.surface0,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppPalette.danger),
                    ),
                    suffixIcon: isGoogleUser
                        ? null
                        : IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppPalette.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                  ),
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
                backgroundColor: AppPalette.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final password = passwordCtrl.text.trim();
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppPalette.danger,
                      content: Text(
                        isGoogleUser
                            ? 'Please type DELETE to confirm.'
                            : 'Please enter your password to confirm.',
                      ),
                    ),
                  );
                  return;
                }
                if (isGoogleUser && password.toUpperCase() != 'DELETE') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppPalette.danger,
                      content: Text('Please type "DELETE" to confirm account deletion.'),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();

                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Permanently Delete Account?',
                  message: 'Are you absolutely sure? All account credentials will be erased and cannot be restored.',
                  confirmLabel: 'Delete Forever',
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;

                final ok = await vm.deleteCustomerAccount(password: password);
                if (context.mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppPalette.success,
                        content: Text('Your account has been deleted.'),
                      ),
                    );
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const CustomerAuthScreen(),
                      ),
                      (r) => false,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppPalette.danger,
                        content: Text(vm.errorMessage ?? 'Failed to delete account. Please try again.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Verify & Delete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
