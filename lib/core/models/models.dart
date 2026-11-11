import 'dart:convert';

/// Accepts bool, int (0/1) or string ("true"/"1") — SQLite stores ints,
/// Firestore stores bools, so both shapes must parse.
bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

/// Clean ViewState pattern for reactive UI feedback
enum ViewState { idle, loading, success, error }

/// Live state of the inventory cloud sync (shown in the top-right chip)
enum InventorySyncStatus { synced, syncing, offline, error }

/// Branch context for Boss Arman MotoHub (Santa Cruz, Laguna)
enum BranchId {
  patimbao,
  pedroGuevara,
  both;

  String get displayName {
    switch (this) {
      case BranchId.patimbao:
        return 'Branch 1: Patimbao';
      case BranchId.pedroGuevara:
        return 'Branch 2: Pedro Guevara';
      case BranchId.both:
        return 'Both Branches (Master)';
    }
  }

  String get shortName {
    switch (this) {
      case BranchId.patimbao:
        return 'Patimbao';
      case BranchId.pedroGuevara:
        return 'P. Guevara';
      case BranchId.both:
        return 'Both';
    }
  }

  String get fullAddress {
    switch (this) {
      case BranchId.patimbao:
        return 'Brgy. Patimbao (Beside Alarcon Hollow Blocks), Santa Cruz, Laguna';
      case BranchId.pedroGuevara:
        return 'Pedro Guevara Ave, Santa Cruz, Laguna';
      case BranchId.both:
        return 'Patimbao & Pedro Guevara Ave, Santa Cruz, Laguna';
    }
  }

  String get terminalId {
    switch (this) {
      case BranchId.patimbao:
        return 'PAT-01';
      case BranchId.pedroGuevara:
        return 'PGV-02';
      case BranchId.both:
        return 'HQ-MASTER';
    }
  }
}

/// Role Architectures across Internal ERP App & Customer App
enum UserRole {
  admin,
  cashier,
  mechanic,
  customer;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.mechanic:
        return 'Mechanic';
      case UserRole.customer:
        return 'Customer';
    }
  }

  String get titleDescription {
    switch (this) {
      case UserRole.admin:
        return 'Master Executive Control';
      case UserRole.cashier:
        return 'POS & Drawer Station';
      case UserRole.mechanic:
        return 'Bay Lift & Inventory Workbench';
      case UserRole.customer:
        return 'Service Booking & Live Tracker';
    }
  }
}

/// 5-Stage Lifecycle State Machine for Repair Bay (plus cancelled terminal state)
enum JobStatus {
  received,
  inBay,
  waitingForParts,
  readyForPickup,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case JobStatus.received:
        return 'Received';
      case JobStatus.inBay:
        return 'In Progress';
      case JobStatus.waitingForParts:
        return 'Waiting for Parts';
      case JobStatus.readyForPickup:
        return 'Ready for Pickup';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get stepIndex {
    switch (this) {
      case JobStatus.received:
        return 0;
      case JobStatus.inBay:
        return 1;
      case JobStatus.waitingForParts:
        return 2;
      case JobStatus.readyForPickup:
        return 3;
      case JobStatus.completed:
        return 4;
      case JobStatus.cancelled:
        return -1;
    }
  }

  static const List<JobStatus> pipelineStages = [
    JobStatus.received,
    JobStatus.inBay,
    JobStatus.waitingForParts,
    JobStatus.readyForPickup,
    JobStatus.completed,
  ];
}

enum PaymentMethod {
  cash,
  gcash,
  split;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.split:
        return 'Split (Cash + GCash)';
    }
  }
}

enum TransferStatus {
  pendingApproval,
  approved,
  inTransit,
  delivered,
  rejected,
  cancelled;

  String get label {
    switch (this) {
      case TransferStatus.pendingApproval:
        return 'Pending Approval';
      case TransferStatus.approved:
        return 'Approved';
      case TransferStatus.inTransit:
        return 'In-Transit';
      case TransferStatus.delivered:
        return 'Received';
      case TransferStatus.rejected:
        return 'Rejected';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isPending => this == TransferStatus.pendingApproval;
  bool get isApproved => this == TransferStatus.approved;
  bool get isInTransit => this == TransferStatus.inTransit;
  bool get isDelivered => this == TransferStatus.delivered;
  bool get isCompleted => this == TransferStatus.delivered;
  bool get isRejected => this == TransferStatus.rejected;
  bool get isCancelled => this == TransferStatus.cancelled;
}

enum StockHealth {
  criticalOut,
  lowStock,
  healthy,
  overStock;

  String get label {
    switch (this) {
      case StockHealth.criticalOut:
        return 'Out of Stock';
      case StockHealth.lowStock:
        return 'Low-Stock';
      case StockHealth.healthy:
        return 'In-Stock';
      case StockHealth.overStock:
        return 'Overstock';
    }
  }
}

// ---------------------------------------------------------------------------
// Defensive Numeric Sanitizers (Prevents NaN, Infinity, null, or < 0 crashes)
// ---------------------------------------------------------------------------

double _safeNonNegativeDouble(dynamic raw, [double fallback = 0.0]) {
  if (raw == null) return fallback;
  final val = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString());
  if (val == null || val.isNaN || val.isInfinite || val < 0.0) {
    return fallback;
  }
  return val;
}

double _safeSignedDouble(dynamic raw, [double fallback = 0.0]) {
  if (raw == null) return fallback;
  final val = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString());
  if (val == null || val.isNaN || val.isInfinite) {
    return fallback;
  }
  return val;
}

int _safeNonNegativeInt(dynamic raw, [int fallback = 0]) {
  if (raw == null) return fallback;
  final val = (raw is num) ? raw.toInt() : int.tryParse(raw.toString());
  if (val == null || val < 0) return fallback;
  return val;
}

class StaffAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final UserRole role;
  final BranchId assignedBranch;
  final String shiftStatus; // 'On Duty', 'In Bay', 'Off Shift', 'Emergency Absence'
  final String? coveredByStaff;
  final String authProvider; // 'password' | 'google'
  final String? fcmToken;
  final bool mustChangePassword;
  final String? photoUrl;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? recoverableUntil;
  final String? termsAcceptedVersion;
  final DateTime? termsAcceptedAt;
  final DateTime createdAt;

  const StaffAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    required this.assignedBranch,
    this.shiftStatus = 'On Duty',
    this.coveredByStaff,
    this.authProvider = 'password',
    this.fcmToken,
    this.mustChangePassword = false,
    this.photoUrl,
    this.isDeleted = false,
    this.deletedAt,
    this.recoverableUntil,
    this.termsAcceptedVersion,
    this.termsAcceptedAt,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    if (f.isNotEmpty && l.isNotEmpty) return '$f$l';
    if (f.isNotEmpty) return f;
    if (username.trim().isNotEmpty) return username.trim()[0].toUpperCase();
    return '?';
  }

  bool get isSoftDeleted =>
      isDeleted &&
      (recoverableUntil == null || DateTime.now().isBefore(recoverableUntil!));

  bool get isPermanentlyPurged =>
      isDeleted &&
      recoverableUntil != null &&
      DateTime.now().isAfter(recoverableUntil!);

  StaffAccount copyWith({
    String? password,
    String? shiftStatus,
    BranchId? assignedBranch,
    String? coveredByStaff,
    bool clearCoveredByStaff = false,
    String? authProvider,
    String? fcmToken,
    bool? mustChangePassword,
    String? photoUrl,
    bool clearPhotoUrl = false,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? recoverableUntil,
    bool clearDeletion = false,
    String? termsAcceptedVersion,
    DateTime? termsAcceptedAt,
  }) {
    return StaffAccount(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      password: password ?? this.password,
      role: role,
      assignedBranch: assignedBranch ?? this.assignedBranch,
      shiftStatus: shiftStatus ?? this.shiftStatus,
      coveredByStaff:
          clearCoveredByStaff ? null : (coveredByStaff ?? this.coveredByStaff),
      authProvider: authProvider ?? this.authProvider,
      fcmToken: fcmToken ?? this.fcmToken,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      isDeleted: clearDeletion ? false : (isDeleted ?? this.isDeleted),
      deletedAt: clearDeletion ? null : (deletedAt ?? this.deletedAt),
      recoverableUntil:
          clearDeletion ? null : (recoverableUntil ?? this.recoverableUntil),
      termsAcceptedVersion: termsAcceptedVersion ?? this.termsAcceptedVersion,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'password': password,
        'role': role.name,
        'assignedBranch': assignedBranch.name,
        'shiftStatus': shiftStatus,
        'coveredByStaff': coveredByStaff,
        'authProvider': authProvider,
        'fcmToken': fcmToken,
        'mustChangePassword': mustChangePassword ? 1 : 0,
        'photoUrl': photoUrl,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedAt': deletedAt?.toIso8601String(),
        'recoverableUntil': recoverableUntil?.toIso8601String(),
        'termsAcceptedVersion': termsAcceptedVersion,
        'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestoreDoc() => {
        'uid': id,
        'email': email,
        'displayName': fullName,
        'role': role.name,
        'branchId': assignedBranch == BranchId.patimbao
            ? 'branch_1_patimbao'
            : (assignedBranch == BranchId.both
                ? 'branch_headquarters'
                : 'branch_2_pedro_guevara'),
        'fcmToken': fcmToken,
        'mustChangePassword': mustChangePassword,
        'photoUrl': photoUrl,
        'isDeleted': isDeleted,
        'deletedAt': deletedAt?.toIso8601String(),
        'recoverableUntil': recoverableUntil?.toIso8601String(),
        'termsAcceptedVersion': termsAcceptedVersion,
        'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory StaffAccount.fromMap(Map<String, dynamic> map) => StaffAccount(
        id: (map['id'] as String?) ?? (map['uid'] as String?) ?? '',
        firstName: (map['firstName'] as String?) ?? '',
        lastName: (map['lastName'] as String?) ?? '',
        username: (map['username'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        password: (map['password'] as String?) ?? '',
        role: UserRole.values.firstWhere(
          (e) => e.name == map['role'],
          orElse: () => UserRole.customer,
        ),
        assignedBranch: BranchId.values.firstWhere(
          (e) =>
              e.name == map['assignedBranch'] ||
              (map['branchId'] == 'branch_1_patimbao' &&
                  e == BranchId.patimbao) ||
              (map['branchId'] == 'branch_headquarters' &&
                  e == BranchId.both) ||
              (map['branchId'] == 'branch_2_pedro_guevara' &&
                  e == BranchId.pedroGuevara),
          orElse: () => BranchId.patimbao,
        ),
        shiftStatus: (map['shiftStatus'] as String?) ?? 'On Duty',
        coveredByStaff: map['coveredByStaff'] as String?,
        authProvider: (map['authProvider'] as String?) ?? 'password',
        fcmToken: map['fcmToken'] as String?,
        mustChangePassword: _asBool(map['mustChangePassword']),
        photoUrl: map['photoUrl'] as String?,
        isDeleted: _asBool(map['isDeleted']),
        deletedAt: map['deletedAt'] != null
            ? DateTime.tryParse(map['deletedAt'].toString())
            : null,
        recoverableUntil: map['recoverableUntil'] != null
            ? DateTime.tryParse(map['recoverableUntil'].toString())
            : null,
        termsAcceptedVersion: map['termsAcceptedVersion'] as String?,
        termsAcceptedAt: map['termsAcceptedAt'] != null
            ? DateTime.tryParse(map['termsAcceptedAt'].toString())
            : null,
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

class InventoryItem {
  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String category; // 'CVT Tuning', 'Engine Oils', 'Thai Bolts', 'Tires & Brakes', 'Electrical'
  final double price;
  final double costPrice;
  final int stockPatimbao;
  final int stockPedroGuevara;
  final int lockedPatimbao;
  final int lockedPedroGuevara;
  final int minThreshold;
  final int maxThreshold;
  final String rack;
  final String shelf;
  final String bin;
  final String compatibleModels;
  final bool isDeleted;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stockPatimbao,
    required this.stockPedroGuevara,
    this.lockedPatimbao = 0,
    this.lockedPedroGuevara = 0,
    this.minThreshold = 5,
    this.maxThreshold = 25,
    required this.rack,
    required this.shelf,
    required this.bin,
    required this.compatibleModels,
    this.isDeleted = false,
  });

  /// Exact Shelf Bin Coordinates (e.g., "Rack B • Shelf 2 • Bin 04")
  String get shelfCoordinates => '$rack • $shelf • $bin';
  String get shortShelfCoordinates => '$rack • $bin';

  int rawStockFor(BranchId branch) {
    if (branch == BranchId.patimbao) return stockPatimbao;
    if (branch == BranchId.pedroGuevara) return stockPedroGuevara;
    return stockPatimbao + stockPedroGuevara;
  }

  int lockedStockFor(BranchId branch) {
    if (branch == BranchId.patimbao) return lockedPatimbao;
    if (branch == BranchId.pedroGuevara) return lockedPedroGuevara;
    return lockedPatimbao + lockedPedroGuevara;
  }

  /// Available stock that can be sold at POS or attached to new jobs (excluding mechanic-locked parts)
  int availableStockFor(BranchId branch) {
    final avail = rawStockFor(branch) - lockedStockFor(branch);
    return avail < 0 ? 0 : avail;
  }

  StockHealth healthFor(BranchId branch) {
    final avail = availableStockFor(branch);
    if (avail <= 0) return StockHealth.criticalOut;
    if (avail <= minThreshold) return StockHealth.lowStock;
    return StockHealth.healthy;
  }

  InventoryItem copyWith({
    String? name,
    String? category,
    double? price,
    double? costPrice,
    int? stockPatimbao,
    int? stockPedroGuevara,
    int? lockedPatimbao,
    int? lockedPedroGuevara,
    int? minThreshold,
    int? maxThreshold,
    String? rack,
    String? shelf,
    String? bin,
    String? compatibleModels,
    bool? isDeleted,
  }) {
    return InventoryItem(
      id: id,
      sku: sku,
      barcode: barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockPatimbao: stockPatimbao ?? this.stockPatimbao,
      stockPedroGuevara: stockPedroGuevara ?? this.stockPedroGuevara,
      lockedPatimbao: lockedPatimbao ?? this.lockedPatimbao,
      lockedPedroGuevara: lockedPedroGuevara ?? this.lockedPedroGuevara,
      minThreshold: minThreshold ?? this.minThreshold,
      maxThreshold: maxThreshold ?? this.maxThreshold,
      rack: rack ?? this.rack,
      shelf: shelf ?? this.shelf,
      bin: bin ?? this.bin,
      compatibleModels: compatibleModels ?? this.compatibleModels,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sku': sku,
        'barcode': barcode,
        'name': name,
        'category': category,
        'price': price,
        'costPrice': costPrice,
        'stockPatimbao': stockPatimbao,
        'stockPedroGuevara': stockPedroGuevara,
        'lockedPatimbao': lockedPatimbao,
        'lockedPedroGuevara': lockedPedroGuevara,
        'minThreshold': minThreshold,
        'maxThreshold': maxThreshold,
        'rack': rack,
        'shelf': shelf,
        'bin': bin,
        'compatibleModels': compatibleModels,
        'isDeleted': isDeleted ? 1 : 0,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
        id: (map['id'] as String?) ?? '',
        sku: (map['sku'] as String?) ?? '',
        barcode: (map['barcode'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        category: (map['category'] as String?) ?? 'CVT Tuning',
        price: _safeNonNegativeDouble(map['price']),
        costPrice: _safeNonNegativeDouble(map['costPrice']),
        stockPatimbao: _safeNonNegativeInt(map['stockPatimbao']),
        stockPedroGuevara: _safeNonNegativeInt(map['stockPedroGuevara']),
        lockedPatimbao: _safeNonNegativeInt(map['lockedPatimbao']),
        lockedPedroGuevara: _safeNonNegativeInt(map['lockedPedroGuevara']),
        minThreshold: _safeNonNegativeInt(map['minThreshold'], 5),
        maxThreshold: _safeNonNegativeInt(map['maxThreshold'], 25),
        rack: (map['rack'] as String?) ?? 'Unassigned',
        shelf: (map['shelf'] as String?) ?? 'Unassigned',
        bin: (map['bin'] as String?) ?? 'Unassigned',
        compatibleModels: (map['compatibleModels'] as String?) ?? 'Universal',
        isDeleted: map['isDeleted'] == true ||
            map['isDeleted'] == 1 ||
            map['is_deleted'] == true ||
            map['is_deleted'] == 1,
      );
}

class AttachedJobPart {
  final String partId;
  final String sku;
  final String name;
  final double unitPrice;
  final int quantity;
  final String shelfCoordinates;

  const AttachedJobPart({
    required this.partId,
    required this.sku,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.shelfCoordinates,
  });

  double get lineTotal => unitPrice * quantity;

  AttachedJobPart copyWith({int? quantity}) => AttachedJobPart(
        partId: partId,
        sku: sku,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        shelfCoordinates: shelfCoordinates,
      );

  Map<String, dynamic> toMap() => {
        'partId': partId,
        'sku': sku,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'shelfCoordinates': shelfCoordinates,
      };

  factory AttachedJobPart.fromMap(Map<String, dynamic> map) => AttachedJobPart(
        partId: (map['partId'] as String?) ?? '',
        sku: (map['sku'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        unitPrice: _safeNonNegativeDouble(map['unitPrice']),
        quantity: _safeNonNegativeInt(map['quantity'], 1),
        shelfCoordinates: (map['shelfCoordinates'] as String?) ?? 'Unassigned',
      );
}

class JobOrder {
  final String id;
  final BranchId branch;
  final String customerName;
  final String customerUsername;
  final String customerPhone;
  final String bikeModel;
  final String plateNumber;
  final String serviceType;
  final String issueDescription;
  final String assignedMechanic;
  final String? mechanicId;
  final JobStatus status;
  final List<AttachedJobPart> attachedParts;
  final double laborFee;
  final String? extraRepairNote;
  final double extraRepairFee;
  final bool extraRepairApproved;
  final bool isBilled;
  final String? preferredSchedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobOrder({
    required this.id,
    required this.branch,
    required this.customerName,
    this.customerUsername = '',
    required this.customerPhone,
    required this.bikeModel,
    required this.plateNumber,
    required this.serviceType,
    required this.issueDescription,
    required this.assignedMechanic,
    this.mechanicId,
    required this.status,
    required this.attachedParts,
    required this.laborFee,
    this.extraRepairNote,
    this.extraRepairFee = 0,
    this.extraRepairApproved = false,
    this.isBilled = false,
    this.preferredSchedule,
    required this.createdAt,
    required this.updatedAt,
  });

  double get partsSubtotal =>
      attachedParts.fold(0.0, (sum, p) => sum + p.lineTotal);

  double get effectiveLaborFee =>
      laborFee + (extraRepairApproved ? extraRepairFee : 0.0);

  double get totalEstimate => partsSubtotal + effectiveLaborFee;

  JobOrder copyWith({
    BranchId? branch,
    String? assignedMechanic,
    String? mechanicId,
    JobStatus? status,
    List<AttachedJobPart>? attachedParts,
    double? laborFee,
    String? extraRepairNote,
    bool clearExtraRepair = false,
    double? extraRepairFee,
    bool? extraRepairApproved,
    bool? isBilled,
    DateTime? updatedAt,
  }) {
    return JobOrder(
      id: id,
      branch: branch ?? this.branch,
      customerName: customerName,
      customerUsername: customerUsername,
      customerPhone: customerPhone,
      bikeModel: bikeModel,
      plateNumber: plateNumber,
      serviceType: serviceType,
      issueDescription: issueDescription,
      assignedMechanic: assignedMechanic ?? this.assignedMechanic,
      mechanicId: mechanicId ?? this.mechanicId,
      status: status ?? this.status,
      attachedParts: attachedParts ?? this.attachedParts,
      laborFee: laborFee ?? this.laborFee,
      extraRepairNote:
          clearExtraRepair ? null : (extraRepairNote ?? this.extraRepairNote),
      extraRepairFee:
          clearExtraRepair ? 0.0 : (extraRepairFee ?? this.extraRepairFee),
      extraRepairApproved: clearExtraRepair
          ? false
          : (extraRepairApproved ?? this.extraRepairApproved),
      isBilled: isBilled ?? this.isBilled,
      preferredSchedule: preferredSchedule,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch': branch.name,
        'customerName': customerName,
        'customerUsername': customerUsername,
        'customerPhone': customerPhone,
        'bikeModel': bikeModel,
        'plateNumber': plateNumber,
        'serviceType': serviceType,
        'issueDescription': issueDescription,
        'assignedMechanic': assignedMechanic,
        'mechanicId': mechanicId,
        'status': status.name,
        'attachedPartsJson':
            jsonEncode(attachedParts.map((e) => e.toMap()).toList()),
        'laborFee': laborFee,
        'extraRepairNote': extraRepairNote,
        'extraRepairFee': extraRepairFee,
        'extraRepairApproved': extraRepairApproved ? 1 : 0,
        'isBilled': isBilled ? 1 : 0,
        'preferredSchedule': preferredSchedule,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JobOrder.fromMap(Map<String, dynamic> map) {
    final partsList = <AttachedJobPart>[];
    final rawJson = map['attachedPartsJson'] as String?;
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        for (final item in decoded) {
          partsList.add(AttachedJobPart.fromMap(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    return JobOrder(
      id: (map['id'] as String?) ?? '',
      branch: BranchId.values.firstWhere(
        (e) => e.name == map['branch'],
        orElse: () => BranchId.patimbao,
      ),
      customerName: (map['customerName'] as String?) ?? '',
      customerUsername: (map['customerUsername'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      bikeModel: (map['bikeModel'] as String?) ?? '',
      plateNumber: (map['plateNumber'] as String?) ?? '',
      serviceType: (map['serviceType'] as String?) ?? 'General Service',
      issueDescription: (map['issueDescription'] as String?) ?? '',
      assignedMechanic: (map['assignedMechanic'] as String?) ?? 'Unassigned',
      mechanicId: map['mechanicId'] as String?,
      status: JobStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JobStatus.received,
      ),
      attachedParts: partsList,
      laborFee: _safeNonNegativeDouble(map['laborFee']),
      extraRepairNote: map['extraRepairNote'] as String?,
      extraRepairFee: _safeNonNegativeDouble(map['extraRepairFee']),
      extraRepairApproved: (map['extraRepairApproved'] as int? ?? 0) == 1,
      isBilled: (map['isBilled'] as int? ?? 0) == 1,
      preferredSchedule: map['preferredSchedule'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class StockTransfer {
  final String id;
  final String partId;
  final String sku;
  final String partName;
  final int quantity;
  final BranchId fromBranch;
  final BranchId toBranch;
  final TransferStatus status;
  final String initiatedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? confirmedBy;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final String? rejectedBy;
  final DateTime? rejectedAt;

  const StockTransfer({
    required this.id,
    required this.partId,
    required this.sku,
    required this.partName,
    required this.quantity,
    required this.fromBranch,
    required this.toBranch,
    required this.status,
    required this.initiatedBy,
    this.approvedBy,
    this.approvedAt,
    this.confirmedBy,
    required this.createdAt,
    this.confirmedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
  });

  StockTransfer copyWith({
    TransferStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? rejectionReason,
    String? rejectedBy,
    DateTime? rejectedAt,
  }) =>
      StockTransfer(
        id: id,
        partId: partId,
        sku: sku,
        partName: partName,
        quantity: quantity,
        fromBranch: fromBranch,
        toBranch: toBranch,
        status: status ?? this.status,
        initiatedBy: initiatedBy,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
        confirmedBy: confirmedBy ?? this.confirmedBy,
        createdAt: createdAt,
        confirmedAt: confirmedAt ?? this.confirmedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        rejectedBy: rejectedBy ?? this.rejectedBy,
        rejectedAt: rejectedAt ?? this.rejectedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'partId': partId,
        'sku': sku,
        'partName': partName,
        'quantity': quantity,
        'fromBranch': fromBranch.name,
        'toBranch': toBranch.name,
        'status': status.name,
        'initiatedBy': initiatedBy,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'confirmedBy': confirmedBy,
        'createdAt': createdAt.toIso8601String(),
        'confirmedAt': confirmedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
        'rejectedBy': rejectedBy,
        'rejectedAt': rejectedAt?.toIso8601String(),
      };

  factory StockTransfer.fromMap(Map<String, dynamic> map) => StockTransfer(
        id: (map['id'] as String?) ?? '',
        partId: (map['partId'] as String?) ?? '',
        sku: (map['sku'] as String?) ?? '',
        partName: (map['partName'] as String?) ?? '',
        quantity: _safeNonNegativeInt(map['quantity'], 1),
        fromBranch: BranchId.values.firstWhere(
          (e) => e.name == map['fromBranch'],
          orElse: () => BranchId.pedroGuevara,
        ),
        toBranch: BranchId.values.firstWhere(
          (e) => e.name == map['toBranch'],
          orElse: () => BranchId.patimbao,
        ),
        status: TransferStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => TransferStatus.pendingApproval,
        ),
        initiatedBy: (map['initiatedBy'] as String?) ?? '',
        approvedBy: map['approvedBy'] as String?,
        approvedAt: map['approvedAt'] != null
            ? DateTime.tryParse(map['approvedAt'] as String)
            : null,
        confirmedBy: map['confirmedBy'] as String?,
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        confirmedAt: map['confirmedAt'] != null
            ? DateTime.tryParse(map['confirmedAt'] as String)
            : null,
        rejectionReason: map['rejectionReason'] as String?,
        rejectedBy: map['rejectedBy'] as String?,
        rejectedAt: map['rejectedAt'] != null
            ? DateTime.tryParse(map['rejectedAt'] as String)
            : null,
      );
}

class CartItem {
  final InventoryItem item;
  final int quantity;

  const CartItem({required this.item, required this.quantity});

  double get subtotal => item.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(item: item, quantity: quantity ?? this.quantity);
}

class PosTransaction {
  final String id;
  final BranchId branch;
  final String cashierName;
  final String customerName;
  final String itemsSummary;
  final double partsSubtotal;
  final double laborTotal;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double amountTendered;
  final double changeAmount;
  final double cashAmount;
  final double gcashAmount;
  final String? gcashRef;
  final String? gcashProofUrl;
  final String? linkedJobOrderId;
  final DateTime createdAt;
  final bool isSynced;

  const PosTransaction({
    required this.id,
    required this.branch,
    required this.cashierName,
    required this.customerName,
    required this.itemsSummary,
    required this.partsSubtotal,
    required this.laborTotal,
    required this.totalAmount,
    required this.paymentMethod,
    required this.amountTendered,
    required this.changeAmount,
    this.cashAmount = 0.0,
    this.gcashAmount = 0.0,
    this.gcashRef,
    this.gcashProofUrl,
    this.linkedJobOrderId,
    required this.createdAt,
    this.isSynced = true,
  });

  /// Formatted payment string for receipts: e.g. "GCash [Ref: ****1234]" or "Split: ₱1,000 Cash / ₱500 GCash"
  String get formattedPaymentDetails {
    final maskedRef = (gcashRef != null && gcashRef!.trim().isNotEmpty)
        ? (gcashRef!.length >= 4
            ? '****${gcashRef!.substring(gcashRef!.length - 4)}'
            : gcashRef!)
        : 'N/A';

    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash (Tendered: ₱${amountTendered.toStringAsFixed(2)})';
      case PaymentMethod.gcash:
        return 'GCash [Ref: $maskedRef]';
      case PaymentMethod.split:
        final cAmt = cashAmount > 0 ? cashAmount : (totalAmount - gcashAmount);
        final gAmt = gcashAmount > 0 ? gcashAmount : (totalAmount - cashAmount);
        return 'Split: ₱${cAmt.toStringAsFixed(2)} Cash / ₱${gAmt.toStringAsFixed(2)} GCash [Ref: $maskedRef]';
    }
  }

  /// Compatibility alias for change amount
  double get changeDue => changeAmount;

  PosTransaction copyWith({bool? isSynced}) => PosTransaction(
        id: id,
        branch: branch,
        cashierName: cashierName,
        customerName: customerName,
        itemsSummary: itemsSummary,
        partsSubtotal: partsSubtotal,
        laborTotal: laborTotal,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        changeAmount: changeAmount,
        cashAmount: cashAmount,
        gcashAmount: gcashAmount,
        gcashRef: gcashRef,
        gcashProofUrl: gcashProofUrl,
        linkedJobOrderId: linkedJobOrderId,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch': branch.name,
        'cashierName': cashierName,
        'customerName': customerName,
        'itemsSummary': itemsSummary,
        'partsSubtotal': partsSubtotal,
        'laborTotal': laborTotal,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod.name,
        'amountTendered': amountTendered,
        'changeAmount': changeAmount,
        'cashAmount': cashAmount,
        'gcashAmount': gcashAmount,
        'gcashRef': gcashRef,
        'gcashProofUrl': gcashProofUrl,
        'linkedJobOrderId': linkedJobOrderId,
        'createdAt': createdAt.toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
      };

  factory PosTransaction.fromMap(Map<String, dynamic> map) {
    final method = PaymentMethod.values.firstWhere(
      (e) => e.name == map['paymentMethod'],
      orElse: () => PaymentMethod.cash,
    );
    final tot = _safeNonNegativeDouble(map['totalAmount']);
    final cAmt = _safeNonNegativeDouble(map['cashAmount']);
    final gAmt = _safeNonNegativeDouble(map['gcashAmount']);

    return PosTransaction(
      id: (map['id'] as String?) ?? '',
      branch: BranchId.values.firstWhere(
        (e) => e.name == map['branch'],
        orElse: () => BranchId.patimbao,
      ),
      cashierName: (map['cashierName'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? 'Walk-in Customer',
      itemsSummary: (map['itemsSummary'] as String?) ?? '',
      partsSubtotal: _safeNonNegativeDouble(map['partsSubtotal']),
      laborTotal: _safeNonNegativeDouble(map['laborTotal']),
      totalAmount: tot,
      paymentMethod: method,
      amountTendered: _safeNonNegativeDouble(map['amountTendered']),
      changeAmount: _safeNonNegativeDouble(map['changeAmount']),
      cashAmount: cAmt > 0 ? cAmt : (method == PaymentMethod.cash ? tot : 0.0),
      gcashAmount: gAmt > 0 ? gAmt : (method == PaymentMethod.gcash ? tot : 0.0),
      gcashRef: map['gcashRef'] as String?,
      gcashProofUrl: map['gcashProofUrl'] as String?,
      linkedJobOrderId: map['linkedJobOrderId'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      isSynced: (map['isSynced'] as int? ?? 1) == 1,
    );
  }
}

enum CashLedgerType {
  morningFloat,
  cashSale,
  serviceCash,
  cashout,
  reconciliationAudit;

  static const CashLedgerType pettyCashOut = CashLedgerType.cashout;

  String get label {
    switch (this) {
      case CashLedgerType.morningFloat:
        return 'Starting Cash';
      case CashLedgerType.cashSale:
        return 'Retail Cash In';
      case CashLedgerType.serviceCash:
        return 'Service Billing Cash In';
      case CashLedgerType.cashout:
        return 'Cashout';
      case CashLedgerType.reconciliationAudit:
        return 'Shift Reconciliation';
    }
  }
}

class CashDrawerEntry {
  final String id;
  final BranchId branch;
  final CashLedgerType type;
  final String description;
  final double amount; // positive for inflow, negative for outflow
  final String staffName;
  final DateTime createdAt;

  const CashDrawerEntry({
    required this.id,
    required this.branch,
    required this.type,
    required this.description,
    required this.amount,
    required this.staffName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch': branch.name,
        'type': type.name,
        'description': description,
        'amount': amount,
        'staffName': staffName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CashDrawerEntry.fromMap(Map<String, dynamic> map) => CashDrawerEntry(
        id: (map['id'] as String?) ?? '',
        branch: BranchId.values.firstWhere(
          (e) => e.name == map['branch'],
          orElse: () => BranchId.patimbao,
        ),
        type: (map['type'] == 'pettyCashOut' || map['type'] == 'cashout')
            ? CashLedgerType.cashout
            : CashLedgerType.values.firstWhere(
                (e) => e.name == map['type'],
                orElse: () => CashLedgerType.cashSale,
              ),
        description: (map['description'] as String?) ?? '',
        amount: _safeSignedDouble(map['amount']),
        staffName: (map['staffName'] as String?) ?? '',
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final String category; // 'transfer', 'low_stock', 'job_order', 'booking', 'reservation', 'drawer', 'chat'
  final BranchId branch;
  final bool isRead;
  final DateTime createdAt;
  final UserRole? targetRole;
  final String? targetUserId;
  final Map<String, dynamic>? payload;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.branch,
    this.isRead = false,
    required this.createdAt,
    this.targetRole,
    this.targetUserId,
    this.payload,
  });

  AppNotificationItem copyWith({
    bool? isRead,
    UserRole? targetRole,
    String? targetUserId,
    Map<String, dynamic>? payload,
  }) =>
      AppNotificationItem(
        id: id,
        title: title,
        message: message,
        category: category,
        branch: branch,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        targetRole: targetRole ?? this.targetRole,
        targetUserId: targetUserId ?? this.targetUserId,
        payload: payload ?? this.payload,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'branch': branch.name,
        'isRead': isRead ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'targetRole': targetRole?.name,
        'targetUserId': targetUserId,
        'payload': payload != null ? jsonEncode(payload) : null,
      };

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedPayload;
    final rawPayload = map['payload'];
    if (rawPayload is Map) {
      parsedPayload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        parsedPayload = jsonDecode(rawPayload) as Map<String, dynamic>;
      } catch (_) {}
    }

    UserRole? role;
    final rawRole = map['targetRole'] as String?;
    if (rawRole != null && rawRole.isNotEmpty) {
      try {
        role = UserRole.values.firstWhere(
          (r) => r.name.toLowerCase() == rawRole.toLowerCase(),
        );
      } catch (_) {}
    }

    return AppNotificationItem(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'general',
      branch: BranchId.values.firstWhere(
        (e) => e.name == map['branch'],
        orElse: () => BranchId.patimbao,
      ),
      isRead: map['isRead'] == true || (map['isRead'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      targetRole: role,
      targetUserId: map['targetUserId'] as String?,
      payload: parsedPayload,
    );
  }
}

class OfflineSyncTask {
  final String id;
  final String operation;
  final String summary;
  final BranchId branch;
  final DateTime timestamp;
  final bool synced;

  const OfflineSyncTask({
    required this.id,
    required this.operation,
    required this.summary,
    required this.branch,
    required this.timestamp,
    this.synced = false,
  });

  OfflineSyncTask copyWith({bool? synced}) => OfflineSyncTask(
        id: id,
        operation: operation,
        summary: summary,
        branch: branch,
        timestamp: timestamp,
        synced: synced ?? this.synced,
      );
}

/// Click & Collect Reservation Contract for Customer App (App B)
class ClickAndCollectOrder {
  final String id;
  final String? customerId;
  final String customerUsername;
  final String customerName;
  final String customerPhone;
  final BranchId pickupBranch;
  final String partId;
  final String sku;
  final String partName;
  final int quantity;
  final double unitPrice;
  final String status; // 'Pending', 'Confirmed', 'Ready for Pickup', 'Completed', 'Cancelled', 'Expired'
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ClickAndCollectOrder({
    required this.id,
    this.customerId,
    required this.customerUsername,
    required this.customerName,
    required this.customerPhone,
    required this.pickupBranch,
    required this.partId,
    required this.sku,
    required this.partName,
    required this.quantity,
    required this.unitPrice,
    this.status = 'Pending',
    required this.createdAt,
    this.expiresAt,
  });

  String get reservationId => id;
  String get itemId => partId;
  BranchId get branchId => pickupBranch;
  int get qty => quantity;

  double get totalAmount => unitPrice * quantity;

  bool get isPending => status == 'Pending' || status == 'Reserved';
  bool get isConfirmed => status == 'Confirmed';
  bool get isReady => status == 'Ready for Pickup' || status.contains('Ready');
  bool get isCompleted => status == 'Completed' || status.startsWith('Claimed');
  bool get isCancelled => status == 'Cancelled' || status.startsWith('Cancelled');
  bool get isExpired =>
      status == 'Expired' ||
      (expiresAt != null && DateTime.now().isAfter(expiresAt!) && !isCompleted && !isCancelled);

  bool get isHoldActive => !isCompleted && !isCancelled && !isExpired;
  bool get canCustomerCancel => (isPending || isConfirmed) && !isCompleted && !isCancelled;
  bool get canStaffConfirm => isPending;
  bool get canStaffMarkReady => isPending || isConfirmed;
  bool get canStaffComplete => !isCompleted && !isCancelled && !isExpired;

  ClickAndCollectOrder copyWith({
    String? status,
    DateTime? expiresAt,
    String? customerName,
    String? customerPhone,
  }) =>
      ClickAndCollectOrder(
        id: id,
        customerId: customerId,
        customerUsername: customerUsername,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        pickupBranch: pickupBranch,
        partId: partId,
        sku: sku,
        partName: partName,
        quantity: quantity,
        unitPrice: unitPrice,
        status: status ?? this.status,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'reservationId': id,
        'customerId': customerId ?? customerUsername,
        'customerUsername': customerUsername,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'pickupBranch': pickupBranch.name,
        'branchId': pickupBranch.name,
        'partId': partId,
        'itemId': partId,
        'sku': sku,
        'partName': partName,
        'quantity': quantity,
        'qty': quantity,
        'unitPrice': unitPrice,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': (expiresAt ?? createdAt.add(const Duration(hours: 48))).toIso8601String(),
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'customerId': customerId ?? customerUsername,
        'customerUsername': customerUsername,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'pickupBranch': pickupBranch.name,
        'partId': partId,
        'sku': sku,
        'partName': partName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': (expiresAt ?? createdAt.add(const Duration(hours: 48))).toIso8601String(),
      };

  factory ClickAndCollectOrder.fromMap(Map<String, dynamic> map) {
    final created = DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now();
    final rawExpires = map['expiresAt'] != null ? DateTime.tryParse(map['expiresAt'].toString()) : null;
    return ClickAndCollectOrder(
      id: (map['id'] as String?) ?? (map['reservationId'] as String?) ?? '',
      customerId: (map['customerId'] as String?) ?? (map['customerUsername'] as String?),
      customerUsername: (map['customerUsername'] as String?) ?? (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      pickupBranch: BranchId.values.firstWhere(
        (e) => e.name == map['pickupBranch'] || e.name == map['branchId'],
        orElse: () => BranchId.patimbao,
      ),
      partId: (map['partId'] as String?) ?? (map['itemId'] as String?) ?? '',
      sku: (map['sku'] as String?) ?? '',
      partName: (map['partName'] as String?) ?? '',
      quantity: _safeNonNegativeInt(map['quantity'] ?? map['qty'], 1),
      unitPrice: _safeNonNegativeDouble(map['unitPrice']),
      status: (map['status'] as String?) ?? 'Pending',
      createdAt: created,
      expiresAt: rawExpires ?? created.add(const Duration(hours: 48)),
    );
  }
}

class ZReadingRecord {
  final String id;
  final BranchId branch;
  final String terminalId;
  final String generatedBy;

  final double morningFloat;
  final double grossCashSales;
  final double gcashVaultCollections;
  final double cashoutOutflows;
  double get pettyCashOutflows => cashoutOutflows; // backwards compatibility

  final double totalGrossRevenue;
  final double expectedPhysicalCash;
  final double actualPhysicalCash;
  final double cashDiscrepancy; // actualPhysicalCash - expectedPhysicalCash
  final String reconciliationNote;
  final int totalTransactions;

  final DateTime generatedAt;

  const ZReadingRecord({
    required this.id,
    required this.branch,
    required this.terminalId,
    required this.generatedBy,
    required this.morningFloat,
    required this.grossCashSales,
    required this.gcashVaultCollections,
    required this.cashoutOutflows,
    required this.totalGrossRevenue,
    required this.expectedPhysicalCash,
    this.actualPhysicalCash = 0.0,
    this.cashDiscrepancy = 0.0,
    this.reconciliationNote = '',
    required this.totalTransactions,
    required this.generatedAt,
  });

  /// Cash that *should* be in the drawer: float + cash sales - cashouts.
  double get netCashInDrawer =>
      morningFloat + grossCashSales - cashoutOutflows;

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch': branch.name,
        'terminalId': terminalId,
        'generatedBy': generatedBy,
        'morningFloat': morningFloat,
        'grossCashSales': grossCashSales,
        'gcashVaultCollections': gcashVaultCollections,
        'cashoutOutflows': cashoutOutflows,
        'pettyCashOutflows': cashoutOutflows,
        'totalGrossRevenue': totalGrossRevenue,
        'expectedPhysicalCash': expectedPhysicalCash,
        'actualPhysicalCash': actualPhysicalCash,
        'cashDiscrepancy': cashDiscrepancy,
        'reconciliationNote': reconciliationNote,
        'totalTransactions': totalTransactions,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory ZReadingRecord.fromMap(Map<String, dynamic> map) => ZReadingRecord(
        id: (map['id'] as String?) ?? '',
        branch: BranchId.values.firstWhere(
          (e) => e.name == map['branch'],
          orElse: () => BranchId.patimbao,
        ),
        terminalId: (map['terminalId'] as String?) ?? '',
        generatedBy: (map['generatedBy'] as String?) ?? '',
        morningFloat: _safeNonNegativeDouble(map['morningFloat']),
        grossCashSales: _safeNonNegativeDouble(map['grossCashSales']),
        gcashVaultCollections:
            _safeNonNegativeDouble(map['gcashVaultCollections']),
        cashoutOutflows: _safeNonNegativeDouble(
            map['cashoutOutflows'] ?? map['pettyCashOutflows']),
        totalGrossRevenue: _safeNonNegativeDouble(map['totalGrossRevenue']),
        expectedPhysicalCash:
            _safeNonNegativeDouble(map['expectedPhysicalCash']),
        actualPhysicalCash:
            _safeNonNegativeDouble(map['actualPhysicalCash']),
        cashDiscrepancy: _safeSignedDouble(map['cashDiscrepancy']),
        reconciliationNote: (map['reconciliationNote'] as String?) ?? '',
        totalTransactions: _safeNonNegativeInt(map['totalTransactions']),
        generatedAt:
            DateTime.tryParse((map['generatedAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}

/// Chat thread between allowed pairs:
/// 1) Customer <-> Admin
/// 2) Customer <-> Assigned Mechanic
class ChatThread {
  final String id;
  final List<String> participantIds; // e.g. [customerId, 'admin'] or [customerId, mechanicId]
  final List<String> authUids; // Firebase Auth UIDs for Firestore security rules
  final List<String> roles; // ['customer', 'admin'] or ['customer', 'mechanic']
  final String? jobOrderId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts; // {userId: unreadCount}
  final Map<String, String>? participantNames; // {userId: displayName}
  final Map<String, String>? participantUsernames; // {userId: username}
  final DateTime createdAt;

  const ChatThread({
    required this.id,
    required this.participantIds,
    this.authUids = const [],
    this.roles = const [],
    this.jobOrderId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCounts = const {},
    this.participantNames,
    this.participantUsernames,
    required this.createdAt,
  });

  ChatThread copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    Map<String, int>? unreadCounts,
    List<String>? authUids,
    Map<String, String>? participantNames,
    Map<String, String>? participantUsernames,
  }) =>
      ChatThread(
        id: id,
        participantIds: participantIds,
        authUids: authUids ?? this.authUids,
        roles: roles,
        jobOrderId: jobOrderId,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        participantNames: participantNames ?? this.participantNames,
        participantUsernames: participantUsernames ?? this.participantUsernames,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'participantIds': participantIds,
        'authUids': authUids,
        'roles': roles,
        'jobOrderId': jobOrderId,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'unreadCounts': unreadCounts,
        'participantNames': participantNames,
        'participantUsernames': participantUsernames,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatThread.fromMap(Map<String, dynamic> map) {
    final unread = <String, int>{};
    final rawUnread = map['unreadCounts'];
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        unread[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }

    Map<String, String>? names;
    final rawNames = map['participantNames'];
    if (rawNames is Map) {
      names = {};
      rawNames.forEach((k, v) {
        names![k.toString()] = v.toString();
      });
    }

    Map<String, String>? usernames;
    final rawUsernames = map['participantUsernames'];
    if (rawUsernames is Map) {
      usernames = {};
      rawUsernames.forEach((k, v) {
        usernames![k.toString()] = v.toString();
      });
    }

    return ChatThread(
      id: (map['id'] as String?) ?? '',
      participantIds: List<String>.from(map['participantIds'] as List? ?? []),
      authUids: List<String>.from(map['authUids'] as List? ?? []),
      roles: List<String>.from(map['roles'] as List? ?? []),
      jobOrderId: map['jobOrderId'] as String?,
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.tryParse(map['lastMessageAt'].toString())
          : null,
      unreadCounts: unread,
      participantNames: names,
      participantUsernames: usernames,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Chat message with optional image URL for attachments
class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String senderRole;
  final String? senderName;
  final String? senderUsername;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> readBy;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    this.senderName,
    this.senderUsername,
    this.text,
    this.imageUrl,
    required this.createdAt,
    this.readBy = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'threadId': threadId,
        'senderId': senderId,
        'senderRole': senderRole,
        'senderName': senderName,
        'senderUsername': senderUsername,
        'text': text,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'readBy': readBy,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: (map['id'] as String?) ?? '',
        threadId: (map['threadId'] as String?) ?? '',
        senderId: (map['senderId'] as String?) ?? '',
        senderRole: (map['senderRole'] as String?) ?? '',
        senderName: map['senderName'] as String?,
        senderUsername: map['senderUsername'] as String?,
        text: map['text'] as String?,
        imageUrl: map['imageUrl'] as String?,
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        readBy: List<String>.from(map['readBy'] as List? ?? []),
      );
}

