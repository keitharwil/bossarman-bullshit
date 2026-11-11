import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';

/// Role-aware history of completed / cancelled job orders.
///
/// * Mechanic  -> own past jobs
/// * Customer  -> own past repairs
/// * Admin / Cashier -> all past jobs, filterable by branch, mechanic,
///   status and date range.
class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JobHistoryScreen()),
    );
  }

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _query = '';
  BranchId? _branch;
  String? _mechanic;
  JobStatus? _status;
  DateTimeRange? _range;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      setState(() => _visible += _pageSize);
    }
  }

  void _resetPaging() => _visible = _pageSize;

  List<JobOrder> _source(MotoHubViewModel vm, UserRole? role) {
    switch (role) {
      case UserRole.mechanic:
        return vm.mechanicJobHistory;
      case UserRole.customer:
        return vm.customerJobHistory;
      default:
        return vm.pastJobOrders;
    }
  }

  List<JobOrder> _applyFilters(List<JobOrder> src, bool staffView) {
    final q = _query.trim().toLowerCase();
    final list = src.where((j) {
      if (staffView) {
        if (_branch != null && j.branch != _branch) return false;
        if (_mechanic != null && j.assignedMechanic != _mechanic) return false;
      }
      if (_status != null && j.status != _status) return false;
      if (_range != null) {
        final d = j.updatedAt;
        final start = DateTime(
            _range!.start.year, _range!.start.month, _range!.start.day);
        final end = DateTime(
            _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
        if (d.isBefore(start) || d.isAfter(end)) return false;
      }
      if (q.isEmpty) return true;
      return j.id.toLowerCase().contains(q) ||
          j.customerName.toLowerCase().contains(q) ||
          j.plateNumber.toLowerCase().contains(q) ||
          j.bikeModel.toLowerCase().contains(q) ||
          j.serviceType.toLowerCase().contains(q) ||
          j.assignedMechanic.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _range = picked;
      _resetPaging();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final role = vm.currentUser?.role;
    final staffView = role == UserRole.admin || role == UserRole.cashier;

    List<JobOrder> filtered;
    String? error;
    try {
      filtered = _applyFilters(_source(vm, role), staffView);
    } catch (e) {
      filtered = const [];
      error = 'Unable to load job history: $e';
    }

    final mechanics = staffView
        ? (vm.pastJobOrders
            .map((j) => j.assignedMechanic)
            .where((m) => m.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort())
        : const <String>[];

    final shown = filtered.take(_visible).toList();
    final title = role == UserRole.customer ? 'Repair History' : 'Job History';

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (filtered.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.danger,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text(
                'Delete All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              onPressed: () => _handleDeleteAllHistory(
                context,
                vm,
                filtered.length,
                role == UserRole.customer,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppPalette.textHigh),
                decoration: InputDecoration(
                  hintText: 'Search job ID, customer, plate, bike…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _query = '';
                              _resetPaging();
                            });
                          },
                        ),
                  filled: true,
                  fillColor: AppPalette.mantle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() {
                  _query = v;
                  _resetPaging();
                }),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(_range == null
                        ? 'Any date'
                        : '${_fmtDate(_range!.start)} – ${_fmtDate(_range!.end)}'),
                    onPressed: _pickRange,
                  ),
                  if (_range != null)
                    IconButton(
                      tooltip: 'Clear date filter',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _range = null;
                        _resetPaging();
                      }),
                    ),
                  const SizedBox(width: 8),
                  _dropdownChip<JobStatus?>(
                    value: _status,
                    hint: 'All statuses',
                    items: const [null, JobStatus.completed, JobStatus.cancelled],
                    labelOf: (s) => s?.label ?? 'All statuses',
                    onChanged: (v) => setState(() {
                      _status = v;
                      _resetPaging();
                    }),
                  ),
                  if (staffView) ...[
                    const SizedBox(width: 8),
                    _dropdownChip<BranchId?>(
                      value: _branch,
                      hint: 'All branches',
                      items: const [null, BranchId.patimbao, BranchId.pedroGuevara],
                      labelOf: (b) => b?.shortName ?? 'All branches',
                      onChanged: (v) => setState(() {
                        _branch = v;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _dropdownChip<String?>(
                      value: mechanics.contains(_mechanic) ? _mechanic : null,
                      hint: 'All mechanics',
                      items: [null, ...mechanics],
                      labelOf: (m) => m ?? 'All mechanics',
                      onChanged: (v) => setState(() {
                        _mechanic = v;
                        _resetPaging();
                      }),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: error != null
                  ? _StateMessage(
                      icon: Icons.error_outline_rounded,
                      color: AppPalette.danger,
                      title: 'Something went wrong',
                      subtitle: error,
                    )
                  : filtered.isEmpty
                      ? const _StateMessage(
                          icon: Icons.history_rounded,
                          color: AppPalette.textMuted,
                          title: 'No past jobs found',
                          subtitle:
                              'Completed and cancelled job orders will appear here.',
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => _JobHistoryTile(
                            job: shown[i],
                            onTap: () => _showDetail(context, shown[i]),
                            onDelete: () => _confirmDelete(context, shown[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip<T>({
    required T value,
    required String hint,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.surface0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppPalette.mantle,
          style: const TextStyle(color: AppPalette.textHigh, fontSize: 12.5),
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem<T>(value: e, child: Text(labelOf(e))))
              .toList(),
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, JobOrder job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _JobDetailView(job: job, controller: scroll),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, JobOrder job) async {
    final ok = await showConfirmDialog(
      context,
      destructive: true,
      title: 'Delete from History?',
      message:
          'Are you sure you want to permanently delete record ${job.id} for ${job.bikeModel}? This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      cancelLabel: 'Keep Record',
    );
    if (!ok || !context.mounted) return;
    final vm = context.read<MotoHubViewModel>();
    final success = await vm.deleteJobFromHistory(job.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppPalette.success : AppPalette.danger,
        content: Text(
          vm.statusMessage ?? (success ? 'Job deleted from history.' : 'Failed to delete record.'),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAllHistory(
    BuildContext context,
    MotoHubViewModel vm,
    int count,
    bool isCustomer,
  ) async {
    final ok = await showConfirmDialog(
      context,
      destructive: true,
      title: 'Delete All Past History?',
      message: isCustomer
          ? 'Are you sure you want to permanently delete all $count past repair records from history? This action cannot be undone.'
          : 'Are you sure you want to permanently delete all $count past completed and cancelled job records from history? This action cannot be undone.',
      confirmLabel: 'Delete All History',
      cancelLabel: 'Keep History',
    );
    if (!ok || !context.mounted) return;
    final deleted = await vm.deleteAllPastJobHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.success,
        content: Text(
          '$deleted past record(s) permanently removed from history.',
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

Color _statusColor(JobStatus s) {
  switch (s) {
    case JobStatus.completed:
      return AppPalette.success;
    case JobStatus.cancelled:
      return AppPalette.danger;
    case JobStatus.readyForPickup:
      return AppPalette.champagneGold;
    default:
      return AppPalette.warning;
  }
}

class _JobHistoryTile extends StatelessWidget {
  final JobOrder job;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _JobHistoryTile({
    required this.job,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(job.status);
    return Card(
      color: AppPalette.mantle,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.surface0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${job.id} • ${job.plateNumber}',
                      style: const TextStyle(
                        color: AppPalette.champagneGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.status.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppPalette.danger,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete record from history',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${job.bikeModel} — ${job.customerName}',
                style: const TextStyle(
                  color: AppPalette.textHigh,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${job.serviceType} • ${job.assignedMechanic} • ${job.branch.shortName}',
                style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppFormatters.dateTimeShort(job.updatedAt),
                      style: const TextStyle(
                          color: AppPalette.textMuted, fontSize: 11.5),
                    ),
                  ),
                  Text(
                    AppFormatters.currency(job.totalEstimate),
                    style: const TextStyle(
                      color: AppPalette.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailView extends StatelessWidget {
  final JobOrder job;
  final ScrollController controller;
  const _JobDetailView({required this.job, required this.controller});

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: AppPalette.textMuted, fontSize: 12);
    const value = TextStyle(
        color: AppPalette.textHigh, fontSize: 13.5, fontWeight: FontWeight.w600);

    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(l, style: label)),
              Expanded(child: Text(v, style: value)),
            ],
          ),
        );

    // Derived status timeline (the model stores createdAt / updatedAt only).
    const flow = [
      JobStatus.received,
      JobStatus.inBay,
      JobStatus.readyForPickup,
      JobStatus.completed,
    ];
    final List<_TimelineStep> steps;
    if (job.status == JobStatus.cancelled) {
      steps = [
        _TimelineStep(JobStatus.received.label, job.createdAt, true),
        _TimelineStep(JobStatus.cancelled.label, job.updatedAt, true),
      ];
    } else {
      final cur = job.status.stepIndex;
      steps = flow.map((s) {
        final reached = s.stepIndex <= cur;
        DateTime? at;
        if (s == JobStatus.received) at = job.createdAt;
        if (s == job.status) at = job.updatedAt;
        return _TimelineStep(s.label, at, reached);
      }).toList();
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppPalette.surface1,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          job.id,
          style: const TextStyle(
            color: AppPalette.champagneGold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        row('Customer', '${job.customerName} (${job.customerPhone})'),
        row('Motorcycle', '${job.bikeModel} • ${job.plateNumber}'),
        row('Services', job.serviceType),
        if (job.issueDescription.trim().isNotEmpty)
          row('Issue', job.issueDescription),
        row('Mechanic', job.assignedMechanic),
        row('Branch', job.branch.displayName),
        row('Created', AppFormatters.dateTimeShort(job.createdAt)),
        row('Last updated', AppFormatters.dateTimeShort(job.updatedAt)),
        const Divider(height: 24),
        const Text('Attached Parts',
            style: TextStyle(
                color: AppPalette.textHigh, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (job.attachedParts.isEmpty)
          const Text('No parts attached.', style: label)
        else
          ...job.attachedParts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.quantity}x ${p.name} @ ${AppFormatters.currency(p.unitPrice)}',
                      style: const TextStyle(
                          color: AppPalette.textBody, fontSize: 12.5),
                    ),
                  ),
                  Text(AppFormatters.currency(p.lineTotal), style: value),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        row('Labor fee', AppFormatters.currency(job.effectiveLaborFee)),
        if (job.extraRepairNote != null && job.extraRepairNote!.isNotEmpty)
          row(
            'Extra repair',
            '${job.extraRepairNote} (${job.extraRepairApproved ? 'approved' : 'not approved'})',
          ),
        Row(
          children: [
            const Expanded(
              child: Text('TOTAL',
                  style: TextStyle(
                      color: AppPalette.textHigh, fontWeight: FontWeight.w900)),
            ),
            Text(
              AppFormatters.currency(job.totalEstimate),
              style: const TextStyle(
                color: AppPalette.success,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        const Text('Status Timeline',
            style: TextStyle(
                color: AppPalette.textHigh, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...steps.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  s.reached
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: s.reached ? AppPalette.success : AppPalette.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(s.label, style: value)),
                if (s.at != null)
                  Text(AppFormatters.dateTimeShort(s.at!), style: label),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.danger,
              side: const BorderSide(color: AppPalette.danger),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                destructive: true,
                title: 'Delete from History?',
                message:
                    'Are you sure you want to permanently delete record ${job.id} for ${job.bikeModel}? This action cannot be undone.',
                confirmLabel: 'Delete Permanently',
                cancelLabel: 'Keep Record',
              );
              if (!ok || !context.mounted) return;
              final vm = context.read<MotoHubViewModel>();
              final success = await vm.deleteJobFromHistory(job.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppPalette.success : AppPalette.danger,
                  content: Text(
                    vm.statusMessage ?? (success ? 'Job deleted from history.' : 'Failed to delete record.'),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete from History'),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  final String label;
  final DateTime? at;
  final bool reached;
  const _TimelineStep(this.label, this.at, this.reached);
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppPalette.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
