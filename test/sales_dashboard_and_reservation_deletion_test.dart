import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boss_arman_motohub/core/models/models.dart';
import 'package:boss_arman_motohub/viewmodels/motohub_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Click & Collect Deletion & Inventory Recovery Tests', () {
    test('deleteClickAndCollectOrder releases locked inventory and removes order', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Ensure active branch is Patimbao
      vm.setActiveBranch(BranchId.patimbao);

      // Create an inventory item with 10 units in Patimbao
      final testItem = InventoryItem(
        id: 'test_part_del',
        sku: 'TEST-DEL-01',
        barcode: '4800000000999',
        name: 'Test Sprocket',
        category: 'Drive Chain',
        rack: 'Rack A',
        shelf: 'Shelf 1',
        bin: 'Bin 1',
        price: 350.0,
        costPrice: 200.0,
        stockPatimbao: 10,
        stockPedroGuevara: 5,
        lockedPatimbao: 0,
        lockedPedroGuevara: 0,
        compatibleModels: 'Sniper 150',
      );
      await vm.addOrUpdateInventoryItem(testItem);

      final initialAvail = vm.allInventory
          .firstWhere((i) => i.id == 'test_part_del')
          .availableStockFor(BranchId.patimbao);
      expect(initialAvail, equals(10));

      // Create a reservation for 3 units
      final order = await vm.createClickAndCollectOrder(
        part: testItem,
        quantity: 3,
        branch: BranchId.patimbao,
        customerPhone: '09123456789',
      );

      expect(order, isNotNull);
      expect(order!.quantity, equals(3));

      // Available stock should be 7 (10 physical - 3 locked)
      var itemAfterReservation = vm.allInventory.firstWhere((i) => i.id == 'test_part_del');
      expect(itemAfterReservation.availableStockFor(BranchId.patimbao), equals(7));
      expect(itemAfterReservation.lockedPatimbao, equals(3));

      // Verify order exists in ViewModel
      expect(vm.clickCollectOrders.any((o) => o.id == order.id), isTrue);

      // Now permanently delete the active reservation
      final deleted = await vm.deleteClickAndCollectOrder(order.id);
      expect(deleted, isTrue);

      // Order should be removed from ViewModel
      expect(vm.clickCollectOrders.any((o) => o.id == order.id), isFalse);

      // Locked stock must be returned to 0, available stock back to 10
      itemAfterReservation = vm.allInventory.firstWhere((i) => i.id == 'test_part_del');
      expect(itemAfterReservation.lockedPatimbao, equals(0));
      expect(itemAfterReservation.availableStockFor(BranchId.patimbao), equals(10));
    });
  });

  group('Daily Sales Dashboard Metrics & Calculations Tests', () {
    test('Daily metrics correctly segment cash, gcash, split, parts, and labor for a target date', () {
      final targetDate = DateTime(2026, 10, 12, 14, 30);
      final otherDate = DateTime(2026, 10, 11, 10, 0);

      final transactions = [
        // Target date - Cash transaction (Parts only)
        PosTransaction(
          id: 'TX-001',
          branch: BranchId.patimbao,
          cashierName: 'Anna',
          customerName: 'Juan Dela Cruz',
          itemsSummary: '2x Chain Lube',
          partsSubtotal: 500.0,
          laborTotal: 0.0,
          totalAmount: 500.0,
          paymentMethod: PaymentMethod.cash,
          amountTendered: 1000.0,
          changeAmount: 500.0,
          cashAmount: 500.0,
          gcashAmount: 0.0,
          createdAt: targetDate,
        ),
        // Target date - GCash transaction (Parts + Labor)
        PosTransaction(
          id: 'TX-002',
          branch: BranchId.patimbao,
          cashierName: 'Anna',
          customerName: 'Maria Santos',
          itemsSummary: '1x Brake Pad, Labor',
          partsSubtotal: 800.0,
          laborTotal: 300.0,
          totalAmount: 1100.0,
          paymentMethod: PaymentMethod.gcash,
          amountTendered: 1100.0,
          changeAmount: 0.0,
          cashAmount: 0.0,
          gcashAmount: 1100.0,
          createdAt: targetDate.add(const Duration(hours: 1)),
        ),
        // Target date - Split transaction (500 Cash + 500 GCash)
        PosTransaction(
          id: 'TX-003',
          branch: BranchId.patimbao,
          cashierName: 'Anna',
          customerName: 'Pedro Penduko',
          itemsSummary: '1x Tire, Labor',
          partsSubtotal: 700.0,
          laborTotal: 300.0,
          totalAmount: 1000.0,
          paymentMethod: PaymentMethod.split,
          amountTendered: 1000.0,
          changeAmount: 0.0,
          cashAmount: 500.0,
          gcashAmount: 500.0,
          createdAt: targetDate.add(const Duration(hours: 2)),
        ),
        // Other date (should be filtered out)
        PosTransaction(
          id: 'TX-004',
          branch: BranchId.patimbao,
          cashierName: 'Anna',
          customerName: 'Yesterday Customer',
          itemsSummary: '1x Helmet',
          partsSubtotal: 2500.0,
          laborTotal: 0.0,
          totalAmount: 2500.0,
          paymentMethod: PaymentMethod.cash,
          amountTendered: 2500.0,
          changeAmount: 0.0,
          cashAmount: 2500.0,
          gcashAmount: 0.0,
          createdAt: otherDate,
        ),
      ];

      // Filter by target date
      final targetDayTxs = transactions.where((tx) =>
          tx.createdAt.year == targetDate.year &&
          tx.createdAt.month == targetDate.month &&
          tx.createdAt.day == targetDate.day).toList();

      expect(targetDayTxs.length, equals(3));

      final grossSales = targetDayTxs.fold<double>(0.0, (sum, t) => sum + t.totalAmount);
      expect(grossSales, equals(2600.0)); // 500 + 1100 + 1000

      final cashCollected = targetDayTxs.fold<double>(0.0, (sum, t) {
        if (t.paymentMethod == PaymentMethod.cash) return sum + t.totalAmount;
        if (t.paymentMethod == PaymentMethod.split) return sum + t.cashAmount;
        return sum;
      });
      expect(cashCollected, equals(1000.0)); // 500 (TX1) + 500 (TX3)

      final gcashVault = targetDayTxs.fold<double>(0.0, (sum, t) {
        if (t.paymentMethod == PaymentMethod.gcash) return sum + t.totalAmount;
        if (t.paymentMethod == PaymentMethod.split) return sum + t.gcashAmount;
        return sum;
      });
      expect(gcashVault, equals(1600.0)); // 1100 (TX2) + 500 (TX3)

      final partsTotal = targetDayTxs.fold<double>(0.0, (sum, t) => sum + t.partsSubtotal);
      expect(partsTotal, equals(2000.0)); // 500 + 800 + 700

      final laborTotal = targetDayTxs.fold<double>(0.0, (sum, t) => sum + t.laborTotal);
      expect(laborTotal, equals(600.0)); // 0 + 300 + 300

      final averageTicket = grossSales / targetDayTxs.length;
      expect(averageTicket, closeTo(866.67, 0.01));
    });
  });

  group('Chat Image Data URI Encoding & Base64 Fallback Tests', () {
    test('Base64 data URI format encodes and decodes cleanly', () {
      final sampleBytes = utf8.encode('fake-image-binary-data-for-chat');
      final base64String = base64Encode(sampleBytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      expect(dataUri.startsWith('data:image'), isTrue);

      final rawData = dataUri.split(',').last;
      final decodedBytes = base64Decode(rawData);
      expect(utf8.decode(decodedBytes), equals('fake-image-binary-data-for-chat'));
    });
  });

  group('Bulk History Deletion Tests', () {
    test('deleteAllPastClickAndCollectHistory deletes completed/cancelled orders while safely preserving active holds', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();
      vm.setActiveBranch(BranchId.patimbao);

      final testItem = InventoryItem(
        id: 'test_bulk_part',
        sku: 'TEST-BULK-01',
        barcode: '4800000000998',
        name: 'Bulk Test Sprocket',
        category: 'Drive Chain',
        rack: 'Rack A',
        shelf: 'Shelf 1',
        bin: 'Bin 1',
        price: 350.0,
        costPrice: 200.0,
        stockPatimbao: 10,
        stockPedroGuevara: 5,
        lockedPatimbao: 0,
        lockedPedroGuevara: 0,
        compatibleModels: 'Sniper 150',
      );
      await vm.addOrUpdateInventoryItem(testItem);

      final activeOrder = await vm.createClickAndCollectOrder(
        part: testItem,
        quantity: 1,
        branch: BranchId.patimbao,
        customerPhone: '09123456789',
      );
      final completedOrder = await vm.createClickAndCollectOrder(
        part: testItem,
        quantity: 1,
        branch: BranchId.patimbao,
        customerPhone: '09123456789',
      );
      final cancelledOrder = await vm.createClickAndCollectOrder(
        part: testItem,
        quantity: 1,
        branch: BranchId.patimbao,
        customerPhone: '09123456789',
      );

      expect(activeOrder, isNotNull);
      expect(completedOrder, isNotNull);
      expect(cancelledOrder, isNotNull);

      // Claim order 2 (completed) and cancel order 3
      await vm.claimClickAndCollectOrder(completedOrder!.id);
      await vm.cancelClickAndCollectOrder(cancelledOrder!.id);

      // Verify statuses
      expect(vm.clickCollectOrders.firstWhere((o) => o.id == activeOrder!.id).isHoldActive, isTrue);
      expect(vm.clickCollectOrders.firstWhere((o) => o.id == completedOrder.id).isCompleted, isTrue);
      expect(vm.clickCollectOrders.firstWhere((o) => o.id == cancelledOrder.id).isCancelled, isTrue);

      final deletedCount = await vm.deleteAllPastClickAndCollectHistory(customerUsername: 'guest');

      expect(deletedCount, equals(2)); // completed + cancelled
      // Active order must STILL exist
      expect(vm.clickCollectOrders.any((o) => o.id == activeOrder!.id), isTrue);
      // Completed and cancelled must be deleted
      expect(vm.clickCollectOrders.any((o) => o.id == completedOrder.id), isFalse);
      expect(vm.clickCollectOrders.any((o) => o.id == cancelledOrder.id), isFalse);
    });

    test('deleteAllPastJobHistory deletes completed/cancelled jobs while keeping active bay jobs', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      final job1 = await vm.createJobOrder(
        customerName: 'Juan Rider',
        customerPhone: '0917-111-2222',
        customerUsername: 'juan_rider',
        bikeModel: 'Yamaha Aerox',
        plateNumber: '111-ABC',
        serviceType: 'Oil Change',
        issueDescription: 'Regular maintenance',
        assignedMechanic: 'Arwel',
      );
      final job2 = await vm.createJobOrder(
        customerName: 'Juan Rider',
        customerPhone: '0917-111-2222',
        customerUsername: 'juan_rider',
        bikeModel: 'Yamaha Aerox',
        plateNumber: '111-ABC',
        serviceType: 'Tire Change',
        issueDescription: 'Punctured rear tire',
        assignedMechanic: 'Arwel',
      );
      final activeJob = await vm.createJobOrder(
        customerName: 'Juan Rider',
        customerPhone: '0917-111-2222',
        customerUsername: 'juan_rider',
        bikeModel: 'Yamaha Aerox',
        plateNumber: '111-ABC',
        serviceType: 'CVT Cleaning',
        issueDescription: 'Belt sluggish',
        assignedMechanic: 'Arwel',
      );

      expect(job1, isNotNull);
      expect(job2, isNotNull);
      expect(activeJob, isNotNull);

      // Cancel job1 and job2 to move them into pastJobOrders
      await vm.deleteJobOrder(job1!.id);
      await vm.deleteJobOrder(job2!.id);

      expect(vm.pastJobOrders.any((j) => j.id == job1.id), isTrue);
      expect(vm.pastJobOrders.any((j) => j.id == job2.id), isTrue);
      expect(vm.activeBranchJobOrders.any((j) => j.id == activeJob!.id), isTrue);

      final deletedCount = await vm.deleteAllPastJobHistory(customerUsername: 'juan_rider');

      expect(deletedCount, equals(2));
      // Past jobs must be permanently removed
      expect(vm.pastJobOrders.any((j) => j.id == job1.id), isFalse);
      expect(vm.pastJobOrders.any((j) => j.id == job2.id), isFalse);
      // Active job must remain untouched
      expect(vm.activeBranchJobOrders.any((j) => j.id == activeJob!.id), isTrue);
    });
  });

  group('Cash Ledger Dismissal & Notification Target Tests', () {
    test('deleteCashLedgerEntry dismisses entry from active drawer and local database', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();
      vm.setActiveBranch(BranchId.patimbao);

      await vm.addMorningFloat(500.0);
      expect(vm.branchCashLedger.isNotEmpty, isTrue);

      final entryId = vm.branchCashLedger.first.id;
      final ok = await vm.deleteCashLedgerEntry(entryId);

      expect(ok, isTrue);
      expect(vm.branchCashLedger.any((e) => e.id == entryId), isFalse);
    });

    test('admin receives order and chat notifications with admin alias', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Log in as Admin bossarman
      final loginOk = await vm.login('bossarman', 'admin123');
      expect(loginOk, isTrue);
      expect(vm.currentUser?.role, equals(UserRole.admin));

      // Notification targeted to 'admin'
      final chatNotif = AppNotificationItem(
        id: 'NTF_CHAT_01',
        title: 'New message from Customer',
        message: 'Hello Admin',
        category: 'chat',
        branch: BranchId.patimbao,
        targetUserId: 'admin',
        createdAt: DateTime.now(),
      );

      // Notification for new item reservation
      final orderNotif = AppNotificationItem(
        id: 'NTF_RES_01',
        title: 'New Item Reservation',
        message: 'Reserved 1x Brake Pads',
        category: 'booking',
        branch: BranchId.patimbao,
        targetRole: UserRole.admin,
        createdAt: DateTime.now(),
      );

      // Add to notifications list
      await vm.markNotificationRead(chatNotif.id);
      expect(chatNotif.targetUserId, equals('admin'));
      expect(orderNotif.targetRole, equals(UserRole.admin));
    });

    test('non-admin is blocked from deleting transactions and cash ledger entries', () async {
      final vm = MotoHubViewModel(isCustomerApp: false);
      await vm.initializeApp();

      // Log in as Cashier
      final loginOk = await vm.login('cashier01', 'cashier123');
      expect(loginOk, isTrue);
      expect(vm.currentUser?.role, equals(UserRole.cashier));

      // Attempt to delete transaction
      final deleteTxOk = await vm.deleteTransaction('TX-FAKE');
      expect(deleteTxOk, isFalse);
      expect(vm.statusMessage, contains('Only Admins'));

      // Attempt to delete cash ledger entry
      final deleteLedgerOk = await vm.deleteCashLedgerEntry('LEDGER-FAKE');
      expect(deleteLedgerOk, isFalse);
      expect(vm.statusMessage, contains('Only Admins'));
    });
  });
}
