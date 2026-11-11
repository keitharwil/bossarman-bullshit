================================================================================
BOSS ARMAN MOTOHUB — PRODUCTION & THESIS DEFENSE ARCHITECTURE REFERENCE
Multi-Branch Motorcycle Parts, POS, Inventory & Service Management System
Branches:
  • Branch 1: Brgy. Patimbao, Santa Cruz, Laguna (POS-PAT-01)
  • Branch 2: P. Guevara Ave., Santa Cruz, Laguna (POS-PGV-02)
================================================================================

1. ARCHITECTURAL OVERVIEW & DECOUPLED ENTRY POINTS
--------------------------------------------------------------------------------
This codebase is structured into two decoupled application targets sharing a
unified, hardened core (`lib/core/`):

  • App A — Internal ERP / POS Terminal (`lib/main_internal.dart`)
    Exclusively serves internal personnel (Admin: Boss Arman, Cashier: Keith,
    Mechanic: Lance). Customer accounts are strictly blocked at both the
    authentication layer (`LoginScreen`) and the router layer (`RoleRouterScreen`).

  • App B — Customer Facing App (`lib/main_customer.dart`)
    Dedicated rider & customer application providing Google One-Tap / Google
    Sign-In, standard Email/Password authentication, Live 4-Stage Service
    Tracker, Appointment Booking, and Atomic Click & Collect Reservations.

HOW TO RUN OR BUILD EACH APPLICATION TARGET:
  • Run Internal ERP/POS App (App A):
      flutter run -t lib/main_internal.dart
  • Run Customer Facing App (App B):
      flutter run -t lib/main_customer.dart
  • Build Internal ERP/POS APK:
      flutter build apk -t lib/main_internal.dart
  • Build Customer Facing APK:
      flutter build apk -t lib/main_customer.dart

================================================================================
HOW TO DEBUG ON A REAL ANDROID DEVICE (USB DEBUGGING GUIDE)
================================================================================
You have enabled USB Debugging in Developer Options on your Android device.
Follow these exact steps to connect, install, and live-debug Boss Arman MotoHub:

STEP 1: CONNECT YOUR ANDROID DEVICE VIA USB
  • Connect your phone or tablet to your PC using a reliable USB data cable.
  • On your phone, swipe down the notification shade and ensure the USB connection
    mode is set to "File Transfer" (MTP) rather than "Charging only".

STEP 2: AUTHORIZE USB DEBUGGING (RSA KEY PROMPT ON PHONE)
  • Unlock your phone. A security pop-up dialog will appear:
      "Allow USB debugging? The computer's RSA key fingerprint is: XX:XX:XX..."
  • Check the box: [x] "Always allow from this computer"
  • Tap "Allow" (or "OK").
  • Tip: If the prompt doesn't appear, unplug the USB cable and plug it back in,
    or run `adb devices` in your PC terminal to trigger the prompt.

STEP 3: VERIFY YOUR DEVICE IS DETECTED
  • Open PowerShell or Command Prompt in this project directory and run:
      flutter devices
    OR:
      adb devices
  • You should see your Android device listed (e.g. `SM-A525F`, `Redmi Note`, `Pixel`,
    or a device serial ID with status `device`).
  • Troubleshooting:
    - If status says 'unauthorized': Look at your phone screen and tap 'Allow'.
    - If no device appears: Ensure your phone manufacturer's OEM USB drivers are installed
      (Windows Device Manager > Portable Devices / Android Device).
    - If ADB is unresponsive, restart the ADB daemon:
        adb kill-server
        adb start-server
    - For Xiaomi / Redmi / POCO (MIUI / HyperOS): You MUST also enable
      "Install via USB" and "USB debugging (Security settings)" in Developer Options.
    - For Oppo / Realme / Vivo: Ensure "Disable Permission Monitoring" is checked
      if app installation is blocked.

STEP 4: LAUNCH THE APP IN DEBUG MODE ON YOUR PHONE
  • If only one Android device is connected to your PC:
      - To debug Internal ERP / POS App (App A):
          flutter run -t lib/main_internal.dart
      - To debug Customer Facing App (App B):
          flutter run -t lib/main_customer.dart

  • If multiple devices or emulators are connected:
      Run `flutter devices` to find your target device ID, then pass `-d <DEVICE_ID>`:
      - Internal ERP / POS App:
          flutter run -d <DEVICE_ID> -t lib/main_internal.dart
      - Customer Facing App:
          flutter run -d <DEVICE_ID> -t lib/main_customer.dart

STEP 5: INTERACTIVE LIVE DEBUGGING SHORTCUTS (IN TERMINAL)
  While the app is running on your phone, press these single-key shortcuts in your terminal:
  • 'r' : HOT RELOAD (instantly applies UI/code edits in ~1 second without resetting app state)
  • 'R' : HOT RESTART (restarts app lifecycle and resets in-memory view models)
  • 'p' : Toggle debug painting / layout boundaries on your phone screen
  • 'v' : Launch Flutter DevTools in your web browser (inspect widget tree, memory, profiler)
  • 'h' : Show all available terminal debugging commands
  • 'q' : Detach and quit the debug session

STEP 6: VIEWING LIVE LOGS & EXCEPTIONS
  • All `print()`, `debugPrint()`, SQLite transaction logs, and error stack traces
    stream directly into your terminal in real time.
  • To view system-level Android logs while debugging:
      flutter logs
    OR:
      adb logcat -s flutter

INITIAL ADMINISTRATIVE & STAFF SEEDS (CLEAN ZERO-MOCK DATABASE):
  The SQLite database (`boss_arman_motohub_prod_v3.db`) initializes completely
  empty of mock inventory items, job orders, transfers, POS invoices, or ledger
  entries. Only the 3 required staff accounts are seeded on first boot:
  • Admin    : Username `bossarman`  | Password `admin123`
  • Cashier  : Username `cashier01`  | Password `cashier123`
  • Mechanic : Username `mechanic01` | Password `mech123`

================================================================================
2. FILE-BY-FILE CODE & FUNCTION DIRECTORY
================================================================================

--------------------------------------------------------------------------------
FILE: lib/main_internal.dart
PURPOSE: App A Entry Point — Internal ERP, POS & Multi-Branch Inventory System
--------------------------------------------------------------------------------
Classes & Functions:
  • main():
      Initializes Flutter bindings, locks device orientations, configures
      Catppuccin Mocha system UI overlay styles, and launches
      `BossArmanInternalApp`.
  • BossArmanInternalApp (StatelessWidget):
      - build(BuildContext context):
          Creates the `ChangeNotifierProvider<MotoHubViewModel>` initialized
          with `MotoHubViewModel(isCustomerApp: false)..initializeApp()` and
          boots `MaterialApp` with `AppTheme.darkTheme` and
          `SplashScreen(isCustomerApp: false)`.

--------------------------------------------------------------------------------
FILE: lib/main_customer.dart
PURPOSE: App B Entry Point — Customer Facing App (Service Tracker & Click & Collect)
--------------------------------------------------------------------------------
Classes & Functions:
  • main():
      Initializes Flutter bindings, locks orientations, sets system UI overlay
      styles, and launches `BossArmanCustomerApp`.
  • BossArmanCustomerApp (StatelessWidget):
      - build(BuildContext context):
          Creates the `ChangeNotifierProvider<MotoHubViewModel>` initialized
          with `MotoHubViewModel(isCustomerApp: true)..initializeApp()` and
          boots `MaterialApp` with `AppTheme.darkTheme` and
          `SplashScrdarteen(isCustomerApp: true)`.

--------------------------------------------------------------------------------
FILE: lib/main.dart
PURPOSE: Default Flutter Entry Point & Barrel Export for Both App Targets
--------------------------------------------------------------------------------
Classes & Functions:
  • main():
      Delegates default `flutter run` execution to `internal_entry.main()`.
  • BossArmanMotoHubApp (StatelessWidget):
      Backwards-compatible wrapper that renders `BossArmanInternalApp`.

--------------------------------------------------------------------------------
FILE: lib/core/models/models.dart
      (Re-exported by lib/models/models.dart)
PURPOSE: Shared Domain Models, Enums & Defensive JSON/SQLite Serialization
--------------------------------------------------------------------------------
Enums & Extensions:
  • BranchId { patimbao, pedroGuevara, both } + BranchIdX:
      - displayName, shortName, address, terminalId
  • UserRole { admin, cashier, mechanic, customer } + UserRoleX:
      - label, badgeLabel, subtitle
  • ViewState { idle, loading, success, error }
  • StockHealth { healthy, lowStock, criticalOut, overStock } + StockHealthX
  • TransferStatus { inTransit, delivered } + TransferStatusX
  • JobStatus { received, inBay, waitingForParts, readyForPickup, completed }
    + JobStatusX
  • PaymentMethod { cash, gcash } + PaymentMethodX
  • CashLedgerType { morningFloat, cashSale, serviceCash, pettyCashOut,
    reconciliationAudit } + CashLedgerTypeX

Domain Model Classes & Methods:
  • StaffAccount:
      - Fields: id, firstName, lastName, username, email, password, role,
        assignedBranch, shiftStatus, coveredByStaff, authProvider ('password' |
        'google'), createdAt.
      - Getters: `fullName`, `initials`.
      - Methods: `copyWith(...)`, `toMap()`, `StaffAccount.fromMap(...)`.
  • InventoryItem:
      - Fields: id, sku, barcode, name, category, price, costPrice,
        stockPatimbao, stockPedroGuevara, lockedPatimbao, lockedPedroGuevara,
        minThreshold, maxThreshold, rack, shelf, bin, compatibleModels.
      - Getters: `shelfCoordinates`, `shortShelfCoordinates`.
      - Methods: `rawStockFor(BranchId)`, `lockedStockFor(BranchId)`,
        `availableStockFor(BranchId)`, `healthFor(BranchId)`, `copyWith(...)`,
        `toMap()`, `InventoryItem.fromMap(...)` (sanitizes NaN/Infinity/negative
        values).
  • AttachedJobPart:
      - Fields: partId, sku, name, unitPrice, quantity, shelfCoordinates.
      - Getter: `subtotal`.
      - Methods: `copyWith(...)`, `toMap()`, `AttachedJobPart.fromMap(...)`.
  • JobOrder:
      - Fields: id, branch, customerName, customerUsername, customerPhone,
        bikeModel, plateNumber, serviceType, issueDescription, assignedMechanic,
        status, attachedParts, laborFee, extraRepairNote, extraRepairFee,
        extraRepairApproved, isBilled, preferredSchedule, createdAt, updatedAt.
      - Getters: `partsSubtotal`, `effectiveLaborFee`, `totalEstimate`.
      - Methods: `copyWith(...)`, `toMap()`, `JobOrder.fromMap(...)`.
  • StockTransfer:
      - Fields: id, partId, sku, partName, quantity, fromBranch, toBranch,
        status, initiatedBy, confirmedBy, createdAt, confirmedAt.
      - Methods: `copyWith(...)`, `toMap()`, `StockTransfer.fromMap(...)`.
  • CartItem:
      - Fields: item (InventoryItem), quantity.
      - Getter: `subtotal`.
      - Method: `copyWith(...)`.
  • PosTransaction:
      - Fields: id, branch, cashierName, customerName, itemsSummary,
        partsSubtotal, laborTotal, totalAmount, paymentMethod, amountTendered,
        changeAmount, gcashRef, linkedJobOrderId, createdAt, isSynced.
      - Methods: `copyWith(...)`, `toMap()`, `PosTransaction.fromMap(...)`.
  • CashDrawerEntry:
      - Fields: id, branch, type, description, amount, staffName, createdAt.
      - Methods: `toMap()`, `CashDrawerEntry.fromMap(...)`.
  • AppNotificationItem:
      - Fields: id, title, message, category, branch, isRead, createdAt.
      - Methods: `copyWith(...)`, `toMap()`, `AppNotificationItem.fromMap(...)`.
  • OfflineSyncTask:
      - Fields: id, operation, summary, branch, timestamp, synced.
      - Methods: `copyWith(...)`.
  • ClickAndCollectOrder:
      - Fields: id, customerUsername, customerName, customerPhone, pickupBranch,
        partId, sku, partName, quantity, unitPrice, status, createdAt.
      - Getter: `totalAmount`.
      - Methods: `toMap()`, `ClickAndCollectOrder.fromMap(...)`.

--------------------------------------------------------------------------------
FILE: lib/core/services/local_database_service.dart
      (Re-exported by lib/services/local_database_service.dart)
PURPOSE: Hardened SQLite + Web Storage Engine with Atomic ACID Transactions
--------------------------------------------------------------------------------
Classes & Functions:
  • LocalDatabaseService (Singleton `LocalDatabaseService.instance`):
      - initializeAndPreWarm({void Function(double, String)? onProgress}):
          Initializes SQLite (`boss_arman_motohub_prod_v3.db`, version 3) on
          native platforms or SharedPreferences JSON store on Web/test, and
          seeds ONLY the 3 initial administrative/staff accounts if empty.
      - _createSchema(Database db):
          Creates tables: `staff`, `inventory`, `job_orders`, `transfers`,
          `transactions`, `cash_ledger`, `notifications`, and
          `click_collect_orders`.
      - loadStaff(), saveStaff(StaffAccount)
      - loadInventory(), saveInventoryItem(InventoryItem),
        deleteInventoryItem(String id)
      - loadJobOrders(), saveJobOrder(JobOrder)
      - loadTransfers(), saveTransfer(StockTransfer)
      - loadTransactions(), saveTransaction(PosTransaction)
      - loadCashLedger(), saveCashLedgerEntry(CashDrawerEntry)
      - loadNotifications(), saveNotification(AppNotificationItem)
      - loadClickCollectOrders(), saveClickCollectOrder(ClickAndCollectOrder)
      - executeRetailCheckoutTransaction({...}):
          ATOMIC TRANSACTION: Deducts branch inventory for all cart items,
          inserts the official OR invoice into `transactions`, and logs a
          `cash_ledger` entry if paid in cash. Rolls back completely on error.
      - executeServiceJobCheckoutTransaction({...}):
          ATOMIC TRANSACTION: Deducts locked parts from branch inventory, marks
          the `JobOrder` as completed & billed, inserts the `PosTransaction`,
          and logs a `CashDrawerEntry` if paid in cash.
      - executeStockTransferTransaction({...}):
          ATOMIC TRANSACTION: Updates branch inventory stock (deducting on
          initiation or crediting on confirmation), upserts the
          `StockTransfer`, and inserts an `AppNotificationItem`.
      - executeJobPartLockTransaction({...}):
          ATOMIC TRANSACTION: Updates locked part quantity on `InventoryItem`
          and updates `attachedParts` on `JobOrder`.
      - executeClickAndCollectTransaction({...}):
          ATOMIC TRANSACTION: Locks reserved stock at the selected pickup
          branch, inserts the `ClickAndCollectOrder`, and creates a branch
          notification.
      - initialAdminAndStaffSeeds():
          Returns ONLY the 3 required staff accounts (`bossarman`, `cashier01`,
          `mechanic01`).

--------------------------------------------------------------------------------
FILE: lib/core/theme/app_theme.dart
      (Re-exported by lib/theme/app_theme.dart)
PURPOSE: Material 3 Design System (Catppuccin Mocha + Champagne Gold) & Widgets
--------------------------------------------------------------------------------
Classes & Functions:
  • AppPalette:
      Defines semantic color tokens (`crust`, `mantle`, `base`, `surface0`,
      `surface1`, `surface2`, `champagneGold`, `warmGold`, `textHigh`,
      `textBody`, `textMuted`, `inactive`, `success`, `warning`, `danger`,
      `info`, `goldGradient`, `darkGlassGradient`).
  • AppTheme:
      - expressiveTheme (M3EThemeData):
          Configures Material 3 Expressive (`material_3_expressive`) color tokens
          and shape morphing synchronized with Catppuccin Mocha + Champagne Gold.
      - darkTheme (ThemeData):
          Configures Material 3 dark theme with `GoogleFonts.plusJakartaSans`,
          `CardThemeData`, `NavigationBarThemeData`, `SegmentedButtonThemeData`,
          `InputDecorationTheme`, `FilledButtonThemeData`, and `DialogThemeData`.
  • GoldGradientButton (StatelessWidget):
      Overflow-safe primary CTA button with Champagne Gold gradient, loading
      spinner state, and `TextOverflow.ellipsis` protection.
  • MotoHubEmptyState (StatelessWidget):
      Production-grade Material 3 empty-state component displaying an icon badge,
      bold title, descriptive subtitle, and optional primary `FilledButton.icon`
      call-to-action.

--------------------------------------------------------------------------------
FILE: lib/core/utils/formatters.dart
      (Re-exported by lib/utils/formatters.dart)
PURPOSE: Currency/Date Formatters & Defensive Form Input Validators
--------------------------------------------------------------------------------
Classes & Functions:
  • AppFormatters:
      - sanitizeDouble(double? value, {double fallback = 0.0}):
          Eliminates `NaN` and `Infinity` before formatting or calculation.
      - currency(num amount): Formats `₱1,234.56` safely.
      - currencyWhole(num amount): Formats `₱1,235` safely.
      - dateTime(DateTime dt): Formats `MMM dd, yyyy • hh:mm a`.
      - shortDate(DateTime dt): Formats `MMM dd, hh:mm a`.
      - timeOnly(DateTime dt): Formats `hh:mm a`.
  • AppValidators:
      - requiredField(String? value, [String fieldName])
      - username(String? value)
      - password(String? value)
      - email(String? value)
      - phone(String? value)
      - plateNumber(String? value): Rejects empty or malformed plate numbers.
      - positiveInt(String? value, {int min = 1, int? max})
      - nonNegativeInt(String? value)
      - positiveAmount(String? value): Prevents <= 0, NaN, or Infinity amounts.
      - nonNegativeAmount(String? value): Prevents < 0, NaN, or Infinity.
      - gcashReference(String? value): Enforces 8–13 digit numeric reference.

--------------------------------------------------------------------------------
FILE: lib/viewmodels/motohub_viewmodel.dart
PURPOSE: Central State Management, Business Rules & Atomic Transaction Controller
--------------------------------------------------------------------------------
Classes & Functions:
  • MotoHubViewModel (ChangeNotifier):
      - Getters & Computed Analytics:
          `viewState`, `statusMessage`, `isInitialized`, `currentUser`,
          `activeBranch`, `isBranchLockedForCurrentUser`, `isOnline`,
          `isSyncing`, `offlineQueue`, `pendingSyncCount`, `staffList`,
          `allInventory`, `clickCollectOrders`, `customerClickCollectOrders`,
          `customerClickAndCollectOrders`, `mechanicsList`,
          `filteredInventory`, `branchJobOrders`, `customerJobOrders`,
          `filteredBranchJobOrders`, `activeBayBikes`, `maxBayCapacity`,
          `serviceToPosQueue`, `branchTransactions`, `branchTodayGross`,
          `branchCashSalesTotal`, `branchGcashVaultTotal`, `branchCashLedger`,
          `branchMorningFloat`, `branchPettyCashOutTotal`,
          `branchPhysicalCashInDrawer`, `branchLowStockItems`,
          `branchOverstockItems`, `incomingInTransitTransfers`, `allTransfers`,
          `branchTransfers`, `branchNotifications`, `unreadNotificationCount`,
          `cartTotal`, `cartItemCount`.
      - Lifecycle & Session Methods:
          `initializeApp({void Function(double, String)? onProgress})`,
          `login(String username, String password, {bool allowCustomerRole, bool internalOnly, bool customerOnly})`,
          `registerCustomerAccount({required String firstName, required String lastName, required String username, required String email, required String password, BranchId preferredBranch})`,
          `signInCustomerWithGoogle({required String email, required String displayName, BranchId preferredBranch})`,
          `logout()`, `switchBranch(BranchId branch)` (blocks Cashiers &
          Mechanics from switching away from their single assigned branch),
          `setActiveBranch(BranchId branch)`.
      - Offline-First Connectivity & Sync Methods:
          `toggleConnectivity()`, `syncPendingLogs()`.
      - Search, Filters & Barcode Lookup Methods:
          `setInventorySearchQuery(String query)`,
          `setSelectedPosCategory(String category)`,
          `setSelectedJobStatusFilter(JobStatus? status)`,
          `findPartByCode(String code)`.
      - Master Inventory & Two-Phase Inter-Branch Transfer Methods:
          `addOrUpdateInventoryItem(InventoryItem item)`,
          `deleteInventoryItem(String id)`,
          `initiateStockTransfer({required InventoryItem item, required BranchId fromBranch, required BranchId toBranch, required int quantity})`,
          `confirmTransferDelivery(StockTransfer transfer)`.
      - Mechanic Bay Lifecycle & Atomic Parts Attachment Methods:
          `createJobOrder({...})` (booked from Customer App),
          `acceptJobOrder(String jobId, {String? mechanicName})` (accepts
          incoming Customer Job Order into Repair Bay by Admin or Mechanic),
          `acceptClickAndCollectOrder(String orderId)` (accepts incoming
          Customer Click & Collect Part Order),
          `updateJobOrderStatus(String jobId, JobStatus newStatus)`,
          `attachPartToJobOrder({required String jobId, required InventoryItem part, int quantity = 1})`,
          `removeAttachedPartFromJob({required String jobId, required String partId})`,
          `updateJobLaborFee({required String jobId, required double laborFee, String? extraRepairNote, double? extraRepairFee})`,
          `approveCustomerExtraRepair(String jobId)`.
      - Customer Click & Collect Method:
          `createClickAndCollectOrder({required InventoryItem part, BranchId? pickupBranch, BranchId? branch, required int quantity, required String customerPhone})`.
      - Cashier Retail POS & Atomic Service-to-POS Auto-Billing Methods:
          `addToCart(InventoryItem item, {int quantity = 1})`,
          `updateCartQuantity(String itemId, int newQty)`,
          `clearCart()`,
          `processRetailCheckout({required PaymentMethod paymentMethod, required double amountTendered, String customerName, String? gcashRef})`,
          `processServiceJobCheckout({required JobOrder job, required PaymentMethod paymentMethod, required double amountTendered, String? gcashRef})`.
      - Cash Drawer & Shift Reconciliation Audit Methods:
          `addMorningFloat(double amount)`,
          `recordPettyCashOut({required String description, required double amount})`,
          `verifyAdminOverridePassword(String password)`,
          `logShiftReconciliationAudit({required double countedCash, required double expectedCash, String? adminOverrideBy})`.
      - Staff & Notification Methods:
          `createStaffAccount({...})` (enforces single-branch assignment for
          Cashiers and Mechanics),
          `updateStaffAssignedBranch({required StaffAccount staff, required BranchId newBranch})`
          (Admin-only branch reassignment for Cashiers & Mechanics),
          `cycleStaffShiftStatus(StaffAccount staff)`,
          `markNotificationRead(String id)`,
          `markAllNotificationsRead()`.

--------------------------------------------------------------------------------
FILE: lib/views/splash_screen.dart
PURPOSE: Facebook/Meta-Inspired Professional Animated Splash Screen
--------------------------------------------------------------------------------
Classes & Functions:
  • SplashScreen (StatefulWidget):
      - Fields: `isCustomerApp` (bool).
      - _bootSequence():
          Runs `MotoHubViewModel.initializeApp` in parallel with entrance &
          concentric halo ring animations (no progress bar or percentage text),
          verifies `if (!mounted) return;`, and transitions smoothly to
          `CustomerShellScreen` / `CustomerAuthScreen` (App B) or
          `RoleRouterScreen` / `LoginScreen` (App A).
      - build(BuildContext context):
          Centerpiece animated emblem with `_EmblemHaloPainter` ripple rings,
          3-dot wave pulse indicator, and bottom-anchored brand signature.

--------------------------------------------------------------------------------
FILE: lib/views/login_screen.dart
PURPOSE: Internal ERP & POS Authentication Screen (Admin, Cashier, Mechanic Only)
--------------------------------------------------------------------------------
Classes & Functions:
  • LoginScreen (StatefulWidget):
      - _quickLogin(String user, String pass):
          Populates quick-switch credentials for the 3 internal seed accounts
          (`bossarman`/`admin123`, `cashier01`/`cashier123`,
          `mechanic01`/`mech123`).
      - _submitLogin():
          Validates credentials with `customerOnly: false`, checks
          `if (!mounted) return;`, and navigates to `RoleRouterScreen`.
      - build(BuildContext context):
          Zero-overflow `LayoutBuilder` + `SingleChildScrollView` login card.

--------------------------------------------------------------------------------
FILE: lib/views/role_router_screen.dart
PURPOSE: Internal Role Router (Admin, Cashier, Mechanic)
--------------------------------------------------------------------------------
Classes & Functions:
  • RoleRouterScreen (StatelessWidget):
      - build(BuildContext context):
          Routes `UserRole.admin` to `AdminShellScreen`, `UserRole.cashier` to
          `CashierShellScreen`, and `UserRole.mechanic` to `MechanicShellScreen`.
          Redirects unauthenticated or non-internal roles back to `LoginScreen`.

--------------------------------------------------------------------------------
FILE: lib/views/admin/admin_shell_screen.dart
PURPOSE: Boss Arman Executive ERP Shell (4 Bottom Tabs + M3E Expressive Lists)
--------------------------------------------------------------------------------
Classes & Functions:
  • AdminShellScreen (StatefulWidget):
      Hosts Material 3 Expressive `M3ENavigationBar`, `M3ESegmentedButton<BranchId>`
      branch switcher, top-right QR Scanner + `NotificationBellAction`, and quick
      POS/Drawer modals.
  • _AdminExecutiveDashboardTab (StatelessWidget):
      Executive Command Center with Today's Gross vs Bikes in Bay, Quick Actions
      (`[POS]`, `[Inventory]`, `[Scan]`, `[Drawer]`), Critical Low-Stock
      Alerts (`M3ECardList`), and Live Repair Bay Queue (`M3ECardList`) with
      one-tap `[Accept Job Order]` CTA.
  • _AdminMasterInventoryTab (StatelessWidget):
      Side-by-side Branch 1 & Branch 2 stock matrix in `M3ECardList.of(...)`,
      Two-Phase Transfer initiation dialog, and Add/Edit Inventory Part dialog.
  • _AdminJobsKanbanTab (StatefulWidget):
      Jobs & Orders Acceptance Hub rendered with `M3ECardList.of(...)` allowing
      Admin to accept incoming Customer Service Job Orders and Customer Click &
      Collect Part Orders and manage the 5-stage bay lifecycle. Adding/creating
      job orders is strictly removed from Admin.
  • AddStaffScreen (4th Tab):
      Executive Profile card and Multi-Branch Staff Directory (`M3ECardList`)
      with Admin-only single-branch assignment switchers (`Branch 1: Patimbao`
      vs `Branch 2: P. Guevara`) for every Cashier and Mechanic.

--------------------------------------------------------------------------------
FILE: lib/views/admin/add_staff_screen.dart
PURPOSE: Dedicated Staff Directory & Admin-Only Branch Assignment Manager
--------------------------------------------------------------------------------
Classes & Functions:
  • AddStaffScreen (StatefulWidget):
      - Renders the Multi-Branch Staff Directory (`M3ECardList`) with shift
        status cycling AND an interactive Admin-only `M3ESegmentedButton<BranchId>`
        on each Cashier and Mechanic card so Boss Arman (Admin) can reassign
        their single branch (`Branch 1: Patimbao` or `Branch 2: P. Guevara`).
      - _AddStaffFormSheet:
          Validates first name, last name, username, email, password, internal
          role (`cashier`, `mechanic`, `admin`), and assigned branch (restricting
          Cashiers & Mechanics to a single branch), then persists to SQLite via
          `vm.createStaffAccount`.

--------------------------------------------------------------------------------
FILE: lib/views/cashier/cashier_shell_screen.dart
PURPOSE: Cashier Terminal Shell (Locked to Single Assigned Branch)
--------------------------------------------------------------------------------
Classes & Functions:
  • CashierShellScreen (StatefulWidget):
      5-tab Material 3 Expressive `M3ENavigationBar` shell locked to the
      Cashier's single assigned branch, featuring a read-only Assigned Branch
      lock badge in the AppBar, top-right QR scanner button, and
      `NotificationBellAction`.
  • CashierPosTabView (StatelessWidget):
      - Displays a read-only Assigned Branch banner when logged in as a Cashier
        (or branch switcher when opened by Admin Override).
      - _openCheckoutModal(BuildContext context):
          Launches checkout sheet for Cash or GCash and displays Official
          Receipt dialog upon atomic SQLite commit.
      - Responsive 360dp–600dp+ POS catalog list (`M3ECardList`) monitoring only
        the Cashier's assigned branch stock.
  • _CashierServiceBillingTab (StatelessWidget):
      - _billServiceJob(BuildContext, MotoHubViewModel, JobOrder, PaymentMethod):
          Executes atomic service billing (`vm.processServiceJobCheckout`) inside
          an `M3ECardList` queue for the Cashier's assigned branch.
  • CashierDrawerTabView (StatefulWidget):
      - _showPettyCashDialog(BuildContext, MotoHubViewModel):
          Records petty cash outflows with positive amount validation.
      - _handleReconcileAudit(BuildContext, MotoHubViewModel):
          Compares physical denomination count against expected drawer cash;
          enforces Boss Arman Admin Override (`admin123`) if a shortage exists.
          Renders Cash Drawer Ledger entries via `M3ECardList` + `M3EListItem`.
  • _CashierTransfersAlertsTab (StatelessWidget):
      Lists shipments involving the Cashier's assigned branch (`vm.branchTransfers`)
      in `M3ECardList` and provides one-tap `[Confirm Delivery]` handshake for
      incoming shipments (`vm.confirmTransferDelivery`).
  • _CashierShiftProfileTab (StatelessWidget):
      Cashier shift profile and Official Z-Reading Shift Report generator.

--------------------------------------------------------------------------------
FILE: lib/views/mechanic/mechanic_shell_screen.dart
PURPOSE: Mechanic Workshop Bay Shell (Locked to Single Assigned Branch)
--------------------------------------------------------------------------------
Classes & Functions:
  • MechanicShellScreen (StatefulWidget):
      4-tab Material 3 Expressive `M3ENavigationBar` shell (`Bay Board`,
      `Workbench`, `Shelf HUD`, `Me`) locked to the Mechanic's single assigned
      branch, with an AppBar Assigned Branch lock badge and top-right QR scanner
      + `NotificationBellAction`.
  • _MechanicBayJobsBoardTab (StatelessWidget):
      Displays a read-only Assigned Branch banner and incoming customer service
      bookings for the Mechanic's assigned branch in `M3ECardList` with a
      primary `[Accept Job Order]` CTA (`vm.updateJobOrderStatus`) plus 5-stage
      lifecycle chips.
  • _MechanicWorkbenchTab (StatefulWidget):
      Allows mechanics to select an accepted job order, scan or tap a part in
      their assigned branch's inventory (`M3ECardList`) to atomically lock &
      deduct stock into the job sheet, and update labor fees.
  • _MechanicShelfBinHudTab (StatelessWidget):
      Single-branch shelf bin HUD (`M3ECardList`) monitoring stock and shelf
      coordinates (`Rack • Shelf • Bin`) exclusively for the Mechanic's assigned
      branch.
  • _MechanicProfileLogsTab (StatelessWidget):
      Mechanic shift profile and Sign Out controls.

--------------------------------------------------------------------------------
FILE: lib/views/customer/customer_auth_screen.dart
PURPOSE: Customer App Authentication (Google One-Tap + Email/Password Sign-In)
--------------------------------------------------------------------------------
Classes & Functions:
  • CustomerAuthScreen (StatefulWidget):
      - _openGoogleOneTapModal():
          Opens the interactive Google One-Tap bottom sheet allowing riders to
          authenticate with Google One-Tap or enter their Google account and
          persist their session via `vm.signInCustomerWithGoogle(...)`.
      - _submitEmailPasswordAuth():
          Handles standard customer Sign-In (`vm.login(..., customerOnly: true)`)
          and Customer Account Registration (`vm.registerCustomerAccount`).

--------------------------------------------------------------------------------
FILE: lib/views/customer/customer_shell_screen.dart
PURPOSE: Decoupled Customer App Shell (Live Tracker, Click & Collect, My Garage)
--------------------------------------------------------------------------------
Classes & Functions:
  • CustomerShellScreen (StatefulWidget):
      3-tab Material 3 Expressive `M3ENavigationBar` shell with top-right
      `NotificationBellAction`, `M3ESegmentedButton<BranchId>` branch selector,
      and `[Book Service]` action.
  • _CustomerLiveTrackerTab (StatelessWidget):
      Displays the rider's active repair jobs in `M3ECardList.of(...)` with a
      visual 4-stage progress stepper, locked parts breakdown, extra-repair
      approval CTA, and live invoice estimate.
  • _CustomerPartsExplorerTab (StatefulWidget):
      - _showClickAndCollectSheet(BuildContext, MotoHubViewModel, InventoryItem):
          Modal bottom sheet to reserve parts for branch pickup using atomic
          SQLite reservation (`vm.createClickAndCollectOrder`). Renders catalog
          items in `M3ECardList.builder(...)`.
  • _CustomerGarageProfileTab (StatelessWidget):
      Displays the authenticated customer's profile (including Google Verified
      badge when signed in via Google), active Click & Collect reservations
      (`M3ECardList` + `M3EListItem`), service history, and Sign Out button.

--------------------------------------------------------------------------------
FILE: lib/views/shared/barcode_scanner_modal.dart
PURPOSE: Live Camera QR & Barcode Scanner (`mobile_scanner`) + Manual SKU Entry
--------------------------------------------------------------------------------
Classes & Functions:
  • BarcodeScannerModal (StatefulWidget):
      - BarcodeScannerModal.show(BuildContext context):
          Static helper returning the scanned QR/Barcode/SKU `Future<String?>`.
      - Integrates `MobileScannerController` & `MobileScanner` (`mobile_scanner`
        package) for live camera QR code and EAN/Code-128 barcode detection,
        with Torch toggle, Front/Rear camera switch, graceful desktop/emulator
        fallback, quick-tap inventory SKU chips, and manual SKU input.

--------------------------------------------------------------------------------
FILE: lib/views/shared/notifications_sheet.dart
PURPOSE: Material 3 Expressive Notification Bell Action & Notification Center
--------------------------------------------------------------------------------
Classes & Functions:
  • NotificationBellAction (StatelessWidget):
      Top-bar notification bell icon button with `M3EBadge` unread counter,
      integrated into the `AppBar.actions` of Admin, Cashier, Mechanic (right
      beside the QR scanner), and Customer shells.
  • NotificationsSheet (StatefulWidget):
      - NotificationsSheet.show(BuildContext context, {String? roleLabel}):
          Opens the Material 3 Expressive modal bottom sheet displaying
          real-time alerts in `M3ECardList.builder` + `M3EListItem` with
          category filter pills (`All`, `Unread`, `Service Bay`, `Stock &
          Transfers`, `POS & Billing`) and one-tap mark-as-read.

--------------------------------------------------------------------------------
FILE: lib/views/shared/create_job_order_sheet.dart
PURPOSE: Customer-Only Service Appointment Booking Sheet (App B)
--------------------------------------------------------------------------------
Classes & Functions:
  • CreateJobOrderSheet (StatefulWidget):
      - CreateJobOrderSheet.show(BuildContext context, {...}):
          Blocks non-customer roles (`admin`, `cashier`, `mechanic`) and opens
          the Customer Service Appointment Booking form for riders.
      - _submit():
          Validates rider name, Philippine mobile number, motorcycle model,
          LTO plate number, preferred appointment schedule slot, and service
          package; calls `vm.createJobOrder(...)` inside a `try-catch` block
          with `if (!mounted) return;` safety.

--------------------------------------------------------------------------------
FILE: test/widget_test.dart
PURPOSE: Automated Widget & ViewModel Integration Tests
--------------------------------------------------------------------------------
Tests Included:
  • App A (Internal ERP/POS) Splash & Login Transition Test
  • App B (Customer App) Splash & Google One-Tap Auth Screen Test
  • MotoHubViewModel Clean DB Startup, Seed Auth, Atomic Inventory & Google One-Tap

================================================================================
HOW PUSH NOTIFICATIONS WORK (HEADS-UP POPUP WHEN APP IS DESTROYED / BACKGROUND)
================================================================================
When the app is destroyed (killed) or in the background:
1. Android OS does not run Dart isolates unless awakened by Google Play Services
   via Firebase Cloud Messaging (FCM).
2. For FCM to send the notification to your device when the app is destroyed:
   • The Cloud Function (`deliverPushNotification`) located in `functions/index.js`
     listens to new documents in Firestore `notifications` collection and sends an
     FCM multicast message with high-priority heads-up channel `high_importance_channel`.
   • To deploy the Cloud Function to your Firebase project (`bossarman-760da`):
       1) Ensure you are logged into the Google account that owns `bossarman-760da`:
            firebase login
       2) Deploy the functions:
            firebase deploy --only functions
   • Once deployed, whenever an order, job status change, or chat message is created,
     Firebase Cloud Messaging instantly delivers a heads-up pop-up banner notification
     to the customer and staff devices even if the app was completely swiped away/killed.
3. While the app is running (foreground or minimized in background), the app also
   triggers instant heads-up pop-up banner notifications (`NotificationService.showNotification`)
   via Android's high-importance channel with sound and vibration whenever a new alert arrives.
================================================================================

