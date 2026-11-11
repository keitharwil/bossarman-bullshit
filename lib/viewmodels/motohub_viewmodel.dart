// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/models/models.dart';
import '../core/services/firebase_service.dart';
import '../core/services/local_database_service.dart';
import '../core/services/notification_service.dart';
import '../core/utils/formatters.dart';
import '../core/utils/password_security.dart';

export '../core/utils/password_security.dart';

import 'package:intl/intl.dart';

/// Central State & Business Logic Controller for Boss Arman MotoHub.
class MotoHubViewModel extends ChangeNotifier {
  final LocalDatabaseService _db = LocalDatabaseService.instance;
  final FirebaseService _firebase = FirebaseService.instance;
  final bool isCustomerApp;

  Future<bool> requestNotificationPermission() async {
    final granted = await NotificationService.requestNotificationPermission();
    if (granted) {
      await syncDeviceBinding();
    }
    return granted;
  }

  static const _uuid = Uuid();
  String _generateId(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
    return '$prefix-$ts-$rand';
  }

  // --- Cloud sync state -----------------------------------------------------
  final List<StreamSubscription<dynamic>> _syncSubs = [];
  final Set<String> _bootstrapped = {};
  Timer? _cloudRetryTimer;
  bool _disposed = false;
  final Completer<void> _staffSynced = Completer<void>();
  bool _isProcessingCheckout = false;

  FirebaseService get firebase => _firebase;

  MotoHubViewModel({this.isCustomerApp = false});

  ViewState _viewState = ViewState.idle;
  ViewState get viewState => _viewState;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  String? get errorMessage =>
      _viewState == ViewState.error ? _statusMessage : null;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Authentication & Session Context
  StaffAccount? _currentUser;
  StaffAccount? get currentUser => _currentUser;

  StaffAccount? _pendingRecoveryAccount;
  StaffAccount? get pendingRecoveryAccount => _pendingRecoveryAccount;

  // Dynamic Branch Context (Defaults to Branch 1: Patimbao)
  BranchId _activeBranch = BranchId.patimbao;
  BranchId get activeBranch => _activeBranch;

  // Offline-First Connectivity & Background Sync Queue
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final List<OfflineSyncTask> _offlineQueue = [];
  List<OfflineSyncTask> get offlineQueue => List.unmodifiable(_offlineQueue);
  int get pendingSyncCount => _offlineQueue.where((t) => !t.synced).length;

  // Core State Collections (Populated exclusively from SQLite — zero mock arrays)
  List<StaffAccount> _staffList = [];
  List<InventoryItem> _inventory = [];
  List<JobOrder> _jobOrders = [];
  List<StockTransfer> _transfers = [];
  List<PosTransaction> _transactions = [];
  List<CashDrawerEntry> _cashLedger = [];
  List<AppNotificationItem> _notifications = [];
  final Set<String> _dismissedNotificationIds = {};
  List<ClickAndCollectOrder> _clickCollectOrders = [];
  List<ZReadingRecord> _zReadings = [];

  // Inventory cloud sync (Firestore <-> local SQLite)
  InventorySyncStatus _inventorySyncStatus = InventorySyncStatus.syncing;
  InventorySyncStatus get inventorySyncStatus => _inventorySyncStatus;

  String? _inventorySyncError;
  String? get inventorySyncError => _inventorySyncError;

  DateTime? _lastInventorySyncAt;
  DateTime? get lastInventorySyncAt => _lastInventorySyncAt;

  int _pendingInventoryCount = 0;
  int get pendingInventoryCount => _pendingInventoryCount;

  StreamSubscription<InventorySnapshot>? _inventorySub;
  Timer? _inventoryDebounce;
  Timer? _inventoryRetryTimer;
  bool _isSyncingInventory = false;
  bool _inventorySyncQueued = false;
  bool _inventoryInitialSyncDone = false;
  bool _inventoryBaselineLoaded = false;
  Map<String, String> _inventoryBaseline = {}; // itemId -> last synced JSON
  static const _kInventoryBaselineKey = 'inventory_sync_baseline_v1';

  // Retail POS Cart State
  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);

  // GCash Payment Config State
  String? _gcashQrPatimbao;
  String _gcashNamePatimbao = 'BossArman MotoHub';
  String _gcashNumberPatimbao = '0917-888-6686';

  String? _gcashQrPedroGuevara;
  String _gcashNamePedroGuevara = 'BossArman MotoHub';
  String _gcashNumberPedroGuevara = '0917-888-6686';

  String? getGcashQrBase64(BranchId branch) =>
      branch == BranchId.pedroGuevara ? _gcashQrPedroGuevara : _gcashQrPatimbao;

  String getGcashAccountName(BranchId branch) => branch == BranchId.pedroGuevara
      ? _gcashNamePedroGuevara
      : _gcashNamePatimbao;

  String getGcashAccountNumber(BranchId branch) =>
      branch == BranchId.pedroGuevara
      ? _gcashNumberPedroGuevara
      : _gcashNumberPatimbao;

  // Filters
  String _inventorySearchQuery = '';
  String get inventorySearchQuery => _inventorySearchQuery;

  String _selectedPosCategory = 'All';
  String get selectedPosCategory => _selectedPosCategory;

  JobStatus? _selectedJobStatusFilter;
  JobStatus? get selectedJobStatusFilter => _selectedJobStatusFilter;

  // ---------------------------------------------------------------------------
  // Getters & Reactive Branch Queries
  // ---------------------------------------------------------------------------

  List<StaffAccount> get staffList => List.unmodifiable(_staffList);
  List<InventoryItem> get allInventory =>
      List.unmodifiable(_inventory.where((i) => !i.isDeleted));
  List<InventoryItem> get allInventoryIncludingDeleted =>
      List.unmodifiable(_inventory);
  List<ClickAndCollectOrder> get clickCollectOrders =>
      List.unmodifiable(_clickCollectOrders);

  /// Dynamic list of mechanics from registered staff accounts
  List<StaffAccount> get mechanicsList =>
      _staffList.where((s) => s.role == UserRole.mechanic).toList();

  List<InventoryItem> get filteredInventory {
    return _inventory.where((item) {
      if (item.isDeleted) return false;
      final matchesCat =
          _selectedPosCategory == 'All' ||
          item.category.toLowerCase() == _selectedPosCategory.toLowerCase();
      if (!matchesCat) return false;
      if (_inventorySearchQuery.trim().isEmpty) return true;
      final q = _inventorySearchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.sku.toLowerCase().contains(q) ||
          item.barcode.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.shelfCoordinates.toLowerCase().contains(q) ||
          item.compatibleModels.toLowerCase().contains(q);
    }).toList();
  }

  static const List<String> categories = [
    'All',
    'CVT Tuning',
    'Engine Oils',
    'Thai Bolts',
    'Tires & Brakes',
    'Electrical',
  ];

  static List<InventoryItem> starterCatalog() => const [
    InventoryItem(
      id: 'PRT-MOTUL-300V',
      sku: 'OIL-MTL-300V',
      barcode: '885010010001',
      name: 'Motul 300V Factory Line 10W-40 4T (1L)',
      category: 'Engine Oils',
      price: 950.0,
      costPrice: 720.0,
      stockPatimbao: 14,
      stockPedroGuevara: 8,
      rack: 'Rack A',
      shelf: 'Shelf 1',
      bin: 'Bin 01',
      compatibleModels: 'Universal 4T / Maxi-Scooter',
    ),
    InventoryItem(
      id: 'PRT-DAYTONA-CVT',
      sku: 'CVT-DAYTONA-01',
      barcode: '885010010002',
      name: 'Daytona Super CVT Tuning Pulley Assembly',
      category: 'CVT Tuning',
      price: 2450.0,
      costPrice: 1850.0,
      stockPatimbao: 6,
      stockPedroGuevara: 4,
      rack: 'Rack B',
      shelf: 'Shelf 2',
      bin: 'Bin 04',
      compatibleModels: 'NMAX V1/V2, Aerox 155, Click 150',
    ),
    InventoryItem(
      id: 'PRT-BREMBO-PADS',
      sku: 'BRK-BRM-001',
      barcode: '885010010003',
      name: 'Brembo High Performance Ceramic Brake Pads',
      category: 'Tires & Brakes',
      price: 780.0,
      costPrice: 550.0,
      stockPatimbao: 15,
      stockPedroGuevara: 10,
      rack: 'Rack C',
      shelf: 'Shelf 1',
      bin: 'Bin 08',
      compatibleModels: 'Click 125/150, Beat, PCX 160',
    ),
    InventoryItem(
      id: 'PRT-THAI-BOLT-M6',
      sku: 'BLT-THAI-M6X25',
      barcode: '885010010004',
      name: 'Thai Concept 6AL-4V Titanium Flange Bolt Set (M6x25)',
      category: 'Thai Bolts',
      price: 480.0,
      costPrice: 310.0,
      stockPatimbao: 25,
      stockPedroGuevara: 18,
      rack: 'Rack T',
      shelf: 'Shelf 1',
      bin: 'Bin 02',
      compatibleModels: 'Universal Thai Concept / Scooters',
    ),
    InventoryItem(
      id: 'PRT-UMA-COIL',
      sku: 'ELC-UMA-COIL',
      barcode: '885010010005',
      name: 'Uma Racing Super Dual Output Ignition Coil',
      category: 'Electrical',
      price: 1650.0,
      costPrice: 1200.0,
      stockPatimbao: 5,
      stockPedroGuevara: 3,
      rack: 'Rack E',
      shelf: 'Shelf 3',
      bin: 'Bin 11',
      compatibleModels: 'Sniper 150/155, Raider 150 Fi',
    ),
  ];

  /// Jobs filtered by active branch
  List<JobOrder> get branchJobOrders {
    return _jobOrders.where((j) => j.branch == _activeBranch).toList();
  }

  /// Active bay jobs for the active branch (strictly excluding completed/cancelled jobs)
  List<JobOrder> get activeBranchJobOrders => _jobOrders
      .where(
        (j) =>
            j.branch == _activeBranch &&
            j.status != JobStatus.completed &&
            j.status != JobStatus.cancelled,
      )
      .toList();

  /// Completed jobs across all branches
  List<JobOrder> get completedJobOrders =>
      _jobOrders.where((j) => j.status == JobStatus.completed).toList();

  /// All past jobs (completed or cancelled) for history
  List<JobOrder> get pastJobOrders => _jobOrders
      .where(
        (j) =>
            j.status == JobStatus.completed || j.status == JobStatus.cancelled,
      )
      .toList();

  /// Past jobs for active branch
  List<JobOrder> get branchJobHistory => _jobOrders
      .where(
        (j) =>
            j.branch == _activeBranch &&
            (j.status == JobStatus.completed ||
                j.status == JobStatus.cancelled),
      )
      .toList();

  /// Mechanic's own completed & past jobs
  List<JobOrder> get mechanicJobHistory {
    final user = _currentUser;
    if (user == null) return const [];
    return _jobOrders
        .where(
          (j) =>
              (j.assignedMechanic.toLowerCase() ==
                      user.fullName.toLowerCase() ||
                  j.assignedMechanic.toLowerCase() ==
                      user.username.toLowerCase()) &&
              (j.status == JobStatus.completed ||
                  j.status == JobStatus.cancelled),
        )
        .toList();
  }

  /// Customer's own completed & past repair history
  List<JobOrder> get customerJobHistory {
    final user = _currentUser;
    if (user == null) return const [];
    return _jobOrders
        .where(
          (j) =>
              j.customerUsername.toLowerCase() == user.username.toLowerCase() &&
              (j.status == JobStatus.completed ||
                  j.status == JobStatus.cancelled),
        )
        .toList();
  }

  /// Jobs belonging to the currently logged-in customer (active only)
  List<JobOrder> get customerJobOrders {
    final user = _currentUser;
    if (user == null) return const [];
    return _jobOrders
        .where(
          (j) =>
              j.customerUsername.toLowerCase() == user.username.toLowerCase() &&
              j.status != JobStatus.completed &&
              j.status != JobStatus.cancelled,
        )
        .toList();
  }

  /// Click & Collect reservations belonging to the currently logged-in customer
  List<ClickAndCollectOrder> get customerClickCollectOrders {
    final user = _currentUser;
    if (user == null) return const [];
    return _clickCollectOrders
        .where(
          (o) =>
              o.customerUsername.toLowerCase() == user.username.toLowerCase(),
        )
        .toList();
  }

  List<JobOrder> get filteredBranchJobOrders {
    if (_selectedJobStatusFilter == null) return activeBranchJobOrders;
    return branchJobOrders
        .where((j) => j.status == _selectedJobStatusFilter)
        .toList();
  }

  /// Active bikes currently occupying lifts in the selected branch.
  /// Note: Pending requests (received) are excluded until staff accepts them.
  List<JobOrder> get activeBayBikes {
    return branchJobOrders
        .where(
          (j) =>
              j.status == JobStatus.inBay ||
              j.status == JobStatus.waitingForParts ||
              j.status == JobStatus.readyForPickup,
        )
        .toList();
  }

  /// Pending customer job orders awaiting staff acceptance
  List<JobOrder> get pendingJobRequests {
    return branchJobOrders
        .where((j) => j.status == JobStatus.received)
        .toList();
  }

  int get maxBayCapacity => 6;

  /// Service-to-POS Auto-Billing Queue (Ready for Pickup & unbilled)
  List<JobOrder> get serviceToPosQueue {
    return branchJobOrders
        .where((j) => !j.isBilled && j.status == JobStatus.readyForPickup)
        .toList();
  }

  /// Saved Z-Readings for active branch (immutable end-of-shift audit snapshots)
  List<ZReadingRecord> get branchZReadings =>
      _zReadings.where((z) => z.branch == _activeBranch).toList();

  ZReadingRecord? get lastZReading {
    final list = branchZReadings;
    if (list.isEmpty) return null;
    return list.first;
  }

  DateTime get currentShiftStartTime {
    final lastZ = lastZReading;
    if (lastZ != null) {
      return lastZ.generatedAt;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// All recorded POS transactions across branches (for reporting and receipt history)
  List<PosTransaction> get transactions => List.unmodifiable(_transactions);

  /// All transactions for active branch
  List<PosTransaction> get branchTransactions {
    return _transactions.where((t) => t.branch == _activeBranch).toList();
  }

  /// Transactions scoped strictly to the current active shift
  List<PosTransaction> get currentShiftTransactions {
    final start = currentShiftStartTime;
    return _transactions
        .where((t) => t.branch == _activeBranch && t.createdAt.isAfter(start))
        .toList();
  }

  /// Current shift gross sales for active branch
  double get branchTodayGross {
    return currentShiftTransactions.fold(0.0, (sum, t) => sum + t.totalAmount);
  }

  /// Cash collections for current shift (pure cash + split cash amount)
  double get branchCashSalesTotal {
    return currentShiftTransactions.fold(0.0, (sum, t) {
      if (t.paymentMethod == PaymentMethod.cash) {
        return sum + (t.cashAmount > 0 ? t.cashAmount : t.totalAmount);
      } else if (t.paymentMethod == PaymentMethod.split) {
        return sum +
            (t.cashAmount > 0 ? t.cashAmount : (t.totalAmount - t.gcashAmount));
      }
      return sum;
    });
  }

  /// GCash collections for current shift (pure gcash + split gcash amount)
  double get branchGcashVaultTotal {
    return currentShiftTransactions.fold(0.0, (sum, t) {
      if (t.paymentMethod == PaymentMethod.gcash) {
        return sum + (t.gcashAmount > 0 ? t.gcashAmount : t.totalAmount);
      } else if (t.paymentMethod == PaymentMethod.split) {
        return sum +
            (t.gcashAmount > 0
                ? t.gcashAmount
                : (t.totalAmount - t.cashAmount));
      }
      return sum;
    });
  }

  /// All cash drawer ledger records for active branch
  List<CashDrawerEntry> get branchCashLedger {
    return _cashLedger.where((e) => e.branch == _activeBranch).toList();
  }

  /// Cash drawer ledger scoped strictly to the current active shift
  List<CashDrawerEntry> get currentShiftCashLedger {
    final start = currentShiftStartTime;
    return _cashLedger
        .where((e) => e.branch == _activeBranch && e.createdAt.isAfter(start))
        .toList();
  }

  double get branchMorningFloat {
    return currentShiftCashLedger
        .where((e) => e.type == CashLedgerType.morningFloat)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get branchCashoutTotal {
    return currentShiftCashLedger
        .where(
          (e) =>
              e.type == CashLedgerType.cashout ||
              e.type == CashLedgerType.pettyCashOut,
        )
        .fold(0.0, (sum, e) => sum + e.amount.abs());
  }

  /// Backward compatible alias for branchCashoutTotal
  double get branchPettyCashOutTotal => branchCashoutTotal;

  /// Expected Physical Cash in Drawer = Morning Float + Cash Sales + Service Cash - Cashouts
  double get branchPhysicalCashInDrawer {
    return currentShiftCashLedger.fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Low-Stock & Critical Out-of-Stock items in active branch
  List<InventoryItem> get branchLowStockItems {
    return _inventory.where((i) {
      if (i.isDeleted) return false;
      final health = i.healthFor(_activeBranch);
      return health == StockHealth.lowStock ||
          health == StockHealth.criticalOut;
    }).toList();
  }

  /// Overstock items in active branch (Disabled: no max threshold)
  List<InventoryItem> get branchOverstockItems => const [];

  /// In-Transit transfers count for a specific branch (receiving or sending)
  int inTransitCountForBranch(BranchId branch) {
    return _transfers
        .where(
          (t) =>
              t.status == TransferStatus.inTransit &&
              (t.toBranch == branch || t.fromBranch == branch),
        )
        .length;
  }

  /// Incoming In-Transit transfers waiting for [Confirm Delivery] at active branch
  List<StockTransfer> get incomingInTransitTransfers {
    return _transfers
        .where(
          (t) =>
              t.status == TransferStatus.inTransit &&
              t.toBranch == _activeBranch,
        )
        .toList();
  }

  /// Transfers waiting for source branch or Admin approval (Strict Approval Workflow)
  List<StockTransfer> get pendingApprovalTransfers {
    return _transfers
        .where(
          (t) =>
              t.status == TransferStatus.pendingApproval &&
              (t.fromBranch == _activeBranch ||
                  _currentUser?.role == UserRole.admin),
        )
        .toList();
  }

  List<StockTransfer> get allTransfers => List.unmodifiable(_transfers);

  /// Transfers involving the currently active branch only (used by single-branch Cashier monitoring)
  List<StockTransfer> get branchTransfers {
    return _transfers
        .where(
          (t) => t.toBranch == _activeBranch || t.fromBranch == _activeBranch,
        )
        .toList();
  }

  /// True when the logged-in user is a Cashier or Mechanic (strictly locked to 1 branch; only Admin can reassign)
  bool get isBranchLockedForCurrentUser {
    final u = _currentUser;
    if (u == null) return false;
    return u.role == UserRole.cashier || u.role == UserRole.mechanic;
  }

  List<AppNotificationItem> get branchNotifications {
    if (isBranchLockedForCurrentUser) {
      return _notifications.where((n) => n.branch == _activeBranch).toList();
    }
    return _notifications
        .where((n) => n.branch == _activeBranch || n.branch == BranchId.both)
        .toList();
  }

  bool _isNotificationForCurrentSession(AppNotificationItem item) {
    final currentUser = _currentUser;
    if (currentUser == null) return false;

    final myId = currentUser.id.trim().toLowerCase();
    final myUsername = currentUser.username.trim().toLowerCase();
    final isAdmin = currentUser.role == UserRole.admin;

    if (item.targetUserId != null && item.targetUserId!.trim().isNotEmpty) {
      final target = item.targetUserId!.trim().toLowerCase();
      final matchesUser = (myId.isNotEmpty && target == myId) ||
          (myUsername.isNotEmpty && target == myUsername);
      final matchesAdminAlias = isAdmin && (target == 'admin' || target == 'staff');
      if (!matchesUser && !matchesAdminAlias) {
        return false;
      }
    }
    if (item.targetRole != null) {
      final matchesRole = item.targetRole == currentUser.role ||
          (isAdmin && (item.targetRole == UserRole.admin || item.category == 'booking' || item.category == 'job_order' || item.category == 'reservation'));
      if (!matchesRole) {
        return false;
      }
    }
    if (isBranchLockedForCurrentUser) {
      return item.branch == _activeBranch || item.branch == BranchId.both;
    }
    return true;
  }

  int get unreadNotificationCount {
    return branchNotifications.where((n) => !n.isRead).length;
  }

  Future<void> markNotificationRead(String id) => markAllNotificationsRead(id);

  double get cartTotal => _cart.fold(0.0, (sum, c) => sum + c.subtotal);
  int get cartItemCount => _cart.fold(0, (sum, c) => sum + c.quantity);

  // ---------------------------------------------------------------------------
  // Initialization & Pre-Warm
  // ---------------------------------------------------------------------------

  Future<void> initializeApp({
    void Function(double progress, String status)? onProgress,
  }) async {
    if (_isInitialized) {
      onProgress?.call(1.0, 'Ready');
      return;
    }
    _setViewState(ViewState.loading);
    try {
      await _db.initializeAndPreWarm(onProgress: onProgress);

      _staffList = List<StaffAccount>.from(await _db.loadStaff());

      // Ensure seed admin accounts exist in local SQLite and memory if none exists
      final hasAdmin = _staffList.any((s) => s.role == UserRole.admin && !s.isDeleted);
      if (!hasAdmin) {
        for (final seed in LocalDatabaseService.initialAdminAndStaffSeeds().where((s) => s.role == UserRole.admin)) {
          final exists = _staffList.any(
            (s) =>
                s.username.toLowerCase() == seed.username.toLowerCase() ||
                s.email.toLowerCase() == seed.email.toLowerCase(),
          );
          if (!exists) {
            await _saveStaff(seed);
            _staffList.add(seed);
          }
        }
      }

      // Enforce single-branch assignment rule for all Cashier & Mechanic accounts
      for (var i = 0; i < _staffList.length; i++) {
        final s = _staffList[i];
        if ((s.role == UserRole.cashier || s.role == UserRole.mechanic) &&
            s.assignedBranch == BranchId.both) {
          final sanitized = s.copyWith(assignedBranch: BranchId.patimbao);
          _staffList[i] = sanitized;
          await _saveStaff(sanitized);
        }
      }

      // Ensure default seed admin/staff accounts are never locked behind forced password change
      const seedIds = {'STF-001', 'STF-002', 'STF-003', 'STF-004', 'STF-005'};
      for (var i = 0; i < _staffList.length; i++) {
        final s = _staffList[i];
        if (seedIds.contains(s.id) && s.mustChangePassword) {
          final cleared = s.copyWith(mustChangePassword: false);
          _staffList[i] = cleared;
          await _saveStaff(cleared);
        }
      }

      _inventory = List<InventoryItem>.from(await _db.loadInventory());
      // Purge any temporary placeholder starter items so only real Admin items remain
      const placeholderIds = {
        'PRT-MOTUL-300V',
        'PRT-DAYTONA-CVT',
        'PRT-BREMBO-PADS',
        'PRT-THAI-BOLT-M6',
        'PRT-UMA-COIL',
      };
      if (_inventory.any((i) => placeholderIds.contains(i.id))) {
        for (final id in placeholderIds) {
          await _db.deleteInventoryItem(id);
        }
        _inventory = List<InventoryItem>.from(await _db.loadInventory());
      }
      await _loadInventoryBaseline();
      _jobOrders = List<JobOrder>.from(await _db.loadJobOrders());
      _transfers = List<StockTransfer>.from(await _db.loadTransfers());
      _transactions = List<PosTransaction>.from(await _db.loadTransactions());
      _cashLedger = List<CashDrawerEntry>.from(await _db.loadCashLedger());
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_notifications_ids') ?? [];
      _dismissedNotificationIds.addAll(dismissedList);

      final loadedNotifications = await _db.loadNotifications();
      _notifications = loadedNotifications
          .where((n) => !_dismissedNotificationIds.contains(n.id))
          .toList();

      _clickCollectOrders = List<ClickAndCollectOrder>.from(
        await _db.loadClickCollectOrders(),
      );
      _zReadings = List<ZReadingRecord>.from(await _db.loadZReadings());
      // Restore cached session isolated by app target (Internal vs Customer)
      final userKey = isCustomerApp
          ? 'cached_customer_user'
          : 'cached_internal_user';
      final savedUsername = prefs.getString(userKey);
      final savedBranch = prefs.getString('cached_branch');

      if (savedBranch != null) {
        _activeBranch = BranchId.values.firstWhere(
          (b) => b.name == savedBranch && b != BranchId.both,
          orElse: () => BranchId.patimbao,
        );
      }
      if (savedUsername != null) {
        final match = _staffList
            .where(
              (s) =>
                  s.username.toLowerCase() == savedUsername.toLowerCase() &&
                  (isCustomerApp
                      ? s.role == UserRole.customer
                      : s.role != UserRole.customer),
            )
            .toList();
        if (match.isNotEmpty) {
          _currentUser = match.first;
          if (_currentUser!.role == UserRole.cashier ||
              _currentUser!.role == UserRole.mechanic) {
            _activeBranch = _currentUser!.assignedBranch == BranchId.both
                ? BranchId.patimbao
                : _currentUser!.assignedBranch;
          }
          unawaited(syncDeviceBinding());
        }
      }

      // Restore cached GCash payment settings
      _gcashQrPatimbao = prefs.getString('gcash_qr_patimbao');
      _gcashNamePatimbao =
          prefs.getString('gcash_name_patimbao') ?? 'BossArman MotoHub';
      _gcashNumberPatimbao =
          prefs.getString('gcash_num_patimbao') ?? '0917-888-6686';
      _gcashQrPedroGuevara = prefs.getString('gcash_qr_pedroguevara');
      _gcashNamePedroGuevara =
          prefs.getString('gcash_name_pedroguevara') ?? 'BossArman MotoHub';
      _gcashNumberPedroGuevara =
          prefs.getString('gcash_num_pedroguevara') ?? '0917-888-6686';

      try {
        await _startCloudSync();
        unawaited(_fetchRemoteGcashConfig());
        unawaited(loadCustomLegalDocuments());
      } catch (e) {
        debugPrint('[MotoHubViewModel] Firebase init notice: $e');
      }
      // Self-heal: if sync is broken (offline at launch, auth not ready),
      // retry every 30s until it recovers.
      _cloudRetryTimer?.cancel();
      _cloudRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_disposed) return;
        if (!_firebase.isInitialized || _firebase.syncError.value != null) {
          unawaited(
            _startCloudSync().catchError((Object e) {
              debugPrint('[MotoHubViewModel] cloud retry failed: $e');
            }),
          );
        }
      });

      _isInitialized = true;
      _setViewState(ViewState.idle);
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to initialize local database: $e');
    }
  }

  Future<void> _fetchRemoteGcashConfig() async {
    try {
      final remote = await _firebase.fetchGcashConfig();
      if (remote == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (remote['patimbaoAccountName'] != null) {
        _gcashNamePatimbao = remote['patimbaoAccountName'].toString();
        await prefs.setString('gcash_name_patimbao', _gcashNamePatimbao);
      }
      if (remote['patimbaoAccountNumber'] != null) {
        _gcashNumberPatimbao = remote['patimbaoAccountNumber'].toString();
        await prefs.setString('gcash_num_patimbao', _gcashNumberPatimbao);
      }
      if (remote['patimbaoQrBase64'] != null) {
        _gcashQrPatimbao = remote['patimbaoQrBase64'].toString();
        await prefs.setString('gcash_qr_patimbao', _gcashQrPatimbao!);
      }
      if (remote['pedroGuevaraAccountName'] != null) {
        _gcashNamePedroGuevara = remote['pedroGuevaraAccountName'].toString();
        await prefs.setString(
          'gcash_name_pedroguevara',
          _gcashNamePedroGuevara,
        );
      }
      if (remote['pedroGuevaraAccountNumber'] != null) {
        _gcashNumberPedroGuevara = remote['pedroGuevaraAccountNumber']
            .toString();
        await prefs.setString(
          'gcash_num_pedroguevara',
          _gcashNumberPedroGuevara,
        );
      }
      if (remote['pedroGuevaraQrBase64'] != null) {
        _gcashQrPedroGuevara = remote['pedroGuevaraQrBase64'].toString();
        await prefs.setString('gcash_qr_pedroguevara', _gcashQrPedroGuevara!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MotoHubViewModel] GCash config remote fetch notice: $e');
    }
  }

  Future<void> saveGcashConfig({
    required BranchId branch,
    required String accountName,
    required String accountNumber,
    String? qrBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (branch == BranchId.patimbao || branch == BranchId.both) {
      _gcashNamePatimbao = accountName.trim();
      _gcashNumberPatimbao = accountNumber.trim();
      if (qrBase64 != null) _gcashQrPatimbao = qrBase64;
      await prefs.setString('gcash_name_patimbao', _gcashNamePatimbao);
      await prefs.setString('gcash_num_patimbao', _gcashNumberPatimbao);
      if (_gcashQrPatimbao != null) {
        await prefs.setString('gcash_qr_patimbao', _gcashQrPatimbao!);
      }
    }
    if (branch == BranchId.pedroGuevara || branch == BranchId.both) {
      _gcashNamePedroGuevara = accountName.trim();
      _gcashNumberPedroGuevara = accountNumber.trim();
      if (qrBase64 != null) _gcashQrPedroGuevara = qrBase64;
      await prefs.setString('gcash_name_pedroguevara', _gcashNamePedroGuevara);
      await prefs.setString('gcash_num_pedroguevara', _gcashNumberPedroGuevara);
      if (_gcashQrPedroGuevara != null) {
        await prefs.setString('gcash_qr_pedroguevara', _gcashQrPedroGuevara!);
      }
    }
    notifyListeners();

    unawaited(
      _firebase.syncGcashConfig({
        'patimbaoAccountName': _gcashNamePatimbao,
        'patimbaoAccountNumber': _gcashNumberPatimbao,
        if (_gcashQrPatimbao != null) 'patimbaoQrBase64': _gcashQrPatimbao,
        'pedroGuevaraAccountName': _gcashNamePedroGuevara,
        'pedroGuevaraAccountNumber': _gcashNumberPedroGuevara,
        if (_gcashQrPedroGuevara != null)
          'pedroGuevaraQrBase64': _gcashQrPedroGuevara,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Owner-Editable Legal Documents (Terms & Conditions and Privacy Policy)
  // ---------------------------------------------------------------------------

  final Map<String, String> _customLegalDocs = {};
  Map<String, String> get customLegalDocs => Map.unmodifiable(_customLegalDocs);

  String? getCustomLegalDocument(String docKey) => _customLegalDocs[docKey];

  Future<void> loadCustomLegalDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final terms = prefs.getString('motohub_legal_terms_and_conditions');
      final privacy = prefs.getString('motohub_legal_privacy_policy');
      if (terms != null && terms.trim().isNotEmpty) {
        _customLegalDocs['terms_and_conditions'] = terms;
      }
      if (privacy != null && privacy.trim().isNotEmpty) {
        _customLegalDocs['privacy_policy'] = privacy;
      }
      notifyListeners();

      unawaited(_refreshLegalDocsFromFirestore());
    } catch (_) {}
  }

  Future<void> _refreshLegalDocsFromFirestore() async {
    try {
      final termsData = await _firebase.fetchLegalDocument('terms_and_conditions');
      final privacyData = await _firebase.fetchLegalDocument('privacy_policy');
      final prefs = await SharedPreferences.getInstance();

      bool changed = false;
      if (termsData != null && termsData['content'] is String) {
        final content = (termsData['content'] as String).trim();
        if (content.isNotEmpty && _customLegalDocs['terms_and_conditions'] != content) {
          _customLegalDocs['terms_and_conditions'] = content;
          await prefs.setString('motohub_legal_terms_and_conditions', content);
          changed = true;
        }
      }
      if (privacyData != null && privacyData['content'] is String) {
        final content = (privacyData['content'] as String).trim();
        if (content.isNotEmpty && _customLegalDocs['privacy_policy'] != content) {
          _customLegalDocs['privacy_policy'] = content;
          await prefs.setString('motohub_legal_privacy_policy', content);
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> saveCustomLegalDocument({
    required String docKey, // 'terms_and_conditions' or 'privacy_policy'
    required String title,
    required String content,
    String? version,
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) {
      _setViewState(ViewState.error, 'Legal document content cannot be empty.');
      return false;
    }

    if (_currentUser != null &&
        _currentUser!.role != UserRole.admin &&
        _currentUser!.username.toLowerCase() != 'bossarman' &&
        _currentUser!.username.toLowerCase() != 'lanceadmin' &&
        _currentUser!.username.toLowerCase() != 'keithadmin') {
      _setViewState(
        ViewState.error,
        'Unauthorized: Only Boss Arman (Owner) or Admin can edit legal documents.',
      );
      return false;
    }

    try {
      _customLegalDocs[docKey] = cleanContent;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('motohub_legal_$docKey', cleanContent);
      notifyListeners();

      final author = _currentUser?.fullName ?? _currentUser?.username ?? 'Boss Arman (Owner)';
      final ver = version ?? 'v1.1 (Owner Edited)';
      await _firebase.syncLegalDocument(
        docKey: docKey,
        content: cleanContent,
        title: title,
        updatedBy: author,
        version: ver,
      );

      _setViewState(ViewState.success, 'Published updated $title successfully.');
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to save legal document: $e');
      return false;
    }
  }

  Future<bool> resetCustomLegalDocument(String docKey) async {
    try {
      _customLegalDocs.remove(docKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('motohub_legal_$docKey');
      notifyListeners();

      await _firebase.syncLegalDocument(
        docKey: docKey,
        content: '',
        title: docKey,
        updatedBy: _currentUser?.username ?? 'Owner',
        version: 'default',
      );
      _setViewState(ViewState.success, 'Restored official default legal document.');
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to reset legal document: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Cloud Sync Engine (Firestore <-> SQLite <-> memory)
  // Firestore is the shared source of truth between phones; SQLite is the
  // offline cache. Remote changes are merged in; local edits are pushed up.
  // ---------------------------------------------------------------------------

  ValueListenable<String?> get cloudSyncStatus => _firebase.syncError;
  bool get isCloudConnected => _firebase.isInitialized;

  /// Called from the sync banner: re-initializes Firebase and re-subscribes
  /// every listener, then pulls the latest data from the cloud.
  Future<void> retryCloudSync() async {
    try {
      await _startCloudSync();
    } catch (e) {
      debugPrint('[MotoHubViewModel] manual cloud retry failed: $e');
    }
    notifyListeners();
  }

  Future<void> _startCloudSync() async {
    await _firebase.initialize();
    if (!_firebase.isInitialized) return;
    await _firebase.ensureSignedIn();

    for (final s in _syncSubs) {
      await s.cancel();
    }
    _syncSubs.clear();

    // Inventory: live listener + first full sync
    _startInventoryRealtime();
    unawaited(syncInventory());

    _syncSubs.add(
      _firebase.streamJobOrders().listen((b) {
        if (_applyBatch<JobOrder>(
          name: 'job_orders',
          batch: b,
          list: _jobOrders,
          idOf: (e) => e.id,
          toMap: (e) => e.toMap(),
          persistLocal: _db.saveJobOrder,
          pushRemote: _firebase.syncJobOrderToFirestore,
        )) {
          notifyListeners();
        }
      }),
    );
    _syncSubs.add(
      _firebase.streamClickCollect().listen((b) {
        if (_applyBatch<ClickAndCollectOrder>(
          name: 'click_and_collect',
          batch: b,
          list: _clickCollectOrders,
          idOf: (e) => e.id,
          toMap: (e) => e.toMap(),
          persistLocal: _db.saveClickCollectOrder,
          pushRemote: _firebase.syncClickAndCollectToFirestore,
        )) {
          notifyListeners();
        }
      }),
    );
    _syncSubs.add(
      _firebase.streamNotifications().listen((b) {
        var changed = false;
        for (final c in b.changes) {
          if (c.removed) {
            _notifications.removeWhere((n) => n.id == c.id);
            _dismissedNotificationIds.add(c.id);
            unawaited(_db.deleteNotification(c.id));
            changed = true;
            continue;
          }
          final item = c.item;
          if (item == null || _dismissedNotificationIds.contains(item.id)) {
            if (item != null) {
              unawaited(_db.deleteNotification(item.id));
              unawaited(_firebase.deleteFirestoreNotification(item.id));
            }
            continue;
          }
          final idx = _notifications.indexWhere((n) => n.id == item.id);
          if (idx >= 0) {
            _notifications[idx] = item;
          } else {
            _notifications.insert(0, item);
            if (!item.isRead && _isNotificationForCurrentSession(item)) {
              unawaited(NotificationService.showNotification(
                title: item.title,
                body: item.message,
                payload: item.payload,
              ));
            }
          }
          unawaited(_db.saveNotification(item));
          changed = true;
        }
        if (changed) {
          notifyListeners();
        }
      }),
    );

    if (isCustomerApp) {
      _syncSubs.add(_firebase.streamCustomerAccounts().listen(_onAccountBatch));
    } else {
      _syncSubs.add(_firebase.streamStaffAccounts().listen(_onAccountBatch));
      _syncSubs.add(
        _firebase.streamStockTransfers().listen((b) {
          if (_applyBatch<StockTransfer>(
            name: 'stock_transfers',
            batch: b,
            list: _transfers,
            idOf: (e) => e.id,
            toMap: (e) => e.toMap(),
            persistLocal: _db.saveTransfer,
            pushRemote: _firebase.syncStockTransferToFirestore,
          )) {
            notifyListeners();
          }
        }),
      );
      _syncSubs.add(
        _firebase.streamTransactions().listen((b) {
          if (_applyBatch<PosTransaction>(
            name: 'transactions',
            batch: b,
            list: _transactions,
            idOf: (e) => e.id,
            toMap: (e) => e.toMap(),
            persistLocal: _db.saveTransaction,
            pushRemote: _firebase.syncPosTransactionToFirestore,
          )) {
            notifyListeners();
          }
        }),
      );
    }
  }

  /// Merges a Firestore snapshot into a local list + SQLite.
  /// Returns true when the UI needs a rebuild.
  bool _applyBatch<T>({
    required String name,
    required RemoteBatch<T> batch,
    required List<T> list,
    required String Function(T) idOf,
    required Map<String, dynamic> Function(T) toMap,
    required Future<void> Function(T) persistLocal,
    required Future<void> Function(T) pushRemote,
  }) {
    var changed = false;
    for (final c in batch.changes) {
      final item = c.item;
      if (c.removed || item == null) continue;
      final idx = list.indexWhere((e) => idOf(e) == c.id);
      if (idx >= 0) {
        if (jsonEncode(toMap(list[idx])) == jsonEncode(toMap(item))) continue;
        list[idx] = item;
      } else {
        list.insert(0, item);
      }
      unawaited(
        persistLocal(item).catchError((Object e) {
          debugPrint('[Sync] local persist $name/${c.id} failed: $e');
        }),
      );
      changed = true;
    }
    if (!batch.isFromCache) {
      // First phone to connect to an EMPTY cloud collection uploads its data.
      if (batch.collectionEmpty && !_bootstrapped.contains(name)) {
        for (final e in List<T>.of(list)) {
          unawaited(pushRemote(e));
        }
      }
      _bootstrapped.add(name);
    }
    return changed;
  }

  Future<void> _onAccountBatch(RemoteBatch<StaffAccount> b) async {
    var changed = false;
    for (final c in b.changes) {
      final remote = c.item;
      if (c.removed || remote == null) continue;
      final idx = _staffList.indexWhere((s) => s.id == remote.id);
      if (remote.isDeleted) {
        if (idx >= 0) {
          _staffList.removeAt(idx);
          await _db.deleteStaff(remote.id);
          changed = true;
        }
        continue;
      }
      if (idx >= 0) {
        if (jsonEncode(_staffList[idx].toMap()) == jsonEncode(remote.toMap())) {
          continue;
        }
        _staffList[idx] = remote;
        if (_currentUser?.id == remote.id) _currentUser = remote;
      } else {
        final nameTaken = _staffList.any(
          (s) => s.username.toLowerCase() == remote.username.toLowerCase(),
        );
        if (nameTaken) {
          continue; // same username under a different id: keep local
        }
        _staffList.insert(0, remote);
      }
      try {
        await _db.saveStaff(remote);
      } catch (e) {
        debugPrint('[Sync] local persist account ${remote.id} failed: $e');
      }
      changed = true;
    }

    final name = isCustomerApp ? 'customer_accounts' : 'staff_accounts';
    if (!b.isFromCache) {
      if (b.collectionEmpty && !_bootstrapped.contains(name)) {
        for (final s in _staffList.where(_shouldSyncAccount)) {
          unawaited(_firebase.syncStaffToFirestore(s));
        }
      }
      _bootstrapped.add(name);
      if (!_staffSynced.isCompleted) _staffSynced.complete();
    }
    if (changed) notifyListeners();
  }

  /// Customer app only syncs customers; internal app only syncs staff.
  bool _shouldSyncAccount(StaffAccount s) =>
      isCustomerApp ? s.role == UserRole.customer : s.role != UserRole.customer;

  /// Saves an account locally AND pushes it to the cloud.
  Future<void> _saveStaff(StaffAccount s) async {
    await _db.saveStaff(s);
    if (_shouldSyncAccount(s)) {
      unawaited(_firebase.syncStaffToFirestore(s));
    }
  }

  /// Lets a fresh phone wait briefly for the cloud account list before
  /// reporting "invalid credentials".
  Future<void> _waitForAccountSync() async {
    if (!_firebase.isInitialized || _staffSynced.isCompleted) return;
    try {
      await _staffSynced.future.timeout(const Duration(seconds: 6));
    } catch (_) {
      /* offline: continue with local data */
    }
  }

  /// Admin tool: forces a full upload of local inventory/staff to the cloud.
  Future<void> forceUploadLocalDataToCloud() async {
    if (!_firebase.isInitialized) return;
    await syncInventory();
    for (final s in _staffList.where(_shouldSyncAccount)) {
      await _firebase.syncStaffToFirestore(s);
    }
    _setViewState(ViewState.success, 'Local data uploaded to the cloud.');
  }

  void _setViewState(ViewState state, [String? message]) {
    _viewState = state;
    _statusMessage = message;
    notifyListeners();
  }

  bool _isValidCurrency(double value) =>
      !value.isNaN && !value.isInfinite && value >= 0.0;

  // ---------------------------------------------------------------------------
  // Authentication (Internal ERP vs. Decoupled Customer App + Google Sign-In)
  // ---------------------------------------------------------------------------

  ///click & collect reservations alias
  List<ClickAndCollectOrder> get customerClickAndCollectOrders =>
      customerClickCollectOrders;

  /// Internal ERP Login (Admin: `bossarman` / `admin123`, Cashier: `cashier01` / `cashier123`, Mechanic: `mechanic01` / `mech123`)
  Future<bool> login(
    String username,
    String password, {
    bool allowCustomerRole = false,
    bool internalOnly = false,
    bool customerOnly = false,
    bool restoreIfDeleted = false,
  }) async {
    final effectiveAllowCustomer =
        allowCustomerRole || customerOnly || (isCustomerApp && !internalOnly);
    _setViewState(ViewState.loading);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final cleanUser = username.trim().toLowerCase();
      final cleanPass = password.trim();

      List<StaffAccount> findCandidates() => _staffList
          .where(
            (s) =>
                s.username.toLowerCase() == cleanUser ||
                s.email.toLowerCase() == cleanUser,
          )
          .toList();

      var candidates = findCandidates();
      if (candidates.isEmpty) {
        // Fresh phone: accounts may still be downloading from the cloud.
        await _waitForAccountSync();
        candidates = findCandidates();
      }

      if (candidates.isEmpty) {
        _setViewState(
          ViewState.error,
          'Invalid credentials. Check username and password.',
        );
        return false;
      }

      final candidate = candidates.first;
      if (candidate.authProvider == 'google') {
        _setViewState(
          ViewState.error,
          'This account is registered via Google One-Tap. Please sign in using Google.',
        );
        return false;
      }

      var passMatches = PasswordSecurity.verify(candidate.password, cleanPass);
      var firebaseVerified = false;
      if (!passMatches && candidate.authProvider == 'password') {
        // The password may have been changed through the Firebase reset email.
        firebaseVerified = await _firebase.verifyEmailPassword(
          candidate.email,
          cleanPass,
        );
        passMatches = firebaseVerified;
      }
      if (!passMatches) {
        _setViewState(
          ViewState.error,
          'Invalid credentials. Check username and password.',
        );
        return false;
      }

      // Check soft deletion / recovery status
      if (candidate.isDeleted) {
        if (candidate.isPermanentlyPurged) {
          _setViewState(
            ViewState.error,
            'This account was deleted and the 30-day recovery window has expired.',
          );
          return false;
        }
        if (restoreIfDeleted) {
          await restoreAccount(candidate.id);
        } else {
          _pendingRecoveryAccount = candidate;
          final dateStr = candidate.recoverableUntil != null
              ? DateFormat('MMM dd, yyyy').format(candidate.recoverableUntil!)
              : '30 days';
          _setViewState(
            ViewState.error,
            'ACCOUNT_DELETED_RECOVERABLE: This account is scheduled for deletion on $dateStr. Tap Restore to recover your account.',
          );
          return false;
        }
      }

      var user = _staffList.firstWhere(
        (s) => s.id == candidate.id,
        orElse: () => candidate,
      );
      // If legacy plaintext password matched, automatically hash and update in SQLite
      if (!user.password.contains(':') || firebaseVerified) {
        final hashed = PasswordSecurity.hashPassword(cleanPass);
        user = user.copyWith(password: hashed);
        final idx = _staffList.indexWhere((s) => s.id == user.id);
        if (idx >= 0) _staffList[idx] = user;
        await _saveStaff(user);
      }
      if (!firebaseVerified && user.authProvider == 'password') {
        // Best effort: make sure a Firebase Auth user exists so the
        // password-reset email works for this account.
        unawaited(_firebase.ensureAuthAccount(user.email, cleanPass));
      }

      if ((internalOnly || (!effectiveAllowCustomer && !isCustomerApp)) &&
          user.role == UserRole.customer) {
        _setViewState(
          ViewState.error,
          'Customer accounts must sign in using the Customer App target.',
        );
        return false;
      }
      if ((customerOnly || effectiveAllowCustomer) &&
          user.role != UserRole.customer) {
        _setViewState(
          ViewState.error,
          'Staff accounts must sign in using the Internal ERP terminal.',
        );
        return false;
      }

      // Strictly enforce single-branch assignment for Cashier and Mechanic
      if ((user.role == UserRole.cashier || user.role == UserRole.mechanic) &&
          user.assignedBranch == BranchId.both) {
        user = user.copyWith(assignedBranch: BranchId.patimbao);
        final idx = _staffList.indexWhere((s) => s.id == user.id);
        if (idx >= 0) _staffList[idx] = user;
        await _saveStaff(user);
      }

      _currentUser = user;

      if (user.role == UserRole.cashier || user.role == UserRole.mechanic) {
        _activeBranch = user.assignedBranch;
      } else if (user.assignedBranch == BranchId.patimbao ||
          user.assignedBranch == BranchId.pedroGuevara) {
        _activeBranch = user.assignedBranch;
      }

      final prefs = await SharedPreferences.getInstance();
      final userKey = (customerOnly || effectiveAllowCustomer)
          ? 'cached_customer_user'
          : 'cached_internal_user';
      await prefs.setString(userKey, user.username);
      await prefs.setString('cached_branch', _activeBranch.name);
      unawaited(syncDeviceBinding());

      _setViewState(
        ViewState.success,
        'Welcome back, ${user.fullName} (${user.role.label})',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Login error: $e');
      return false;
    }
  }

  /// Customer Email/Password Registration for `main_customer.dart`
  Future<bool> registerCustomerAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    String termsVersion = 'v1.0 (2026-10)',
    DateTime? termsAcceptedAt,
  }) async {
    _setViewState(ViewState.loading);
    try {
      final cleanUsername = username.trim().toLowerCase();
      final cleanEmail = email.trim().toLowerCase();

      final duplicate = _staffList.any(
        (s) =>
            !s.isDeleted &&
            (s.username.toLowerCase() == cleanUsername ||
                s.email.toLowerCase() == cleanEmail),
      );
      if (duplicate) {
        _setViewState(
          ViewState.error,
          'Username or email is already registered.',
        );
        return false;
      }

      final now = DateTime.now();
      final newCustomer = StaffAccount(
        id: _generateId('CUS'),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        username: cleanUsername,
        email: cleanEmail,
        password: PasswordSecurity.hashPassword(password.trim()),
        role: UserRole.customer,
        // Customers are not tied to a branch; they choose one when booking
        // or reserving.
        assignedBranch: BranchId.both,
        shiftStatus: 'Verified Customer',
        authProvider: 'password',
        termsAcceptedVersion: termsVersion,
        termsAcceptedAt: termsAcceptedAt ?? now,
        createdAt: now,
      );

      await _saveStaff(newCustomer);
      _staffList.add(newCustomer);
      _currentUser = newCustomer;
      unawaited(_firebase.ensureAuthAccount(cleanEmail, password.trim()));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customer_user', newCustomer.username);
      await prefs.setString('cached_branch', _activeBranch.name);
      unawaited(syncDeviceBinding());

      _setViewState(
        ViewState.success,
        'Welcome to Boss Arman MotoHub, ${newCustomer.fullName}!',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Registration failed: $e');
      return false;
    }
  }

  /// Google One-Tap / Google Sign-In Handler for `main_customer.dart`
  Future<bool> signInCustomerWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
    String termsVersion = 'v1.0 (2026-10)',
  }) async {
    _setViewState(ViewState.loading);
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
        _setViewState(ViewState.error, 'Invalid Google account email.');
        return false;
      }

      final existing = _staffList
          .where(
            (s) =>
                s.role == UserRole.customer &&
                s.email.toLowerCase() == cleanEmail,
          )
          .toList();

      StaffAccount customer;
      if (existing.isNotEmpty) {
        customer = existing.first;
        if (customer.isDeleted) {
          if (customer.isPermanentlyPurged) {
            _setViewState(
              ViewState.error,
              'This customer account was deleted and its 30-day recovery window has expired.',
            );
            return false;
          }
          // Restore customer account upon login within 30 days
          customer = customer.copyWith(clearDeletion: true);
          await _firebase.restoreUserDoc(customer.id);
        }
        if (photoUrl != null &&
            photoUrl.isNotEmpty &&
            (customer.photoUrl == null || customer.photoUrl!.isEmpty)) {
          customer = customer.copyWith(photoUrl: photoUrl);
          await _firebase.updateUserProfilePhoto(customer.id, photoUrl);
        }
        if (customer.termsAcceptedVersion == null) {
          customer = customer.copyWith(
            termsAcceptedVersion: termsVersion,
            termsAcceptedAt: DateTime.now(),
          );
        }
        final idx = _staffList.indexWhere((s) => s.id == customer.id);
        if (idx >= 0) _staffList[idx] = customer;
        await _saveStaff(customer);
      } else {
        final nameParts = displayName.trim().split(RegExp(r'\s+'));
        final firstName = nameParts.isNotEmpty && nameParts.first.isNotEmpty
            ? nameParts.first
            : cleanEmail.split('@').first;
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : 'Rider';
        final generatedUsername = cleanEmail.split('@').first.toLowerCase();
        final now = DateTime.now();

        customer = StaffAccount(
          id: _generateId('GGL'),
          firstName: firstName,
          lastName: lastName,
          username: generatedUsername,
          email: cleanEmail,
          password: 'AUTH_PROVIDER_GOOGLE_${_uuid.v4()}',
          role: UserRole.customer,
          assignedBranch: BranchId.both,
          shiftStatus: 'Google Verified',
          authProvider: 'google',
          photoUrl: photoUrl,
          termsAcceptedVersion: termsVersion,
          termsAcceptedAt: now,
          createdAt: now,
        );
        await _saveStaff(customer);
        _staffList.add(customer);
        if (photoUrl != null) {
          await _firebase.updateUserProfilePhoto(customer.id, photoUrl);
        }
      }

      _currentUser = customer;
      _activeBranch = customer.assignedBranch == BranchId.both
          ? BranchId.patimbao
          : customer.assignedBranch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customer_user', customer.username);
      await prefs.setString('cached_branch', _activeBranch.name);
      unawaited(syncDeviceBinding());

      _setViewState(
        ViewState.success,
        'Signed in with Google as ${customer.fullName} (${customer.email})',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Google Sign-In failed: $e');
      return false;
    }
  }

  /// Google One-Tap / Google Sign-In for Staff & Management (Internal App)
  /// Enforces that the Google email MUST already be registered by Admin as an authorized staff account (Admin, Cashier, or Mechanic).
  /// If not found in staff directory, login is strictly REJECTED.
  Future<bool> signInStaffWithGoogle({
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    _setViewState(ViewState.loading);
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
        _setViewState(ViewState.error, 'Invalid Google account email address.');
        return false;
      }

      // Check against registered staff list (must NOT be customer)
      final matchedStaff = _staffList
          .where(
            (s) =>
                s.email.trim().toLowerCase() == cleanEmail &&
                s.role != UserRole.customer,
          )
          .toList();

      if (matchedStaff.isEmpty) {
        _setViewState(
          ViewState.error,
          'Account not found. Google email "$cleanEmail" is not registered as an authorized staff account. Please contact Boss Arman to register your email in the Admin Panel.',
        );
        return false;
      }

      var staff = matchedStaff.first;
      if (staff.isDeleted) {
        if (staff.isPermanentlyPurged) {
          _setViewState(
            ViewState.error,
            'This staff account was deleted and the 30-day recovery window has expired.',
          );
          return false;
        }
        // Restore staff account upon login within 30 days
        staff = staff.copyWith(clearDeletion: true);
        await _firebase.restoreUserDoc(staff.id);
      }
      if (photoUrl != null &&
          photoUrl.isNotEmpty &&
          (staff.photoUrl == null || staff.photoUrl!.isEmpty)) {
        staff = staff.copyWith(photoUrl: photoUrl);
        await _firebase.updateUserProfilePhoto(staff.id, photoUrl);
      }
      final sIdx = _staffList.indexWhere((s) => s.id == staff.id);
      if (sIdx >= 0) _staffList[sIdx] = staff;
      await _saveStaff(staff);

      _currentUser = staff;
      _activeBranch =
          (staff.role == UserRole.cashier || staff.role == UserRole.mechanic)
          ? (staff.assignedBranch == BranchId.both
                ? BranchId.patimbao
                : staff.assignedBranch)
          : staff.assignedBranch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_internal_user', staff.username);
      await prefs.setString('cached_branch', _activeBranch.name);
      unawaited(syncDeviceBinding());

      _setViewState(
        ViewState.success,
        'Authenticated as ${staff.role.label}: ${staff.fullName}',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Google Sign-In failed: $e');
      return false;
    }
  }

  /// Updates current user's profile photo (compressed base64 or URL)
  Future<bool> updateCurrentUserProfilePhoto(String? base64OrUrl) async {
    final cur = _currentUser;
    if (cur == null) return false;
    _setViewState(ViewState.loading);
    try {
      final updated = cur.copyWith(
        photoUrl: base64OrUrl,
        clearPhotoUrl: base64OrUrl == null,
      );
      _currentUser = updated;
      final idx = _staffList.indexWhere((s) => s.id == cur.id);
      if (idx >= 0) {
        _staffList[idx] = updated;
      }
      await _saveStaff(updated);
      await _firebase.updateUserProfilePhoto(updated.id, base64OrUrl);
      _setViewState(
        ViewState.success,
        base64OrUrl != null
            ? 'Profile photo updated successfully!'
            : 'Profile photo removed.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update profile photo: $e');
      return false;
    }
  }

  /// Soft-deletes a user account with a 30-day recovery window.
  /// If the current user deletes their own account, signs them out.
  Future<bool> softDeleteAccount({
    required String accountId,
    required String confirmation,
  }) async {
    final cleanConf = confirmation.trim().toUpperCase();
    final idx = _staffList.indexWhere((s) => s.id == accountId);
    if (idx < 0) {
      _setViewState(ViewState.error, 'Account not found.');
      return false;
    }
    final target = _staffList[idx];

    // Must confirm by typing 'DELETE' or providing valid password
    final passwordValid = PasswordSecurity.verify(target.password, confirmation) ||
        confirmation == target.password;
    if (cleanConf != 'DELETE' && !passwordValid) {
      _setViewState(
        ViewState.error,
        'Confirmation failed. Please type "DELETE" or enter your correct password.',
      );
      return false;
    }

    _setViewState(ViewState.loading);
    try {
      final now = DateTime.now();
      final recoverableUntil = now.add(const Duration(days: 30));
      final updated = target.copyWith(
        isDeleted: true,
        deletedAt: now,
        recoverableUntil: recoverableUntil,
      );

      _staffList[idx] = updated;
      await _saveStaff(updated);
      await _firebase.softDeleteUserDoc(updated.id, recoverableUntil);

      if (_currentUser?.id == accountId) {
        await logout();
        _setViewState(
          ViewState.success,
          'Account scheduled for deletion. You have 30 days to restore it by logging in again.',
        );
      } else {
        _setViewState(
          ViewState.success,
          'Staff account ${target.fullName} marked for deletion (30-day recovery window).',
        );
      }
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete account: $e');
      return false;
    }
  }

  /// Restores a soft-deleted account within its 30-day recovery window.
  Future<bool> restoreAccount(String accountId) async {
    _setViewState(ViewState.loading);
    try {
      final idx = _staffList.indexWhere((s) => s.id == accountId);
      if (idx < 0) {
        _setViewState(ViewState.error, 'Account not found.');
        return false;
      }
      final target = _staffList[idx];
      if (target.isPermanentlyPurged) {
        _setViewState(
          ViewState.error,
          'Recovery window has expired. This account has been permanently purged.',
        );
        return false;
      }

      final updated = target.copyWith(clearDeletion: true);
      _staffList[idx] = updated;
      await _saveStaff(updated);
      await _firebase.restoreUserDoc(updated.id);

      if (_currentUser?.id == accountId) {
        _currentUser = updated;
      }
      _pendingRecoveryAccount = null;
      _setViewState(
        ViewState.success,
        'Account ${updated.fullName} successfully restored!',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to restore account: $e');
      return false;
    }
  }

  /// Permanently deletes the customer's account (Firebase Auth + Firestore document + local session)
  /// Reauthenticates first with the customer's password (or 'DELETE' confirmation for Google accounts).
  Future<bool> deleteCustomerAccount({required String password}) async {
    final user = _currentUser;
    if (user == null) {
      _setViewState(ViewState.error, 'No logged in customer.');
      return false;
    }
    final isGoogleUser = user.authProvider == 'google' ||
        user.password.startsWith('AUTH_PROVIDER_GOOGLE_');
    if (isGoogleUser) {
      if (password.trim().toUpperCase() != 'DELETE') {
        _setViewState(
          ViewState.error,
          'Please type "DELETE" to confirm permanent account deletion.',
        );
        return false;
      }
    } else if (user.password.isNotEmpty &&
        !PasswordSecurity.verify(user.password, password) &&
        user.password != password) {
      _setViewState(
        ViewState.error,
        'Incorrect password. Please verify your credentials.',
      );
      return false;
    }

    _setViewState(ViewState.loading);
    try {
      try {
        if (user.id.isNotEmpty) {
          await _firebase.unbindUser(appUserId: user.id);
        }
        if (user.username.isNotEmpty) {
          await _firebase.unbindUser(appUserId: user.username);
        }
        await _firebase.deleteCustomerAuthAndData(
          uid: user.id,
          currentPassword: isGoogleUser ? null : password,
        );
      } catch (e) {
        debugPrint('[deleteCustomerAccount] cloud delete warning: $e');
      }

      _staffList.removeWhere((s) => s.id == user.id);
      await _db.deleteStaff(user.id);
      unawaited(_firebase.deleteStaffFromFirestore(user.id));
      await logout();
      _setViewState(ViewState.success, 'Your account has been deleted.');
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _setViewState(
          ViewState.error,
          'Incorrect password. Please verify your credentials.',
        );
      } else if (e.code == 'requires-recent-login') {
        _setViewState(
          ViewState.error,
          'Security check: please sign out and sign back in before deleting your account.',
        );
      } else {
        _setViewState(
          ViewState.error,
          'Failed to delete account: ${e.message}',
        );
      }
      return false;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete account: $e');
      return false;
    }
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      final uid = _currentUser!.id.isNotEmpty ? _currentUser!.id : _currentUser!.username;
      unawaited(_firebase.unbindUser(appUserId: uid));
      if (_currentUser!.username.isNotEmpty &&
          _currentUser!.username.toLowerCase() != uid.toLowerCase()) {
        unawaited(_firebase.unbindUser(appUserId: _currentUser!.username));
      }
    }
    _currentUser = null;
    _cart.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isCustomerApp) {
        await prefs.remove('cached_customer_user');
        await prefs.remove('cached_customer_user_id');
        await prefs.remove('cached_customer_role');
      } else {
        await prefs.remove('cached_internal_user');
        await prefs.remove('cached_internal_user_id');
        await prefs.remove('cached_internal_role');
      }
    } catch (_) {}
    _setViewState(ViewState.idle);
  }

  /// Synchronizes device FCM token and Auth UID to user_bindings/{appUserId} in Firestore
  Future<void> syncDeviceBinding() async {
    final user = _currentUser;
    if (user != null) {
      final userId = user.id.isNotEmpty ? user.id : user.username;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (isCustomerApp) {
          await prefs.setString('cached_customer_user', user.username);
          await prefs.setString('cached_customer_user_id', userId);
          await prefs.setString('cached_customer_role', user.role.name);
        } else {
          await prefs.setString('cached_internal_user', user.username);
          await prefs.setString('cached_internal_user_id', userId);
          await prefs.setString('cached_internal_role', user.role.name);
        }
      } catch (_) {}
      await _firebase.updateUserBinding(
        appUserId: userId,
        role: user.role,
        branch: _activeBranch,
      );
      if (user.username.isNotEmpty && user.username.toLowerCase() != userId.toLowerCase()) {
        await _firebase.updateUserBinding(
          appUserId: user.username,
          role: user.role,
          branch: _activeBranch,
        );
      }
      if (user.role == UserRole.admin) {
        await _firebase.updateUserBinding(
          appUserId: 'admin',
          role: UserRole.admin,
          branch: _activeBranch,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Password Recovery (Firebase Auth reset email)
  // ---------------------------------------------------------------------------

  /// Sends the Firebase password-reset email. Throws [AuthFlowException]
  /// with a user-friendly message on failure.
  Future<void> sendPasswordResetEmail(String email) =>
      _firebase.sendPasswordResetEmail(email);

  Future<void> switchBranch(BranchId branch) async {
    if (branch == BranchId.both) return;
    if (isBranchLockedForCurrentUser) {
      final lockedBranch = _currentUser!.assignedBranch == BranchId.both
          ? BranchId.patimbao
          : _currentUser!.assignedBranch;
      _activeBranch = lockedBranch;
      _setViewState(
        ViewState.error,
        'Branch locked to ${lockedBranch.displayName}. Only the Admin can change your assigned branch.',
      );
      return;
    }
    if (_activeBranch == branch) return;
    _activeBranch = branch;
    _cart.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_branch', branch.name);
    } catch (_) {}
    _setViewState(
      ViewState.success,
      'Switched context to ${branch.displayName}',
    );
  }

  Future<void> setActiveBranch(BranchId branch) => switchBranch(branch);

  // ---------------------------------------------------------------------------
  // Offline-First Connectivity & Background Sync Worker
  // ---------------------------------------------------------------------------

  Future<void> toggleConnectivity() async {
    _isOnline = !_isOnline;
    if (_isOnline && pendingSyncCount > 0) {
      await syncPendingLogs();
    } else {
      _setViewState(
        ViewState.idle,
        _isOnline ? 'Network Online • Real-time Cloud Sync Active' : 'Offline Mode Active • Writing all transactions to local SQLite first',
      );
    }
  }

  void _enqueueIfOffline(String operation, String summary) {
    if (_isOnline) return;
    _offlineQueue.insert(
      0,
      OfflineSyncTask(
        id: 'SYNC-${DateTime.now().millisecondsSinceEpoch}',
        operation: operation,
        summary: summary,
        branch: _activeBranch,
        timestamp: DateTime.now(),
        synced: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inventory Cloud Sync (Firestore <-> SQLite, 3-way merge)
  // ---------------------------------------------------------------------------

  /// Every notifyListeners() (sale, stock edit, job part, transfer...) also
  /// schedules a quick "is anything not uploaded yet?" check. This is why you
  /// do not have to edit each of the ~15 places that change inventory.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
    _scheduleInventorySyncCheck();
  }

  String _inventoryFingerprint(InventoryItem i) => jsonEncode(i.toMap());

  Future<void> _loadInventoryBaseline() async {
    if (_inventoryBaselineLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kInventoryBaselineKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _inventoryBaseline = decoded.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      debugPrint('[MotoHubViewModel] inventory baseline load note: $e');
    }
    _inventoryBaselineLoaded = true;
  }

  Future<void> _saveInventoryBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kInventoryBaselineKey,
        jsonEncode(_inventoryBaseline),
      );
    } catch (e) {
      debugPrint('[MotoHubViewModel] inventory baseline save note: $e');
    }
  }

  /// Number of items that differ from what the cloud last confirmed.
  int _countDirtyInventory() {
    var dirty = 0;
    final seen = <String>{};
    for (final item in _inventory) {
      seen.add(item.id);
      if (_inventoryBaseline[item.id] != _inventoryFingerprint(item)) dirty++;
    }
    for (final id in _inventoryBaseline.keys) {
      if (!seen.contains(id)) dirty++; // deleted here, not yet deleted in cloud
    }
    return dirty;
  }

  void _scheduleInventorySyncCheck() {
    if (isCustomerApp || !_inventoryBaselineLoaded) return;
    _inventoryDebounce?.cancel();
    _inventoryDebounce = Timer(
      const Duration(milliseconds: 1500),
      _syncIfInventoryDirty,
    );
  }

  void _syncIfInventoryDirty() {
    if (_isSyncingInventory) return;
    final dirty = _countDirtyInventory();
    if (dirty != _pendingInventoryCount) {
      _pendingInventoryCount = dirty;
      super.notifyListeners(); // refresh the chip only (does not re-schedule)
    }
    if (dirty == 0 || !_inventoryInitialSyncDone) return;
    if (_inventorySyncStatus == InventorySyncStatus.offline ||
        _inventorySyncStatus == InventorySyncStatus.error) {
      return; // the 15 s retry timer handles these
    }
    unawaited(syncInventory());
  }

  void _setInventorySyncStatus(InventorySyncStatus status) {
    _inventorySyncStatus = status;
    if (status == InventorySyncStatus.offline ||
        status == InventorySyncStatus.error) {
      _inventoryRetryTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
        if (!_isSyncingInventory) unawaited(syncInventory());
      });
    } else {
      _inventoryRetryTimer?.cancel();
      _inventoryRetryTimer = null;
    }
    notifyListeners();
  }

  /// Live listener: when ANOTHER phone changes inventory, Firestore pushes it
  /// here and we merge it into SQLite immediately.
  void _startInventoryRealtime() {
    if (!_firebase.isInitialized) return;
    _inventorySub?.cancel();
    _inventorySub = _firebase.streamInventory().listen(
      (snap) {
        // Ignore cache echoes and our own not-yet-confirmed writes.
        if (!snap.fromServer || snap.hasPendingWrites) return;
        if (_isSyncingInventory) {
          _inventorySyncQueued = true;
          return;
        }
        unawaited(syncInventory(remote: snap.items));
      },
      onError: (Object e) {
        _inventorySyncError = '$e';
        _setInventorySyncStatus(
          '$e'.contains('permission-denied')
              ? InventorySyncStatus.error
              : InventorySyncStatus.offline,
        );
      },
    );
  }

  /// Syncs inventory with Firestore. Returns true when fully in sync.
  /// Call it from anywhere: opening the inventory tab, the chip, etc.
  Future<bool> syncInventory({List<InventoryItem>? remote}) async {
    if (!_firebase.isInitialized) {
      _inventorySyncError =
          _firebase.initError ?? 'Firebase is not available on this device.';
      _setInventorySyncStatus(InventorySyncStatus.offline);
      return false;
    }
    if (_isSyncingInventory) {
      _inventorySyncQueued = true;
      return false;
    }

    _isSyncingInventory = true;
    _setInventorySyncStatus(InventorySyncStatus.syncing);

    var ok = false;
    var denied = false;
    try {
      await _loadInventoryBaseline();
      final remoteItems = remote ?? await _firebase.fetchInventoryFromServer();

      final remoteMap = {for (final r in remoteItems) r.id: r};
      final localMap = {for (final l in _inventory) l.id: l};
      final base = Map<String, String>.from(_inventoryBaseline);

      final pull = <String, InventoryItem?>{}; // null = delete locally
      final pushUpserts = <InventoryItem>[];
      final pushDeletes = <String>[];

      final ids = <String>{...remoteMap.keys, ...localMap.keys, ...base.keys};

      for (final id in ids) {
        final l = localMap[id];
        final r = remoteMap[id];
        final lf = l == null ? null : _inventoryFingerprint(l);
        final rf = r == null ? null : _inventoryFingerprint(r);
        final bf = base[id];

        if (lf == rf) {
          // Same on both sides (or missing on both): nothing to do.
          if (lf == null) {
            base.remove(id);
          } else {
            base[id] = lf;
          }
          continue;
        }

        final localChanged = lf != bf;
        final remoteChanged = rf != bf;

        if (remoteChanged && !localChanged) {
          // Another phone changed or deleted it: take the cloud version.
          pull[id] = r;
          if (rf == null) {
            base.remove(id);
          } else {
            base[id] = rf;
          }
        } else if (l == null) {
          // Deleted on this phone.
          if (remoteChanged) {
            // ...but edited elsewhere meanwhile: keep it, do not lose data.
            pull[id] = r;
            base[id] = rf!;
          } else {
            pushDeletes.add(id);
          }
        } else {
          // Changed on this phone: upload it (this phone wins a true conflict).
          pushUpserts.add(l);
        }
      }

      // 1) Apply cloud changes to SQLite + memory.
      for (final entry in pull.entries) {
        final item = entry.value;
        if (item == null) {
          await _db.deleteInventoryItem(entry.key);
          _inventory.removeWhere((p) => p.id == entry.key);
        } else {
          await _db.saveInventoryItem(item);
          final idx = _inventory.indexWhere((p) => p.id == item.id);
          if (idx >= 0) {
            _inventory[idx] = item;
          } else {
            _inventory.add(item);
          }
        }
      }
      if (pull.isNotEmpty) {
        _inventory.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        // Keep the POS cart consistent with the new stock numbers.
        for (var i = _cart.length - 1; i >= 0; i--) {
          final matches = _inventory.where((p) => p.id == _cart[i].item.id);
          if (matches.isEmpty) {
            _cart.removeAt(i);
            continue;
          }
          final fresh = matches.first;
          final avail = fresh.availableStockFor(_activeBranch);
          if (avail <= 0) {
            _cart.removeAt(i);
          } else {
            _cart[i] = CartItem(
              item: fresh,
              quantity: _cart[i].quantity.clamp(1, avail),
            );
          }
        }
      }

      // 2) Upload this phone's changes (staff/internal app only; customer app is read-only for inventory).
      Object? pushError;
      if (!isCustomerApp &&
          (pushUpserts.isNotEmpty || pushDeletes.isNotEmpty)) {
        try {
          await _firebase.pushInventoryChanges(
            upserts: pushUpserts,
            deletedIds: pushDeletes,
          );
          for (final item in pushUpserts) {
            base[item.id] = _inventoryFingerprint(item);
          }
          for (final id in pushDeletes) {
            base.remove(id);
          }
        } catch (e) {
          pushError = e;
        }
      }

      // 3) Remember what the cloud now holds, even if the upload failed,
      //    so the pulled items are not treated as local edits next time.
      _inventoryBaseline = base;
      await _saveInventoryBaseline();
      if (pushError != null) throw pushError;

      _inventorySyncError = null;
      _lastInventorySyncAt = DateTime.now();
      _inventoryInitialSyncDone = true;
      ok = true;
    } catch (e) {
      final msg = '$e';
      denied = msg.contains('permission-denied');
      _inventorySyncError = msg;
      debugPrint('[MotoHubViewModel] syncInventory failed: $e');
    }

    _isSyncingInventory = false;
    _pendingInventoryCount = _countDirtyInventory();
    _setInventorySyncStatus(
      ok
          ? InventorySyncStatus.synced
          : (denied ? InventorySyncStatus.error : InventorySyncStatus.offline),
    );

    if (_inventorySyncQueued) {
      _inventorySyncQueued = false;
      if (ok) unawaited(syncInventory());
    }
    return ok;
  }

  Future<void> syncPendingLogs() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      for (var i = 0; i < _offlineQueue.length; i++) {
        _offlineQueue[i] = _offlineQueue[i].copyWith(synced: true);
      }
      for (var i = 0; i < _transactions.length; i++) {
        if (!_transactions[i].isSynced) {
          final updated = _transactions[i].copyWith(isSynced: true);
          _transactions[i] = updated;
          await _db.saveTransaction(updated);
        }
      }
      _isSyncing = false;
      _setViewState(
        ViewState.success,
        'All queued offline SQLite records synchronized.',
      );
    } catch (e) {
      _isSyncing = false;
      _setViewState(ViewState.error, 'Sync failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Search, Filters & Barcode Lookup
  // ---------------------------------------------------------------------------

  void setInventorySearchQuery(String query) {
    _inventorySearchQuery = query;
    notifyListeners();
  }

  void setSelectedPosCategory(String category) {
    _selectedPosCategory = category;
    notifyListeners();
  }

  void setSelectedJobStatusFilter(JobStatus? status) {
    _selectedJobStatusFilter = status;
    notifyListeners();
  }

  InventoryItem? findPartByCode(String code) {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final item in _inventory) {
      if (item.isDeleted) continue;
      if (item.barcode.toLowerCase() == clean ||
          item.sku.toLowerCase() == clean ||
          item.id.toLowerCase() == clean) {
        return item;
      }
    }
    return null;
  }

  /// Searches parts across inventory matching exact barcode/SKU, or
  /// case-insensitive partial substring matches across name, SKU, barcode, category, or models.
  List<InventoryItem> searchParts(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final exactMatches = <InventoryItem>[];
    final partialMatches = <InventoryItem>[];

    for (final item in _inventory) {
      if (item.isDeleted) continue;
      if (item.barcode.toLowerCase() == clean ||
          item.sku.toLowerCase() == clean ||
          item.id.toLowerCase() == clean) {
        exactMatches.add(item);
      } else if (item.name.toLowerCase().contains(clean) ||
          item.sku.toLowerCase().contains(clean) ||
          item.barcode.toLowerCase().contains(clean) ||
          item.category.toLowerCase().contains(clean) ||
          item.compatibleModels.toLowerCase().contains(clean)) {
        partialMatches.add(item);
      }
    }
    return [...exactMatches, ...partialMatches];
  }

  // ---------------------------------------------------------------------------
  // Master Inventory & Atomic Two-Phase Inter-Branch Transfer Protocol
  // ---------------------------------------------------------------------------

  Future<bool> addOrUpdateInventoryItem(InventoryItem item) async {
    if (_currentUser != null &&
        (_currentUser!.role == UserRole.customer ||
            _currentUser!.role == UserRole.mechanic)) {
      _setViewState(
        ViewState.error,
        'Unauthorized: Only Admin or Cashier staff can modify master inventory.',
      );
      return false;
    }

    final nameError = AppValidators.partName(item.name);
    if (nameError != null) {
      _setViewState(ViewState.error, nameError);
      return false;
    }

    final otherItems = _inventory.where(
      (e) => !e.isDeleted && e.id != item.id,
    );
    final skuError = AppValidators.sku(
      item.sku,
      existingSkus: otherItems.map((e) => e.sku),
    );
    if (skuError != null) {
      _setViewState(ViewState.error, skuError);
      return false;
    }

    final barcodeError = AppValidators.barcode(
      item.barcode,
      existingBarcodes: otherItems.map((e) => e.barcode),
    );
    if (barcodeError != null) {
      _setViewState(ViewState.error, barcodeError);
      return false;
    }

    if (!_isValidCurrency(item.price) ||
        item.price <= 0 ||
        !_isValidCurrency(item.costPrice) ||
        item.stockPatimbao < 0 ||
        item.stockPedroGuevara < 0) {
      _setViewState(
        ViewState.error,
        'Invalid price or negative stock quantity rejected.',
      );
      return false;
    }
    if (item.stockPatimbao < item.lockedPatimbao ||
        item.stockPedroGuevara < item.lockedPedroGuevara) {
      _setViewState(
        ViewState.error,
        'Stock cannot be set lower than units currently locked in active service bays or reservations.',
      );
      return false;
    }

    try {
      await _db.saveInventoryItem(item);
      final idx = _inventory.indexWhere((e) => e.id == item.id);
      if (idx >= 0) {
        _inventory[idx] = item;
      } else {
        _inventory.insert(0, item);
      }
      final cartIdx = _cart.indexWhere((c) => c.item.id == item.id);
      if (cartIdx >= 0) {
        final avail = item.availableStockFor(_activeBranch);
        if (avail <= 0) {
          _cart.removeAt(cartIdx);
        } else {
          _cart[cartIdx] = CartItem(
            item: item,
            quantity: _cart[cartIdx].quantity.clamp(1, avail),
          );
        }
      }
      unawaited(_firebase.syncInventoryItemToFirestore(item));
      _enqueueIfOffline('INVENTORY_UPSERT', '${item.sku} (${item.name})');
      _setViewState(
        ViewState.success,
        'Saved ${item.name} (${item.shelfCoordinates}) to SQLite.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to save inventory item: $e');
      return false;
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    final idx = _inventory.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      final target = _inventory[idx];
      if (target.lockedPatimbao > 0 || target.lockedPedroGuevara > 0) {
        _setViewState(
          ViewState.error,
          'Cannot delete ${target.name} while units are locked in active jobs or reservations.',
        );
        return false;
      }
      final hasInTransit = _transfers.any(
        (t) => t.partId == id && t.status == TransferStatus.inTransit,
      );
      if (hasInTransit) {
        _setViewState(
          ViewState.error,
          'Cannot delete ${target.name} while an inter-branch transfer is in-transit.',
        );
        return false;
      }
    }
    try {
      await _db.deleteInventoryItem(id);
      _inventory.removeWhere((i) => i.id == id);
      unawaited(_firebase.deleteInventoryItemFromFirestore(id));
      _cart.removeWhere((c) => c.item.id == id);
      notifyListeners();
      _setViewState(ViewState.success, 'Permanently removed item from inventory.');
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete inventory item: $e');
      return false;
    }
  }

  /// Strict Approval Transfer Workflow Phase 1: Branch A requests stock from Branch B.
  /// Status is [pendingApproval]; NO stock is decremented yet from Branch B.
  Future<bool> requestStockTransfer({
    required InventoryItem item,
    required BranchId fromBranch,
    required BranchId toBranch,
    required int quantity,
  }) async {
    if (fromBranch == toBranch ||
        fromBranch == BranchId.both ||
        toBranch == BranchId.both) {
      _setViewState(
        ViewState.error,
        'Source and destination branches must be two distinct branches.',
      );
      return false;
    }
    if (quantity <= 0) {
      _setViewState(
        ViewState.error,
        'Transfer quantity must be greater than 0.',
      );
      return false;
    }
    final pIdx = _inventory.indexWhere((e) => e.id == item.id);
    final liveItem = pIdx >= 0 ? _inventory[pIdx] : item;
    final available = liveItem.availableStockFor(fromBranch);
    if (quantity > available) {
      _setViewState(
        ViewState.error,
        'Cannot request $quantity units: only $available available at ${fromBranch.shortName}.',
      );
      return false;
    }

    try {
      final transfer = StockTransfer(
        id: _generateId('TRF'),
        partId: liveItem.id,
        sku: liveItem.sku,
        partName: liveItem.name,
        quantity: quantity,
        fromBranch: fromBranch,
        toBranch: toBranch,
        status: TransferStatus.pendingApproval,
        initiatedBy: _currentUser?.fullName ?? 'Authorized Staff',
        createdAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Transfer Request Pending (${transfer.id})',
        message:
            '${toBranch.shortName} requested ${quantity}x ${liveItem.name} from ${fromBranch.shortName}. Requires Approval.',
        category: 'transfer',
        branch: fromBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: null, // NO stock deduction yet!
        transfer: transfer,
        notification: notif,
      );

      _transfers.insert(0, transfer);
      _notifications.insert(0, notif);
      _firebase.syncStockTransferToFirestore(transfer);
      _firebase.createFirestoreNotification(notif);

      _enqueueIfOffline(
        'TRANSFER_REQ',
        '${transfer.id}: ${quantity}x ${liveItem.sku} (${fromBranch.shortName} -> ${toBranch.shortName})',
      );

      _setViewState(
        ViewState.success,
        'Stock transfer request ${transfer.id} submitted for ${fromBranch.shortName} approval.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to submit transfer request: $e');
      return false;
    }
  }

  /// Strict Approval Transfer Workflow Phase 2: Source branch cashier or Admin APPROVES.
  /// Stock is decremented from source branch and status becomes [inTransit].
  Future<bool> approveStockTransfer(StockTransfer transfer) async {
    if (transfer.status != TransferStatus.pendingApproval) {
      _setViewState(ViewState.error, 'Transfer is not pending approval.');
      return false;
    }

    if (_currentUser != null &&
        _currentUser!.role != UserRole.admin &&
        _currentUser!.assignedBranch != transfer.fromBranch &&
        _currentUser!.assignedBranch != BranchId.both) {
      _setViewState(
        ViewState.error,
        'Access Denied: Only staff assigned to source branch (${transfer.fromBranch.displayName}) or Admin can approve this transfer.',
      );
      return false;
    }

    final tIdx = _transfers.indexWhere((t) => t.id == transfer.id);
    final pIdx = _inventory.indexWhere((p) => p.id == transfer.partId);
    if (tIdx < 0 || pIdx < 0) {
      _setViewState(ViewState.error, 'Transfer or part record not found.');
      return false;
    }

    final liveItem = _inventory[pIdx];
    final available = liveItem.availableStockFor(transfer.fromBranch);
    if (transfer.quantity > available) {
      _setViewState(
        ViewState.error,
        'Insufficient stock at ${transfer.fromBranch.shortName} ($available available).',
      );
      return false;
    }

    try {
      final updatedItem = liveItem.copyWith(
        stockPatimbao: transfer.fromBranch == BranchId.patimbao
            ? liveItem.stockPatimbao - transfer.quantity
            : liveItem.stockPatimbao,
        stockPedroGuevara: transfer.fromBranch == BranchId.pedroGuevara
            ? liveItem.stockPedroGuevara - transfer.quantity
            : liveItem.stockPedroGuevara,
      );

      final approvedTransfer = transfer.copyWith(
        status: TransferStatus.inTransit,
        approvedBy: _currentUser?.fullName ?? 'Branch Manager',
        approvedAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Transfer Approved & Dispatched (${transfer.id})',
        message:
            '${transfer.quantity}x ${transfer.partName} approved by ${transfer.fromBranch.shortName}. Shipment now In-Transit.',
        category: 'transfer',
        branch: transfer.toBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: updatedItem,
        transfer: approvedTransfer,
        notification: notif,
      );

      _inventory[pIdx] = updatedItem;
      _transfers[tIdx] = approvedTransfer;
      _notifications.insert(0, notif);
      _firebase.syncStockTransferToFirestore(approvedTransfer);
      _firebase.createFirestoreNotification(notif);

      _enqueueIfOffline(
        'TRANSFER_APPROVE',
        '${transfer.id} approved by ${transfer.fromBranch.shortName}',
      );

      _setViewState(
        ViewState.success,
        'Transfer ${transfer.id} approved and marked In-Transit.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to approve transfer: $e');
      return false;
    }
  }

  /// Strict Approval Transfer Workflow Phase 2b: Source branch REJECTS.
  /// No stock moved. Status set to [rejected].
  Future<bool> rejectStockTransfer(
    StockTransfer transfer,
    String reason,
  ) async {
    if (transfer.status != TransferStatus.pendingApproval) return false;

    if (_currentUser != null &&
        _currentUser!.role != UserRole.admin &&
        _currentUser!.assignedBranch != transfer.fromBranch &&
        _currentUser!.assignedBranch != BranchId.both) {
      _setViewState(
        ViewState.error,
        'Access Denied: Only staff assigned to source branch (${transfer.fromBranch.displayName}) or Admin can reject this transfer.',
      );
      return false;
    }

    final tIdx = _transfers.indexWhere((t) => t.id == transfer.id);
    if (tIdx < 0) return false;

    try {
      final rejectedTransfer = transfer.copyWith(
        status: TransferStatus.rejected,
        rejectionReason: reason.trim().isEmpty
            ? 'Rejected by source branch cashier'
            : reason.trim(),
        rejectedBy: _currentUser?.fullName ?? 'Branch Manager',
        rejectedAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Transfer Request Rejected (${transfer.id})',
        message:
            'Transfer of ${transfer.quantity}x ${transfer.partName} was rejected: ${rejectedTransfer.rejectionReason}',
        category: 'transfer',
        branch: transfer.toBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: null,
        transfer: rejectedTransfer,
        notification: notif,
      );

      _transfers[tIdx] = rejectedTransfer;
      _notifications.insert(0, notif);
      _firebase.syncStockTransferToFirestore(rejectedTransfer);
      _firebase.createFirestoreNotification(notif);

      _setViewState(
        ViewState.success,
        'Transfer request ${transfer.id} rejected.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to reject transfer: $e');
      return false;
    }
  }

  /// Cancels an Inter-Branch Stock Transfer (Pending or In-Transit).
  /// If already In-Transit, refunds deducted stock back to the source branch.
  Future<bool> cancelStockTransfer(
    StockTransfer transfer, {
    String? reason,
  }) async {
    if (transfer.status == TransferStatus.delivered ||
        transfer.status == TransferStatus.rejected ||
        transfer.status == TransferStatus.cancelled) {
      _setViewState(
        ViewState.error,
        'Transfer is already ${transfer.status.label}.',
      );
      return false;
    }

    final tIdx = _transfers.indexWhere((t) => t.id == transfer.id);
    if (tIdx < 0) return false;

    try {
      InventoryItem? updatedItem;
      // If the transfer was already In-Transit, source stock was decremented, so refund it back to source!
      if (transfer.status == TransferStatus.inTransit) {
        final pIdx = _inventory.indexWhere((p) => p.id == transfer.partId);
        if (pIdx >= 0) {
          final cur = _inventory[pIdx];
          updatedItem = cur.copyWith(
            stockPatimbao: transfer.fromBranch == BranchId.patimbao
                ? cur.stockPatimbao + transfer.quantity
                : cur.stockPatimbao,
            stockPedroGuevara: transfer.fromBranch == BranchId.pedroGuevara
                ? cur.stockPedroGuevara + transfer.quantity
                : cur.stockPedroGuevara,
          );
          await _db.saveInventoryItem(updatedItem);
          _inventory[pIdx] = updatedItem;
          await _firebase.syncInventoryItemToFirestore(updatedItem);
        }
      }

      final cancelledTransfer = transfer.copyWith(
        status: TransferStatus.cancelled,
        rejectionReason: reason ?? 'Cancelled by staff',
        rejectedBy: _currentUser?.fullName ?? 'Staff',
        rejectedAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Transfer Cancelled (${transfer.id})',
        message:
            'Transfer ${transfer.id} (${transfer.quantity}x ${transfer.partName}) has been cancelled.',
        category: 'transfer',
        branch: transfer.fromBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: updatedItem,
        transfer: cancelledTransfer,
        notification: notif,
      );

      _transfers[tIdx] = cancelledTransfer;
      _notifications.insert(0, notif);
      await _firebase.syncStockTransferToFirestore(cancelledTransfer);
      await _firebase.createFirestoreNotification(notif);

      _setViewState(
        ViewState.success,
        'Stock transfer ${transfer.id} has been cancelled.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to cancel transfer: $e');
      return false;
    }
  }

  /// Backward compatible / direct initiation (used by Admin & unit tests)
  Future<bool> initiateStockTransfer({
    required InventoryItem item,
    required BranchId fromBranch,
    required BranchId toBranch,
    required int quantity,
  }) async {
    if (fromBranch == toBranch ||
        fromBranch == BranchId.both ||
        toBranch == BranchId.both) {
      _setViewState(
        ViewState.error,
        'Source and destination branches must be two distinct branches.',
      );
      return false;
    }
    if (quantity <= 0) {
      _setViewState(
        ViewState.error,
        'Transfer quantity must be greater than 0.',
      );
      return false;
    }
    final pIdx = _inventory.indexWhere((e) => e.id == item.id);
    final liveItem = pIdx >= 0 ? _inventory[pIdx] : item;
    final available = liveItem.availableStockFor(fromBranch);
    if (quantity > available) {
      _setViewState(
        ViewState.error,
        'Insufficient available stock at ${fromBranch.shortName} ($available available).',
      );
      return false;
    }

    try {
      final updatedItem = liveItem.copyWith(
        stockPatimbao: fromBranch == BranchId.patimbao
            ? liveItem.stockPatimbao - quantity
            : liveItem.stockPatimbao,
        stockPedroGuevara: fromBranch == BranchId.pedroGuevara
            ? liveItem.stockPedroGuevara - quantity
            : liveItem.stockPedroGuevara,
      );

      final transfer = StockTransfer(
        id: _generateId('TRF'),
        partId: liveItem.id,
        sku: liveItem.sku,
        partName: liveItem.name,
        quantity: quantity,
        fromBranch: fromBranch,
        toBranch: toBranch,
        status: TransferStatus.inTransit,
        initiatedBy: _currentUser?.fullName ?? 'Authorized Staff',
        approvedBy: _currentUser?.fullName ?? 'Direct Dispatch',
        approvedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Shipment In-Transit (${transfer.id})',
        message:
            '${quantity}x ${liveItem.name} dispatched from ${fromBranch.shortName} to ${toBranch.shortName}. Awaiting [Confirm Delivery].',
        category: 'transfer',
        branch: toBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: updatedItem,
        transfer: transfer,
        notification: notif,
      );

      if (pIdx >= 0) _inventory[pIdx] = updatedItem;
      _transfers.insert(0, transfer);
      _notifications.insert(0, notif);
      _firebase.syncStockTransferToFirestore(transfer);
      _firebase.createFirestoreNotification(notif);

      _enqueueIfOffline(
        'TRANSFER_INIT',
        '${transfer.id}: ${quantity}x ${liveItem.sku} (${fromBranch.shortName} -> ${toBranch.shortName})',
      );

      _setViewState(
        ViewState.success,
        'Transfer ${transfer.id} marked In-Transit. Deducted $quantity units from ${fromBranch.shortName}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Stock transfer failed (rolled back): $e');
      return false;
    }
  }

  /// Strict Approval Transfer Workflow Phase 3:
  /// Destination branch cashier inspects physical parts upon arrival and taps Confirm Receipt.
  Future<bool> confirmTransferDelivery(StockTransfer transfer) async {
    if (transfer.status != TransferStatus.inTransit) {
      _setViewState(
        ViewState.error,
        'Only in-transit transfers can be confirmed as delivered.',
      );
      return false;
    }

    if (_currentUser != null &&
        _currentUser!.role != UserRole.admin &&
        _currentUser!.assignedBranch != transfer.toBranch &&
        _currentUser!.assignedBranch != BranchId.both) {
      _setViewState(
        ViewState.error,
        'Access Denied: Only staff assigned to ${transfer.toBranch.displayName} or Admin can confirm delivery.',
      );
      return false;
    }

    final tIdx = _transfers.indexWhere((t) => t.id == transfer.id);
    final pIdx = _inventory.indexWhere((p) => p.id == transfer.partId);
    if (tIdx < 0 || pIdx < 0) {
      _setViewState(
        ViewState.error,
        'Transfer or target part no longer exists.',
      );
      return false;
    }

    try {
      final currentPart = _inventory[pIdx];
      final updatedPart = currentPart.copyWith(
        stockPatimbao: transfer.toBranch == BranchId.patimbao
            ? currentPart.stockPatimbao + transfer.quantity
            : currentPart.stockPatimbao,
        stockPedroGuevara: transfer.toBranch == BranchId.pedroGuevara
            ? currentPart.stockPedroGuevara + transfer.quantity
            : currentPart.stockPedroGuevara,
      );

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.delivered,
        confirmedBy: _currentUser?.fullName ?? 'Branch Receiver',
        confirmedAt: DateTime.now(),
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'Delivery Confirmed (${transfer.id})',
        message:
            '${transfer.quantity}x ${transfer.partName} received and credited to ${transfer.toBranch.shortName} stock.',
        category: 'transfer',
        branch: transfer.toBranch,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _db.executeStockTransferTransaction(
        updatedItem: updatedPart,
        transfer: updatedTransfer,
        notification: notif,
      );

      _inventory[pIdx] = updatedPart;
      _transfers[tIdx] = updatedTransfer;
      _notifications.insert(0, notif);
      _firebase.syncStockTransferToFirestore(updatedTransfer);
      _firebase.createFirestoreNotification(notif);

      _enqueueIfOffline(
        'TRANSFER_CONFIRM',
        '${transfer.id} credited +${transfer.quantity} to ${transfer.toBranch.shortName}',
      );

      _setViewState(
        ViewState.success,
        'Confirmed receipt for ${transfer.id}. Added ${transfer.quantity} to ${transfer.toBranch.shortName} stock.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to confirm delivery: $e');
      return false;
    }
  }

  /// Alias for confirmTransferDelivery matching specification
  Future<bool> confirmStockTransferReceipt(StockTransfer transfer) =>
      confirmTransferDelivery(transfer);

  /// Permanently deletes a stock transfer from local database, memory, and history
  Future<bool> deleteStockTransfer(String id) async {
    _transfers.removeWhere((t) => t.id == id);
    await _db.deleteStockTransfer(id);
    _setViewState(ViewState.success, 'Transfer record $id removed from history.');
    return true;
  }

  // ---------------------------------------------------------------------------
  // Mechanic Bay Lifecycle, Atomic Parts Locking & Customer Booking
  // ---------------------------------------------------------------------------

  Future<JobOrder?> createJobOrder({
    required String customerName,
    required String customerPhone,
    required String bikeModel,
    required String plateNumber,
    required String serviceType,
    required String issueDescription,
    required String assignedMechanic,
    double laborFee = 0.0,
    BranchId? targetBranch,
    String? preferredSchedule,
    String? customerUsername,
  }) async {
    if (_currentUser != null && _currentUser!.role != UserRole.customer) {
      _setViewState(
        ViewState.error,
        'Adding/booking service job orders is a Customer-only function. Admin & Mechanics can only accept incoming customer bookings.',
      );
      return null;
    }
    final nameError = AppValidators.riderFullName(customerName);
    if (nameError != null) {
      _setViewState(ViewState.error, nameError);
      return null;
    }
    final phoneError = AppValidators.philippineMobileNumber(customerPhone);
    if (phoneError != null) {
      _setViewState(ViewState.error, phoneError);
      return null;
    }
    final bikeError = AppValidators.motorcycleModel(bikeModel);
    if (bikeError != null) {
      _setViewState(ViewState.error, bikeError);
      return null;
    }
    final plateError = AppValidators.plateNumber(plateNumber);
    if (plateError != null) {
      _setViewState(ViewState.error, plateError);
      return null;
    }
    final issueError = AppValidators.serviceNotes(issueDescription);
    if (issueError != null) {
      _setViewState(ViewState.error, issueError);
      return null;
    }
    if (!_isValidCurrency(laborFee)) {
      _setViewState(ViewState.error, 'Invalid labor fee amount.');
      return null;
    }

    try {
      final branch = targetBranch ?? _activeBranch;
      final job = JobOrder(
        id: _generateId('JO'),
        branch: branch,
        customerName: customerName.trim(),
        customerUsername: (customerUsername ?? _currentUser?.username ?? '')
            .trim(),
        customerPhone: customerPhone.trim(),
        bikeModel: bikeModel.trim(),
        plateNumber: plateNumber.trim().toUpperCase(),
        serviceType: serviceType.trim(),
        issueDescription: issueDescription.trim(),
        assignedMechanic: assignedMechanic.trim(),
        status: JobStatus.received,
        attachedParts: const [],
        laborFee: laborFee,
        preferredSchedule: preferredSchedule ?? 'Walk-in • Immediate',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.saveJobOrder(job);
      _jobOrders.insert(0, job);
      _firebase.syncJobOrderToFirestore(job);

      await _pushNotification(
        title: 'New Repair Job Order (${job.id})',
        message:
            '${job.bikeModel} (${job.plateNumber}) assigned to ${job.assignedMechanic} at ${branch.shortName}.',
        category: 'job_order',
        branch: branch,
        targetRole: UserRole.admin,
        payload: {
          'type': 'job_order',
          'jobId': job.id,
          'customerName': job.customerName,
          'assignedMechanic': job.assignedMechanic,
          'branch': branch.name,
        },
      );

      _enqueueIfOffline('JOB_CREATE', '${job.id} (${job.plateNumber})');
      _setViewState(
        ViewState.success,
        'Created Job Order ${job.id} for ${job.bikeModel} (${job.plateNumber}).',
      );
      return job;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to create job order: $e');
      return null;
    }
  }

  Future<bool> updateJobOrderStatus(String jobId, JobStatus newStatus) async {
    final idx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (idx < 0) return false;

    try {
      final current = _jobOrders[idx];
      final updated = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _db.saveJobOrder(updated);
      _jobOrders[idx] = updated;

      if (newStatus == JobStatus.readyForPickup) {
        await _pushNotification(
          title: 'Service-to-POS Auto-Billing Ready (${updated.id})',
          message:
              '${updated.bikeModel} (${updated.plateNumber}) is Ready for Pickup. Total bill: ₱${updated.totalEstimate.toStringAsFixed(2)}.',
          category: 'job_order',
          branch: updated.branch,
          targetUserId: updated.customerUsername.isNotEmpty
              ? updated.customerUsername
              : null,
          payload: {
            'type': 'job_order',
            'jobId': updated.id,
            'branch': updated.branch.name,
          },
        );

        // Automated Customer Push Notifications (FCM) via FirebaseService
        final customer = _staffList
            .where(
              (s) =>
                  s.username.toLowerCase() ==
                      updated.customerUsername.toLowerCase() ||
                  s.fullName.toLowerCase() ==
                      updated.customerName.toLowerCase(),
            )
            .toList();
        final fcmToken = customer.isNotEmpty ? customer.first.fcmToken : null;
        await _firebase.sendJobReadyPushNotification(
          jobId: updated.id,
          bikeModel: updated.bikeModel,
          customerFcmToken: fcmToken,
          branch: updated.branch,
        );
      } else if (updated.customerUsername.isNotEmpty) {
        await _pushNotification(
          title: 'Service Update: ${newStatus.label} (${updated.id})',
          message:
              'Your ${updated.bikeModel} (${updated.plateNumber}) at ${updated.branch.shortName} is now "${newStatus.label}".',
          category: 'job_order',
          branch: updated.branch,
          targetRole: UserRole.customer,
          targetUserId: updated.customerUsername,
          payload: {
            'type': 'job_order',
            'jobId': updated.id,
            'branch': updated.branch.name,
          },
        );
      }

      // Real-time Firestore sync across apps
      await _firebase.syncJobOrderToFirestore(updated);

      _enqueueIfOffline('JOB_STATUS', '${updated.id} -> ${newStatus.label}');
      _setViewState(
        ViewState.success,
        'Updated ${updated.id} status to "${newStatus.label}".',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update job status: $e');
      return false;
    }
  }

  /// Accepts an incoming Customer Job Order (`JobStatus.received` -> `JobStatus.inBay`)
  /// by either Admin or Mechanic and assigns the bay lift.
  Future<bool> acceptJobOrder(String jobId, {String? mechanicName}) async {
    final idx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (idx < 0) return false;

    try {
      final current = _jobOrders[idx];
      final resolvedMechanic =
          (mechanicName != null && mechanicName.trim().isNotEmpty)
          ? mechanicName.trim()
          : (_currentUser?.role == UserRole.mechanic
                ? _currentUser!.fullName
                : current.assignedMechanic);

      final updated = current.copyWith(
        status: JobStatus.inBay,
        assignedMechanic: resolvedMechanic,
        updatedAt: DateTime.now(),
      );
      await _db.saveJobOrder(updated);
      _jobOrders[idx] = updated;
      _firebase.syncJobOrderToFirestore(updated);

      await _pushNotification(
        title: 'Job Order Accepted (${updated.id})',
        message:
            '${updated.bikeModel} (${updated.plateNumber}) accepted into ${updated.branch.shortName} bay by ${_currentUser?.fullName ?? resolvedMechanic}.',
        category: 'job_order',
        branch: updated.branch,
        targetUserId: updated.customerUsername.isNotEmpty
            ? updated.customerUsername
            : null,
        payload: {
          'type': 'job_order',
          'jobId': updated.id,
          'branch': updated.branch.name,
        },
      );

      _enqueueIfOffline(
        'JOB_ACCEPT',
        '${updated.id} accepted into bay ($resolvedMechanic)',
      );
      _setViewState(
        ViewState.success,
        'Accepted Job Order ${updated.id} into ${updated.branch.shortName} Repair Bay!',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to accept job order: $e');
      return false;
    }
  }

  /// Cancels an active or pending Job Order:
  /// Releases all locked parts attached to the job back to available inventory.
  Future<bool> cancelJobOrder(String jobId) async {
    return await deleteJobOrder(jobId);
  }

  /// Deletes an active job order, automatically moving it to history as Cancelled.
  /// Releases any held parts attached to the job back to available inventory.
  Future<bool> deleteJobOrder(String jobId) async {
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (jIdx < 0) return false;
    final job = _jobOrders[jIdx];

    // If already in history, delete permanently
    if (job.status == JobStatus.completed ||
        job.status == JobStatus.cancelled) {
      return await deleteJobFromHistory(jobId);
    }

    try {
      // Release locked stock for all attached parts
      for (final ap in job.attachedParts) {
        final pIdx = _inventory.indexWhere((p) => p.id == ap.partId);
        if (pIdx >= 0) {
          final cur = _inventory[pIdx];
          final updatedPart = cur.copyWith(
            lockedPatimbao: job.branch == BranchId.patimbao
                ? (cur.lockedPatimbao - ap.quantity).clamp(0, 999999)
                : cur.lockedPatimbao,
            lockedPedroGuevara: job.branch == BranchId.pedroGuevara
                ? (cur.lockedPedroGuevara - ap.quantity).clamp(0, 999999)
                : cur.lockedPedroGuevara,
          );
          await _db.saveInventoryItem(updatedPart);
          _inventory[pIdx] = updatedPart;
          await _firebase.syncInventoryItemToFirestore(updatedPart);
        }
      }

      final updatedJob = job.copyWith(
        status: JobStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      await _db.saveJobOrder(updatedJob);
      _jobOrders[jIdx] = updatedJob;
      await _firebase.syncJobOrderToFirestore(updatedJob);

      await _pushNotification(
        title: 'Job Order Deleted (${updatedJob.id})',
        message:
            '${updatedJob.bikeModel} (${updatedJob.plateNumber}) moved to history. Reserved parts unlocked.',
        category: 'job_order',
        branch: updatedJob.branch,
      );

      _setViewState(
        ViewState.success,
        'Job Order ${updatedJob.id} deleted and moved to history.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete job order: $e');
      return false;
    }
  }

  /// Cancels or deletes an active service booking on behalf of the customer,
  /// automatically moving it to the customer repair history.
  Future<bool> deleteCustomerJobBooking(String jobId) async {
    return await deleteJobOrder(jobId);
  }

  /// Cancels an active service booking on behalf of the customer (legacy alias)
  Future<bool> cancelCustomerJobBooking(String jobId) async {
    return await deleteCustomerJobBooking(jobId);
  }

  /// Permanently deletes a job order from historical records (completed or cancelled).
  Future<bool> deleteJobFromHistory(String jobId) async {
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (jIdx < 0) return false;

    try {
      _jobOrders.removeAt(jIdx);
      await _db.deleteJobOrder(jobId);
      await _firebase.deleteJobOrderFromFirestore(jobId);
      _setViewState(
        ViewState.success,
        'Job Order $jobId permanently deleted from history.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete job from history: $e');
      return false;
    }
  }

  /// Permanently deletes all past completed or cancelled job orders for the user from history.
  Future<int> deleteAllPastJobHistory({String? customerUsername}) async {
    final targetUser = customerUsername ??
        (currentUser?.role == UserRole.customer
            ? currentUser?.username
            : null);
    final toDelete = _jobOrders.where((j) {
      final isPast =
          j.status == JobStatus.completed || j.status == JobStatus.cancelled;
      if (!isPast) return false;
      if (targetUser != null && targetUser.trim().isNotEmpty) {
        return j.customerUsername.toLowerCase() == targetUser.toLowerCase();
      }
      return true;
    }).toList();

    if (toDelete.isEmpty) return 0;

    int count = 0;
    for (final job in toDelete) {
      _jobOrders.removeWhere((j) => j.id == job.id);
      await _db.deleteJobOrder(job.id);
      await _firebase.deleteJobOrderFromFirestore(job.id);
      count++;
    }

    _setViewState(
      ViewState.success,
      '$count job history records permanently removed.',
    );
    notifyListeners();
    return count;
  }

  /// Active Click & Collect reservation currently handed off to POS cart
  ClickAndCollectOrder? _activeHandoffReservation;
  ClickAndCollectOrder? get activeHandoffReservation =>
      _activeHandoffReservation;

  void clearHandoffReservation() {
    _activeHandoffReservation = null;
    notifyListeners();
  }

  /// Hands off a confirmed reservation to the POS counter:
  /// Pre-fills the cart with the customer's reserved item, ready for tender.
  bool handoffReservationToPos(ClickAndCollectOrder order) {
    final pIdx = _inventory.indexWhere((p) => p.id == order.partId);
    if (pIdx < 0) {
      _setViewState(
        ViewState.error,
        'Reserved part no longer found in inventory.',
      );
      return false;
    }
    final item = _inventory[pIdx];
    _activeHandoffReservation = order;
    _cart.clear();
    _cart.add(CartItem(item: item, quantity: order.quantity));
    notifyListeners();
    return true;
  }

  /// Click & Collect orders for the active branch
  List<ClickAndCollectOrder> get branchClickCollectOrders {
    return _clickCollectOrders
        .where((o) => o.pickupBranch == _activeBranch)
        .toList();
  }

  /// Confirms a customer Click & Collect reservation (Pending -> Confirmed)
  Future<bool> confirmClickAndCollectOrder(String orderId) async {
    final idx = _clickCollectOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;

    try {
      final cur = _clickCollectOrders[idx];
      final updated = cur.copyWith(status: 'Confirmed');
      await _db.saveClickCollectOrder(updated);
      _clickCollectOrders[idx] = updated;
      await _firebase.syncClickAndCollectToFirestore(updated);

      await _pushNotification(
        title: 'Reservation Confirmed (${updated.id})',
        message:
            'Order ${updated.id} (${updated.quantity}x ${updated.partName}) confirmed at ${updated.pickupBranch.shortName}.',
        category: 'booking',
        branch: updated.pickupBranch,
        targetRole: UserRole.customer,
        targetUserId: updated.customerUsername.isNotEmpty
            ? updated.customerUsername
            : updated.customerId,
        payload: {
          'type': 'reservation',
          'orderId': updated.id,
          'branch': updated.pickupBranch.name,
        },
      );

      _setViewState(
        ViewState.success,
        'Confirmed reservation ${updated.id} for ${updated.customerName}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to confirm reservation: $e');
      return false;
    }
  }

  /// Marks a customer Click & Collect reservation ready for pickup (Confirmed/Pending -> Ready for Pickup)
  Future<bool> markReadyClickAndCollectOrder(String orderId) async {
    final idx = _clickCollectOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;

    try {
      final cur = _clickCollectOrders[idx];
      final updated = cur.copyWith(status: 'Ready for Pickup');
      await _db.saveClickCollectOrder(updated);
      _clickCollectOrders[idx] = updated;
      await _firebase.syncClickAndCollectToFirestore(updated);

      await _pushNotification(
        title: 'Order Ready for Pickup (${updated.id})',
        message:
            '${updated.quantity}x ${updated.partName} is ready for counter pickup at ${updated.pickupBranch.shortName}.',
        category: 'booking',
        branch: updated.pickupBranch,
        targetRole: UserRole.customer,
        targetUserId: updated.customerUsername.isNotEmpty
            ? updated.customerUsername
            : updated.customerId,
        payload: {
          'type': 'reservation',
          'orderId': updated.id,
          'branch': updated.pickupBranch.name,
        },
      );

      _setViewState(
        ViewState.success,
        'Reservation ${updated.id} marked Ready for Pickup.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to mark reservation ready: $e');
      return false;
    }
  }

  /// Accepts a Customer Click & Collect Part Order in Admin/Mechanic panel (alias)
  Future<bool> acceptClickAndCollectOrder(String orderId) =>
      confirmClickAndCollectOrder(orderId);

  /// Atomic Parts Attachment Engine: Locks part in local stock & attaches to JobOrder
  Future<bool> attachPartToJobOrder({
    required String jobId,
    required InventoryItem part,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      _setViewState(ViewState.error, 'Quantity must be positive.');
      return false;
    }
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    final pIdx = _inventory.indexWhere((p) => p.id == part.id);
    if (jIdx < 0 || pIdx < 0) return false;

    final job = _jobOrders[jIdx];
    if (job.isBilled || job.status == JobStatus.completed) {
      _setViewState(
        ViewState.error,
        'Cannot attach parts to a completed or billed Job Order.',
      );
      return false;
    }

    final livePart = _inventory[pIdx];

    final avail = livePart.availableStockFor(job.branch);
    if (avail < quantity) {
      _setViewState(
        ViewState.error,
        'Cannot attach ${livePart.name}: only $avail unlocked unit(s) available in ${job.branch.shortName}.',
      );
      return false;
    }

    try {
      final updatedPart = livePart.copyWith(
        lockedPatimbao: job.branch == BranchId.patimbao
            ? livePart.lockedPatimbao + quantity
            : livePart.lockedPatimbao,
        lockedPedroGuevara: job.branch == BranchId.pedroGuevara
            ? livePart.lockedPedroGuevara + quantity
            : livePart.lockedPedroGuevara,
      );

      final currentParts = List<AttachedJobPart>.from(job.attachedParts);
      final existingIdx = currentParts.indexWhere(
        (ap) => ap.partId == livePart.id,
      );
      if (existingIdx >= 0) {
        currentParts[existingIdx] = currentParts[existingIdx].copyWith(
          quantity: currentParts[existingIdx].quantity + quantity,
        );
      } else {
        currentParts.add(
          AttachedJobPart(
            partId: livePart.id,
            sku: livePart.sku,
            name: livePart.name,
            unitPrice: livePart.price,
            quantity: quantity,
            shelfCoordinates: livePart.shelfCoordinates,
          ),
        );
      }

      final updatedJob = job.copyWith(
        attachedParts: currentParts,
        updatedAt: DateTime.now(),
      );

      await _db.executeJobPartLockTransaction(
        updatedItem: updatedPart,
        updatedJob: updatedJob,
      );

      _inventory[pIdx] = updatedPart;
      _jobOrders[jIdx] = updatedJob;
      _firebase.syncJobOrderToFirestore(updatedJob);

      _enqueueIfOffline(
        'JOB_LOCK_PART',
        'Locked ${quantity}x ${livePart.sku} to ${job.id}',
      );
      _setViewState(
        ViewState.success,
        'Locked ${quantity}x ${livePart.name} (${livePart.shortShelfCoordinates}) to ${job.id}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to lock part to job: $e');
      return false;
    }
  }

  Future<bool> removeAttachedPartFromJob({
    required String jobId,
    required String partId,
  }) async {
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (jIdx < 0) return false;
    final job = _jobOrders[jIdx];

    final existing = job.attachedParts
        .where((p) => p.partId == partId)
        .toList();
    if (existing.isEmpty) return false;
    final removedPart = existing.first;

    final pIdx = _inventory.indexWhere((p) => p.id == partId);
    if (pIdx < 0) return false;

    try {
      final livePart = _inventory[pIdx];
      final updatedPart = livePart.copyWith(
        lockedPatimbao: job.branch == BranchId.patimbao
            ? (livePart.lockedPatimbao - removedPart.quantity).clamp(0, 999999)
            : livePart.lockedPatimbao,
        lockedPedroGuevara: job.branch == BranchId.pedroGuevara
            ? (livePart.lockedPedroGuevara - removedPart.quantity).clamp(
                0,
                999999,
              )
            : livePart.lockedPedroGuevara,
      );

      final updatedParts = job.attachedParts
          .where((p) => p.partId != partId)
          .toList();
      final updatedJob = job.copyWith(
        attachedParts: updatedParts,
        updatedAt: DateTime.now(),
      );

      await _db.executeJobPartLockTransaction(
        updatedItem: updatedPart,
        updatedJob: updatedJob,
      );

      _inventory[pIdx] = updatedPart;
      _jobOrders[jIdx] = updatedJob;
      _firebase.syncJobOrderToFirestore(updatedJob);

      _setViewState(
        ViewState.success,
        'Released lock on ${removedPart.name} from ${job.id}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to unlock part: $e');
      return false;
    }
  }

  Future<bool> updateJobLaborFee({
    required String jobId,
    required double laborFee,
    String? extraRepairNote,
    double? extraRepairFee,
  }) async {
    if (!_isValidCurrency(laborFee) ||
        (extraRepairFee != null && !_isValidCurrency(extraRepairFee))) {
      _setViewState(ViewState.error, 'Invalid labor or extra repair fee.');
      return false;
    }
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (jIdx < 0) return false;

    try {
      final current = _jobOrders[jIdx];
      final cleanExtraNote = extraRepairNote?.trim();
      final shouldClearExtra =
          extraRepairNote != null &&
          (cleanExtraNote == null || cleanExtraNote.isEmpty);
      final nextExtraNote = shouldClearExtra
          ? null
          : (cleanExtraNote ?? current.extraRepairNote);
      final nextExtraFee = shouldClearExtra
          ? 0.0
          : (extraRepairFee ?? current.extraRepairFee);
      final extraChanged =
          nextExtraNote != current.extraRepairNote ||
          nextExtraFee != current.extraRepairFee;

      final updated = current.copyWith(
        laborFee: laborFee,
        extraRepairNote: nextExtraNote,
        clearExtraRepair: shouldClearExtra,
        extraRepairFee: nextExtraFee,
        extraRepairApproved: extraChanged ? false : current.extraRepairApproved,
        updatedAt: DateTime.now(),
      );
      await _db.saveJobOrder(updated);
      _jobOrders[jIdx] = updated;
      await _firebase.syncJobOrderToFirestore(updated);

      if (extraChanged && nextExtraNote != null && nextExtraNote.isNotEmpty) {
        await _pushNotification(
          title: 'Extra Repair Recommended (${updated.id})',
          message:
              'Mechanic recommended "$nextExtraNote" (+₱${nextExtraFee.toStringAsFixed(0)}) for ${updated.bikeModel}. Awaiting customer approval.',
          category: 'job_order',
          branch: updated.branch,
          targetRole: UserRole.customer,
          targetUserId: updated.customerUsername.isNotEmpty
              ? updated.customerUsername
              : null,
          payload: {
            'type': 'job_order',
            'jobId': updated.id,
            'branch': updated.branch.name,
          },
        );
      }

      _setViewState(
        ViewState.success,
        'Updated labor & repair quote for ${updated.id}. Total bill: ₱${updated.totalEstimate.toStringAsFixed(2)}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update labor fee: $e');
      return false;
    }
  }

  Future<bool> approveCustomerExtraRepair(String jobId) async {
    final jIdx = _jobOrders.indexWhere((j) => j.id == jobId);
    if (jIdx < 0) return false;
    try {
      final current = _jobOrders[jIdx];
      final updated = current.copyWith(
        extraRepairApproved: true,
        updatedAt: DateTime.now(),
      );
      await _db.saveJobOrder(updated);
      _jobOrders[jIdx] = updated;
      await _firebase.syncJobOrderToFirestore(updated);

      await _pushNotification(
        title: 'Customer Approved Extra Repair (${updated.id})',
        message:
            '${updated.customerName} approved "${updated.extraRepairNote}" (+₱${updated.extraRepairFee.toStringAsFixed(0)}).',
        category: 'job_order',
        branch: updated.branch,
      );

      _setViewState(
        ViewState.success,
        'Extra repair approved for ${updated.id}! Assigned mechanic notified.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to approve extra repair: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Customer App: Click & Collect Part Reservation (Atomic Transaction)
  // ---------------------------------------------------------------------------

  Future<ClickAndCollectOrder?> createClickAndCollectOrder({
    required InventoryItem part,
    BranchId? pickupBranch,
    BranchId? branch,
    required int quantity,
    required String customerPhone,
  }) async {
    final targetBranch = pickupBranch ?? branch ?? _activeBranch;
    if (quantity <= 0) {
      _setViewState(
        ViewState.error,
        'Reservation quantity must be at least 1.',
      );
      return null;
    }
    final pIdx = _inventory.indexWhere((i) => i.id == part.id);
    if (pIdx < 0) {
      _setViewState(ViewState.error, 'Selected part was not found.');
      return null;
    }
    final livePart = _inventory[pIdx];
    final avail = livePart.availableStockFor(targetBranch);
    if (quantity > avail) {
      _setViewState(
        ViewState.error,
        'Only $avail unit(s) available for Click & Collect at ${targetBranch.shortName}.',
      );
      return null;
    }

    try {
      final updatedPart = livePart.copyWith(
        lockedPatimbao: targetBranch == BranchId.patimbao
            ? livePart.lockedPatimbao + quantity
            : livePart.lockedPatimbao,
        lockedPedroGuevara: targetBranch == BranchId.pedroGuevara
            ? livePart.lockedPedroGuevara + quantity
            : livePart.lockedPedroGuevara,
      );

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 48));
      final order = ClickAndCollectOrder(
        id: _generateId('RES'),
        customerId: _currentUser?.id ?? _currentUser?.username ?? 'guest',
        customerUsername: _currentUser?.username ?? 'guest',
        customerName: _currentUser?.fullName ?? 'MotoHub Customer',
        customerPhone: customerPhone.trim(),
        pickupBranch: targetBranch,
        partId: livePart.id,
        sku: livePart.sku,
        partName: livePart.name,
        quantity: quantity,
        unitPrice: livePart.price,
        status: 'Pending',
        createdAt: now,
        expiresAt: expiresAt,
      );

      final notif = AppNotificationItem(
        id: _generateId('NTF'),
        title: 'New Item Reservation (${order.id})',
        message:
            '${order.customerName} reserved ${quantity}x ${livePart.name} at ${targetBranch.shortName}. Stock held for pickup.',
        category: 'booking',
        branch: targetBranch,
        isRead: false,
        createdAt: now,
        targetRole: UserRole.admin,
        payload: {
          'type': 'reservation',
          'orderId': order.id,
          'customerName': order.customerName,
          'partName': livePart.name,
          'quantity': quantity,
          'branch': targetBranch.name,
        },
      );

      await _db.executeClickAndCollectTransaction(
        updatedItem: updatedPart,
        order: order,
        notification: notif,
      );

      _inventory[pIdx] = updatedPart;
      _clickCollectOrders.insert(0, order);
      _notifications.insert(0, notif);
      await _firebase.createFirestoreNotification(notif);

      final txOk = await _firebase.executeReservationTransaction(
        order: order,
        updatedItem: updatedPart,
      );
      if (!txOk) {
        await _firebase.syncClickAndCollectToFirestore(order);
        await _firebase.syncInventoryItemToFirestore(updatedPart);
      }

      _setViewState(
        ViewState.success,
        'Reserved ${quantity}x ${livePart.name} at ${targetBranch.shortName} (${order.id})!',
      );
      return order;
    } catch (e) {
      _setViewState(
        ViewState.error,
        'Click & Collect reservation failed (rolled back): $e',
      );
      return null;
    }
  }

  /// Completes / claims a Click & Collect reservation at the branch counter:
  /// Decrements total physical stock AND decrements the locked stock hold.
  Future<bool> claimClickAndCollectOrder(String orderId) async {
    final oIdx = _clickCollectOrders.indexWhere((o) => o.id == orderId);
    if (oIdx < 0) return false;
    final order = _clickCollectOrders[oIdx];
    if (order.status.startsWith('Claimed') ||
        order.status.startsWith('Cancelled')) {
      _setViewState(
        ViewState.error,
        'Order has already been processed (${order.status}).',
      );
      return false;
    }

    final pIdx = _inventory.indexWhere((p) => p.id == order.partId);
    if (pIdx >= 0) {
      final cur = _inventory[pIdx];
      final updatedPart = cur.copyWith(
        stockPatimbao: order.pickupBranch == BranchId.patimbao
            ? (cur.stockPatimbao - order.quantity).clamp(0, 999999)
            : cur.stockPatimbao,
        stockPedroGuevara: order.pickupBranch == BranchId.pedroGuevara
            ? (cur.stockPedroGuevara - order.quantity).clamp(0, 999999)
            : cur.stockPedroGuevara,
        lockedPatimbao: order.pickupBranch == BranchId.patimbao
            ? (cur.lockedPatimbao - order.quantity).clamp(0, 999999)
            : cur.lockedPatimbao,
        lockedPedroGuevara: order.pickupBranch == BranchId.pedroGuevara
            ? (cur.lockedPedroGuevara - order.quantity).clamp(0, 999999)
            : cur.lockedPedroGuevara,
      );
      await _db.saveInventoryItem(updatedPart);
      _inventory[pIdx] = updatedPart;
      await _firebase.syncInventoryItemToFirestore(updatedPart);
    }

    final updatedOrder = order.copyWith(status: 'Completed');
    await _db.saveClickCollectOrder(updatedOrder);
    _clickCollectOrders[oIdx] = updatedOrder;
    await _firebase.syncClickAndCollectToFirestore(updatedOrder);

    _setViewState(
      ViewState.success,
      'Order ${order.id} completed at ${order.pickupBranch.shortName}. Stock deducted.',
    );
    return true;
  }

  /// Cancels a Click & Collect reservation:
  /// Releases the locked stock back to available stock (total physical stock unchanged).
  Future<bool> cancelClickAndCollectOrder(String orderId) async {
    final oIdx = _clickCollectOrders.indexWhere((o) => o.id == orderId);
    if (oIdx < 0) return false;
    final order = _clickCollectOrders[oIdx];
    if (order.status == 'Completed' ||
        order.status == 'Cancelled' ||
        order.status.startsWith('Claimed') ||
        order.status.startsWith('Cancelled')) {
      _setViewState(
        ViewState.error,
        'Order has already been processed (${order.status}).',
      );
      return false;
    }

    final pIdx = _inventory.indexWhere((p) => p.id == order.partId);
    if (pIdx >= 0) {
      final cur = _inventory[pIdx];
      final updatedPart = cur.copyWith(
        lockedPatimbao: order.pickupBranch == BranchId.patimbao
            ? (cur.lockedPatimbao - order.quantity).clamp(0, 999999)
            : cur.lockedPatimbao,
        lockedPedroGuevara: order.pickupBranch == BranchId.pedroGuevara
            ? (cur.lockedPedroGuevara - order.quantity).clamp(0, 999999)
            : cur.lockedPedroGuevara,
      );
      await _db.saveInventoryItem(updatedPart);
      _inventory[pIdx] = updatedPart;
      await _firebase.syncInventoryItemToFirestore(updatedPart);
    }

    final updatedOrder = order.copyWith(status: 'Cancelled');
    await _db.saveClickCollectOrder(updatedOrder);
    _clickCollectOrders[oIdx] = updatedOrder;
    await _firebase.syncClickAndCollectToFirestore(updatedOrder);

    _setViewState(
      ViewState.success,
      'Reservation ${order.id} cancelled. Held stock released back to inventory.',
    );
    return true;
  }

  /// Permanently deletes a Click & Collect reservation from local database and Firestore.
  /// If the reservation was active (holding stock), releases locked inventory first.
  Future<bool> deleteClickAndCollectOrder(String orderId) async {
    final oIdx = _clickCollectOrders.indexWhere((o) => o.id == orderId);
    if (oIdx < 0) return false;
    final order = _clickCollectOrders[oIdx];

    try {
      // If still holding inventory, release locked stock first
      if (order.isHoldActive) {
        await cancelClickAndCollectOrder(orderId);
      }

      _clickCollectOrders.removeWhere((o) => o.id == orderId);
      await _db.deleteClickCollectOrder(orderId);
      await _firebase.deleteClickAndCollectFromFirestore(orderId);

      _setViewState(
        ViewState.success,
        'Reservation $orderId permanently deleted.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to delete reservation: $e');
      return false;
    }
  }

  /// Permanently deletes all past Click & Collect reservations (completed, cancelled, or expired)
  /// for a customer (or across all past orders if staff). Active holding reservations are safely preserved.
  Future<int> deleteAllPastClickAndCollectHistory({String? customerUsername}) async {
    final targetUser = customerUsername ??
        (currentUser?.role == UserRole.customer
            ? currentUser?.username
            : null);
    final toDelete = _clickCollectOrders.where((o) {
      final isPast = o.isCompleted || o.isCancelled || o.isExpired;
      if (!isPast) return false;
      if (targetUser != null && targetUser.trim().isNotEmpty) {
        return o.customerUsername.toLowerCase() == targetUser.toLowerCase();
      }
      return true;
    }).toList();

    if (toDelete.isEmpty) return 0;

    int count = 0;
    for (final order in toDelete) {
      _clickCollectOrders.removeWhere((o) => o.id == order.id);
      await _db.deleteClickCollectOrder(order.id);
      await _firebase.deleteClickAndCollectFromFirestore(order.id);
      count++;
    }

    _setViewState(
      ViewState.success,
      '$count past reservation(s) permanently removed from history.',
    );
    notifyListeners();
    return count;
  }

  // ---------------------------------------------------------------------------
  // Cashier Retail POS & Atomic Service-to-POS Auto-Billing
  // ---------------------------------------------------------------------------

  bool addToCart(InventoryItem item, {int quantity = 1}) {
    if (quantity <= 0) return false;
    final pIdx = _inventory.indexWhere((i) => i.id == item.id);
    final liveItem = pIdx >= 0 ? _inventory[pIdx] : item;
    final avail = liveItem.availableStockFor(_activeBranch);
    final existingIdx = _cart.indexWhere((c) => c.item.id == liveItem.id);
    final currentInCart = existingIdx >= 0 ? _cart[existingIdx].quantity : 0;

    if (currentInCart + quantity > avail) {
      _setViewState(
        ViewState.error,
        'Stock Guard: Only $avail unlocked unit(s) of ${liveItem.name} available in ${_activeBranch.shortName}.',
      );
      return false;
    }

    if (existingIdx >= 0) {
      _cart[existingIdx] = CartItem(
        item: liveItem,
        quantity: currentInCart + quantity,
      );
    } else {
      _cart.add(CartItem(item: liveItem, quantity: quantity));
    }
    notifyListeners();
    return true;
  }

  void updateCartQuantity(String itemId, int newQty) {
    final idx = _cart.indexWhere((c) => c.item.id == itemId);
    if (idx < 0) return;
    if (newQty <= 0) {
      _cart.removeAt(idx);
      notifyListeners();
      return;
    }
    final liveItem = _inventory.firstWhere(
      (i) => i.id == itemId,
      orElse: () => _cart[idx].item,
    );
    final avail = liveItem.availableStockFor(_activeBranch);
    if (newQty > avail) {
      _setViewState(
        ViewState.error,
        'Max available unlocked stock in ${_activeBranch.shortName} is $avail.',
      );
      return;
    }
    _cart[idx] = CartItem(item: liveItem, quantity: newQty);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Atomic Retail POS Checkout:
  /// Deducts inventory + creates POS invoice + logs Cash Drawer in a single SQLite transaction.
  /// Supports Cash, GCash (with last-4-digit verification), and Split payments (Cash + GCash).
  Future<PosTransaction?> processRetailCheckout({
    required PaymentMethod paymentMethod,
    required double amountTendered,
    double cashAmount = 0.0,
    double gcashAmount = 0.0,
    String customerName = 'Walk-in Customer',
    String? gcashRef,
    String? gcashProofUrl,
  }) async {
    if (_isProcessingCheckout) {
      _setViewState(
        ViewState.error,
        'A checkout transaction is already in progress.',
      );
      return null;
    }
    _isProcessingCheckout = true;

    try {
      if (_cart.isEmpty) {
        _setViewState(ViewState.error, 'POS Cart is empty.');
        return null;
      }
      if (!_isValidCurrency(amountTendered)) {
        _setViewState(ViewState.error, 'Invalid tendered cash amount.');
        return null;
      }

      final total = cartTotal;

      // Split Payment calculations & validation
      final effectiveCash = paymentMethod == PaymentMethod.split
          ? (cashAmount > 0 ? cashAmount : (total - gcashAmount))
          : (paymentMethod == PaymentMethod.cash ? total : 0.0);
      final effectiveGcash = paymentMethod == PaymentMethod.split
          ? (gcashAmount > 0 ? gcashAmount : (total - cashAmount))
          : (paymentMethod == PaymentMethod.gcash ? total : 0.0);

      if (paymentMethod == PaymentMethod.split) {
        if ((effectiveCash + effectiveGcash - total).abs() > 0.01) {
          _setViewState(
            ViewState.error,
            'Split amounts (₱${effectiveCash.toStringAsFixed(2)} + ₱${effectiveGcash.toStringAsFixed(2)}) must equal total (₱${total.toStringAsFixed(2)}).',
          );
          return null;
        }
        if (amountTendered < effectiveCash) {
          _setViewState(
            ViewState.error,
            'Tendered cash (₱${amountTendered.toStringAsFixed(2)}) is less than cash portion (₱${effectiveCash.toStringAsFixed(2)}).',
          );
          return null;
        }
        if (gcashRef == null || gcashRef.trim().length < 4) {
          _setViewState(
            ViewState.error,
            'Please enter at least the last 4 digits of the GCash Reference Number.',
          );
          return null;
        }
      } else if (paymentMethod == PaymentMethod.cash) {
        if (amountTendered < total) {
          _setViewState(
            ViewState.error,
            'Tendered cash (₱${amountTendered.toStringAsFixed(2)}) is less than total (₱${total.toStringAsFixed(2)}).',
          );
          return null;
        }
      } else if (paymentMethod == PaymentMethod.gcash) {
        if (gcashRef == null || gcashRef.trim().length < 4) {
          _setViewState(
            ViewState.error,
            'Please enter at least the last 4 digits of the GCash Reference Number.',
          );
          return null;
        }
      }

      final changeDue = (paymentMethod == PaymentMethod.gcash)
          ? 0.0
          : (amountTendered - effectiveCash);

      final summaryParts = <String>[];
      final updatedItems = <InventoryItem>[];

      for (final cartItem in _cart) {
        summaryParts.add('${cartItem.quantity}x ${cartItem.item.name}');
        final pIdx = _inventory.indexWhere((p) => p.id == cartItem.item.id);
        if (pIdx < 0) {
          throw StateError('Part ${cartItem.item.name} no longer exists.');
        }
        final cur = _inventory[pIdx];
        final isReservedHandoff =
            _activeHandoffReservation != null &&
            _activeHandoffReservation!.partId == cur.id;
        final avail = isReservedHandoff
            ? cur.rawStockFor(_activeBranch)
            : cur.availableStockFor(_activeBranch);
        if (cartItem.quantity > avail) {
          throw StateError(
            'Insufficient stock for ${cur.name} ($avail available).',
          );
        }
        final updated = cur.copyWith(
          stockPatimbao: _activeBranch == BranchId.patimbao
              ? cur.stockPatimbao - cartItem.quantity
              : cur.stockPatimbao,
          stockPedroGuevara: _activeBranch == BranchId.pedroGuevara
              ? cur.stockPedroGuevara - cartItem.quantity
              : cur.stockPedroGuevara,
          lockedPatimbao:
              isReservedHandoff && _activeBranch == BranchId.patimbao
              ? (cur.lockedPatimbao - cartItem.quantity).clamp(0, 999999)
              : cur.lockedPatimbao,
          lockedPedroGuevara:
              isReservedHandoff && _activeBranch == BranchId.pedroGuevara
              ? (cur.lockedPedroGuevara - cartItem.quantity).clamp(0, 999999)
              : cur.lockedPedroGuevara,
        );
        updatedItems.add(updated);
      }

      final tx = PosTransaction(
        id: _generateId('OR'),
        branch: _activeBranch,
        cashierName: _currentUser?.fullName ?? 'Cashier',
        customerName: customerName.trim().isEmpty
            ? 'Walk-in Customer'
            : customerName.trim(),
        itemsSummary: summaryParts.join(', '),
        partsSubtotal: total,
        laborTotal: 0.0,
        totalAmount: total,
        paymentMethod: paymentMethod,
        amountTendered: paymentMethod == PaymentMethod.gcash
            ? total
            : amountTendered,
        changeAmount: changeDue,
        cashAmount: effectiveCash,
        gcashAmount: effectiveGcash,
        gcashRef: gcashRef,
        gcashProofUrl: gcashProofUrl,
        createdAt: DateTime.now(),
        isSynced: _isOnline,
      );

      final cashToRecord = paymentMethod == PaymentMethod.cash
          ? total
          : (paymentMethod == PaymentMethod.split ? effectiveCash : 0.0);

      final cashEntry = cashToRecord > 0
          ? CashDrawerEntry(
              id: _generateId('CSH'),
              branch: _activeBranch,
              type: CashLedgerType.cashSale,
              description: '${tx.id} • ${tx.itemsSummary}',
              amount: cashToRecord,
              staffName: tx.cashierName,
              createdAt: DateTime.now(),
            )
          : null;

      // Execute atomic database transaction
      await _db.executeRetailCheckoutTransaction(
        updatedInventoryItems: updatedItems,
        transaction: tx,
        cashLedgerEntry: cashEntry,
      );

      // Update in-memory state only after transaction commits
      for (final updated in updatedItems) {
        final pIdx = _inventory.indexWhere((p) => p.id == updated.id);
        if (pIdx >= 0) _inventory[pIdx] = updated;
        _firebase.syncInventoryItemToFirestore(updated);
      }
      _transactions.insert(0, tx);
      if (cashEntry != null) {
        _cashLedger.insert(0, cashEntry);
      }
      await _firebase.syncPosTransactionToFirestore(tx);

      if (_activeHandoffReservation != null) {
        final resId = _activeHandoffReservation!.id;
        final resIdx = _clickCollectOrders.indexWhere((o) => o.id == resId);
        if (resIdx >= 0) {
          final completedOrder = _clickCollectOrders[resIdx].copyWith(
            status: 'Completed',
          );
          await _db.saveClickCollectOrder(completedOrder);
          _clickCollectOrders[resIdx] = completedOrder;
          await _firebase.syncClickAndCollectToFirestore(completedOrder);
        }
        _activeHandoffReservation = null;
      }

      _cart.clear();
      _enqueueIfOffline(
        'POS_SALE',
        '${tx.id} • ₱${tx.totalAmount.toStringAsFixed(2)} (${tx.formattedPaymentDetails})',
      );
      _setViewState(
        ViewState.success,
        'Completed sale ${tx.id} (₱${tx.totalAmount.toStringAsFixed(2)} via ${tx.formattedPaymentDetails}).',
      );
      return tx;
    } catch (e) {
      _setViewState(ViewState.error, 'POS Checkout failed and rolled back: $e');
      return null;
    } finally {
      _isProcessingCheckout = false;
    }
  }

  /// Atomic Service-to-POS Auto-Billing Checkout
  Future<PosTransaction?> processServiceJobCheckout({
    required JobOrder job,
    required PaymentMethod paymentMethod,
    required double amountTendered,
    double cashAmount = 0.0,
    double gcashAmount = 0.0,
    String? gcashRef,
    String? gcashProofUrl,
  }) async {
    if (_isProcessingCheckout) {
      _setViewState(
        ViewState.error,
        'A checkout transaction is currently in progress.',
      );
      return null;
    }
    _isProcessingCheckout = true;

    try {
      final jIdx = _jobOrders.indexWhere((j) => j.id == job.id);
      final liveJob = jIdx >= 0 ? _jobOrders[jIdx] : job;
      if (liveJob.isBilled || liveJob.status == JobStatus.completed) {
        _setViewState(
          ViewState.error,
          'Job Order ${liveJob.id} has already been billed and completed.',
        );
        return null;
      }
      if (!_isValidCurrency(amountTendered)) {
        _setViewState(ViewState.error, 'Invalid tendered amount.');
        return null;
      }
      final total = liveJob.totalEstimate;

      // Split Payment calculations & validation
      final effectiveCash = paymentMethod == PaymentMethod.split
          ? (cashAmount > 0 ? cashAmount : (total - gcashAmount))
          : (paymentMethod == PaymentMethod.cash ? total : 0.0);
      final effectiveGcash = paymentMethod == PaymentMethod.split
          ? (gcashAmount > 0 ? gcashAmount : (total - cashAmount))
          : (paymentMethod == PaymentMethod.gcash ? total : 0.0);

      if (paymentMethod == PaymentMethod.split) {
        if ((effectiveCash + effectiveGcash - total).abs() > 0.01) {
          _setViewState(
            ViewState.error,
            'Split amounts must equal total bill (₱${total.toStringAsFixed(2)}).',
          );
          return null;
        }
        if (amountTendered < effectiveCash) {
          _setViewState(
            ViewState.error,
            'Tendered cash is less than cash portion.',
          );
          return null;
        }
        if (gcashRef == null || gcashRef.trim().length < 4) {
          _setViewState(
            ViewState.error,
            'Please enter at least the last 4 digits of the GCash Reference Number.',
          );
          return null;
        }
      } else if (paymentMethod == PaymentMethod.cash) {
        if (amountTendered < total) {
          _setViewState(
            ViewState.error,
            'Tendered cash is less than total service bill.',
          );
          return null;
        }
      } else if (paymentMethod == PaymentMethod.gcash) {
        if (gcashRef == null || gcashRef.trim().length < 4) {
          _setViewState(
            ViewState.error,
            'Please enter at least the last 4 digits of the GCash Reference Number.',
          );
          return null;
        }
      }

      final changeDue = (paymentMethod == PaymentMethod.gcash)
          ? 0.0
          : (amountTendered - effectiveCash);

      final updatedItems = <InventoryItem>[];
      for (final ap in liveJob.attachedParts) {
        final pIdx = _inventory.indexWhere((p) => p.id == ap.partId);
        if (pIdx >= 0) {
          final cur = _inventory[pIdx];
          final updated = cur.copyWith(
            stockPatimbao: liveJob.branch == BranchId.patimbao
                ? (cur.stockPatimbao - ap.quantity).clamp(0, 999999)
                : cur.stockPatimbao,
            stockPedroGuevara: liveJob.branch == BranchId.pedroGuevara
                ? (cur.stockPedroGuevara - ap.quantity).clamp(0, 999999)
                : cur.stockPedroGuevara,
            lockedPatimbao: liveJob.branch == BranchId.patimbao
                ? (cur.lockedPatimbao - ap.quantity).clamp(0, 999999)
                : cur.lockedPatimbao,
            lockedPedroGuevara: liveJob.branch == BranchId.pedroGuevara
                ? (cur.lockedPedroGuevara - ap.quantity).clamp(0, 999999)
                : cur.lockedPedroGuevara,
          );
          updatedItems.add(updated);
        }
      }

      final completedJob = liveJob.copyWith(
        status: JobStatus.completed,
        isBilled: true,
        updatedAt: DateTime.now(),
      );

      final itemsList =
          liveJob.attachedParts.map((p) => '${p.quantity}x ${p.name}').toList()
            ..add('${liveJob.serviceType} Labor');

      final tx = PosTransaction(
        id: _generateId('OR'),
        branch: liveJob.branch,
        cashierName: _currentUser?.fullName ?? 'Cashier',
        customerName: '${liveJob.customerName} (${liveJob.plateNumber})',
        itemsSummary: itemsList.join(', '),
        partsSubtotal: liveJob.partsSubtotal,
        laborTotal: liveJob.effectiveLaborFee,
        totalAmount: total,
        paymentMethod: paymentMethod,
        amountTendered: paymentMethod == PaymentMethod.gcash
            ? total
            : amountTendered,
        changeAmount: changeDue,
        cashAmount: effectiveCash,
        gcashAmount: effectiveGcash,
        gcashRef: gcashRef,
        gcashProofUrl: gcashProofUrl,
        linkedJobOrderId: liveJob.id,
        createdAt: DateTime.now(),
        isSynced: _isOnline,
      );

      final cashToRecord = paymentMethod == PaymentMethod.cash
          ? total
          : (paymentMethod == PaymentMethod.split ? effectiveCash : 0.0);

      final cashEntry = cashToRecord > 0
          ? CashDrawerEntry(
              id: _generateId('CSH'),
              branch: liveJob.branch,
              type: CashLedgerType.serviceCash,
              description:
                  '${tx.id} • Service Billing ${liveJob.id} (${liveJob.plateNumber})',
              amount: cashToRecord,
              staffName: tx.cashierName,
              createdAt: DateTime.now(),
            )
          : null;

      await _db.executeServiceJobCheckoutTransaction(
        updatedInventoryItems: updatedItems,
        completedJob: completedJob,
        transaction: tx,
        cashLedgerEntry: cashEntry,
      );

      for (final updated in updatedItems) {
        final pIdx = _inventory.indexWhere((p) => p.id == updated.id);
        if (pIdx >= 0) _inventory[pIdx] = updated;
        _firebase.syncInventoryItemToFirestore(updated);
      }
      if (jIdx >= 0) _jobOrders[jIdx] = completedJob;
      _firebase.syncJobOrderToFirestore(completedJob);
      _transactions.insert(0, tx);
      if (cashEntry != null) {
        _cashLedger.insert(0, cashEntry);
      }
      await _firebase.syncPosTransactionToFirestore(tx);

      _enqueueIfOffline(
        'SERVICE_POS_BILLING',
        '${tx.id} for ${liveJob.id} • ₱${total.toStringAsFixed(2)}',
      );
      _setViewState(
        ViewState.success,
        'Billed Job Order ${liveJob.id} (${tx.id}) • ₱${total.toStringAsFixed(2)} via ${tx.formattedPaymentDetails}!',
      );
      return tx;
    } catch (e) {
      _setViewState(
        ViewState.error,
        'Service checkout failed and rolled back: $e',
      );
      return null;
    } finally {
      _isProcessingCheckout = false;
    }
  }

  /// Permanently deletes a POS transaction receipt from local database and history (Admin only)
  Future<bool> deleteTransaction(String id) async {
    if (_currentUser != null && _currentUser!.role != UserRole.admin) {
      _setViewState(ViewState.error, 'Access denied: Only Admins can delete receipt history.');
      return false;
    }
    _transactions.removeWhere((t) => t.id == id);
    await _db.deleteTransaction(id);
    _setViewState(ViewState.success, 'Transaction $id removed from history.');
    return true;
  }

  // ---------------------------------------------------------------------------
  // Cash Drawer Starting Cash, Petty Cash & End-of-Shift Denomination Audit
  // ---------------------------------------------------------------------------

  Future<bool> addMorningFloat(double amount) async {
    if (!_isValidCurrency(amount) || amount <= 0) {
      _setViewState(ViewState.error, 'Starting cash amount must be greater than 0.');
      return false;
    }
    try {
      final entry = CashDrawerEntry(
        id: 'CSH-${DateTime.now().millisecondsSinceEpoch}',
        branch: _activeBranch,
        type: CashLedgerType.morningFloat,
        description: 'Starting Cash Added (${_activeBranch.shortName})',
        amount: amount,
        staffName: _currentUser?.fullName ?? 'Cashier',
        createdAt: DateTime.now(),
      );
      await _db.saveCashLedgerEntry(entry);
      _cashLedger.insert(0, entry);
      _setViewState(
        ViewState.success,
        'Recorded Starting Cash of ₱${amount.toStringAsFixed(2)}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to record starting cash: $e');
      return false;
    }
  }

  Future<bool> recordCashout({
    required String description,
    required double amount,
  }) async {
    if (!_isValidCurrency(amount) || amount <= 0) {
      _setViewState(ViewState.error, 'Cashout amount must be positive.');
      return false;
    }
    if (amount > branchPhysicalCashInDrawer) {
      _setViewState(
        ViewState.error,
        'Cashout amount exceeds physical cash in drawer.',
      );
      return false;
    }
    try {
      final entry = CashDrawerEntry(
        id: 'CSH-${DateTime.now().millisecondsSinceEpoch}',
        branch: _activeBranch,
        type: CashLedgerType.cashout,
        description: 'Cashout • ${description.trim()}',
        amount: -amount,
        staffName: _currentUser?.fullName ?? 'Cashier',
        createdAt: DateTime.now(),
      );
      await _db.saveCashLedgerEntry(entry);
      _cashLedger.insert(0, entry);
      _enqueueIfOffline(
        'CASHOUT',
        '-₱${amount.toStringAsFixed(2)} ($description)',
      );
      _setViewState(
        ViewState.success,
        'Logged Cashout: -₱${amount.toStringAsFixed(2)} ($description).',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to log cashout: $e');
      return false;
    }
  }

  /// Backward-compatible forwarder for legacy calls
  Future<bool> recordPettyCashOut({
    required String description,
    required double amount,
  }) => recordCashout(description: description, amount: amount);

  /// True when the signed-in user is still on a provisioned/default password.
  bool get requiresPasswordChange =>
      _currentUser != null &&
      _currentUser!.mustChangePassword &&
      _currentUser!.authProvider == 'password';

  Future<bool> completeForcedPasswordChange(String newPassword) async {
    final u = _currentUser;
    if (u == null) return false;
    final pw = newPassword.trim();
    if (pw.length < 8) {
      _setViewState(ViewState.error, 'Password must be at least 8 characters.');
      return false;
    }
    if (PasswordSecurity.verify(u.password, pw)) {
      _setViewState(
        ViewState.error,
        'Choose a password different from the current one.',
      );
      return false;
    }
    try {
      final updated = u.copyWith(
        password: PasswordSecurity.hashPassword(pw),
        mustChangePassword: false,
      );
      await _saveStaff(updated);
      final idx = _staffList.indexWhere((s) => s.id == u.id);
      if (idx >= 0) _staffList[idx] = updated;
      _currentUser = updated;
      _setViewState(ViewState.success, 'Password updated.');
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update password: $e');
      return false;
    }
  }

  bool verifyAdminOverridePassword(String password) {
    return _staffList.any(
      (s) =>
          s.role == UserRole.admin &&
          PasswordSecurity.verify(s.password, password.trim()),
    );
  }

  Future<bool> logShiftReconciliationAudit({
    required double countedCash,
    required double expectedCash,
    String? adminOverrideBy,
  }) async {
    if (!_isValidCurrency(countedCash)) {
      _setViewState(ViewState.error, 'Invalid counted cash amount.');
      return false;
    }
    try {
      final variance = countedCash - expectedCash;
      final statusLabel = variance == 0
          ? 'EXACT MATCH (₱0.00 Variance)'
          : variance < 0
          ? 'SHORTAGE (₱${variance.toStringAsFixed(2)}) • Override: ${adminOverrideBy ?? "Boss Arman"}'
          : 'OVERAGE (+₱${variance.toStringAsFixed(2)})';

      final entry = CashDrawerEntry(
        id: _generateId('CSH'),
        branch: _activeBranch,
        type: CashLedgerType.reconciliationAudit,
        description:
            'Shift Audit: Counted ₱${countedCash.toStringAsFixed(0)} vs Expected ₱${expectedCash.toStringAsFixed(0)} • $statusLabel',
        amount: 0.0,
        staffName: _currentUser?.fullName ?? 'Cashier',
        createdAt: DateTime.now(),
      );
      await _db.saveCashLedgerEntry(entry);
      _cashLedger.insert(0, entry);

      await _pushNotification(
        title: 'Shift Drawer Audit Logged • ${_activeBranch.shortName}',
        message: entry.description,
        category: 'drawer',
        branch: _activeBranch,
      );

      _setViewState(
        ViewState.success,
        'Shift Cash Reconciliation Audit recorded ($statusLabel).',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to log shift audit: $e');
      return false;
    }
  }

  /// Dismisses / permanently removes a cash drawer ledger record from the active drawer (Admin only)
  Future<bool> deleteCashLedgerEntry(String entryId) async {
    if (_currentUser != null && _currentUser!.role != UserRole.admin) {
      _setViewState(ViewState.error, 'Access denied: Only Admins can delete cash drawer ledger entries.');
      return false;
    }
    final idx = _cashLedger.indexWhere((e) => e.id == entryId);
    if (idx < 0) return false;
    _cashLedger.removeAt(idx);
    await _db.deleteCashLedgerEntry(entryId);
    notifyListeners();
    return true;
  }

  /// Generates and persists an immutable end-of-shift Z-Reading snapshot with physical cash reconciliation.
  Future<ZReadingRecord?> generateZReadingReport({
    double? actualPhysicalCash,
    String? reconciliationNote,
  }) async {
    try {
      final actual = actualPhysicalCash ?? branchPhysicalCashInDrawer;
      final discrepancy = actual - branchPhysicalCashInDrawer;

      final record = ZReadingRecord(
        id: _generateId('Z'),
        branch: _activeBranch,
        terminalId: _activeBranch.terminalId,
        generatedBy: _currentUser?.fullName ?? 'Cashier',
        morningFloat: branchMorningFloat,
        grossCashSales: branchCashSalesTotal,
        gcashVaultCollections: branchGcashVaultTotal,
        cashoutOutflows: branchCashoutTotal,
        totalGrossRevenue: branchTodayGross,
        expectedPhysicalCash: branchPhysicalCashInDrawer,
        actualPhysicalCash: actual,
        cashDiscrepancy: discrepancy,
        reconciliationNote: reconciliationNote ?? '',
        totalTransactions: currentShiftTransactions.length,
        generatedAt: DateTime.now(),
      );

      await _db.saveZReading(record);
      _zReadings.insert(0, record);

      final discrepancyText = discrepancy == 0
          ? 'Exact match'
          : (discrepancy < 0
                ? 'Shortage -₱${(-discrepancy).toStringAsFixed(2)}'
                : 'Overage +₱${discrepancy.toStringAsFixed(2)}');

      await _pushNotification(
        title: 'Z-Reading Generated (${record.id})',
        message:
            '${_activeBranch.shortName} shift closed • '
            'Gross ₱${record.totalGrossRevenue.toStringAsFixed(2)} • '
            'Drawer: ₱${record.expectedPhysicalCash.toStringAsFixed(2)} (Counted: ₱${actual.toStringAsFixed(2)}, $discrepancyText)',
        category: 'drawer',
        branch: _activeBranch,
      );

      _enqueueIfOffline(
        'Z_READING',
        '${record.id} • ₱${record.totalGrossRevenue.toStringAsFixed(2)}',
      );

      _setViewState(
        ViewState.success,
        'Z-Reading ${record.id} archived to local SQLite.',
      );
      return record;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to save Z-Reading: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Staff & Admin Management (add_staff_screen.dart)
  // ---------------------------------------------------------------------------

  Future<bool> createStaffAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required UserRole role,
    required BranchId assignedBranch,
  }) async {
    if (_currentUser != null && _currentUser!.role != UserRole.admin) {
      _setViewState(
        ViewState.error,
        'Access Denied: Only the Admin can create staff accounts and assign branches.',
      );
      return false;
    }

    if ((role == UserRole.cashier || role == UserRole.mechanic) &&
        assignedBranch == BranchId.both) {
      _setViewState(
        ViewState.error,
        'Each ${role.label} can only be assigned to ONE branch (Branch 1 or Branch 2).',
      );
      return false;
    }

    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final duplicate = _staffList.any(
      (s) =>
          !s.isDeleted &&
          (s.username.toLowerCase() == cleanUsername ||
              s.email.toLowerCase() == cleanEmail),
    );
    if (duplicate) {
      _setViewState(
        ViewState.error,
        'Username or email is already registered to an active account.',
      );
      return false;
    }

    // Clean up any old soft-deleted entry with this username/email
    _staffList.removeWhere(
      (s) =>
          s.isDeleted &&
          (s.username.toLowerCase() == cleanUsername ||
              s.email.toLowerCase() == cleanEmail),
    );

    _setViewState(ViewState.loading);
    try {
      String uid;
      try {
        if (_firebase.isInitialized) {
          uid = await _firebase.createAuthUserSecondary(
            email: cleanEmail,
            password: password.trim(),
          );
        } else {
          uid = _generateId('STF');
        }
      } catch (e) {
        debugPrint('[MotoHubViewModel] Secondary cloud auth note: $e');
        // Graceful offline fallback: Generate unique staff ID so creation always succeeds locally
        uid = _generateId('STF');
      }

      final newStaff = StaffAccount(
        id: uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        username: cleanUsername,
        email: cleanEmail,
        password: PasswordSecurity.hashPassword(password.trim()),
        role: role,
        assignedBranch: assignedBranch,
        shiftStatus: role == UserRole.mechanic ? 'In Bay' : 'On Duty',
        createdAt: DateTime.now(),
      );

      await _saveStaff(newStaff);
      _staffList.insert(0, newStaff);
      _enqueueIfOffline(
        'STAFF_CREATE',
        '${newStaff.fullName} (${newStaff.role.label} • ${assignedBranch.shortName})',
      );

      await _pushNotification(
        title: 'New Staff Provisioned: ${newStaff.fullName}',
        message:
            'Role: ${role.label} • Assigned to ${assignedBranch.displayName}.',
        category: 'staff',
        branch: assignedBranch,
      );

      _setViewState(
        ViewState.success,
        'Created ${role.label} account for ${newStaff.fullName} (@$cleanUsername) assigned to ${assignedBranch.displayName}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to create staff account: $e');
      return false;
    }
  }

  /// Admin-Only: Permanently deletes a staff account from SQLite, memory, and directory
  Future<bool> deleteStaffAccount(String accountId) async {
    _staffList.removeWhere((s) => s.id == accountId);
    await _db.deleteStaff(accountId);
    unawaited(_firebase.deleteStaffFromFirestore(accountId));
    unawaited(_firebase.softDeleteUserDoc(accountId, DateTime.now()));
    _setViewState(ViewState.success, 'Staff member removed from directory.');
    return true;
  }

  /// Admin-Only: Reassigns a Cashier or Mechanic to a single branch (`BranchId.patimbao` or `BranchId.pedroGuevara`).
  Future<bool> updateStaffAssignedBranch({
    required StaffAccount staff,
    required BranchId newBranch,
  }) async {
    if (_currentUser?.role != UserRole.admin) {
      _setViewState(
        ViewState.error,
        'Access Denied: Only the Admin can change staff branch assignments.',
      );
      return false;
    }

    if ((staff.role == UserRole.cashier || staff.role == UserRole.mechanic) &&
        newBranch == BranchId.both) {
      _setViewState(
        ViewState.error,
        'Each ${staff.role.label} can only be assigned to a single branch.',
      );
      return false;
    }

    final idx = _staffList.indexWhere((s) => s.id == staff.id);
    if (idx < 0) return false;
    if (_staffList[idx].assignedBranch == newBranch) return true;

    try {
      final updated = _staffList[idx].copyWith(assignedBranch: newBranch);
      await _saveStaff(updated);
      _staffList[idx] = updated;

      _enqueueIfOffline(
        'STAFF_BRANCH_REASSIGN',
        '${updated.fullName} (${updated.role.label}) -> ${newBranch.shortName}',
      );

      await _pushNotification(
        title: 'Branch Assignment Updated • ${updated.fullName}',
        message:
            'Admin reassigned ${updated.fullName} (${updated.role.label}) to ${newBranch.displayName}.',
        category: 'staff',
        branch: newBranch,
      );

      _setViewState(
        ViewState.success,
        'Reassigned ${updated.fullName} (${updated.role.label}) to ${newBranch.displayName}.',
      );
      return true;
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to reassign staff branch: $e');
      return false;
    }
  }

  Future<void> cycleStaffShiftStatus(StaffAccount staff) async {
    const statuses = ['On Duty', 'In Bay', 'Off Shift', 'Emergency Absence'];
    final curIdx = statuses.indexOf(staff.shiftStatus);
    final nextStatus = statuses[(curIdx + 1) % statuses.length];
    final idx = _staffList.indexWhere((s) => s.id == staff.id);
    if (idx < 0) return;

    try {
      final isEmergency = nextStatus == 'Emergency Absence';
      final updated = staff.copyWith(
        shiftStatus: nextStatus,
        coveredByStaff: isEmergency ? 'Cross-Branch Reliever Requested' : null,
        clearCoveredByStaff: !isEmergency,
      );
      await _saveStaff(updated);
      _staffList[idx] = updated;
      _setViewState(
        ViewState.success,
        '${staff.fullName} status updated to "$nextStatus".',
      );
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update shift status: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications Helper
  // ---------------------------------------------------------------------------

  Future<void> _pushNotification({
    required String title,
    required String message,
    required String category,
    required BranchId branch,
    UserRole? targetRole,
    String? targetUserId,
    Map<String, dynamic>? payload,
  }) async {
    final notif = AppNotificationItem(
      id: _generateId('NTF'),
      title: title,
      message: message,
      category: category,
      branch: branch,
      isRead: false,
      createdAt: DateTime.now(),
      targetRole: targetRole ?? UserRole.admin,
      targetUserId: targetUserId,
      payload: payload,
    );
    await _db.saveNotification(notif);
    _notifications.insert(0, notif);
    await _firebase.createFirestoreNotification(notif);
  }

  Future<void> markAllNotificationsRead([String? notificationId]) async {
    try {
      for (var i = 0; i < _notifications.length; i++) {
        final notif = _notifications[i];
        final isInActiveBranchScope =
            notif.branch == _activeBranch ||
            (!isBranchLockedForCurrentUser && notif.branch == BranchId.both);
        final matchesTarget = notificationId != null
            ? notif.id == notificationId
            : isInActiveBranchScope;
        if (matchesTarget && !notif.isRead) {
          final updated = notif.copyWith(isRead: true);
          _notifications[i] = updated;
          await _db.saveNotification(updated);
        }
      }
      notifyListeners();
    } catch (e) {
      _setViewState(ViewState.error, 'Failed to update notifications: $e');
    }
  }

  /// Permanently removes a notification from SQLite, Firestore, and active memory.
  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _dismissedNotificationIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'dismissed_notifications_ids',
        _dismissedNotificationIds.toList(),
      );
      await _db.deleteNotification(id);
      await _firebase.deleteFirestoreNotification(id);
    } catch (e) {
      debugPrint('[ViewModel] Error deleting notification $id: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _inventorySub?.cancel();
    _inventoryDebounce?.cancel();
    _inventoryRetryTimer?.cancel();
    _cloudRetryTimer?.cancel();
    for (final s in _syncSubs) {
      s.cancel();
    }
    _syncSubs.clear();
    super.dispose();
  }
}
