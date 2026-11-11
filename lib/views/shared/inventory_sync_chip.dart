import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Top-right chip: Synced / Syncing / Offline (n) / Sync error.
/// Tap it to force a sync now.
class InventorySyncChip extends StatelessWidget {
  /// true = icon only (use on cashier / mechanic where the bar is crowded)
  final bool compact;
  const InventorySyncChip({super.key, this.compact = false});

  Future<void> _onTap(BuildContext context, MotoHubViewModel vm) async {
    if (vm.inventorySyncStatus == InventorySyncStatus.syncing) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.syncInventory();

    String text;
    if (ok) {
      text = 'Inventory is up to date on all devices.';
    } else if (vm.inventorySyncStatus == InventorySyncStatus.error) {
      text = 'Sync blocked: ${vm.inventorySyncError}';
    } else {
      text = 'Offline. Changes are saved on this phone and will upload '
          'automatically when you are back online.';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final status = vm.inventorySyncStatus;
    final pending = vm.pendingInventoryCount;

    Color color = AppPalette.success;
    String label = 'Synced';
    IconData icon = Icons.cloud_done_outlined;
    var spinning = false;

    if (status == InventorySyncStatus.syncing) {
      color = AppPalette.info;
      label = 'Syncing';
      spinning = true;
    } else if (status == InventorySyncStatus.offline) {
      color = AppPalette.warning;
      label = pending > 0 ? 'Offline ($pending)' : 'Offline';
      icon = Icons.cloud_off_rounded;
    } else if (status == InventorySyncStatus.error) {
      color = AppPalette.danger;
      label = 'Sync error';
      icon = Icons.error_outline_rounded;
    } else if (pending > 0) {
      color = AppPalette.info;
      label = 'Pending ($pending)';
      icon = Icons.cloud_upload_outlined;
    }

    final last = vm.lastInventorySyncAt;
    final tooltip = last == null
        ? 'Tap to sync inventory'
        : 'Last synced ${TimeOfDay.fromDateTime(last).format(context)}. '
            'Tap to sync now.';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onTap(context, vm),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinning
                  ? SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 13, color: color),
              if (!compact || pending > 0) ...[
                const SizedBox(width: 4),
                Text(
                  compact ? '$pending' : label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
