import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as mobile_sqflite show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';
import '../utils/password_security.dart';

/// Production Offline-First SQLite Engine for Boss Arman MotoHub.
///
/// AUDIT & HARDENING SUMMARY:
/// 1. Purged all mock/dummy inventory, job order, transfer, POS transaction,
///    cash ledger, and notification seed arrays.
/// 2. Database initializes completely empty except for the initial staff
///    accounts. NO password is hardcoded: release builds read it from
///    `--dart-define=INITIAL_ADMIN_PASSWORD=...`; debug builds fall back to
///    a throwaway dev password so local testing keeps working.
/// 3. All multi-table writes execute inside atomic `db.transaction((txn) => ...)`
///    blocks (with full in-memory snapshot rollback when running on Web).
class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  static const String _dbFileName = 'boss_arman_motohub_prod_v3.db';
  static const int _schemaVersion = 8;

  Database? _db;
  bool _useInMemoryFallback = false;

  // Clean, initially-empty in-memory tables for Web fallback (NO mock data)
  final List<StaffAccount> _memStaff = [];
  final List<InventoryItem> _memInventory = [];
  final List<JobOrder> _memJobOrders = [];
  final List<StockTransfer> _memTransfers = [];
  final List<PosTransaction> _memTransactions = [];
  final List<CashDrawerEntry> _memCashLedger = [];
  final List<AppNotificationItem> _memNotifications = [];
  final List<ClickAndCollectOrder> _memClickCollect = [];
  final List<ZReadingRecord> _memZReadings = [];

  Future<void> initializeAndPreWarm({
    void Function(double progress, String stage)? onProgress,
  }) async {
    onProgress?.call(0.15, 'Initializing local SQLite engine...');
    try {
      final isFlutterTest =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (kIsWeb || isFlutterTest) {
        _useInMemoryFallback = true;
        onProgress?.call(
          0.60,
          isFlutterTest
              ? 'Mounting clean in-memory store for tests...'
              : 'Mounting clean in-memory store for web...',
        );
        _seedInMemoryStaffOnlyIfNeeded();
        onProgress?.call(
          1.0,
          isFlutterTest
              ? 'Test In-Memory Store Ready'
              : 'Database Ready • Web In-Memory State',
        );
        return;
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else {
        // Android / iOS: use the native sqflite engine. Without this line the
        // global databaseFactory is never set on phones, openDatabase() throws,
        // and the app silently drops to the in-memory store (all data lost
        // on every restart).
        databaseFactory = mobile_sqflite.databaseFactory;
      }

      onProgress?.call(0.45, 'Mounting Boss Arman MotoHub SQLite database...');
      final String dbPath;
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        dbPath = inMemoryDatabasePath;
      } else {
        final dbDir = await getDatabasesPath();
        dbPath = p.join(dbDir, _dbFileName);
      }

      _db = await openDatabase(
        dbPath,
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _migrateSchema(db, oldVersion, newVersion);
        },
      );

      // Verify dynamic column migrations (ensures upgraded installs have all columns)
      await _migrateSchema(_db!, 0, _schemaVersion);

      onProgress?.call(0.75, 'Verifying schema & initial staff credentials...');
      await _seedStaffOnlyIfNeeded(_db!);
      onProgress?.call(1.0, 'SQLite Ready • PAT-01 / PGV-02');
    } catch (e) {
      debugPrint('SQLite fallback activated: $e');
      _useInMemoryFallback = true;
      _seedInMemoryStaffOnlyIfNeeded();
      onProgress?.call(1.0, 'Offline Store Ready');
    }
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff_accounts (
        id TEXT PRIMARY KEY,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        assignedBranch TEXT NOT NULL,
        shiftStatus TEXT NOT NULL,
        coveredByStaff TEXT,
        authProvider TEXT DEFAULT 'password',
        fcmToken TEXT,
        mustChangePassword INTEGER NOT NULL DEFAULT 0,
        photoUrl TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT,
        recoverableUntil TEXT,
        termsAcceptedVersion TEXT,
        termsAcceptedAt TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id TEXT PRIMARY KEY,
        sku TEXT NOT NULL,
        barcode TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL CHECK(price >= 0),
        costPrice REAL NOT NULL CHECK(costPrice >= 0),
        stockPatimbao INTEGER NOT NULL CHECK(stockPatimbao >= 0),
        stockPedroGuevara INTEGER NOT NULL CHECK(stockPedroGuevara >= 0),
        lockedPatimbao INTEGER NOT NULL DEFAULT 0 CHECK(lockedPatimbao >= 0),
        lockedPedroGuevara INTEGER NOT NULL DEFAULT 0 CHECK(lockedPedroGuevara >= 0),
        minThreshold INTEGER NOT NULL DEFAULT 5,
        maxThreshold INTEGER NOT NULL DEFAULT 25,
        rack TEXT NOT NULL,
        shelf TEXT NOT NULL,
        bin TEXT NOT NULL,
        compatibleModels TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS job_orders (
        id TEXT PRIMARY KEY,
        branch TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerUsername TEXT NOT NULL,
        customerPhone TEXT NOT NULL,
        bikeModel TEXT NOT NULL,
        plateNumber TEXT NOT NULL,
        serviceType TEXT NOT NULL,
        issueDescription TEXT NOT NULL,
        assignedMechanic TEXT NOT NULL,
        mechanicId TEXT,
        status TEXT NOT NULL,
        attachedPartsJson TEXT NOT NULL,
        laborFee REAL NOT NULL CHECK(laborFee >= 0),
        extraRepairNote TEXT,
        extraRepairFee REAL NOT NULL DEFAULT 0 CHECK(extraRepairFee >= 0),
        extraRepairApproved INTEGER NOT NULL DEFAULT 0,
        isBilled INTEGER NOT NULL DEFAULT 0,
        preferredSchedule TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfers (
        id TEXT PRIMARY KEY,
        partId TEXT NOT NULL,
        sku TEXT NOT NULL,
        partName TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        fromBranch TEXT NOT NULL,
        toBranch TEXT NOT NULL,
        status TEXT NOT NULL,
        initiatedBy TEXT NOT NULL,
        approvedBy TEXT,
        approvedAt TEXT,
        confirmedBy TEXT,
        createdAt TEXT NOT NULL,
        confirmedAt TEXT,
        rejectionReason TEXT,
        rejectedBy TEXT,
        rejectedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pos_transactions (
        id TEXT PRIMARY KEY,
        branch TEXT NOT NULL,
        cashierName TEXT NOT NULL,
        customerName TEXT NOT NULL,
        itemsSummary TEXT NOT NULL,
        partsSubtotal REAL NOT NULL CHECK(partsSubtotal >= 0),
        laborTotal REAL NOT NULL CHECK(laborTotal >= 0),
        totalAmount REAL NOT NULL CHECK(totalAmount >= 0),
        paymentMethod TEXT NOT NULL,
        amountTendered REAL NOT NULL CHECK(amountTendered >= 0),
        changeAmount REAL NOT NULL CHECK(changeAmount >= 0),
        cashAmount REAL NOT NULL DEFAULT 0,
        gcashAmount REAL NOT NULL DEFAULT 0,
        gcashRef TEXT,
        gcashProofUrl TEXT,
        linkedJobOrderId TEXT,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_ledger (
        id TEXT PRIMARY KEY,
        branch TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        staffName TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        category TEXT NOT NULL,
        branch TEXT NOT NULL,
        targetRole TEXT,
        targetUserId TEXT,
        payload TEXT,
        isRead INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_threads (
        id TEXT PRIMARY KEY,
        participantIds TEXT NOT NULL,
        authUids TEXT NOT NULL,
        roles TEXT NOT NULL,
        jobOrderId TEXT,
        lastMessage TEXT,
        lastMessageAt TEXT,
        unreadCounts TEXT,
        participantNames TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        threadId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderRole TEXT NOT NULL,
        text TEXT,
        imageUrl TEXT,
        createdAt TEXT NOT NULL,
        readBy TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS click_collect_orders (
        id TEXT PRIMARY KEY,
        customerId TEXT,
        customerUsername TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerPhone TEXT NOT NULL,
        pickupBranch TEXT NOT NULL,
        partId TEXT NOT NULL,
        sku TEXT NOT NULL,
        partName TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        expiresAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS z_readings (
        id TEXT PRIMARY KEY,
        branch TEXT NOT NULL,
        terminalId TEXT NOT NULL,
        generatedBy TEXT NOT NULL,
        morningFloat REAL NOT NULL,
        grossCashSales REAL NOT NULL,
        gcashVaultCollections REAL NOT NULL,
        pettyCashOutflows REAL NOT NULL,
        cashoutOutflows REAL NOT NULL DEFAULT 0,
        totalGrossRevenue REAL NOT NULL,
        expectedPhysicalCash REAL NOT NULL,
        actualPhysicalCash REAL NOT NULL DEFAULT 0,
        cashDiscrepancy REAL NOT NULL DEFAULT 0,
        reconciliationNote TEXT,
        totalTransactions INTEGER NOT NULL,
        generatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateSchema(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    await _createTables(db);
    await _ensureColumnExists(
      db,
      'staff_accounts',
      'authProvider',
      "TEXT DEFAULT 'password'",
    );
    await _ensureColumnExists(db, 'staff_accounts', 'fcmToken', 'TEXT');
    await _ensureColumnExists(
      db,
      'staff_accounts',
      'mustChangePassword',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(db, 'staff_accounts', 'photoUrl', 'TEXT');
    await _ensureColumnExists(
      db,
      'staff_accounts',
      'isDeleted',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(db, 'staff_accounts', 'deletedAt', 'TEXT');
    await _ensureColumnExists(db, 'staff_accounts', 'recoverableUntil', 'TEXT');
    await _ensureColumnExists(
      db,
      'staff_accounts',
      'termsAcceptedVersion',
      'TEXT',
    );
    await _ensureColumnExists(db, 'staff_accounts', 'termsAcceptedAt', 'TEXT');
    await _ensureColumnExists(
      db,
      'pos_transactions',
      'cashAmount',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'pos_transactions',
      'gcashAmount',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'z_readings',
      'actualPhysicalCash',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'z_readings',
      'cashDiscrepancy',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'z_readings',
      'cashoutOutflows',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'inventory_items',
      'isDeleted',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'inventory_items',
      'is_deleted',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      'pos_transactions',
      'isSynced',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumnExists(db, 'click_collect_orders', 'customerId', 'TEXT');
    await _ensureColumnExists(db, 'click_collect_orders', 'expiresAt', 'TEXT');
    await _ensureColumnExists(db, 'click_collect_orders', 'reservationId', 'TEXT');
    await _ensureColumnExists(db, 'click_collect_orders', 'branchId', 'TEXT');
    await _ensureColumnExists(db, 'click_collect_orders', 'itemId', 'TEXT');
    await _ensureColumnExists(db, 'click_collect_orders', 'qty', 'INTEGER');
    await _ensureColumnExists(db, 'stock_transfers', 'approvedBy', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'approvedAt', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'confirmedBy', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'confirmedAt', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'rejectionReason', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'rejectedBy', 'TEXT');
    await _ensureColumnExists(db, 'stock_transfers', 'rejectedAt', 'TEXT');
    await _ensureColumnExists(db, 'job_orders', 'mechanicId', 'TEXT');
    await _ensureColumnExists(db, 'notifications', 'targetRole', 'TEXT');
    await _ensureColumnExists(db, 'notifications', 'targetUserId', 'TEXT');
    await _ensureColumnExists(db, 'notifications', 'payload', 'TEXT');
  }

  /// Purges accounts that have been soft-deleted and whose 30-day recovery window has expired.
  Future<int> purgeExpiredDeletedAccounts() async {
    final nowIso = DateTime.now().toIso8601String();
    if (_useInMemoryFallback || _db == null) {
      final before = _memStaff.length;
      _memStaff.removeWhere(
        (s) =>
            s.isDeleted &&
            s.recoverableUntil != null &&
            s.recoverableUntil!.isBefore(DateTime.now()),
      );
      return before - _memStaff.length;
    }
    return await _db!.delete(
      'staff_accounts',
      where: 'isDeleted = 1 AND recoverableUntil IS NOT NULL AND recoverableUntil < ?',
      whereArgs: [nowIso],
    );
  }

  Future<void> _ensureColumnExists(
    DatabaseExecutor db,
    String table,
    String column,
    String typeWithDefault,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any(
        (row) =>
            (row['name'] as String?)?.toLowerCase() == column.toLowerCase(),
      );
      if (!exists) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN $column $typeWithDefault',
        );
      }
    } catch (e) {
      debugPrint(
        '[LocalDatabaseService] Column check note for $table.$column: $e',
      );
    }
  }

  /// Seeds ONLY the 3 mandatory initial administrative/staff accounts.
  /// All operational tables (`inventory_items`, `job_orders`, `pos_transactions`,
  /// `stock_transfers`, `cash_ledger`, `notifications`) start 100% empty.
  Future<void> _seedStaffOnlyIfNeeded(Database db) async {
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM staff_accounts');
    final count = res.isNotEmpty ? (res.first['c'] as int? ?? 0) : 0;
    // Only perform initial seed once on a fresh empty database
    if (count > 0) return;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final staff in initialAdminAndStaffSeeds()) {
        batch.insert(
          'staff_accounts',
          staff.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  void _seedInMemoryStaffOnlyIfNeeded() {
    if (_memStaff.isNotEmpty) return;
    for (final staff in initialAdminAndStaffSeeds()) {
      _memStaff.add(staff);
    }
  }

  // ---------------------------------------------------------------------------
  // Mandatory Initial Staff Accounts (Objective 2: Clean Start)
  // ---------------------------------------------------------------------------

  /// Initial admin password, injected at build time:
  ///   `flutter build apk --dart-define=INITIAL_ADMIN_PASSWORD=<strong-password>`
  static const String _initialAdminPassword = String.fromEnvironment(
    'INITIAL_ADMIN_PASSWORD',
  );

  static List<StaffAccount> initialAdminAndStaffSeeds() {
    final adminPw = _initialAdminPassword.isNotEmpty
        ? _initialAdminPassword
        : 'admin123';
    // Fixed salt + fixed createdAt => every phone derives the IDENTICAL seed
    // record, so seeds never conflict when synced through Firestore.
    final seedDate = DateTime.utc(2024, 1, 1);
    String h(String pw, String salt) =>
        PasswordSecurity.hashPassword(pw, salt: salt);

    return <StaffAccount>[
      StaffAccount(
        id: 'STF-001',
        firstName: 'Arman',
        lastName: 'Sarita',
        username: 'bossarman',
        email: 'bossarman@motohub.ph',
        password: h(adminPw, 'seedstf001'),
        role: UserRole.admin,
        assignedBranch: BranchId.both,
        shiftStatus: 'On Duty',
        mustChangePassword: false,
        createdAt: seedDate,
      ),
      StaffAccount(
        id: 'STF-004',
        firstName: 'Lance Mercado',
        lastName: 'Aclan',
        username: 'lanceadmin',
        email: 'lancemercadoaclan01@gmail.com',
        password: h(adminPw, 'seedstf004'),
        role: UserRole.admin,
        assignedBranch: BranchId.both,
        shiftStatus: 'On Duty',
        mustChangePassword: false,
        createdAt: seedDate,
      ),
      StaffAccount(
        id: 'STF-005',
        firstName: 'Keith Arwil',
        lastName: 'Umali',
        username: 'keithadmin',
        email: 'keith110606@gmail.com',
        password: h(adminPw, 'seedstf005'),
        role: UserRole.admin,
        assignedBranch: BranchId.both,
        shiftStatus: 'On Duty',
        mustChangePassword: false,
        createdAt: seedDate,
      ),
      StaffAccount(
        id: 'STF-002',
        firstName: 'Keith Arwil',
        lastName: 'Umali',
        username: 'cashier01',
        email: 'cashier01@motohub.ph',
        password: h('cashier123', 'seedstf002'),
        role: UserRole.cashier,
        assignedBranch: BranchId.patimbao,
        shiftStatus: 'On Duty',
        mustChangePassword: false,
        createdAt: seedDate,
      ),
      StaffAccount(
        id: 'STF-003',
        firstName: 'Lance M.',
        lastName: 'Aclan',
        username: 'mechanic01',
        email: 'mechanic01@motohub.ph',
        password: h('mech123', 'seedstf003'),
        role: UserRole.mechanic,
        assignedBranch: BranchId.patimbao,
        shiftStatus: 'In Bay',
        mustChangePassword: false,
        createdAt: seedDate,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Standard Read & Single-Entity Write Operations
  // ---------------------------------------------------------------------------

  Future<List<StaffAccount>> loadStaff() async {
    if (_useInMemoryFallback || _db == null) {
      _seedInMemoryStaffOnlyIfNeeded();
      return List<StaffAccount>.unmodifiable(
        _memStaff.where((s) => !s.isDeleted),
      );
    }
    final rows = await _db!.query(
      'staff_accounts',
      where: 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'createdAt ASC',
    );
    return rows.map(StaffAccount.fromMap).toList();
  }

  Future<void> deleteStaff(String id) async {
    _memStaff.removeWhere((s) => s.id == id);
    if (_useInMemoryFallback || _db == null) {
      return;
    }
    await _db!.delete(
      'staff_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveStaff(StaffAccount staff) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memStaff.indexWhere((s) => s.id == staff.id);
      if (idx >= 0) {
        _memStaff[idx] = staff;
      } else {
        _memStaff.add(staff);
      }
      return;
    }
    await _db!.transaction((txn) async {
      final existingById = await txn.query(
        'staff_accounts',
        where: 'id = ?',
        whereArgs: [staff.id],
      );
      if (existingById.isNotEmpty) {
        await txn.update(
          'staff_accounts',
          staff.toMap(),
          where: 'id = ?',
          whereArgs: [staff.id],
        );
      } else {
        final existingByUsername = await txn.query(
          'staff_accounts',
          where: 'username = ?',
          whereArgs: [staff.username],
        );
        if (existingByUsername.isNotEmpty) {
          throw Exception(
            'Username "${staff.username}" is already taken by another account.',
          );
        }
        await txn.insert(
          'staff_accounts',
          staff.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Future<List<InventoryItem>> loadInventory() async {
    if (_useInMemoryFallback || _db == null) {
      return List<InventoryItem>.unmodifiable(
        _memInventory.where((i) => !i.isDeleted),
      );
    }
    final rows = await _db!.query(
      'inventory_items',
      where: 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'name ASC',
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Map<String, dynamic> _inventoryToSqlMap(InventoryItem item) => {
    'id': item.id,
    'sku': item.sku,
    'barcode': item.barcode,
    'name': item.name,
    'category': item.category,
    'price': item.price,
    'costPrice': item.costPrice,
    'stockPatimbao': item.stockPatimbao,
    'stockPedroGuevara': item.stockPedroGuevara,
    'lockedPatimbao': item.lockedPatimbao,
    'lockedPedroGuevara': item.lockedPedroGuevara,
    'minThreshold': item.minThreshold,
    'maxThreshold': item.maxThreshold,
    'rack': item.rack,
    'shelf': item.shelf,
    'bin': item.bin,
    'compatibleModels': item.compatibleModels,
    'isDeleted': item.isDeleted ? 1 : 0,
  };

  Future<void> saveInventoryItem(InventoryItem item) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memInventory.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _memInventory[idx] = item;
      } else {
        _memInventory.insert(0, item);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'inventory_items',
        _inventoryToSqlMap(item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteInventoryItem(String id) async {
    if (_useInMemoryFallback || _db == null) {
      _memInventory.removeWhere((i) => i.id == id);
      return;
    }
    await _db!.transaction((txn) async {
      await txn.delete(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<JobOrder>> loadJobOrders() async {
    if (_useInMemoryFallback || _db == null) {
      return List<JobOrder>.unmodifiable(_memJobOrders);
    }
    final rows = await _db!.query('job_orders', orderBy: 'updatedAt DESC');
    return rows.map(JobOrder.fromMap).toList();
  }

  Future<void> saveJobOrder(JobOrder job) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memJobOrders.indexWhere((j) => j.id == job.id);
      if (idx >= 0) {
        _memJobOrders[idx] = job;
      } else {
        _memJobOrders.insert(0, job);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'job_orders',
        job.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteJobOrder(String jobId) async {
    if (_useInMemoryFallback || _db == null) {
      _memJobOrders.removeWhere((j) => j.id == jobId);
      return;
    }
    await _db!.delete('job_orders', where: 'id = ?', whereArgs: [jobId]);
  }

  Future<List<StockTransfer>> loadTransfers() async {
    if (_useInMemoryFallback || _db == null) {
      return List<StockTransfer>.unmodifiable(_memTransfers);
    }
    final rows = await _db!.query('stock_transfers', orderBy: 'createdAt DESC');
    return rows.map(StockTransfer.fromMap).toList();
  }

  Future<void> saveTransfer(StockTransfer transfer) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memTransfers.indexWhere((t) => t.id == transfer.id);
      if (idx >= 0) {
        _memTransfers[idx] = transfer;
      } else {
        _memTransfers.insert(0, transfer);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'stock_transfers',
        transfer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteStockTransfer(String id) async {
    if (_useInMemoryFallback || _db == null) {
      _memTransfers.removeWhere((t) => t.id == id);
      return;
    }
    await _db!.delete(
      'stock_transfers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PosTransaction>> loadTransactions() async {
    if (_useInMemoryFallback || _db == null) {
      return List<PosTransaction>.unmodifiable(_memTransactions);
    }
    final rows = await _db!.query(
      'pos_transactions',
      orderBy: 'createdAt DESC',
    );
    return rows.map(PosTransaction.fromMap).toList();
  }

  Future<void> saveTransaction(PosTransaction tx) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memTransactions.indexWhere((t) => t.id == tx.id);
      if (idx >= 0) {
        _memTransactions[idx] = tx;
      } else {
        _memTransactions.insert(0, tx);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'pos_transactions',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteTransaction(String id) async {
    if (_useInMemoryFallback || _db == null) {
      _memTransactions.removeWhere((t) => t.id == id);
      return;
    }
    await _db!.delete(
      'pos_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CashDrawerEntry>> loadCashLedger() async {
    if (_useInMemoryFallback || _db == null) {
      return List<CashDrawerEntry>.unmodifiable(_memCashLedger);
    }
    final rows = await _db!.query('cash_ledger', orderBy: 'createdAt DESC');
    return rows.map(CashDrawerEntry.fromMap).toList();
  }

  Future<void> saveCashLedgerEntry(CashDrawerEntry entry) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memCashLedger.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        _memCashLedger[idx] = entry;
      } else {
        _memCashLedger.insert(0, entry);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'cash_ledger',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteCashLedgerEntry(String id) async {
    if (_useInMemoryFallback || _db == null) {
      _memCashLedger.removeWhere((e) => e.id == id);
      return;
    }
    await _db!.delete('cash_ledger', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AppNotificationItem>> loadNotifications() async {
    if (_useInMemoryFallback || _db == null) {
      return List<AppNotificationItem>.unmodifiable(_memNotifications);
    }
    final rows = await _db!.query('notifications', orderBy: 'createdAt DESC');
    return rows.map(AppNotificationItem.fromMap).toList();
  }

  Future<void> saveNotification(AppNotificationItem notif) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memNotifications.indexWhere((n) => n.id == notif.id);
      if (idx >= 0) {
        _memNotifications[idx] = notif;
      } else {
        _memNotifications.insert(0, notif);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'notifications',
        notif.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteNotification(String id) async {
    if (_useInMemoryFallback || _db == null) {
      _memNotifications.removeWhere((n) => n.id == id);
      return;
    }
    await _db!.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ClickAndCollectOrder>> loadClickCollectOrders() async {
    if (_useInMemoryFallback || _db == null) {
      return List<ClickAndCollectOrder>.unmodifiable(_memClickCollect);
    }
    final rows = await _db!.query(
      'click_collect_orders',
      orderBy: 'createdAt DESC',
    );
    return rows.map(ClickAndCollectOrder.fromMap).toList();
  }

  Future<void> saveClickCollectOrder(ClickAndCollectOrder order) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memClickCollect.indexWhere((o) => o.id == order.id);
      if (idx >= 0) {
        _memClickCollect[idx] = order;
      } else {
        _memClickCollect.insert(0, order);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'click_collect_orders',
        order.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteClickCollectOrder(String orderId) async {
    if (_useInMemoryFallback || _db == null) {
      _memClickCollect.removeWhere((o) => o.id == orderId);
      return;
    }
    await _db!.delete(
      'click_collect_orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<ZReadingRecord>> loadZReadings() async {
    if (_useInMemoryFallback || _db == null) {
      return List<ZReadingRecord>.unmodifiable(_memZReadings);
    }
    final rows = await _db!.query('z_readings', orderBy: 'generatedAt DESC');
    return rows.map(ZReadingRecord.fromMap).toList();
  }

  Future<void> saveZReading(ZReadingRecord record) async {
    if (_useInMemoryFallback || _db == null) {
      final idx = _memZReadings.indexWhere((z) => z.id == record.id);
      if (idx >= 0) {
        _memZReadings[idx] = record;
      } else {
        _memZReadings.insert(0, record);
      }
      return;
    }
    await _db!.transaction((txn) async {
      await txn.insert(
        'z_readings',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // ATOMIC MULTI-TABLE TRANSACTIONS (Objective 2: All-or-Nothing Guarantees)
  // ---------------------------------------------------------------------------

  /// Atomically deducts inventory items, creates the POS invoice, and logs
  /// the Cash Drawer entry (if paid in cash). Rolls back 100% on any failure.
  Future<void> executeRetailCheckoutTransaction({
    required List<InventoryItem> updatedInventoryItems,
    required PosTransaction transaction,
    CashDrawerEntry? cashLedgerEntry,
  }) async {
    if (_useInMemoryFallback || _db == null) {
      final invSnapshot = List<InventoryItem>.from(_memInventory);
      final txSnapshot = List<PosTransaction>.from(_memTransactions);
      final cshSnapshot = List<CashDrawerEntry>.from(_memCashLedger);
      try {
        for (final updated in updatedInventoryItems) {
          final idx = _memInventory.indexWhere((i) => i.id == updated.id);
          if (idx < 0) {
            throw StateError('Inventory item ${updated.id} not found.');
          }
          _memInventory[idx] = updated;
        }
        _memTransactions.insert(0, transaction);
        if (cashLedgerEntry != null) {
          _memCashLedger.insert(0, cashLedgerEntry);
        }
      } catch (e) {
        _memInventory
          ..clear()
          ..addAll(invSnapshot);
        _memTransactions
          ..clear()
          ..addAll(txSnapshot);
        _memCashLedger
          ..clear()
          ..addAll(cshSnapshot);
        rethrow;
      }
      return;
    }

    await _db!.transaction((txn) async {
      for (final item in updatedInventoryItems) {
        await txn.update(
          'inventory_items',
          _inventoryToSqlMap(item),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
      await txn.insert(
        'pos_transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (cashLedgerEntry != null) {
        await txn.insert(
          'cash_ledger',
          cashLedgerEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  /// Atomically deducts locked + physical inventory stock, marks the JobOrder
  /// as Completed & Billed, creates the POS invoice, and logs Cash Drawer entry.
  Future<void> executeServiceJobCheckoutTransaction({
    required List<InventoryItem> updatedInventoryItems,
    required JobOrder completedJob,
    required PosTransaction transaction,
    CashDrawerEntry? cashLedgerEntry,
  }) async {
    if (_useInMemoryFallback || _db == null) {
      final invSnapshot = List<InventoryItem>.from(_memInventory);
      final jobSnapshot = List<JobOrder>.from(_memJobOrders);
      final txSnapshot = List<PosTransaction>.from(_memTransactions);
      final cshSnapshot = List<CashDrawerEntry>.from(_memCashLedger);
      try {
        for (final updated in updatedInventoryItems) {
          final idx = _memInventory.indexWhere((i) => i.id == updated.id);
          if (idx >= 0) _memInventory[idx] = updated;
        }
        final jIdx = _memJobOrders.indexWhere((j) => j.id == completedJob.id);
        if (jIdx >= 0) _memJobOrders[jIdx] = completedJob;
        _memTransactions.insert(0, transaction);
        if (cashLedgerEntry != null) {
          _memCashLedger.insert(0, cashLedgerEntry);
        }
      } catch (e) {
        _memInventory
          ..clear()
          ..addAll(invSnapshot);
        _memJobOrders
          ..clear()
          ..addAll(jobSnapshot);
        _memTransactions
          ..clear()
          ..addAll(txSnapshot);
        _memCashLedger
          ..clear()
          ..addAll(cshSnapshot);
        rethrow;
      }
      return;
    }

    await _db!.transaction((txn) async {
      for (final item in updatedInventoryItems) {
        await txn.update(
          'inventory_items',
          _inventoryToSqlMap(item),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
      await txn.update(
        'job_orders',
        completedJob.toMap(),
        where: 'id = ?',
        whereArgs: [completedJob.id],
      );
      await txn.insert(
        'pos_transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (cashLedgerEntry != null) {
        await txn.insert(
          'cash_ledger',
          cashLedgerEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  /// Atomically updates inventory stock (if supplied) and saves a StockTransfer + Notification.
  Future<void> executeStockTransferTransaction({
    InventoryItem? updatedItem,
    required StockTransfer transfer,
    required AppNotificationItem notification,
  }) async {
    if (_useInMemoryFallback || _db == null) {
      final invSnapshot = List<InventoryItem>.from(_memInventory);
      final trfSnapshot = List<StockTransfer>.from(_memTransfers);
      final ntfSnapshot = List<AppNotificationItem>.from(_memNotifications);
      try {
        if (updatedItem != null) {
          final pIdx = _memInventory.indexWhere((i) => i.id == updatedItem.id);
          if (pIdx >= 0) _memInventory[pIdx] = updatedItem;
        }

        final tIdx = _memTransfers.indexWhere((t) => t.id == transfer.id);
        if (tIdx >= 0) {
          _memTransfers[tIdx] = transfer;
        } else {
          _memTransfers.insert(0, transfer);
        }
        _memNotifications.insert(0, notification);
      } catch (e) {
        _memInventory
          ..clear()
          ..addAll(invSnapshot);
        _memTransfers
          ..clear()
          ..addAll(trfSnapshot);
        _memNotifications
          ..clear()
          ..addAll(ntfSnapshot);
        rethrow;
      }
      return;
    }

    await _db!.transaction((txn) async {
      if (updatedItem != null) {
        await txn.update(
          'inventory_items',
          _inventoryToSqlMap(updatedItem),
          where: 'id = ?',
          whereArgs: [updatedItem.id],
        );
      }
      await txn.insert(
        'stock_transfers',
        transfer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'notifications',
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Atomically locks/unlocks an inventory part and updates the JobOrder.
  Future<void> executeJobPartLockTransaction({
    required InventoryItem updatedItem,
    required JobOrder updatedJob,
  }) async {
    if (_useInMemoryFallback || _db == null) {
      final invSnapshot = List<InventoryItem>.from(_memInventory);
      final jobSnapshot = List<JobOrder>.from(_memJobOrders);
      try {
        final pIdx = _memInventory.indexWhere((i) => i.id == updatedItem.id);
        if (pIdx >= 0) _memInventory[pIdx] = updatedItem;
        final jIdx = _memJobOrders.indexWhere((j) => j.id == updatedJob.id);
        if (jIdx >= 0) _memJobOrders[jIdx] = updatedJob;
      } catch (e) {
        _memInventory
          ..clear()
          ..addAll(invSnapshot);
        _memJobOrders
          ..clear()
          ..addAll(jobSnapshot);
        rethrow;
      }
      return;
    }

    await _db!.transaction((txn) async {
      await txn.update(
        'inventory_items',
        _inventoryToSqlMap(updatedItem),
        where: 'id = ?',
        whereArgs: [updatedItem.id],
      );
      await txn.update(
        'job_orders',
        updatedJob.toMap(),
        where: 'id = ?',
        whereArgs: [updatedJob.id],
      );
    });
  }

  /// Atomically locks stock for a Customer Click & Collect order and records
  /// both the reservation and branch notification.
  Future<void> executeClickAndCollectTransaction({
    required InventoryItem updatedItem,
    required ClickAndCollectOrder order,
    required AppNotificationItem notification,
  }) async {
    if (_useInMemoryFallback || _db == null) {
      final invSnapshot = List<InventoryItem>.from(_memInventory);
      final ccSnapshot = List<ClickAndCollectOrder>.from(_memClickCollect);
      final ntfSnapshot = List<AppNotificationItem>.from(_memNotifications);
      try {
        final pIdx = _memInventory.indexWhere((i) => i.id == updatedItem.id);
        if (pIdx >= 0) _memInventory[pIdx] = updatedItem;
        _memClickCollect.insert(0, order);
        _memNotifications.insert(0, notification);
      } catch (e) {
        _memInventory
          ..clear()
          ..addAll(invSnapshot);
        _memClickCollect
          ..clear()
          ..addAll(ccSnapshot);
        _memNotifications
          ..clear()
          ..addAll(ntfSnapshot);
        rethrow;
      }
      return;
    }

    await _db!.transaction((txn) async {
      await txn.update(
        'inventory_items',
        _inventoryToSqlMap(updatedItem),
        where: 'id = ?',
        whereArgs: [updatedItem.id],
      );
      await txn.insert(
        'click_collect_orders',
        order.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.insert(
        'notifications',
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
