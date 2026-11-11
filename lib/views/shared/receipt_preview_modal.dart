import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Realistic Digital Thermal Receipt Preview Modal
/// Captures high-res PNG byte stream using [RepaintBoundary] and shares via [SharePlus.instance.share].
class ReceiptPreviewModal extends StatefulWidget {
  final PosTransaction transaction;
  final bool clearCartOnClose;

  const ReceiptPreviewModal({
    super.key,
    required this.transaction,
    this.clearCartOnClose = true,
  });

  static Future<void> show(
    BuildContext context,
    PosTransaction transaction, {
    bool clearCartOnClose = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptPreviewModal(
        transaction: transaction,
        clearCartOnClose: clearCartOnClose,
      ),
    );
  }

  @override
  State<ReceiptPreviewModal> createState() => _ReceiptPreviewModalState();
}

class _ReceiptPreviewModalState extends State<ReceiptPreviewModal> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final fileName = 'receipt_${widget.transaction.id}.png';

      final XFile xFile;
      if (kIsWeb) {
        xFile = XFile.fromData(bytes, mimeType: 'image/png', name: fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        xFile = XFile(filePath, mimeType: 'image/png', name: fileName);
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Boss Arman MotoHub Official Receipt - ${widget.transaction.id}',
          subject: 'Official Receipt ${widget.transaction.id}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export receipt image: $e'),
            backgroundColor: AppPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _handleClose() {
    if (widget.clearCartOnClose) {
      final vm = context.read<MotoHubViewModel>();
      vm.clearCart();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final branchAddress = tx.branch == BranchId.patimbao
        ? 'Poblacion II, Patimbao Rd., Santa Cruz, Laguna'
        : 'P. Guevara Ave, Santa Cruz, Laguna';

    final dateFormatted =
        '${tx.createdAt.year}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')} '
        '${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.crust,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: AppPalette.champagneGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppPalette.champagneGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transaction Receipt',
                    style: TextStyle(
                      color: AppPalette.textHigh,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Share / Export Receipt PNG',
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.champagneGold,
                          ),
                        )
                      : const Icon(
                          Icons.share_rounded,
                          color: AppPalette.champagneGold,
                        ),
                  onPressed: _isSharing ? null : _shareReceipt,
                ),
                IconButton(
                  tooltip: 'Close & Clear Cart',
                  icon: const Icon(Icons.close_rounded, color: AppPalette.textMuted),
                  onPressed: _handleClose,
                ),
              ],
            ),
          ),

          // Scrollable Thermal Receipt Preview Container
          Flexible(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF9F6), // Thermal Paper Off-White
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Center(
                        child: Text(
                          'BOSS ARMAN',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'MOTORCYCLE PARTS & REPAIR',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Branch: ${tx.branch.displayName.toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          branchAddress,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // Meta Information
                      _buildReceiptRow('RECEIPT #:', tx.id),
                      _buildReceiptRow('DATE / TIME:', dateFormatted),
                      _buildReceiptRow('CASHIER:', tx.cashierName.toUpperCase()),
                      _buildReceiptRow('CUSTOMER:', tx.customerName.toUpperCase()),
                      if (tx.linkedJobOrderId != null)
                        _buildReceiptRow('JOB ORDER:', tx.linkedJobOrderId!),

                      const SizedBox(height: 8),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // Itemized Table Header
                      const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'QTY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'TOTAL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Itemized Table Rows
                      ..._buildItemizedRows(tx),

                      const SizedBox(height: 8),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // Subtotals & Labor Breakdown
                      if (tx.partsSubtotal > 0)
                        _buildReceiptRow(
                          'PARTS SUBTOTAL:',
                          '₱${tx.partsSubtotal.toStringAsFixed(2)}',
                        ),
                      if (tx.laborTotal > 0)
                        _buildReceiptRow(
                          'SERVICE / LABOR:',
                          '₱${tx.laborTotal.toStringAsFixed(2)}',
                        ),

                      const SizedBox(height: 6),
                      // Grand Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL AMOUNT:',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF000000),
                            ),
                          ),
                          Text(
                            '₱${tx.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // Payment Breakdown
                      _buildPaymentBreakdown(tx),

                      const SizedBox(height: 14),
                      _buildDashedLine(),
                      const SizedBox(height: 12),

                      // Footer Barcode Graphic & Patronage note
                      const Center(
                        child: Text(
                          '*** THANK YOU FOR YOUR BUSINESS! ***',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Center(
                        child: Text(
                          'Ride Safe with Boss Arman MotoHub',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '*${tx.id}*',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            letterSpacing: 4,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Close Action
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.champagneGold,
                  foregroundColor: AppPalette.crust,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'DONE & RETURN TO POS',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemizedRows(PosTransaction tx) {
    // itemsSummary can be comma separated "1x Tire, 2x Oil Filter" or custom string
    final items = tx.itemsSummary.split(', ');
    if (items.isEmpty || tx.itemsSummary.trim().isEmpty) {
      return [
        _buildItemLine(
          desc: 'Items & Services Rendered',
          qty: '1',
          total: '₱${tx.totalAmount.toStringAsFixed(2)}',
        ),
      ];
    }

    return items.map((raw) {
      final trimmed = raw.trim();
      // Match pattern like "2x Part Name"
      final match = RegExp(r'^(\d+)x\s+(.+)$').firstMatch(trimmed);
      if (match != null) {
        final qty = match.group(1) ?? '1';
        final name = match.group(2) ?? trimmed;
        return _buildItemLine(desc: name, qty: qty, total: '');
      }
      return _buildItemLine(desc: trimmed, qty: '1', total: '');
    }).toList();
  }

  Widget _buildItemLine({
    required String desc,
    required String qty,
    required String total,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              desc,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              total,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(PosTransaction tx) {
    switch (tx.paymentMethod) {
      case PaymentMethod.cash:
        return Column(
          children: [
            _buildReceiptRow('PAYMENT METHOD:', 'CASH'),
            _buildReceiptRow(
              'AMOUNT TENDERED:',
              '₱${tx.amountTendered.toStringAsFixed(2)}',
            ),
            _buildReceiptRow(
              'CHANGE DUE:',
              '₱${tx.changeAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        );
      case PaymentMethod.gcash:
        final last4 = (tx.gcashRef != null && tx.gcashRef!.length >= 4)
            ? tx.gcashRef!.substring(tx.gcashRef!.length - 4)
            : (tx.gcashRef ?? 'N/A');
        return Column(
          children: [
            _buildReceiptRow('PAYMENT METHOD:', 'GCASH'),
            _buildReceiptRow('GCASH REF (LAST 4):', '****$last4'),
            _buildReceiptRow(
              'AMOUNT PAID:',
              '₱${tx.totalAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        );
      case PaymentMethod.split:
        final last4 = (tx.gcashRef != null && tx.gcashRef!.length >= 4)
            ? tx.gcashRef!.substring(tx.gcashRef!.length - 4)
            : (tx.gcashRef ?? 'N/A');
        return Column(
          children: [
            _buildReceiptRow('PAYMENT METHOD:', 'SPLIT (CASH + GCASH)'),
            _buildReceiptRow(
              'CASH PORTION:',
              '₱${tx.cashAmount.toStringAsFixed(2)}',
            ),
            _buildReceiptRow(
              'CASH TENDERED:',
              '₱${tx.amountTendered.toStringAsFixed(2)}',
            ),
            _buildReceiptRow(
              'CASH CHANGE:',
              '₱${tx.changeAmount.toStringAsFixed(2)}',
            ),
            _buildReceiptRow(
              'GCASH PORTION:',
              '₱${tx.gcashAmount.toStringAsFixed(2)}',
            ),
            _buildReceiptRow('GCASH REF (LAST 4):', '****$last4'),
          ],
        );
    }
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: const Color(0xFF333333),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF888888)),
              ),
            );
          }),
        );
      },
    );
  }
}
