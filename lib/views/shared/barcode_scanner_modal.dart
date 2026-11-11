import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../checkout/checkout_screen.dart';

/// Live Camera QR/Barcode Scanner HUD powered by `mobile_scanner` with
/// Instant Shelf Bin Coordinate Locator (`Rack B • Shelf 2 • Bin 04`) and
/// Material 3 Expressive (`M3ECard`, `M3EButton`) action triggers for POS / Mechanic / Admin.
class BarcodeScannerModal extends StatefulWidget {
  final String? targetJobOrderId;
  final bool autoAddToPosCart;

  const BarcodeScannerModal({
    super.key,
    this.targetJobOrderId,
    this.autoAddToPosCart = false,
  });

  static Future<InventoryItem?> show(
    BuildContext context, {
    String? targetJobOrderId,
    bool autoAddToPosCart = false,
  }) {
    return showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (_) => BarcodeScannerModal(
        targetJobOrderId: targetJobOrderId,
        autoAddToPosCart: autoAddToPosCart,
      ),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  late final MobileScannerController _scannerController;
  final TextEditingController _codeController = TextEditingController();
  InventoryItem? _scannedItem;
  List<InventoryItem> _matchingItems = [];
  bool _torchEnabled = false;
  String? _lastDetectedRawCode;
  DateTime? _lastDetectedAt;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture, MotoHubViewModel vm) {
    if (_isProcessingScan) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        final now = DateTime.now();
        if (_lastDetectedRawCode == raw &&
            _lastDetectedAt != null &&
            now.difference(_lastDetectedAt!).inMilliseconds < 1500) {
          return;
        }
        _lastDetectedRawCode = raw;
        _lastDetectedAt = now;
        _handleScanCode(vm, raw, fromCamera: true);
        break;
      }
    }
  }

  void _handleScanCode(
    MotoHubViewModel vm,
    String code, {
    bool fromCamera = false,
  }) {
    if (_isProcessingScan && fromCamera) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    if (fromCamera) {
      _isProcessingScan = true;
    }

    try {
      String resolvedSku = trimmed;
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map && decoded['sku'] != null) {
            resolvedSku = decoded['sku'].toString().trim();
          }
        } catch (_) {}
      }

      if (fromCamera) {
        final found = vm.findPartByCode(resolvedSku) ?? vm.findPartByCode(trimmed);
        if (found != null) {
          HapticFeedback.mediumImpact();
        }

        if (!mounted) return;
        setState(() {
          _scannedItem = found;
          _matchingItems = [];
          if (found != null) {
            _codeController.text = found.barcode;
          }
        });
        if (found == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text('No registered part matches barcode "$trimmed"'),
              backgroundColor: AppPalette.danger,
            ),
          );
          return;
        }

        if (widget.autoAddToPosCart) {
          final avail = found.availableStockFor(vm.activeBranch);
          if (avail > 0) {
            final added = vm.addToCart(found);
            if (added) {
              final cartQty = vm.cart.firstWhere(
                (c) => c.item.id == found.id,
                orElse: () => CartItem(item: found, quantity: 1),
              ).quantity;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 1400),
                  content: Text('Added ${found.name} to POS Cart (Qty: $cartQty)'),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.danger,
                  duration: const Duration(milliseconds: 1500),
                  content: Text(vm.statusMessage ?? 'Stock limit reached for ${found.name}'),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppPalette.danger,
                duration: const Duration(milliseconds: 1500),
                content: Text('${found.name} is OUT OF STOCK at ${vm.activeBranch.displayName}'),
              ),
            );
          }
        }
        return;
      }

    // Manual input search (matches exact barcode/SKU first, then partial item name)
    final exact = vm.findPartByCode(resolvedSku) ?? vm.findPartByCode(trimmed);
    if (exact != null) {
      if (!mounted) return;
      setState(() {
        _scannedItem = exact;
        _matchingItems = [];
        _codeController.text = exact.barcode;
      });
      if (widget.autoAddToPosCart) {
        final avail = exact.availableStockFor(vm.activeBranch);
        if (avail > 0) {
          vm.addToCart(exact);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found & added ${exact.name} to POS Cart'),
            ),
          );
        }
      }
      return;
    }

    // Partial search by item name, SKU, or barcode
    final searchMatches = vm.searchParts(trimmed);
    if (!mounted) return;
    if (searchMatches.isEmpty) {
      setState(() {
        _matchingItems = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No part matched "$trimmed" (searched name, barcode, and SKU)'),
          backgroundColor: AppPalette.danger,
        ),
      );
    } else if (searchMatches.length == 1) {
      final single = searchMatches.first;
      setState(() {
        _scannedItem = single;
        _matchingItems = [];
        _codeController.text = single.barcode;
      });
      if (widget.autoAddToPosCart) {
        final avail = single.availableStockFor(vm.activeBranch);
        if (avail > 0) {
          final added = vm.addToCart(single);
          if (added) {
            final cartQty = vm.cart.firstWhere(
              (c) => c.item.id == single.id,
              orElse: () => CartItem(item: single, quantity: 1),
            ).quantity;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 1400),
                content: Text('Matched & added ${single.name} to POS Cart (Qty: $cartQty)'),
              ),
            );
          }
        }
      }
    } else {
      // Multiple items match — show tappable list
      setState(() {
        _matchingItems = searchMatches;
      });
    }
  } finally {
    if (fromCamera) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _isProcessingScan = false;
        }
      });
    }
  }
}

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (!mounted) return;
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {
      // Ignore on single-camera or desktop devices
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final InventoryItem? rawItem = _scannedItem;
    final InventoryItem? item = rawItem == null
        ? null
        : vm.allInventory.firstWhere(
            (i) => i.id == rawItem.id,
            orElse: () => rawItem,
          );
    final availActive = item?.availableStockFor(vm.activeBranch) ?? 0;

    final hasCartItems = vm.cartItemCount > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    (hasCartItems ? 125 : 20),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppPalette.surface0,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.champagneGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppPalette.champagneGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live QR / Barcode & Shelf HUD',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Active Terminal: ${vm.activeBranch.displayName}',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Switch Camera',
                    onPressed: _switchCamera,
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: AppPalette.textBody,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Toggle Torch',
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchEnabled
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: _torchEnabled
                          ? AppPalette.champagneGold
                          : AppPalette.textMuted,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.champagneGold.withValues(alpha: 0.18),
                      foregroundColor: AppPalette.champagneGold,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live MobileScanner Camera Viewfinder with Animated Laser & Bin HUD Overlay
              Container(
                height: 215,
                decoration: BoxDecoration(
                  color: AppPalette.crust,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppPalette.champagneGold.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Real MobileScanner camera feed with graceful HUD fallback
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) => _onBarcodeDetect(capture, vm),
                      errorBuilder: (context, error) {
                        final isDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
                        return Container(
                          color: AppPalette.crust,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isDenied
                                    ? Icons.no_photography_rounded
                                    : Icons.camera_alt_outlined,
                                color: AppPalette.danger,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isDenied
                                    ? 'Camera Access Denied'
                                    : 'Camera Unavailable',
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isDenied
                                    ? 'Camera permission is required to scan QR and barcodes. Please enable it in Settings or use manual search below.'
                                    : 'Camera preview could not be loaded. Please enter barcode/SKU below.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      placeholderBuilder: (context) {
                        return _buildOpticalGridFallback();
                      },
                    ),

                    // Subtle Corner Reticle Frame
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 34,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppPalette.champagneGold
                                  .withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Animated Laser Line
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        return Positioned(
                          top: 28 + (_laserController.value * 140),
                          left: 28,
                          right: 28,
                          child: IgnorePointer(
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                gradient: AppPalette.goldActionGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.champagneGold
                                        .withValues(alpha: 0.75),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Top Left Camera Pill
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.mantle.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppPalette.surface0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: item != null
                                      ? AppPalette.success
                                      : AppPalette.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item != null
                                      ? 'LIVE QR/BARCODE SCANNER • ${item.barcode}'
                                      : 'LIVE QR/BARCODE SCANNER • READY',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.textHigh,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Shelf Bin Locator Coordinate Readout
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppPalette.champagneGold,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              color: AppPalette.champagneGold,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item != null
                                    ? 'SHELF BIN LOCATOR: ${item.shelfCoordinates}'
                                    : 'SHELF BIN LOCATOR: NO INVENTORY REGISTERED YET',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Manual Barcode / SKU / Name Search Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      onSubmitted: (val) => _handleScanCode(vm, val),
                      decoration: const InputDecoration(
                        hintText: 'Search by part name, QR/barcode, or SKU...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppPalette.champagneGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  M3EButton.filled(
                    size: M3EButtonSize.md,
                    onPressed: () => _handleScanCode(vm, _codeController.text),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    child: const Text('Lookup'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Multi-item Search Results list (Feature B)
              if (_matchingItems.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppPalette.surface0,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppPalette.champagneGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.list_alt_rounded,
                              size: 16,
                              color: AppPalette.champagneGold,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_matchingItems.length} Matching Parts Found (Tap to Select):',
                              style: const TextStyle(
                                color: AppPalette.champagneGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppPalette.surface1, height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _matchingItems.length,
                          separatorBuilder: (_, _) =>
                              const Divider(color: AppPalette.surface1, height: 1),
                          itemBuilder: (context, idx) {
                            final p = _matchingItems[idx];
                            final avail = p.availableStockFor(vm.activeBranch);
                            return ListTile(
                              dense: true,
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                '${p.category} • SKU: ${p.sku} • ${p.shelfCoordinates}',
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${p.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppPalette.champagneGold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$avail avail (${vm.activeBranch.shortName})',
                                    style: TextStyle(
                                      color: avail > 0
                                          ? AppPalette.success
                                          : AppPalette.danger,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _scannedItem = p;
                                  _codeController.text = p.barcode;
                                  _matchingItems = [];
                                });
                                if (widget.autoAddToPosCart && avail > 0) {
                                  vm.addToCart(p);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ${p.name} to POS Cart'),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (item == null)
                MotoHubEmptyState(
                  icon: Icons.qr_code_scanner_rounded,
                  title: vm.allInventory.isEmpty
                      ? 'No Inventory SKUs Registered Yet'
                      : 'Scan a Part or Enter SKU',
                  subtitle: vm.allInventory.isEmpty
                      ? 'Add motorcycle parts in Inventory Catalog first to scan QR/barcodes.'
                      : 'Point the camera at a QR code, barcode, or enter a SKU above to locate shelf bin coordinates.',
                  actionLabel: 'Close Scanner',
                  onAction: () => Navigator.of(context).pop(),
                )
              else ...[
                // Instant Tap-to-Scan Barcode Deck
                const Text(
                  'QUICK SELECT / SIMULATE QR TAG:',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.allInventory.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final p = vm.allInventory[index];
                      final isSelected = p.id == item.id;
                      return FilterChip(
                        selected: isSelected,
                        label: Text('${p.sku} • ${p.name.split(" (").first}'),
                        onSelected: (_) {
                          setState(() {
                            _scannedItem = p;
                            _codeController.text = p.barcode;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Scanned Part Result Card using Material 3 Expressive M3ECard
                M3ECard(
                  variant: M3ECardVariant.filled,
                  color: AppPalette.crust,
                  borderRadius: BorderRadius.circular(22),
                  border: const BorderSide(
                    color: AppPalette.champagneGold,
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.sku}  •  QR/EAN: ${item.barcode}',
                                  style: const TextStyle(
                                    color: AppPalette.champagneGold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: AppPalette.textHigh,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fits: ${item.compatibleModels}',
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.currency(item.price),
                            style: const TextStyle(
                              color: AppPalette.champagneGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Warehouse Shelf Bin Coordinates Banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.surface0),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shelves,
                                  color: AppPalette.champagneGold,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Location: ${item.shelfCoordinates}',
                                    style: const TextStyle(
                                      color: AppPalette.textHigh,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                color: availActive > 0
                                    ? AppPalette.success.withValues(alpha: 0.18)
                                    : AppPalette.danger.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (vm.currentUser?.role == UserRole.cashier ||
                                        vm.currentUser?.role ==
                                            UserRole.mechanic)
                                    ? '${vm.activeBranch.displayName}: $availActive In-Stock'
                                    : 'Patimbao: ${item.availableStockFor(BranchId.patimbao)} | P.Guevara: ${item.availableStockFor(BranchId.pedroGuevara)}',
                                style: TextStyle(
                                  color: availActive > 0
                                      ? AppPalette.success
                                      : AppPalette.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Material 3 Expressive Action Buttons based on Context
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          M3EButton.filled(
                            size: M3EButtonSize.sm,
                            onPressed: availActive > 0
                                ? () {
                                    final added = vm.addToCart(item);
                                    if (!added) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppPalette.danger,
                                          content: Text(
                                            vm.statusMessage ??
                                                'Could not add part to POS Cart.',
                                            style: const TextStyle(
                                              color: AppPalette.crust,
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final cartQty = vm.cart.firstWhere(
                                      (c) => c.item.id == item.id,
                                      orElse: () => CartItem(item: item, quantity: 1),
                                    ).quantity;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(milliseconds: 1400),
                                        content: Text(
                                          'Added ${item.name} (${item.shortShelfCoordinates}) to POS Cart (Qty: $cartQty)',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18,
                            ),
                            child: const Text('Add to POS Cart'),
                          ),
                          if (widget.targetJobOrderId != null)
                            M3EButton.tonal(
                              size: M3EButtonSize.sm,
                              onPressed: availActive > 0
                                  ? () async {
                                      final ok = await vm.attachPartToJobOrder(
                                        jobId: widget.targetJobOrderId!,
                                        part: item,
                                      );
                                      if (!context.mounted) return;
                                      if (ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            duration: const Duration(milliseconds: 1400),
                                            content: Text(
                                              'Locked ${item.name} to Job ${widget.targetJobOrderId}',
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppPalette.danger,
                                            content: Text(
                                              vm.statusMessage ??
                                                  'Could not lock part to job order.',
                                              style: const TextStyle(
                                                color: AppPalette.crust,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              child: Text('Lock to ${widget.targetJobOrderId}'),
                            ),
                          M3EButton.outlined(
                            size: M3EButtonSize.sm,
                            onPressed: () {
                              Navigator.of(context).pop(item);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasCartItems) _buildFloatingPaymentFlyout(context, vm),
      ],
    );
  },
);
}

  Widget _buildFloatingPaymentFlyout(BuildContext context, MotoHubViewModel vm) {
    final total = vm.cartTotal;
    final count = vm.cartItemCount;

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.crust.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppPalette.champagneGold.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cart Summary Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.champagneGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppPalette.champagneGold,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count ${count == 1 ? "Item" : "Items"}',
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${AppFormatters.currency(total)}',
                    style: const TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Standalone Checkout Screen Trigger
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.champagneGold,
                foregroundColor: AppPalette.crust,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => CheckoutScreen.push(context),
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Proceed to Checkout (${AppFormatters.currency(total)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpticalGridFallback() {
    return ColoredBox(
      color: AppPalette.crust,
      child: Opacity(
        opacity: 0.14,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 32,
          itemBuilder: (_, index) => Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppPalette.champagneGold,
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
