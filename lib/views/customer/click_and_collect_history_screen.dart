import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';

/// Dedicated Click & Collect Reservation History Screen for the Customer App.
/// Allows riders to browse all past and active item reservations, filter by status,
/// search by item/SKU/order ID, cancel active holds, delete individual past records,
/// and permanently "Delete All History" in one tap.
class ClickAndCollectHistoryScreen extends StatefulWidget {
  const ClickAndCollectHistoryScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClickAndCollectHistoryScreen()),
    );
  }

  @override
  State<ClickAndCollectHistoryScreen> createState() =>
      _ClickAndCollectHistoryScreenState();
}

class _ClickAndCollectHistoryScreenState
    extends State<ClickAndCollectHistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'active', 'completed', 'cancelled'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAllHistory(
    BuildContext context,
    MotoHubViewModel vm,
    int pastCount,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      destructive: true,
      title: 'Delete All Past History?',
      message:
          'Are you sure you want to permanently delete all $pastCount completed and cancelled reservation records? Active reservations waiting for pickup will NOT be deleted.',
      confirmLabel: 'Delete All History',
      cancelLabel: 'Keep History',
    );

    if (!confirmed || !context.mounted) return;

    final count = await vm.deleteAllPastClickAndCollectHistory();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.success,
        content: Text(
          '$count past reservation record(s) permanently removed from history.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final allReservations = vm.customerClickCollectOrders;

    final pastCount = allReservations
        .where((o) => o.isCompleted || o.isCancelled || o.isExpired)
        .length;

    final query = _searchCtrl.text.trim().toLowerCase();

    // Filter by tab selection
    final filtered = allReservations.where((order) {
      if (_selectedFilter == 'active' && !order.isHoldActive) return false;
      if (_selectedFilter == 'completed' && !order.isCompleted) return false;
      if (_selectedFilter == 'cancelled' &&
          !(order.isCancelled || order.isExpired)) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchId = order.id.toLowerCase().contains(query);
        final matchPart = order.partName.toLowerCase().contains(query);
        final matchSku = order.sku.toLowerCase().contains(query);
        final matchBranch =
            order.pickupBranch.displayName.toLowerCase().contains(query);
        return matchId || matchPart || matchSku || matchBranch;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        backgroundColor: AppPalette.mantle,
        foregroundColor: AppPalette.textHigh,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservation History',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            Text(
              'Click & Collect • ${allReservations.length} total orders',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppPalette.champagneGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (pastCount > 0)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.danger,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text(
                'Delete All History',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              onPressed: () => _handleDeleteAllHistory(context, vm, pastCount),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppPalette.textHigh, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by part name, SKU, or order ID...',
                  hintStyle: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppPalette.textMuted,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: AppPalette.mantle,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppPalette.surface0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppPalette.surface0),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Status Filter Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  _buildFilterChip('all', 'All (${allReservations.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'active',
                    'Active (${allReservations.where((o) => o.isHoldActive).length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'completed',
                    'Completed (${allReservations.where((o) => o.isCompleted).length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'cancelled',
                    'Cancelled (${allReservations.where((o) => o.isCancelled || o.isExpired).length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Item List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(query)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return _buildReservationCard(context, vm, order);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? AppPalette.crust : AppPalette.textHigh,
      ),
      selectedColor: AppPalette.champagneGold,
      backgroundColor: AppPalette.mantle,
      side: BorderSide(
        color: isSelected ? AppPalette.champagneGold : AppPalette.surface0,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    MotoHubViewModel vm,
    ClickAndCollectOrder order,
  ) {
    Color statusColor;
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

    final dateStr = DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID & Branch & Status
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.id} • ${order.pickupBranch.displayName}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Part Name & Total Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppPalette.surface1,
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppPalette.champagneGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.partName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quantity: ${order.quantity} unit(s) • Unit: ${AppFormatters.currency(order.unitPrice)}',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppFormatters.currency(order.totalAmount),
                style: const TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date and Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10.5,
                ),
              ),
              if (order.canCustomerCancel)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        backgroundColor:
                            success ? AppPalette.success : AppPalette.danger,
                        content: Text(
                          vm.statusMessage ??
                              (success
                                  ? 'Reservation cancelled.'
                                  : 'Failed to cancel reservation.'),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text(
                    'Cancel Reservation',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                )
              else if (order.isCompleted ||
                  order.isCancelled ||
                  order.isExpired)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    final success =
                        await vm.deleteClickAndCollectOrder(order.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor:
                            success ? AppPalette.success : AppPalette.danger,
                        content: Text(
                          vm.statusMessage ??
                              (success
                                  ? 'Reservation removed from history.'
                                  : 'Failed to delete record.'),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text(
                    'Delete Record',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: AppPalette.surface2,
            ),
            const SizedBox(height: 12),
            Text(
              query.isNotEmpty
                  ? 'No reservations match "$query"'
                  : 'No Reservation History Found',
              style: const TextStyle(
                color: AppPalette.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.isNotEmpty
                  ? 'Try searching with another item name or SKU.'
                  : 'Parts you reserve in the Click & Collect catalog will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

