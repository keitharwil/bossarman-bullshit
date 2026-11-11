import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Screen to generate, inspect, and export physical bin tags and part sticker QR/barcodes.
class PartBarcodeGeneratorScreen extends StatefulWidget {
  final InventoryItem item;

  const PartBarcodeGeneratorScreen({
    super.key,
    required this.item,
  });

  static Future<void> navigate(BuildContext context, InventoryItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartBarcodeGeneratorScreen(item: item),
      ),
    );
  }

  @override
  State<PartBarcodeGeneratorScreen> createState() =>
      _PartBarcodeGeneratorScreenState();
}

class _PartBarcodeGeneratorScreenState
    extends State<PartBarcodeGeneratorScreen> {
  final GlobalKey _tagBoundaryKey = GlobalKey();
  bool _useJsonPayload = true;
  bool _isExporting = false;

  String _getPayloadString(BranchId branch) {
    if (_useJsonPayload) {
      final payload = {
        'sku': widget.item.sku,
        'name': widget.item.name,
        'price': widget.item.price,
        'branch': branch.name,
      };
      return jsonEncode(payload);
    } else {
      return widget.item.sku;
    }
  }

  Future<void> _exportTagImage() async {
    setState(() => _isExporting = true);
    try {
      final boundary = _tagBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final safeSku = widget.item.sku.replaceAll('/', '_');
      final fileName = 'bin_tag_$safeSku.png';

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
          text:
              'Bin Tag Sticker: ${widget.item.name} (${widget.item.sku}) - Boss Arman MotoHub',
          subject: 'Bin Tag - ${widget.item.sku}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export tag image: $e'),
            backgroundColor: AppPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final branch = vm.activeBranch;
    final payload = _getPayloadString(branch);

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        title: const Text('Bin Tag & QR Generator'),
        backgroundColor: AppPalette.mantle,
        foregroundColor: AppPalette.textHigh,
        actions: [
          IconButton(
            tooltip: 'Export & Share Sticker PNG',
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppPalette.champagneGold,
                    ),
                  )
                : const Icon(Icons.share_rounded, color: AppPalette.champagneGold),
            onPressed: _isExporting ? null : _exportTagImage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payload Mode Selector Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surface0,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.champagneGold.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QR Payload Format',
                    style: TextStyle(
                      color: AppPalette.textHigh,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select whether to embed structured JSON metadata or raw SKU for handheld 1D/2D optical readers.',
                    style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: SlidingMarqueeText(text: 'JSON Payload'),
                        icon: Icon(Icons.data_object_rounded, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: SlidingMarqueeText(text: 'Raw SKU'),
                        icon: Icon(Icons.qr_code_2_rounded, size: 16),
                      ),
                    ],
                    selected: {_useJsonPayload},
                    onSelectionChanged: (set) {
                      setState(() {
                        _useJsonPayload = set.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppPalette.champagneGold.withValues(alpha: 0.25);
                        }
                        return AppPalette.surface1;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppPalette.champagneGold;
                        }
                        return AppPalette.textMuted;
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.crust,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppPalette.surface2,
                      ),
                    ),
                    child: Text(
                      payload,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppPalette.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Center(
              child: Text(
                'PHYSICAL BIN TAG PREVIEW',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Printable Bin Tag / Sticker Container (Target of RepaintBoundary)
            Center(
              child: RepaintBoundary(
                key: _tagBoundaryKey,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black87, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Branding
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.two_wheeler_rounded,
                              size: 16, color: Colors.black87),
                          SizedBox(width: 6),
                          Text(
                            'BOSS ARMAN MOTOHUB',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Colors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Location: ${branch.displayName.toUpperCase()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(color: Colors.black87, thickness: 1.5),
                      const SizedBox(height: 6),

                      // Part Name & Category
                      Text(
                        widget.item.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.category.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // High Contrast QR Code
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data: payload,
                          version: QrVersions.auto,
                          size: 150,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // SKU Display
                      Text(
                        widget.item.sku,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Shelf Coordinates & Large Price Tag
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SHELF BIN:',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  widget.item.shortShelfCoordinates,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '₱${widget.item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD700), // Gold
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Share & Print Button
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportTagImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.champagneGold,
                foregroundColor: AppPalette.crust,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.print_rounded),
              label: Text(
                _isExporting
                    ? 'GENERATING LABEL PNG...'
                    : 'PRINT / EXPORT BIN TAG (PNG)',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
