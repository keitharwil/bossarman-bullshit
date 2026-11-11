import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Customer-Only Service Appointment Booking Sheet (`App B`).
/// Admin, Cashier, and Mechanic accounts are strictly blocked from creating
/// job orders; internal staff can only accept incoming customer bookings.
class CreateJobOrderSheet extends StatefulWidget {
  final String? defaultCustomerName;
  final String? defaultCustomerUsername;

  const CreateJobOrderSheet({
    super.key,
    this.defaultCustomerName,
    this.defaultCustomerUsername,
  });

  static Future<JobOrder?> show(
    BuildContext context, {
    String? defaultCustomerName,
    String? defaultCustomerUsername,
  }) async {
    final vm = context.read<MotoHubViewModel>();
    if (vm.currentUser != null && vm.currentUser!.role != UserRole.customer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Adding/booking service jobs is a Customer-only function. Staff & Admin can only accept incoming customer bookings.',
            style: TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      return null;
    }

    return showModalBottomSheet<JobOrder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      builder: (_) => CreateJobOrderSheet(
        defaultCustomerName: defaultCustomerName,
        defaultCustomerUsername: defaultCustomerUsername,
      ),
    );
  }

  @override
  State<CreateJobOrderSheet> createState() => _CreateJobOrderSheetState();
}

class _CreateJobOrderSheetState extends State<CreateJobOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameCtrl;
  final _phoneCtrl = TextEditingController();
  final _bikeModelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();

  String _selectedServiceType = 'CVT Tuning & Pulley Upgrade';
  String _selectedSchedule = 'Today • Morning (9:00 AM – 12:00 PM)';
  String _selectedMechanic = 'Lance M. Aclan';
  late BranchId _selectedBranch;
  bool _isSubmitting = false;

  DateTime _bookingDate = DateTime.now();
  TimeOfDay _bookingTime = const TimeOfDay(hour: 9, minute: 30);
  bool _useCustomDateTime = false;

  String _formatBookingSchedule() {
    final now = DateTime.now();
    final isToday = _bookingDate.year == now.year &&
        _bookingDate.month == now.month &&
        _bookingDate.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = _bookingDate.year == tomorrow.year &&
        _bookingDate.month == tomorrow.month &&
        _bookingDate.day == tomorrow.day;

    final dateStr = isToday
        ? 'Today'
        : (isTomorrow ? 'Tomorrow' : DateFormat('EEE, MMM d, yyyy').format(_bookingDate));
    final hour = _bookingTime.hourOfPeriod == 0 ? 12 : _bookingTime.hourOfPeriod;
    final period = _bookingTime.period == DayPeriod.am ? 'AM' : 'PM';
    final minuteStr = _bookingTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minuteStr $period';
    return '$dateStr at $timeStr';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate.isBefore(now) ? now : _bookingDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppPalette.champagneGold,
              onPrimary: AppPalette.crust,
              surface: AppPalette.surface1,
              onSurface: AppPalette.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _bookingDate = picked;
        _useCustomDateTime = true;
        _selectedSchedule = _formatBookingSchedule();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bookingTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppPalette.champagneGold,
              onPrimary: AppPalette.crust,
              surface: AppPalette.surface1,
              onSurface: AppPalette.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _bookingTime = picked;
        _useCustomDateTime = true;
        _selectedSchedule = _formatBookingSchedule();
      });
    }
  }

  static const List<String> _serviceTypes = [
    'CVT Tuning & Pulley Upgrade',
    'Change Oil & Full PMS Tune-Up',
    'Thai Concept Bolts & Accessories Install',
    'Brake Caliper & Master Pump Bleeding',
    'FI Diagnostics & Throttle Cleaning',
    'Tire Mounting & Wheel Alignment',
  ];

  static const List<String> _scheduleSlots = [
    'Today • Morning (9:00 AM – 12:00 PM)',
    'Today • Afternoon (1:00 PM – 5:00 PM)',
    'Tomorrow • Morning (9:00 AM – 12:00 PM)',
    'Tomorrow • Afternoon (1:00 PM – 5:00 PM)',
  ];

  @override
  void initState() {
    super.initState();
    _customerNameCtrl = TextEditingController(
      text: widget.defaultCustomerName ?? '',
    );
    final vm = context.read<MotoHubViewModel>();
    _selectedBranch = vm.activeBranch == BranchId.both
        ? BranchId.patimbao
        : vm.activeBranch;
    final branchMechanics = vm.mechanicsList
        .where((m) => m.assignedBranch == _selectedBranch)
        .toList();
    final mechanics =
        branchMechanics.isNotEmpty ? branchMechanics : vm.mechanicsList;
    if (mechanics.isNotEmpty) {
      _selectedMechanic = mechanics.first.fullName;
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bikeModelCtrl.dispose();
    _plateCtrl.dispose();
    _issueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final vm = context.read<MotoHubViewModel>();

    try {
      final job = await vm.createJobOrder(
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        bikeModel: _bikeModelCtrl.text.trim(),
        plateNumber: _plateCtrl.text.trim().toUpperCase(),
        serviceType: _selectedServiceType,
        issueDescription: _issueCtrl.text.trim(),
        assignedMechanic: _selectedMechanic,
        laborFee: 0.0,
        targetBranch: _selectedBranch,
        preferredSchedule: _selectedSchedule,
        customerUsername: widget.defaultCustomerUsername ?? '',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (job == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              vm.statusMessage ?? 'Failed to submit service appointment.',
              style: const TextStyle(color: AppPalette.crust),
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pop(job);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booked Service Appointment ${job.id} (${job.plateNumber}) at ${_selectedBranch.shortName}. Awaiting shop acceptance.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Failed to book appointment: $e',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final branchMechanics = vm.mechanicsList
        .where((m) => m.assignedBranch == _selectedBranch)
        .map((m) => m.fullName)
        .toSet()
        .toList();
    final mechanicNames = branchMechanics.isNotEmpty
        ? branchMechanics
        : vm.mechanicsList.map((m) => m.fullName).toSet().toList();
    if (mechanicNames.isEmpty) {
      mechanicNames.add('Lance M. Aclan');
    }
    if (!mechanicNames.contains(_selectedMechanic)) {
      _selectedMechanic = mechanicNames.first;
    }

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
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
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
                      Icons.calendar_month_rounded,
                      color: AppPalette.champagneGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book Service Appointment',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Schedule a repair bay slot for Admin/Mechanic acceptance',
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

              // Material 3 Branch SegmentedButton
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<BranchId>(
                  segments: const [
                    ButtonSegment(
                      value: BranchId.patimbao,
                      label: SlidingMarqueeText(text: 'Branch 1: Patimbao'),
                      icon: Icon(Icons.storefront_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: BranchId.pedroGuevara,
                      label: SlidingMarqueeText(text: 'Branch 2: P. Guevara'),
                      icon: Icon(Icons.location_on_outlined, size: 16),
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
              // Preferred Booking Schedule Selection Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface0,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _useCustomDateTime
                        ? AppPalette.champagneGold
                        : AppPalette.surface1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AppPalette.champagneGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Booking Schedule',
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppPalette.surface1,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedSchedule,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Presets
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._scheduleSlots.map((slot) {
                          final isSelected = !_useCustomDateTime && _selectedSchedule == slot;
                          final shortLabel = slot.contains('Today • Morning')
                              ? 'Today Morning'
                              : (slot.contains('Today • Afternoon')
                                  ? 'Today Afternoon'
                                  : (slot.contains('Tomorrow • Morning')
                                      ? 'Tomorrow Morning'
                                      : 'Tomorrow Afternoon'));
                          return ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(shortLabel, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _useCustomDateTime = false;
                                  _selectedSchedule = slot;
                                });
                              }
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppPalette.surface1),
                    const SizedBox(height: 8),
                    // Custom Date & Time Picker buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: _useCustomDateTime
                                  ? AppPalette.champagneGold
                                  : AppPalette.textBody,
                              side: BorderSide(
                                color: _useCustomDateTime
                                    ? AppPalette.champagneGold
                                    : AppPalette.surface1,
                              ),
                            ),
                            onPressed: _pickDate,
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: Text(
                              DateFormat('MMM d, yyyy').format(_bookingDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: _useCustomDateTime
                                  ? AppPalette.champagneGold
                                  : AppPalette.textBody,
                              side: BorderSide(
                                color: _useCustomDateTime
                                    ? AppPalette.champagneGold
                                    : AppPalette.surface1,
                              ),
                            ),
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(
                              _bookingTime.format(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Responsive Customer & Phone Fields (prevents crowding on 360dp screens)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 380;
                  final nameField = TextFormField(
                    controller: _customerNameCtrl,
                    maxLength: AppValidators.maxRiderNameLength,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppValidators.maxRiderNameLength,
                      ),
                    ],
                    validator: AppValidators.riderFullName,
                    decoration: const InputDecoration(
                      labelText: 'Rider Full Name (max 50 chars)',
                      hintText: 'e.g. Juan Dela Cruz',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  );
                  final phoneField = TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: AppValidators.philippineMobileNumber,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number (11 digits)',
                      hintText: '09171234567',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        nameField,
                        const SizedBox(height: 12),
                        phoneField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: nameField),
                      const SizedBox(width: 12),
                      Expanded(child: phoneField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Responsive Motorcycle Model & Plate Fields
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 380;
                  final bikeField = TextFormField(
                    controller: _bikeModelCtrl,
                    maxLength: AppValidators.maxMotorcycleModelLength,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppValidators.maxMotorcycleModelLength,
                      ),
                    ],
                    validator: AppValidators.motorcycleModel,
                    decoration: const InputDecoration(
                      labelText: 'Motorcycle Model (max 40 chars)',
                      hintText: 'e.g. Yamaha NMAX v2 155',
                      prefixIcon: Icon(Icons.two_wheeler_rounded),
                    ),
                  );
                  final plateField = TextFormField(
                    controller: _plateCtrl,
                    maxLength: AppValidators.maxPlateLength,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppValidators.maxPlateLength,
                      ),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\-\s]'),
                      ),
                    ],
                    validator: AppValidators.plateNumber,
                    decoration: const InputDecoration(
                      labelText: 'Plate / MV No. (max 7 chars)',
                      hintText: '412-NBO or ABC1234',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        bikeField,
                        const SizedBox(height: 12),
                        plateField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: bikeField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: plateField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedServiceType,
                decoration: const InputDecoration(
                  labelText: 'Service Package / Category',
                  prefixIcon: Icon(Icons.miscellaneous_services_outlined),
                ),
                dropdownColor: AppPalette.mantle,
                items: _serviceTypes
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedServiceType = v;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                key: ValueKey('${_selectedBranch.name}_$_selectedMechanic'),
                isExpanded: true,
                initialValue: _selectedMechanic,
                decoration: const InputDecoration(
                  labelText: 'Preferred Bay Mechanic',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                dropdownColor: AppPalette.mantle,
                items: mechanicNames
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMechanic = v);
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _issueCtrl,
                maxLines: 2,
                maxLength: AppValidators.maxServiceNotesLength,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    AppValidators.maxServiceNotesLength,
                  ),
                ],
                validator: AppValidators.serviceNotes,
                decoration: const InputDecoration(
                  labelText: 'Motorcycle Symptoms / Requested Work (Sentence)',
                  hintText: 'Describe the issue or requested service in a sentence...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppPalette.surface1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.surface0),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      color: AppPalette.champagneGold,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No upfront labor fee. Your assigned mechanic & admin will assess your motorcycle in real-time upon bay inspection and set the labor rate dynamically.',
                        style: TextStyle(
                          color: AppPalette.textBody,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GoldGradientButton(
                label: 'Submit Service Booking',
                icon: Icons.event_available_rounded,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
