import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import 'confirm_dialog.dart';
import 'receipt_preview_modal.dart';
import '../sales/sales_history_dashboard_screen.dart';

/// Bottom Sheet modal to browse and reopen past POS receipts.
/// Allows Cashiers and Admin to review transaction history, inspect
/// payment breakdowns, and re-export thermal receipt PNGs via SharePlus.
class ReceiptHistorySheet extends StatefulWidget {
  final BranchId? branchFilter;

  const ReceiptHistorySheet({
    super.key,
    this.branchFilter,
  });

  static Future<void> show(BuildContext context, {BranchId? branchFilter}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.crust,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReceiptHistorySheet(branchFilter: branchFilter),
    );
  }

  @override
  State<ReceiptHistorySheet> createState() => _ReceiptHistorySheetState();
}

class _ReceiptHistorySheetState extends State<ReceiptHistorySheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  PaymentMethod? _selectedMethod;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final targetBranch = widget.branchFilter ?? vm.activeBranch;
    final isAdmin = vm.currentUser?.role == UserRole.admin;

    final query = _searchCtrl.text.trim().toLowerCase();

    // Filter transactions
    final transactions = vm.transactions.where((tx) {
      if (!isAdmin && tx.branch != targetBranch) {
        return false;
      }
      if (_selectedMethod != null && tx.paymentMethod != _selectedMethod) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchId = tx.id.toLowerCase().contains(query);
        final matchCust = tx.customerName.toLowerCase().contains(query);
        final matchCashier = tx.cashierName.toLowerCase().contains(query);
        final matchSummary = tx.itemsSummary.toLowerCase().contains(query);
        return matchId || matchCust || matchCashier || matchSummary;
      }
      return true;
    }).toList();

    final totalRevenue = transactions.fold<double>(0.0, (sum, tx) => sum + tx.totalAmount);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppPalette.surface2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
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
                      Icons.receipt_long_rounded,
                      color: AppPalette.champagneGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt History',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${transactions.length} receipts • Total ₱${totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Daily Sales Dashboard',
                    icon: const Icon(Icons.analytics_rounded, color: AppPalette.champagneGold),
                    onPressed: () {
                      Navigator.of(context).pop();
                      SalesHistoryDashboardScreen.push(context, branchFilter: targetBranch);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppPalette.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by Receipt #, customer, or items...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppPalette.champagneGold, size: 20),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppPalette.mantle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Methods'),
                    selected: _selectedMethod == null,
                    onSelected: (sel) => setState(() => _selectedMethod = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Cash'),
                    selected: _selectedMethod == PaymentMethod.cash,
                    onSelected: (sel) => setState(() => _selectedMethod = sel ? PaymentMethod.cash : null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('GCash'),
                    selected: _selectedMethod == PaymentMethod.gcash,
                    onSelected: (sel) => setState(() => _selectedMethod = sel ? PaymentMethod.gcash : null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Split (Cash+GCash)'),
                    selected: _selectedMethod == PaymentMethod.split,
                    onSelected: (sel) => setState(() => _selectedMethod = sel ? PaymentMethod.split : null),
                  ),
                ],
              ),
            ),
            const Divider(color: AppPalette.surface1, height: 16),

            // Transactions List
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 48,
                            color: AppPalette.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No receipts match your search.',
                            style: TextStyle(color: AppPalette.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(tx.createdAt);

                        return Container(
                          decoration: BoxDecoration(
                            color: AppPalette.mantle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppPalette.surface1,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            title: Row(
                              children: [
                                Text(
                                  tx.id,
                                  style: const TextStyle(
                                    color: AppPalette.champagneGold,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    fontSize: 13.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₱${tx.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppPalette.textHigh,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${tx.customerName} • Cashier: ${tx.cashierName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppPalette.textHigh,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tx.paymentMethod == PaymentMethod.cash
                                            ? AppPalette.success.withValues(alpha: 0.15)
                                            : (tx.paymentMethod == PaymentMethod.gcash
                                                ? AppPalette.info.withValues(alpha: 0.15)
                                                : AppPalette.warning.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tx.paymentMethod.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: tx.paymentMethod == PaymentMethod.cash
                                              ? AppPalette.success
                                              : (tx.paymentMethod == PaymentMethod.gcash
                                                  ? AppPalette.info
                                                  : AppPalette.warning),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (tx.itemsSummary.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    tx.itemsSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppPalette.textMuted,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (vm.currentUser?.role == UserRole.admin)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger, size: 20),
                                    tooltip: 'Delete Receipt from History (Admin Only)',
                                    onPressed: () async {
                                      final confirmed = await showConfirmDialog(
                                        context,
                                        title: 'Delete Receipt?',
                                        message: 'Permanently remove receipt ${tx.id} from transaction history? This cannot be undone.',
                                        confirmLabel: 'Delete Receipt',
                                        destructive: true,
                                      );
                                      if (confirmed && context.mounted) {
                                        final ok = await vm.deleteTransaction(tx.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: ok ? AppPalette.surface1 : AppPalette.danger,
                                              content: Text(
                                                ok ? 'Receipt ${tx.id} removed from history.' : (vm.statusMessage ?? 'Failed to delete receipt.'),
                                                style: const TextStyle(color: AppPalette.textHigh),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.share_rounded, color: AppPalette.champagneGold, size: 20),
                                  tooltip: 'Open Thermal Receipt & Share',
                                  onPressed: () {
                                    ReceiptPreviewModal.show(
                                      context,
                                      tx,
                                      clearCartOnClose: false,
                                    );
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              ReceiptPreviewModal.show(
                                context,
                                tx,
                                clearCartOnClose: false,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
