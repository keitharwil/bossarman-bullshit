import 'package:flutter/material.dart';
import 'package:boss_arman_motohub/core/models/models.dart';
import 'package:boss_arman_motohub/viewmodels/motohub_viewmodel.dart';
import 'package:boss_arman_motohub/views/shared/sliding_marquee_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Features A to D Verification Tests', () {
    test('Feature B: searchParts matches by name, SKU, and barcode with branch coordinates', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      final item1 = InventoryItem(
        id: 'INV-TEST-001',
        sku: 'BRK-PAD-NMAX',
        barcode: '4800999000111',
        name: 'Brembo Ceramic Front Brake Pads',
        category: 'Tires & Brakes',
        compatibleModels: 'NMAX V1, NMAX V2',
        rack: 'Rack B',
        shelf: 'Shelf 3',
        bin: 'Bin 12',
        price: 850.0,
        costPrice: 600.0,
        stockPatimbao: 15,
        stockPedroGuevara: 8,
      );

      final item2 = InventoryItem(
        id: 'INV-TEST-002',
        sku: 'OIL-MOTUL-SCOOT',
        barcode: '4800999000222',
        name: 'Motul Scooter Power LE 5W-40',
        category: 'Engine Oils',
        compatibleModels: 'All Scooters',
        rack: 'Rack A',
        shelf: 'Shelf 1',
        bin: 'Bin 04',
        price: 420.0,
        costPrice: 320.0,
        stockPatimbao: 20,
        stockPedroGuevara: 5,
      );

      await vm.addOrUpdateInventoryItem(item1);
      await vm.addOrUpdateInventoryItem(item2);

      // Search by partial Name
      final nameResults = vm.searchParts('brembo');
      expect(nameResults.length, 1);
      expect(nameResults.first.id, 'INV-TEST-001');
      expect(nameResults.first.availableStockFor(BranchId.patimbao), 15);
      expect(nameResults.first.rack, 'Rack B');
      expect(nameResults.first.bin, 'Bin 12');

      // Search by SKU
      final skuResults = vm.searchParts('MOTUL-SCOOT');
      expect(skuResults.length, 1);
      expect(skuResults.first.id, 'INV-TEST-002');

      // Search by Barcode
      final barcodeResults = vm.searchParts('4800999000111');
      expect(barcodeResults.length, 1);
      expect(barcodeResults.first.id, 'INV-TEST-001');

      // Non-matching search
      expect(vm.searchParts('NonExistentPartXYZ'), isEmpty);
    });

    test('Feature C: User profile picture and initials fallback', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Login as master admin
      final ok = await vm.login('bossarman', 'admin123');
      expect(ok, isTrue);
      expect(vm.currentUser?.initials, 'AS'); // Arman Sarita
      expect(vm.currentUser?.photoUrl, isNull);

      // Update avatar with base64 data URI
      const sampleBase64 = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...';
      final photoUpdated = await vm.updateCurrentUserProfilePhoto(sampleBase64);
      expect(photoUpdated, isTrue);
      expect(vm.currentUser?.photoUrl, sampleBase64);

      // Verify Google One-Tap sign-in stores photoUrl
      final googleLogin = await vm.signInStaffWithGoogle(
        email: 'lancemercadoaclan01@gmail.com',
        displayName: 'Lance Mercado Aclan',
        photoUrl: 'https://lh3.googleusercontent.com/a/sample-photo',
      );
      expect(googleLogin, isTrue);
      expect(vm.currentUser?.photoUrl, 'https://lh3.googleusercontent.com/a/sample-photo');
    });

    test('Feature D: Soft delete with 30-day recovery window and restoration', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Seed cashier account
      final cashier = vm.staffList.firstWhere((s) => s.username == 'cashier01');
      expect(cashier.isDeleted, isFalse);
      expect(cashier.isSoftDeleted, isFalse);

      // Soft delete requires confirmation 'DELETE'
      final badConfirm = await vm.softDeleteAccount(
        accountId: cashier.id,
        confirmation: 'NO',
      );
      expect(badConfirm, isFalse);

      final deleted = await vm.softDeleteAccount(
        accountId: cashier.id,
        confirmation: 'DELETE',
      );
      expect(deleted, isTrue);

      final deletedCashier = vm.staffList.firstWhere((s) => s.id == cashier.id);
      expect(deletedCashier.isDeleted, isTrue);
      expect(deletedCashier.isSoftDeleted, isTrue);
      expect(deletedCashier.deletedAt, isNotNull);
      expect(deletedCashier.recoverableUntil, isNotNull);

      // Login attempt without restore flag should return false with ACCOUNT_DELETED_RECOVERABLE
      final loginFailed = await vm.login('cashier01', 'cashier123');
      expect(loginFailed, isFalse);
      expect(vm.statusMessage, contains('ACCOUNT_DELETED_RECOVERABLE'));
      expect(vm.pendingRecoveryAccount?.id, cashier.id);

      // Restore account
      final restored = await vm.restoreAccount(cashier.id);
      expect(restored, isTrue);

      final restoredCashier = vm.staffList.firstWhere((s) => s.id == cashier.id);
      expect(restoredCashier.isDeleted, isFalse);
      expect(restoredCashier.isSoftDeleted, isFalse);

      // Now login succeeds
      final loginSuccess = await vm.login('cashier01', 'cashier123');
      expect(loginSuccess, isTrue);
      expect(vm.currentUser?.id, cashier.id);
    });

    test('Feature A & D: Transactions and historical receipts remain preserved after soft-delete', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Add item and process POS sale
      final item = InventoryItem(
        id: 'INV-SALE-01',
        sku: 'PLUG-NGK-CR7E',
        barcode: '4800999000333',
        name: 'NGK Spark Plug CR7E',
        category: 'CVT Tuning',
        compatibleModels: 'Mio, Click, Beat',
        rack: 'Rack C',
        shelf: 'Shelf 2',
        bin: 'Bin 05',
        price: 150.0,
        costPrice: 90.0,
        stockPatimbao: 10,
        stockPedroGuevara: 10,
      );
      await vm.addOrUpdateInventoryItem(item);

      // Cashier logs in and sells item
      await vm.login('cashier01', 'cashier123');
      vm.addToCart(item);

      final tx = await vm.processRetailCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 200.0,
        customerName: 'Mario Santos',
      );
      expect(tx, isNotNull);
      expect(tx!.changeDue, 50.0);
      expect(vm.transactions.length, 1);
      expect(vm.branchTransactions.length, 1);

      // Now soft-delete cashier01
      await vm.login('bossarman', 'admin123');
      final cashierId = vm.staffList.firstWhere((s) => s.username == 'cashier01').id;
      await vm.softDeleteAccount(accountId: cashierId, confirmation: 'DELETE');

      // Historical transaction & receipt must STILL exist in vm.transactions and SQLite
      expect(vm.transactions.length, 1);
      final historicalTx = vm.transactions.first;
      expect(historicalTx.id, tx.id);
      expect(historicalTx.customerName, 'Mario Santos');
      expect(historicalTx.totalAmount, 150.0);
    });

    test('Inventory: Add stock, quick restock, and verify SQLite schema serialization', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      final newPart = InventoryItem(
        id: 'PRT-TEST-STOCK-999',
        sku: 'OIL-SHELL-AX7',
        barcode: '4800999888777',
        name: 'Shell Advance AX7 10W-40 4T',
        category: 'Engine Oils',
        price: 320.0,
        costPrice: 240.0,
        stockPatimbao: 5,
        stockPedroGuevara: 3,
        rack: 'Rack A',
        shelf: 'Shelf 2',
        bin: 'Bin 08',
        compatibleModels: 'Universal Motorcycle',
      );

      // Verify toMap() contains valid integer isDeleted and NO invalid is_deleted column
      final map = newPart.toMap();
      expect(map.containsKey('is_deleted'), isFalse,
          reason: 'toMap() must NOT contain is_deleted column to prevent SQLite crash');
      expect(map['isDeleted'], 0);

      // Test adding new stock item
      final addResult = await vm.addOrUpdateInventoryItem(newPart);
      expect(addResult, isTrue, reason: 'Must successfully add inventory item to SQLite');

      // Verify in inventory list
      final added = vm.findPartByCode('OIL-SHELL-AX7');
      expect(added, isNotNull);
      expect(added!.stockPatimbao, 5);
      expect(added.stockPedroGuevara, 3);

      // Test restocking / updating stock levels
      final restocked = added.copyWith(
        stockPatimbao: added.stockPatimbao + 10,
        stockPedroGuevara: added.stockPedroGuevara + 5,
      );
      final restockResult = await vm.addOrUpdateInventoryItem(restocked);
      expect(restockResult, isTrue, reason: 'Must successfully restock and update inventory item');

      final updated = vm.findPartByCode('OIL-SHELL-AX7');
      expect(updated, isNotNull);
      expect(updated!.stockPatimbao, 15);
      expect(updated.stockPedroGuevara, 8);

      // Permanent delete test (Ghost Item Fix)
      final deleteResult = await vm.deleteInventoryItem('PRT-TEST-STOCK-999');
      expect(deleteResult, isTrue);
      expect(vm.allInventory.any((i) => i.id == 'PRT-TEST-STOCK-999'), isFalse);
      expect(vm.findPartByCode('OIL-SHELL-AX7'), isNull);
    });

    test('Jobs: Delete job order moves automatically to history, and delete in history permanently removes it', () async {
      final vm = MotoHubViewModel(isCustomerApp: true);
      await vm.initializeApp();

      // Create a test job order
      final testJob = await vm.createJobOrder(
        customerName: 'Juan Rider',
        customerPhone: '0917-123-4567',
        bikeModel: 'Yamaha Aerox 155',
        plateNumber: '412-NBO',
        serviceType: 'CVT Tuning & Pulley Upgrade',
        issueDescription: 'Belt vibration',
        assignedMechanic: 'Lance M. Aclan',
        laborFee: 450.0,
      );
      expect(testJob, isNotNull);
      final jobId = testJob!.id;

      // Verify it is in active jobs and NOT yet in pastJobOrders
      expect(vm.activeBranchJobOrders.any((j) => j.id == jobId), isTrue);
      expect(vm.pastJobOrders.any((j) => j.id == jobId), isFalse);

      // Delete active job (Customer or Admin action)
      final deleteActiveResult = await vm.deleteJobOrder(jobId);
      expect(deleteActiveResult, isTrue);

      // Must be removed from active jobs
      expect(vm.activeBranchJobOrders.any((j) => j.id == jobId), isFalse);

      // Must automatically appear in history (pastJobOrders) with status cancelled
      expect(vm.pastJobOrders.any((j) => j.id == jobId), isTrue);
      final historyJob = vm.pastJobOrders.firstWhere((j) => j.id == jobId);
      expect(historyJob.status, JobStatus.cancelled);

      // Now delete from history (History screen action)
      final deleteFromHistoryResult = await vm.deleteJobFromHistory(jobId);
      expect(deleteFromHistoryResult, isTrue);

      // Must be permanently removed from all pastJobOrders
      expect(vm.pastJobOrders.any((j) => j.id == jobId), isFalse);
    });

    testWidgets('SlidingMarqueeText renders and animates overflowing text without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: SlidingMarqueeText(
                text: 'Branch 1: Patimbao (Very Long Branch Name That Overflows)',
              ),
            ),
          ),
        ),
      );

      // Verify the widget renders without RenderFlex errors
      expect(find.byType(SlidingMarqueeText), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is SlidingMarqueeText &&
            w.text == 'Branch 1: Patimbao (Very Long Branch Name That Overflows)'),
        findsOneWidget,
      );

      // Advance animation frames
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));

      // Test short text that fits
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SlidingMarqueeText(
                text: 'Fits Easily',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
            (w) => w is SlidingMarqueeText && w.text == 'Fits Easily'),
        findsOneWidget,
      );
    });

    test('Receipts & Transfers: Delete transaction and full inter-branch request/approval/receipt workflow', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Seed part with stock in Branch 2 (Pedro Guevara: 10), Branch 1 (Patimbao: 2)
      final testPart = InventoryItem(
        id: 'PRT-XFER-TEST',
        sku: 'XFER-SKU-001',
        barcode: '4800999000888',
        name: 'High Flow Air Filter',
        category: 'Engine',
        compatibleModels: 'Universal 4T',
        rack: 'Rack X',
        shelf: 'Shelf 1',
        bin: 'Bin 01',
        price: 500.0,
        costPrice: 350.0,
        stockPatimbao: 2,
        stockPedroGuevara: 10,
      );
      await vm.addOrUpdateInventoryItem(testPart);

      // 1. Transaction creation & deletion
      vm.addToCart(testPart);
      final tx = await vm.processRetailCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );
      expect(tx, isNotNull);
      expect(vm.transactions.length, greaterThanOrEqualTo(1));
      final txId = tx!.id;

      // Delete transaction
      final deleteTxOk = await vm.deleteTransaction(txId);
      expect(deleteTxOk, isTrue);
      expect(vm.transactions.any((t) => t.id == txId), isFalse);

      // 2. Inter-branch stock transfer request:
      // Cashier at Branch 1 (Patimbao) requests 4 units from Branch 2 (Pedro Guevara)
      vm.switchBranch(BranchId.patimbao);
      final reqOk = await vm.requestStockTransfer(
        item: testPart,
        fromBranch: BranchId.pedroGuevara,
        toBranch: BranchId.patimbao,
        quantity: 4,
      );
      expect(reqOk, isTrue);

      final transfer = vm.allTransfers.firstWhere((t) => t.partId == testPart.id);
      expect(transfer.status, TransferStatus.pendingApproval);
      expect(transfer.quantity, 4);

      // Verify stock has NOT yet been deducted while pending approval
      var partCheck = vm.allInventory.firstWhere((i) => i.id == testPart.id);
      expect(partCheck.stockPedroGuevara, 10);
      expect(partCheck.stockPatimbao, 1); // 2 original - 1 sold above

      // 3. Cashier/Admin at Branch 2 (Pedro Guevara) approves & dispatches transfer
      vm.switchBranch(BranchId.pedroGuevara);
      expect(vm.pendingApprovalTransfers.any((t) => t.id == transfer.id), isTrue);

      final approveOk = await vm.approveStockTransfer(transfer);
      expect(approveOk, isTrue);

      // Stock is now deducted from source (Pedro Guevara) and marked inTransit
      partCheck = vm.allInventory.firstWhere((i) => i.id == testPart.id);
      expect(partCheck.stockPedroGuevara, 6); // 10 - 4
      expect(partCheck.stockPatimbao, 1); // not yet received

      final inTransitTrf = vm.allTransfers.firstWhere((t) => t.id == transfer.id);
      expect(inTransitTrf.status, TransferStatus.inTransit);

      // 4. Cashier at Branch 1 (Patimbao) confirms receipt & restocks
      vm.switchBranch(BranchId.patimbao);
      final receiveOk = await vm.confirmStockTransferReceipt(inTransitTrf);
      expect(receiveOk, isTrue);

      // Stock is added to destination (Patimbao) and status is delivered
      partCheck = vm.allInventory.firstWhere((i) => i.id == testPart.id);
      expect(partCheck.stockPatimbao, 5); // 1 + 4 received
      expect(partCheck.stockPedroGuevara, 6);

      final completedTrf = vm.allTransfers.firstWhere((t) => t.id == transfer.id);
      expect(completedTrf.status, TransferStatus.delivered);

      // 5. Delete transfer record from history
      final deleteTrfOk = await vm.deleteStockTransfer(completedTrf.id);
      expect(deleteTrfOk, isTrue);
      expect(vm.allTransfers.any((t) => t.id == completedTrf.id), isFalse);
    });

    test('Staff Management: Create staff and permanently delete without resurrection', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Login as Admin
      await vm.login('bossarman', 'admin123');
      expect(vm.currentUser?.role, UserRole.admin);

      // Create a new Cashier staff member
      final createOk = await vm.createStaffAccount(
        firstName: 'Maria',
        lastName: 'Santos',
        username: 'mariacashier',
        email: 'maria@motohub.ph',
        password: 'Password123!',
        role: UserRole.cashier,
        assignedBranch: BranchId.patimbao,
      );
      expect(createOk, isTrue);

      final staffMember = vm.staffList.firstWhere((s) => s.username == 'mariacashier');
      expect(staffMember.fullName, 'Maria Santos');
      expect(staffMember.assignedBranch, BranchId.patimbao);

      // Delete staff account permanently
      final deleteOk = await vm.deleteStaffAccount(staffMember.id);
      expect(deleteOk, isTrue);
      expect(vm.staffList.any((s) => s.id == staffMember.id), isFalse);

      // Re-initialize another ViewModel instance to ensure no ghost resurrection from SQLite
      final vm2 = MotoHubViewModel(isCustomerApp: false);
      await vm2.initializeApp();
      expect(vm2.staffList.any((s) => s.id == staffMember.id), isFalse);
      expect(vm2.staffList.any((s) => s.username == 'mariacashier'), isFalse);
    });
  });
}
