import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../checkout/checkout_screen.dart';
import 'confirm_dialog.dart';

/// Staff-facing list of active customer item reservations for the active
/// branch. Lets Cashier/Owner Confirm, Mark Ready, hand off to POS, or Cancel.
class ReservationQueueSection extends StatefulWidget {
  const ReservationQueueSection({super.key});

  @override
  State<ReservationQueueSection> createState() =>
      _ReservationQueueSectionState();
}

class _ReservationQueueSectionState extends State<ReservationQueueSection> {
  final Set<String> _busy = <String>{};

  Future<void> _run(
    String orderId,
    Future<bool> Function() action,
    String successMsg,
  ) async {
    if (_busy.contains(orderId)) return;
    setState(() => _busy.add(orderId));
    final vm = context.read<MotoHubViewModel>();
    try {
      final ok = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppPalette.success : AppPalette.danger,
          content: Text(
            ok ? successMsg : (vm.statusMessage ?? 'Action failed.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text('Action failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(orderId));
    }
  }

  Color _statusColor(ClickAndCollectOrder o) {
    if (o.isReady) return AppPalette.success;
    if (o.isConfirmed) return AppPalette.champagneGold;
    if (o.isCancelled || o.isExpired) return AppPalette.danger;
    if (o.isCompleted) return AppPalette.textMuted;
    return AppPalette.warning;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final orders = vm.branchClickCollectOrders
        .where((o) => o.isPending || o.isConfirmed || o.isReady)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Item Reservations (${orders.length})',
          style: const TextStyle(
            color: AppPalette.textHigh,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Confirm, prepare, and hand off reserved items to POS for pickup.',
          style: TextStyle(color: AppPalette.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        M3ECardList(
          itemCount: orders.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(14),
          emptyBuilder: const MotoHubEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No Active Reservations',
            subtitle:
                'Customer item reservations for this branch will appear here.',
          ),
          itemBuilder: (context, index) {
            final order = orders[index];
            final color = _statusColor(order);
            final busy = _busy.contains(order.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.id} • ${order.quantity}x ${order.partName}',
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${order.customerName} (${order.customerPhone}) • ${AppFormatters.currency(order.totalAmount)}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (busy)
                  const LinearProgressIndicator(minHeight: 3)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (order.canStaffConfirm)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () => _run(
                            order.id,
                            () => vm.confirmClickAndCollectOrder(order.id),
                            'Confirmed reservation ${order.id}.',
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 16),
                          child: const Text('Confirm'),
                        ),
                      if (order.canStaffMarkReady)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () => _run(
                            order.id,
                            () => vm.markReadyClickAndCollectOrder(order.id),
                            'Reservation ${order.id} is Ready for Pickup.',
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined,
                              size: 16),
                          child: const Text('Mark Ready'),
                        ),
                      if (order.canStaffComplete)
                        M3EButton.filled(
                          size: M3EButtonSize.xs,
                          onPressed: () {
                            final ok = vm.handoffReservationToPos(order);
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppPalette.danger,
                                  content: Text(vm.statusMessage ??
                                      'Could not hand off to POS.'),
                                ),
                              );
                              return;
                            }
                            CheckoutScreen.push(context);
                          },
                          icon: const Icon(Icons.point_of_sale_rounded,
                              size: 16),
                          child: const Text('Pickup via POS'),
                        ),
                      M3EButton.tonal(
                        size: M3EButtonSize.xs,
                        onPressed: () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Cancel Reservation?',
                            message:
                                'Cancel reservation ${order.id} for ${order.customerName}? The held stock will be released.',
                            confirmLabel: 'Cancel Reservation',
                            destructive: true,
                          );
                          if (!confirmed || !mounted) return;
                          await _run(
                            order.id,
                            () => vm.cancelClickAndCollectOrder(order.id),
                            'Cancelled reservation ${order.id}.',
                          );
                        },
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppPalette.danger),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppPalette.danger)),
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
