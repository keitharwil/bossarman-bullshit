import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Single reusable confirmation dialog for every destructive / irreversible
/// action. Returns `true` only when the user explicitly taps the confirm
/// button. Critical dialogs cannot be dismissed by tapping outside, and the
/// confirm button disables itself after the first tap to prevent double-taps.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool barrierDismissible = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.icon,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.destructive ? AppPalette.danger : AppPalette.champagneGold;
    return AlertDialog(
      backgroundColor: AppPalette.mantle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(
            widget.icon ??
                (widget.destructive
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded),
            color: accent,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        widget.message,
        style: const TextStyle(color: AppPalette.textBody, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed:
              _tapped ? null : () => Navigator.of(context).pop(false),
          child: Text(
            widget.cancelLabel,
            style: const TextStyle(color: AppPalette.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor:
                widget.destructive ? Colors.white : AppPalette.crust,
          ),
          onPressed: _tapped
              ? null
              : () {
                  setState(() => _tapped = true);
                  Navigator.of(context).pop(true);
                },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
