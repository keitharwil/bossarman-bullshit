import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../shared/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../login_screen.dart';
import '../shared/user_avatar.dart';

/// Me / Admin Management (`add_staff_screen.dart`)
/// - Staff directory showing active shift statuses & emergency absence reliever assignment
/// - [+ Add Staff or Admin Account] form with Role, Branch, First/Last Name, Username, Email, Password
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  void _openAddAccountModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (_) => const _AddStaffFormSheet(),
    );
  }

  void _showDeleteStaffDialog(
    BuildContext context,
    MotoHubViewModel vm,
    StaffAccount staff,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${staff.fullName}?',
      message:
          'This will remove @${staff.username} from the active staff directory. '
          'They will no longer be able to log in to this terminal.',
      confirmLabel: 'Remove Staff',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await vm.deleteStaffAccount(staff.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppPalette.surface1 : AppPalette.danger,
        content: Text(
          ok
              ? 'Staff member @${staff.username} removed from directory.'
              : (vm.statusMessage ?? 'Failed to remove account.'),
          style: const TextStyle(color: AppPalette.textHigh),
        ),
      ),
    );
  }

  void _showGcashSettingsDialog(BuildContext context) {
    final vm = context.read<MotoHubViewModel>();
    BranchId selectedBranch =
        vm.activeBranch == BranchId.both ? BranchId.patimbao : vm.activeBranch;
    String name = vm.getGcashAccountName(selectedBranch);
    String number = vm.getGcashAccountNumber(selectedBranch);
    String? qrBase64 = vm.getGcashQrBase64(selectedBranch);

    final nameCtrl = TextEditingController(text: name);
    final numberCtrl = TextEditingController(text: number);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                color: AppPalette.champagneGold, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'GCash Payment QR Settings',
                              style: TextStyle(
                                color: AppPalette.textHigh,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<BranchId>(
                      segments: const [
                        ButtonSegment(
                          value: BranchId.patimbao,
                          label: SlidingMarqueeText(
                            text: 'Branch 1 (Patimbao)',
                          ),
                        ),
                        ButtonSegment(
                          value: BranchId.pedroGuevara,
                          label: SlidingMarqueeText(
                            text: 'Branch 2 (P. Guevara)',
                          ),
                        ),
                      ],
                      selected: {selectedBranch},
                      onSelectionChanged: (set) {
                        setSheetState(() {
                          selectedBranch = set.first;
                          nameCtrl.text = vm.getGcashAccountName(selectedBranch);
                          numberCtrl.text =
                              vm.getGcashAccountNumber(selectedBranch);
                          qrBase64 = vm.getGcashQrBase64(selectedBranch);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppPalette.crust,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppPalette.champagneGold
                                .withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: qrBase64 != null && qrBase64!.isNotEmpty
                            ? Image.memory(
                                base64Decode(qrBase64!),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text('Invalid QR image',
                                      style: TextStyle(
                                          color: AppPalette.danger)),
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppPalette.textMuted,
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No GCash QR Uploaded',
                                      style: TextStyle(
                                          color: AppPalette.textMuted,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 600,
                            maxHeight: 600,
                            imageQuality: 85,
                          );
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          final encoded = base64Encode(bytes);
                          setSheetState(() {
                            qrBase64 = encoded;
                          });
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(qrBase64 == null
                            ? 'Upload Shop GCash QR'
                            : 'Replace GCash QR Image'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GCash Registered Account Name',
                        hintText: 'e.g. BossArman MotoHub / Arman Sarita',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numberCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'GCash Mobile Number',
                        hintText: 'e.g. 0917-888-6686',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.champagneGold,
                        foregroundColor: AppPalette.crust,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await vm.saveGcashConfig(
                          branch: selectedBranch,
                          accountName: nameCtrl.text.trim().isEmpty
                              ? 'BossArman MotoHub'
                              : nameCtrl.text.trim(),
                          accountNumber: numberCtrl.text.trim().isEmpty
                              ? '0917-888-6686'
                              : numberCtrl.text.trim(),
                          qrBase64: qrBase64,
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GCash QR settings saved for ${selectedBranch.displayName}. Available offline & at all checkout counters.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Save GCash Settings',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final staffOnly = vm.staffList
        .where((s) => !s.isDeleted && s.role != UserRole.customer)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Executive Profile Card (Responsive LayoutBuilder prevents mobile text overflow)
        Card.filled(
          color: AppPalette.mantle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;
                final signOutBtn = OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: 'You will need to sign in again to continue.',
                      confirmLabel: 'Sign Out',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    await vm.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign Out'),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          user: user,
                          radius: 27,
                          isEditable: true,
                          onEditPhoto: () =>
                              UserAvatar.showPhotoPickerSheet(context),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Arman Sarita',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Shop Owner • Master Executive Control',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Managing Branch 1 (Patimbao) & Branch 2 (Pedro Guevara Ave)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppPalette.textMuted.withValues(alpha: 0.9),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 14),
                          signOutBtn,
                        ],
                      ],
                    ),
                    if (isCompact) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: signOutBtn,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // [+ Add Staff or Admin Account] CTA Button
        GoldGradientButton(
          label: 'Add Staff or Admin Account',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () => _openAddAccountModal(context),
        ),
        const SizedBox(height: 10),

        // GCash Payment QR Settings Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.champagneGold,
            side: const BorderSide(color: AppPalette.champagneGold, width: 1.2),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _showGcashSettingsDialog(context),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'GCash Payment QR & Account Settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Staff Directory Header
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: AppPalette.champagneGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Multi-Branch Staff Directory (${staffOnly.length})',
                  style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Text(
              'Tap shift badge to cycle status',
              style: TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Material 3 Expressive M3ECardList for Staff Directory
        M3ECardList(
          itemCount: staffOnly.length,
          outerRadius: 24,
          innerRadius: 6,
          gap: 4,
          variant: M3ECardVariant.filled,
          color: AppPalette.mantle,
          border: const BorderSide(color: AppPalette.surface0),
          padding: const EdgeInsets.all(14),
          emptyBuilder: MotoHubEmptyState(
            icon: Icons.badge_outlined,
            title: 'No Staff Accounts Found',
            subtitle:
                'Provision Admin, Cashier, or Mechanic credentials to manage your branches.',
            actionLabel: '+ Add Staff Account',
            onAction: () => _openAddAccountModal(context),
          ),
          itemBuilder: (context, index) {
            final staff = staffOnly[index];
            final isEmergency = staff.shiftStatus == 'Emergency Absence';
            final isOff = staff.shiftStatus == 'Off Shift';
            final statusColor = isEmergency
                ? AppPalette.danger
                : isOff
                    ? AppPalette.inactive
                    : AppPalette.success;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      user: staff,
                      radius: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                staff.fullName,
                                style: const TextStyle(
                                  color: AppPalette.textHigh,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.surface1,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppPalette.champagneGold
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  staff.role.label.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppPalette.champagneGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${staff.username} • ${staff.email}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.store_mall_directory_outlined,
                                size: 13,
                                color: AppPalette.warmGold,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  staff.assignedBranch.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.warmGold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => vm.cycleStaffShiftStatus(staff),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              staff.shiftStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (staff.id != user?.id) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppPalette.danger,
                          size: 20,
                        ),
                        tooltip: 'Deactivate / Soft-Delete Staff Account',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showDeleteStaffDialog(context, vm, staff),
                      ),
                    ],
                  ],
                ),

                // Admin-Only Single-Branch Assignment Switcher for Cashier & Mechanic
                if (staff.role == UserRole.cashier ||
                    staff.role == UserRole.mechanic) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.crust,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.surface0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 14,
                              color: AppPalette.champagneGold,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ADMIN BRANCH ASSIGNMENT (SINGLE BRANCH ONLY)',
                                style: TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<BranchId>(
                            segments: const [
                              ButtonSegment<BranchId>(
                                value: BranchId.patimbao,
                                icon: Icon(Icons.storefront_rounded, size: 15),
                                label: SlidingMarqueeText(
                                  text: 'Branch 1: Patimbao',
                                ),
                              ),
                              ButtonSegment<BranchId>(
                                value: BranchId.pedroGuevara,
                                icon: Icon(Icons.storefront_rounded, size: 15),
                                label: SlidingMarqueeText(
                                  text: 'Branch 2: P. Guevara',
                                ),
                              ),
                            ],
                            selected: {
                              staff.assignedBranch == BranchId.pedroGuevara
                                  ? BranchId.pedroGuevara
                                  : BranchId.patimbao,
                            },
                          onSelectionChanged: (set) async {
                            if (set.isEmpty) return;
                            final nextBranch = set.first;
                            if (staff.assignedBranch == nextBranch) return;
                            const statuses = [
                              'On Duty',
                              'In Bay',
                              'Off Shift',
                              'Emergency Absence',
                            ];
                            final curIdx = statuses.indexOf(staff.shiftStatus);
                            final prevStatus = statuses[
                                (curIdx - 1 + statuses.length) %
                                    statuses.length];
                            await vm.cycleStaffShiftStatus(
                              staff.copyWith(
                                assignedBranch: nextBranch,
                                shiftStatus: prevStatus,
                              ),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppPalette.surface1,
                                content: Text(
                                  'Reassigned ${staff.fullName} (${staff.role.label}) to ${nextBranch.displayName}.',
                                  style: const TextStyle(
                                    color: AppPalette.textHigh,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      ],
                    ),
                  ),
                ],

                if (staff.coveredByStaff != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppPalette.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppPalette.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cross-Branch Reliever Assigned: ${staff.coveredByStaff}',
                            style: const TextStyle(
                              color: AppPalette.warning,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddStaffFormSheet extends StatefulWidget {
  const _AddStaffFormSheet();

  @override
  State<_AddStaffFormSheet> createState() => _AddStaffFormSheetState();
}

class _AddStaffFormSheetState extends State<_AddStaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.cashier;
  BranchId _selectedBranch = BranchId.patimbao;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final vm = context.read<MotoHubViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final cleanEmail = _emailCtrl.text.trim();
    final cleanUsername = _usernameCtrl.text.trim().toLowerCase();

    // Check duplicate username or email first against active accounts
    final duplicate = vm.staffList.any(
      (s) =>
          !s.isDeleted &&
          (s.username.toLowerCase() == cleanUsername ||
              s.email.toLowerCase() == cleanEmail.toLowerCase()),
    );
    if (duplicate) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Username or email is already registered to an existing active account.',
            style: TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Creates the Firebase Auth login (secondary app, owner stays signed
      // in) and saves the staff profile under the new UID.
      final ok = await vm.createStaffAccount(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        username: _usernameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        role: _selectedRole,
        assignedBranch: _selectedBranch,
      );

      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(); // Close form sheet
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.success,
            content: Text(
              'Created staff account for ${_firstNameCtrl.text} ${_lastNameCtrl.text}. '
              'They can sign in now with the password you set.',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              vm.statusMessage ?? 'Could not create staff account',
              style: const TextStyle(color: AppPalette.crust),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Could not create staff account. Please try again.',
            style: TextStyle(color: AppPalette.crust),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppPalette.champagneGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Staff or Admin Account',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Provision role credentials & branch assignment',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role Selector (Admin, Cashier, Mechanic)
              const Text(
                'Select Role',
                style: TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.admin,
                      label: SlidingMarqueeText(text: 'Admin'),
                      icon: Icon(Icons.admin_panel_settings_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: UserRole.cashier,
                      label: SlidingMarqueeText(text: 'Cashier'),
                      icon: Icon(Icons.point_of_sale_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: UserRole.mechanic,
                      label: SlidingMarqueeText(text: 'Mechanic'),
                      icon: Icon(Icons.handyman_outlined, size: 16),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedRole = set.first;
                      // Cashiers and Mechanics can only be assigned to a single branch
                      if ((_selectedRole == UserRole.cashier ||
                              _selectedRole == UserRole.mechanic) &&
                          _selectedBranch == BranchId.both) {
                        _selectedBranch = BranchId.patimbao;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Branch Assignment Selector (Single Branch for Cashier/Mechanic; Both allowed only for Admin)
              Text(
                _selectedRole == UserRole.admin
                    ? 'Assign Branch Context'
                    : 'Assign Single Branch (Cashier & Mechanic locked to 1 branch)',
                style: const TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<BranchId>(
                  segments: [
                    const ButtonSegment(
                      value: BranchId.patimbao,
                      label: SlidingMarqueeText(
                        text: 'Branch 1: Patimbao',
                      ),
                    ),
                    const ButtonSegment(
                      value: BranchId.pedroGuevara,
                      label: SlidingMarqueeText(
                        text: 'Branch 2: P. Guevara',
                      ),
                    ),
                    if (_selectedRole == UserRole.admin)
                      const ButtonSegment(
                        value: BranchId.both,
                        label: SlidingMarqueeText(
                          text: 'Both Branches',
                        ),
                      ),
                  ],
                  selected: {_selectedBranch},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedBranch = set.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      validator: (v) =>
                          AppValidators.requiredField(v, 'First Name'),
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      validator: (v) =>
                          AppValidators.requiredField(v, 'Last Name'),
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _usernameCtrl,
                validator: AppValidators.username,
                decoration: const InputDecoration(
                  labelText: 'Store Username',
                  hintText: 'e.g. mark.cashier',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'staff@motohub.ph',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Password is required';
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'The staff member signs in with this password.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Please confirm the password';
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              GoldGradientButton(
                label: _isSubmitting
                    ? 'Creating account...'
                    : 'Create Staff / Admin Account',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}