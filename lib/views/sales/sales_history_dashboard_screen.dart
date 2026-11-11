import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';
import '../shared/receipt_preview_modal.dart';

/// Interactive Daily Sales History Dashboard.
/// Allows Cashiers, Admin, and Owners to monitor daily financial performance by date,
/// inspect gross revenue, cash drawer inflows, GCash vault collections, parts vs labor
/// breakdowns, average ticket size, and review/delete itemized transaction receipts.
class SalesHistoryDashboardScreen extends StatefulWidget {
  final BranchId? initialBranch;

  const SalesHistoryDashboardScreen({
    super.key,
    this.initialBranch,
  });

  static Future<void> push(BuildContext context, {BranchId? branchFilter}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesHistoryDashboardScreen(initialBranch: branchFilter),
      ),
    );
  }

  @override
  State<SalesHistoryDashboardScreen> createState() =>
      _SalesHistoryDashboardScreenState();
}

class _SalesHistoryDashboardScreenState
    extends State<SalesHistoryDashboardScreen> {
  late DateTime _selectedDate;
  BranchId? _selectedBranch;
  PaymentMethod? _selectedPaymentMethod;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedBranch = widget.initialBranch;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeDateBy(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppPalette.champagneGold,
              onPrimary: AppPalette.crust,
              surface: AppPalette.mantle,
              onSurface: AppPalette.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isYesterday(DateTime d) {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return d.year == yest.year && d.month == yest.month && d.day == yest.day;
  }

  String _getDateBadgeText(DateTime d) {
    if (_isToday(d)) return 'TODAY';
    if (_isYesterday(d)) return 'YESTERDAY';
    return DateFormat('EEE, MMM d').format(d).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final isAdmin = vm.currentUser?.role == UserRole.admin;
    final activeBranch = _selectedBranch ?? (isAdmin ? null : vm.activeBranch);

    // Filter transactions by selected date (and optional branch)
    final allDayTransactions = vm.transactions.where((tx) {
      final txDate = tx.createdAt;
      final sameDay = txDate.year == _selectedDate.year &&
          txDate.month == _selectedDate.month &&
          txDate.day == _selectedDate.day;
      if (!sameDay) return false;
      if (activeBranch != null && tx.branch != activeBranch) return false;
      return true;
    }).toList();

    // Compute key financial metrics for this date
    final totalGrossSales = allDayTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.totalAmount,
    );

    final totalCashCollected = allDayTransactions.fold<double>(0.0, (sum, tx) {
      if (tx.paymentMethod == PaymentMethod.cash) {
        return sum + tx.totalAmount;
      } else if (tx.paymentMethod == PaymentMethod.split) {
        return sum +
            (tx.cashAmount > 0
                ? tx.cashAmount
                : (tx.totalAmount - tx.gcashAmount).clamp(0.0, tx.totalAmount));
      }
      return sum;
    });

    final totalGcashVault = allDayTransactions.fold<double>(0.0, (sum, tx) {
      if (tx.paymentMethod == PaymentMethod.gcash) {
        return sum + tx.totalAmount;
      } else if (tx.paymentMethod == PaymentMethod.split) {
        return sum +
            (tx.gcashAmount > 0
                ? tx.gcashAmount
                : (tx.totalAmount - tx.cashAmount).clamp(0.0, tx.totalAmount));
      }
      return sum;
    });

    final totalPartsSales = allDayTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.partsSubtotal,
    );

    final totalLaborSales = allDayTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.laborTotal,
    );

    final transactionCount = allDayTransactions.length;
    final averageTicket =
        transactionCount > 0 ? (totalGrossSales / transactionCount) : 0.0;

    // Filtered transactions for the itemized list based on search & payment filter
    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    final displayedTransactions = allDayTransactions.where((tx) {
      if (_selectedPaymentMethod != null &&
          tx.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final matchesId = tx.id.toLowerCase().contains(searchQuery);
        final matchesCust = tx.customerName.toLowerCase().contains(searchQuery);
        final matchesCashier =
            tx.cashierName.toLowerCase().contains(searchQuery);
        final matchesSummary =
            tx.itemsSummary.toLowerCase().contains(searchQuery);
        return matchesId || matchesCust || matchesCashier || matchesSummary;
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
              'Daily Sales Dashboard',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.textHigh,
              ),
            ),
            Text(
              activeBranch == null
                  ? 'All Branches Consolidated'
                  : '${activeBranch.displayName} Branch',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppPalette.champagneGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            PopupMenuButton<BranchId?>(
              tooltip: 'Filter Branch',
              icon: const Icon(Icons.storefront_rounded, color: AppPalette.champagneGold),
              initialValue: _selectedBranch,
              onSelected: (b) => setState(() => _selectedBranch = b),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('All Branches'),
                ),
                ...BranchId.values.map(
                  (b) => PopupMenuItem(
                    value: b,
                    child: Text(b.displayName),
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Select Custom Date',
            icon: const Icon(Icons.calendar_month_rounded, color: AppPalette.champagneGold),
            onPressed: _pickCustomDate,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            // Date Stepper Banner
            _buildDateBanner(context),
            const SizedBox(height: 14),

            // Top Gross Sales Overview Hero Card
            _buildGrossSalesHeroCard(
              totalGross: totalGrossSales,
              totalParts: totalPartsSales,
              totalLabor: totalLaborSales,
              transactionCount: transactionCount,
            ),
            const SizedBox(height: 14),

            // 4-Quadrant Metric Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricMiniCard(
                    title: 'Cash Inflow',
                    value: AppFormatters.currency(totalCashCollected),
                    icon: Icons.payments_rounded,
                    iconColor: AppPalette.success,
                    subtitle: 'Drawer collection',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricMiniCard(
                    title: 'GCash Vault',
                    value: AppFormatters.currency(totalGcashVault),
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF007DFE),
                    subtitle: 'Digital receipts',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricMiniCard(
                    title: 'Transactions',
                    value: '$transactionCount Orders',
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppPalette.champagneGold,
                    subtitle: 'Completed tickets',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricMiniCard(
                    title: 'Average Ticket',
                    value: AppFormatters.currency(averageTicket),
                    icon: Icons.trending_up_rounded,
                    iconColor: AppPalette.warning,
                    subtitle: 'Per transaction avg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sales Mix & Revenue Breakdown Card
            if (totalGrossSales > 0) ...[
              _buildRevenueMixCard(
                totalGross: totalGrossSales,
                totalParts: totalPartsSales,
                totalLabor: totalLaborSales,
                totalCash: totalCashCollected,
                totalGcash: totalGcashVault,
              ),
              const SizedBox(height: 20),
            ],

            // Itemized Sales Transactions Header & Search Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Transactions (${displayedTransactions.length})',
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Itemized POS sales ledger for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Payment Method Filter Menu
                PopupMenuButton<PaymentMethod?>(
                  tooltip: 'Filter Payment Method',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.mantle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.surface0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedPaymentMethod == null
                              ? Icons.filter_alt_outlined
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: AppPalette.champagneGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedPaymentMethod == null
                              ? 'All Methods'
                              : _selectedPaymentMethod!.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.champagneGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  initialValue: _selectedPaymentMethod,
                  onSelected: (m) => setState(() => _selectedPaymentMethod = m),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All Payment Methods'),
                    ),
                    const PopupMenuItem(
                      value: PaymentMethod.cash,
                      child: Text('Cash Only'),
                    ),
                    const PopupMenuItem(
                      value: PaymentMethod.gcash,
                      child: Text('GCash Only'),
                    ),
                    const PopupMenuItem(
                      value: PaymentMethod.split,
                      child: Text('Split (Cash + GCash)'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppPalette.textHigh, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search receipt #, customer, cashier, or items...',
                hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppPalette.textMuted),
                suffixIcon: searchQuery.isEmpty
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
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
            const SizedBox(height: 12),

            // Itemized Transaction List or Empty State
            if (displayedTransactions.isEmpty)
              _buildEmptyState(searchQuery)
            else
              ...displayedTransactions.map((tx) => _buildTransactionCard(context, vm, tx)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date Selector Banner
  // ---------------------------------------------------------------------------

  Widget _buildDateBanner(BuildContext context) {
    final now = DateTime.now();
    final isFuture = _selectedDate.isAfter(DateTime(now.year, now.month, now.day));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous Day',
            icon: const Icon(Icons.chevron_left_rounded, color: AppPalette.champagneGold),
            onPressed: () => _changeDateBy(-1),
          ),
          Expanded(
            child: InkWell(
              onTap: _pickCustomDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isToday(_selectedDate)
                                ? AppPalette.champagneGold.withValues(alpha: 0.2)
                                : AppPalette.surface1,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getDateBadgeText(_selectedDate),
                            style: TextStyle(
                              color: _isToday(_selectedDate)
                                  ? AppPalette.champagneGold
                                  : AppPalette.textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to change date via calendar',
                      style: TextStyle(color: AppPalette.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next Day',
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isFuture ? AppPalette.surface2 : AppPalette.champagneGold,
            ),
            onPressed: isFuture ? null : () => _changeDateBy(1),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gross Sales Overview Card
  // ---------------------------------------------------------------------------

  Widget _buildGrossSalesHeroCard({
    required double totalGross,
    required double totalParts,
    required double totalLabor,
    required int transactionCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.mantle,
            AppPalette.mantle.withValues(alpha: 0.95),
            AppPalette.crust,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.champagneGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: AppPalette.champagneGold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DAILY GROSS REVENUE',
                    style: TextStyle(
                      color: AppPalette.champagneGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.champagneGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('MM/dd/yyyy').format(_selectedDate),
                  style: const TextStyle(
                    color: AppPalette.champagneGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppFormatters.currency(totalGross),
            style: const TextStyle(
              color: AppPalette.champagneGold,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppPalette.surface0, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARTS / PRODUCTS',
                      style: TextStyle(color: AppPalette.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.currency(totalParts),
                      style: const TextStyle(color: AppPalette.textHigh, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: AppPalette.surface0),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SERVICE & LABOR',
                      style: TextStyle(color: AppPalette.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.currency(totalLabor),
                      style: const TextStyle(color: AppPalette.textHigh, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: AppPalette.surface0),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TICKETS PAID',
                      style: TextStyle(color: AppPalette.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$transactionCount',
                      style: const TextStyle(color: AppPalette.textHigh, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metric Mini Card
  // ---------------------------------------------------------------------------

  Widget _buildMetricMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.textHigh,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Revenue Mix Card
  // ---------------------------------------------------------------------------

  Widget _buildRevenueMixCard({
    required double totalGross,
    required double totalParts,
    required double totalLabor,
    required double totalCash,
    required double totalGcash,
  }) {
    final partsRatio = totalGross > 0 ? (totalParts / totalGross) : 0.0;
    final laborRatio = totalGross > 0 ? (totalLabor / totalGross) : 0.0;
    final cashRatio = totalGross > 0 ? (totalCash / totalGross) : 0.0;
    final gcashRatio = totalGross > 0 ? (totalGcash / totalGross) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY REVENUE INSIGHTS',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),

          // Parts vs Labor Proportion Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parts (${(partsRatio * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppPalette.textBody, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              Text(
                'Labor (${(laborRatio * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppPalette.textBody, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (partsRatio * 100).round().clamp(0, 100),
                    child: Container(color: AppPalette.champagneGold),
                  ),
                  Expanded(
                    flex: (laborRatio * 100).round().clamp(0, 100),
                    child: Container(color: AppPalette.warning),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cash vs GCash Distribution Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash Tender (${(cashRatio * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppPalette.textBody, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              Text(
                'GCash Digital (${(gcashRatio * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppPalette.textBody, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (cashRatio * 100).round().clamp(0, 100),
                    child: Container(color: AppPalette.success),
                  ),
                  Expanded(
                    flex: (gcashRatio * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFF007DFE)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction Card
  // ---------------------------------------------------------------------------

  Widget _buildTransactionCard(
    BuildContext context,
    MotoHubViewModel vm,
    PosTransaction tx,
  ) {
    Color methodColor;
    String methodLabel;
    switch (tx.paymentMethod) {
      case PaymentMethod.cash:
        methodColor = AppPalette.success;
        methodLabel = 'CASH';
        break;
      case PaymentMethod.gcash:
        methodColor = const Color(0xFF007DFE);
        methodLabel = 'GCASH';
        break;
      case PaymentMethod.split:
        methodColor = AppPalette.warning;
        methodLabel = 'SPLIT';
        break;
    }

    final timeFormatted = DateFormat('hh:mm a').format(tx.createdAt);

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
          // Top Row: ID, Time, Payment Method Pill
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tx.id} • $timeFormatted',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: methodColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  methodLabel,
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Customer and Cashier
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AppPalette.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${tx.customerName} • Cashier: ${tx.cashierName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                AppFormatters.currency(tx.totalAmount),
                style: const TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Items summary
          if (tx.itemsSummary.isNotEmpty) ...[
            Text(
              tx.itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppPalette.textBody, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
          ],

          // Action Buttons: View Receipt and Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (tx.partsSubtotal > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Parts: ₱${tx.partsSubtotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppPalette.textMuted, fontSize: 10.5),
                      ),
                    ),
                  if (tx.laborTotal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Labor: ₱${tx.laborTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppPalette.textMuted, fontSize: 10.5),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.champagneGold,
                      side: BorderSide(
                        color: AppPalette.champagneGold.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => ReceiptPreviewModal.show(context, tx),
                    icon: const Icon(Icons.receipt_outlined, size: 14),
                    label: const Text('Receipt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  if (vm.currentUser?.role == UserRole.admin) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Delete Receipt (Admin Only)',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger, size: 18),
                      onPressed: () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Delete Receipt?',
                          message:
                              'Permanently delete receipt ${tx.id} from historical sales? This action cannot be undone.',
                          confirmLabel: 'Delete Receipt',
                          destructive: true,
                        );
                        if (confirmed && context.mounted) {
                          final ok = await vm.deleteTransaction(tx.id);
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Receipt ${tx.id} deleted from sales history.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(String searchQuery) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: AppPalette.surface2,
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isNotEmpty
                ? 'No receipts match "$searchQuery"'
                : 'No Transactions on ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
            style: const TextStyle(
              color: AppPalette.textHigh,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            searchQuery.isNotEmpty
                ? 'Try searching by a different receipt number or customer name.'
                : 'No sales were tendered on this date. Use the date arrows above or pick another date.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

