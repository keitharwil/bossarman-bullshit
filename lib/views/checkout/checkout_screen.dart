import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';
import '../shared/receipt_preview_modal.dart';

/// Standalone Checkout Screen with dedicated AppBar, leave confirmation,
/// full-size real GCash payment QR verification, cash change calculator,
/// and split-tender payment support.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final TextEditingController _customerCtrl =
      TextEditingController(text: 'Walk-in Rider');
  final TextEditingController _tenderedCtrl = TextEditingController();
  final TextEditingController _splitCashCtrl = TextEditingController();
  final TextEditingController _gcashRefCtrl = TextEditingController();

  bool _gcashPaymentVerified = false;
  bool _isProcessing = false;
  bool _cartExpanded = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<MotoHubViewModel>();
    _tenderedCtrl.text = vm.cartTotal.toStringAsFixed(0);
    _splitCashCtrl.text = (vm.cartTotal / 2).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _tenderedCtrl.dispose();
    _splitCashCtrl.dispose();
    _gcashRefCtrl.dispose();
    super.dispose();
  }

  Future<bool> _handleLeave(BuildContext context) async {
    final vm = context.read<MotoHubViewModel>();
    if (vm.cart.isEmpty) return true;
    final leave = await showConfirmDialog(
      context,
      title: 'Leave Checkout?',
      message:
          'Your cart items will remain saved. You can resume checkout anytime.',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
    );
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final cartTotal = vm.cartTotal;
    final branch = vm.activeBranch;
    final isOwner = vm.currentUser?.role == UserRole.admin;

    final gcashQrBase64 = vm.getGcashQrBase64(branch);
    final gcashName = vm.getGcashAccountName(branch);
    final gcashNumber = vm.getGcashAccountNumber(branch);

    final splitCash = double.tryParse(_splitCashCtrl.text.trim()) ?? (cartTotal / 2);
    final splitGcash = (cartTotal - splitCash).clamp(0.0, cartTotal);
    final tendered = double.tryParse(_tenderedCtrl.text.trim()) ??
        (_selectedMethod == PaymentMethod.split ? splitCash : cartTotal);

    final change = _selectedMethod == PaymentMethod.split
        ? (tendered - splitCash)
        : (_selectedMethod == PaymentMethod.cash ? (tendered - cartTotal) : 0.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _handleLeave(context);
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppPalette.crust,
        appBar: AppBar(
          backgroundColor: AppPalette.mantle,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppPalette.champagneGold),
            onPressed: () async {
              final shouldLeave = await _handleLeave(context);
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Checkout',
                style: TextStyle(
                  color: AppPalette.textHigh,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                '${vm.cartItemCount} ${vm.cartItemCount == 1 ? "item" : "items"} • ${branch.displayName}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.champagneGold.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                AppFormatters.currency(cartTotal),
                style: const TextStyle(
                  color: AppPalette.champagneGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: vm.cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        size: 56,
                        color: AppPalette.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cart is Empty',
                        style: TextStyle(
                          color: AppPalette.textHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Scan barcodes or select parts from inventory to checkout.',
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Counter'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cart Summary Card
                      Card(
                        color: AppPalette.mantle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppPalette.surface0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _cartExpanded = !_cartExpanded),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.receipt_outlined,
                                      color: AppPalette.champagneGold,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Order Summary (${vm.cartItemCount} items)',
                                        style: const TextStyle(
                                          color: AppPalette.textHigh,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _cartExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: AppPalette.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                              if (_cartExpanded) ...[
                                const Divider(color: AppPalette.surface0, height: 16),
                                ...vm.cart.map((c) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${c.quantity}x ${c.item.name}',
                                              style: const TextStyle(
                                                color: AppPalette.textBody,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            AppFormatters.currency(c.subtotal),
                                            style: const TextStyle(
                                              color: AppPalette.textHigh,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                              const Divider(color: AppPalette.surface0, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Due:',
                                    style: TextStyle(
                                      color: AppPalette.textHigh,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.currency(cartTotal),
                                    style: const TextStyle(
                                      color: AppPalette.champagneGold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Info
                      TextField(
                        controller: _customerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer / Rider Name',
                          hintText: 'Walk-in Rider',
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: AppPalette.champagneGold),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Method Selector
                      const Text(
                        'PAYMENT METHOD',
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<PaymentMethod>(
                          segments: const [
                            ButtonSegment(
                              value: PaymentMethod.cash,
                              icon: Icon(Icons.payments_outlined, size: 18),
                              label: SlidingMarqueeText(text: 'Cash'),
                            ),
                            ButtonSegment(
                              value: PaymentMethod.gcash,
                              icon: Icon(Icons.qr_code_2_rounded, size: 18),
                              label: SlidingMarqueeText(text: 'GCash'),
                            ),
                            ButtonSegment(
                              value: PaymentMethod.split,
                              icon: Icon(Icons.call_split_rounded, size: 18),
                              label: SlidingMarqueeText(text: 'Split'),
                            ),
                          ],
                          selected: {_selectedMethod},
                          onSelectionChanged: (set) {
                            setState(() {
                              _selectedMethod = set.first;
                              _gcashPaymentVerified = false;
                              if (_selectedMethod == PaymentMethod.cash) {
                                _tenderedCtrl.text = cartTotal.toStringAsFixed(0);
                              } else if (_selectedMethod == PaymentMethod.split) {
                                _splitCashCtrl.text = (cartTotal / 2).toStringAsFixed(0);
                                _tenderedCtrl.text = (cartTotal / 2).toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Details based on method
                      if (_selectedMethod == PaymentMethod.cash)
                        _buildCashSection(cartTotal, tendered, change)
                      else if (_selectedMethod == PaymentMethod.gcash)
                        _buildGcashSection(
                          cartTotal,
                          gcashQrBase64,
                          gcashName,
                          gcashNumber,
                          isOwner,
                        )
                      else
                        _buildSplitSection(
                          cartTotal,
                          splitCash,
                          splitGcash,
                          tendered,
                          change,
                          gcashQrBase64,
                          gcashName,
                          gcashNumber,
                          isOwner,
                        ),

                      const SizedBox(height: 24),

                      // Checkout Action Button
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.champagneGold,
                          foregroundColor: AppPalette.crust,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _executeCheckout(vm, cartTotal, tendered, splitCash, splitGcash),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppPalette.crust,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Complete Checkout (${AppFormatters.currency(cartTotal)})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCashSection(double total, double tendered, double change) {
    return Card(
      color: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.surface0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tenderedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Cash Tendered (₱)',
                prefixIcon: Icon(Icons.attach_money_rounded,
                    color: AppPalette.champagneGold),
              ),
            ),
            const SizedBox(height: 10),
            // Quick preset pills
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Exact'),
                  onPressed: () {
                    setState(() {
                      _tenderedCtrl.text = total.toStringAsFixed(0);
                    });
                  },
                ),
                ActionChip(
                  label: const Text('+₱50'),
                  onPressed: () {
                    final cur = double.tryParse(_tenderedCtrl.text) ?? total;
                    setState(() {
                      _tenderedCtrl.text = (cur + 50).toStringAsFixed(0);
                    });
                  },
                ),
                ActionChip(
                  label: const Text('+₱100'),
                  onPressed: () {
                    final cur = double.tryParse(_tenderedCtrl.text) ?? total;
                    setState(() {
                      _tenderedCtrl.text = (cur + 100).toStringAsFixed(0);
                    });
                  },
                ),
                ActionChip(
                  label: const Text('+₱500'),
                  onPressed: () {
                    final cur = double.tryParse(_tenderedCtrl.text) ?? total;
                    setState(() {
                      _tenderedCtrl.text = (cur + 500).toStringAsFixed(0);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: change >= 0
                    ? AppPalette.success.withValues(alpha: 0.15)
                    : AppPalette.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    change >= 0 ? 'Change to Return:' : 'Insufficient Tender:',
                    style: TextStyle(
                      color: change >= 0 ? AppPalette.success : AppPalette.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(change.abs()),
                    style: TextStyle(
                      color: change >= 0 ? AppPalette.success : AppPalette.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGcashSection(
    double total,
    String? qrBase64,
    String accountName,
    String accountNumber,
    bool isOwner,
  ) {
    return Card(
      color: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.surface0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'SCAN OFFICIAL SHOP GCASH QR',
              style: TextStyle(
                color: AppPalette.champagneGold,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Real GCash QR Display
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPalette.champagneGold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: qrBase64 != null && qrBase64.isNotEmpty
                  ? Image.memory(
                      base64Decode(qrBase64),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text(
                          'Invalid QR image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No GCash QR Configured',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOwner
                                  ? 'Upload your shop GCash QR in Admin Settings.'
                                  : 'Contact the owner to set up the shop GCash QR.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            // Account details pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.surface1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Account: $accountName',
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Number: $accountNumber',
                    style: const TextStyle(
                      color: AppPalette.champagneGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // GCash Reference Number Field
            TextField(
              controller: _gcashRefCtrl,
              decoration: const InputDecoration(
                labelText: 'GCash Reference # (Optional / Last 4 Digits)',
                hintText: 'e.g. 1234',
                prefixIcon: Icon(Icons.tag_rounded, color: AppPalette.champagneGold),
              ),
            ),
            const SizedBox(height: 12),

            // Required Verification Checkbox
            CheckboxListTile(
              value: _gcashPaymentVerified,
              onChanged: (v) => setState(() => _gcashPaymentVerified = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppPalette.success,
              title: const Text(
                'Payment received in shop GCash account',
                style: TextStyle(
                  color: AppPalette.textHigh,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: const Text(
                'Cashier must verify the SMS or app receipt before completing.',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection(
    double total,
    double splitCash,
    double splitGcash,
    double tendered,
    double change,
    String? qrBase64,
    String accountName,
    String accountNumber,
    bool isOwner,
  ) {
    return Card(
      color: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.surface0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _splitCashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cash Portion (₱)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GCash Portion:',
                          style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormatters.currency(splitGcash),
                            style: const TextStyle(
                              color: AppPalette.champagneGold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tenderedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Cash Tendered (₱)',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cash Change: ${AppFormatters.currency(change >= 0 ? change : 0)}',
              style: TextStyle(
                color: change >= 0 ? AppPalette.success : AppPalette.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gcashRefCtrl,
              decoration: const InputDecoration(
                labelText: 'GCash Reference # (Optional)',
                hintText: 'e.g. 1234',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _gcashPaymentVerified,
              onChanged: (v) => setState(() => _gcashPaymentVerified = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppPalette.success,
              title: const Text(
                'GCash portion confirmed received',
                style: TextStyle(
                  color: AppPalette.textHigh,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeCheckout(
    MotoHubViewModel vm,
    double total,
    double tendered,
    double splitCash,
    double splitGcash,
  ) async {
    final customer = _customerCtrl.text.trim().isEmpty
        ? 'Walk-in Rider'
        : _customerCtrl.text.trim();

    if (_selectedMethod == PaymentMethod.cash) {
      if (tendered < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text('Cash tendered is less than the total amount due.'),
          ),
        );
        return;
      }
    } else if (_selectedMethod == PaymentMethod.gcash) {
      if (!_gcashPaymentVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              'Please confirm GCash payment was received before completing checkout.',
            ),
          ),
        );
        return;
      }
    } else if (_selectedMethod == PaymentMethod.split) {
      if (splitCash + splitGcash < total - 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text('Split cash and GCash portions must equal total amount.'),
          ),
        );
        return;
      }
      if (tendered < splitCash) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text('Cash tendered is less than the cash portion.'),
          ),
        );
        return;
      }
      if (!_gcashPaymentVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              'Please confirm GCash payment was received before completing checkout.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      final tx = await vm.processRetailCheckout(
        paymentMethod: _selectedMethod,
        customerName: customer,
        amountTendered: _selectedMethod == PaymentMethod.gcash ? total : tendered,
        cashAmount: _selectedMethod == PaymentMethod.cash
            ? total
            : (_selectedMethod == PaymentMethod.split ? splitCash : 0),
        gcashAmount: _selectedMethod == PaymentMethod.gcash
            ? total
            : (_selectedMethod == PaymentMethod.split ? splitGcash : 0),
        gcashRef: _gcashRefCtrl.text.trim().isNotEmpty
            ? _gcashRefCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      if (tx != null) {
        Navigator.of(context).pop(); // Close checkout screen
        ReceiptPreviewModal.show(context, tx);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              vm.statusMessage ?? 'Checkout failed. Please verify payment details.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text('Checkout error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
