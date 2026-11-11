import 'package:boss_arman_motohub/core/models/models.dart';
import 'package:boss_arman_motohub/main.dart';
import 'package:boss_arman_motohub/viewmodels/motohub_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App A (Internal ERP/POS) Splash & Login Transition Test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BossArmanInternalApp());
    expect(find.text('Boss Arman MotoHub'), findsOneWidget);
    expect(
      find.text('App A • Internal ERP, POS & Bay Management'),
      findsOneWidget,
    );

    // Advance through SQLite pre-warm and transition to LoginScreen
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Staff Login'), findsOneWidget);
    expect(find.text("What's your username and\npassword?"), findsOneWidget);
  });

  testWidgets('App B (Customer App) Splash & Google One-Tap Auth Screen Test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BossArmanCustomerApp());
    expect(find.text('Boss Arman MotoHub'), findsOneWidget);
    expect(
      find.text('App B • Rider Facing Companion Application'),
      findsOneWidget,
    );

    // Advance through SQLite pre-warm and transition to CustomerAuthScreen
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Continue with Google One-Tap'), findsOneWidget);
  });

  test(
      'MotoHubViewModel Clean DB Startup, Seed Auth, Atomic Inventory & Google One-Tap',
      () async {
    final vm = MotoHubViewModel(isCustomerApp: false);
    await vm.initializeApp();

    // 1. Verify Zero Mock Data on Startup (5 staff accounts seeded)
    expect(vm.allInventory, isEmpty);
    expect(vm.branchJobOrders, isEmpty);
    expect(vm.allTransfers, isEmpty);
    expect(vm.staffList.length, 5);

    // 2. Verify Hardened Master Credentials
    expect(
      await vm.login('bossarman', 'admin123', customerOnly: false),
      isTrue,
    );
    expect(vm.currentUser?.role, UserRole.admin);

    // Verify Lance Mercado Aclan and Keith Arwil Umali Admin credentials
    expect(
      await vm.login('lanceadmin', 'admin123', customerOnly: false),
      isTrue,
    );
    expect(vm.currentUser?.role, UserRole.admin);
    expect(vm.currentUser?.email, 'lancemercadoaclan01@gmail.com');

    final lanceGoogle = await vm.signInStaffWithGoogle(
      email: 'lancemercadoaclan01@gmail.com',
      displayName: 'Lance Mercado Aclan',
    );
    expect(lanceGoogle, isTrue);
    expect(vm.currentUser?.role, UserRole.admin);

    expect(
      await vm.login('keithadmin', 'admin123', customerOnly: false),
      isTrue,
    );
    expect(vm.currentUser?.role, UserRole.admin);
    expect(vm.currentUser?.email, 'keith110606@gmail.com');

    expect(
      await vm.login('cashier01', 'cashier123', customerOnly: false),
      isTrue,
    );
    expect(vm.currentUser?.role, UserRole.cashier);
    expect(vm.activeBranch, BranchId.patimbao);
    // Cashier cannot switch branches — locked to assigned branch
    await vm.switchBranch(BranchId.pedroGuevara);
    expect(vm.activeBranch, BranchId.patimbao);

    expect(
      await vm.login('mechanic01', 'mech123', customerOnly: false),
      isTrue,
    );
    expect(vm.currentUser?.role, UserRole.mechanic);
    expect(vm.activeBranch, BranchId.patimbao);
    // Mechanic cannot switch branches — locked to assigned branch
    await vm.switchBranch(BranchId.pedroGuevara);
    expect(vm.activeBranch, BranchId.patimbao);

    // 3. Verify Only Admin Can Switch Branches & Reassign Staff Branch
    expect(
      await vm.login('bossarman', 'admin123', customerOnly: false),
      isTrue,
    );
    await vm.switchBranch(BranchId.pedroGuevara);
    expect(vm.activeBranch, BranchId.pedroGuevara);
    await vm.switchBranch(BranchId.patimbao);
    expect(vm.activeBranch, BranchId.patimbao);

    // Admin reassigns mechanic01 to Pedro Guevara branch
    const statuses = ['On Duty', 'In Bay', 'Off Shift', 'Emergency Absence'];
    final mechAccount =
        vm.staffList.firstWhere((s) => s.username == 'mechanic01');
    final curIdx = statuses.indexOf(mechAccount.shiftStatus);
    final prevStatus = statuses[(curIdx - 1 + statuses.length) % statuses.length];
    await vm.cycleStaffShiftStatus(
      mechAccount.copyWith(
        assignedBranch: BranchId.pedroGuevara,
        shiftStatus: prevStatus,
      ),
    );
    expect(
      vm.staffList.firstWhere((s) => s.username == 'mechanic01').assignedBranch,
      BranchId.pedroGuevara,
    );

    // When mechanic01 logs in now, they are locked to Pedro Guevara branch
    await vm.login('mechanic01', 'mech123', customerOnly: false);
    expect(vm.activeBranch, BranchId.pedroGuevara);

    // Reassign mechanic01 back to Patimbao as Admin
    await vm.login('bossarman', 'admin123', customerOnly: false);
    final mechUpdated =
        vm.staffList.firstWhere((s) => s.username == 'mechanic01');
    await vm.cycleStaffShiftStatus(
      mechUpdated.copyWith(
        assignedBranch: BranchId.patimbao,
        shiftStatus: prevStatus,
      ),
    );
    await vm.switchBranch(BranchId.patimbao);

    // 4. Add a Real Inventory Item & Test Two-Phase Inter-Branch Transfer
    final newItem = InventoryItem(
      id: 'INV-TEST-01',
      sku: 'YM-10W40-01',
      barcode: '4800912000101',
      name: 'Yamalube Blue Core 10W-40 (1L)',
      category: 'Engine Oils',
      compatibleModels: 'NMAX, Aerox, Mio i125',
      rack: 'Rack A',
      shelf: 'Shelf 1',
      bin: 'Bin 01',
      price: 365.0,
      costPrice: 280.0,
      stockPatimbao: 10,
      stockPedroGuevara: 5,
    );
    final added = await vm.addOrUpdateInventoryItem(newItem);
    expect(added, isTrue);
    expect(vm.allInventory.length, 1);

    final item = vm.allInventory.first;
    // Self-transfer to same branch must be rejected
    final selfTransfer = await vm.initiateStockTransfer(
      item: item,
      fromBranch: BranchId.patimbao,
      toBranch: BranchId.patimbao,
      quantity: 1,
    );
    expect(selfTransfer, isFalse);

    final ok = await vm.initiateStockTransfer(
      item: item,
      fromBranch: BranchId.patimbao,
      toBranch: BranchId.pedroGuevara,
      quantity: 2,
    );
    expect(ok, isTrue);
    final updatedItem = vm.allInventory.firstWhere((i) => i.id == item.id);
    expect(updatedItem.stockPatimbao, 8);

    // Deleting an item with an active in-transit transfer must be blocked
    final deletedWhileInTransit = await vm.deleteInventoryItem(item.id);
    expect(deletedWhileInTransit, isFalse);

    // 5. Verify Customer Google One-Tap Sign-In
    final signedIn = await vm.signInCustomerWithGoogle(
      email: 'juan.rider@gmail.com',
      displayName: 'Juan Dela Cruz',
    );
    expect(signedIn, isTrue);
    expect(vm.currentUser?.role, UserRole.customer);
    expect(vm.currentUser?.authProvider, 'google');

    // 6. Verify Customer Booking, Extra Repair Quote & Duplicate Billing Guard
    final job = await vm.createJobOrder(
      customerName: 'Juan Dela Cruz',
      customerPhone: '09175550192',
      bikeModel: 'Yamaha NMAX V2',
      plateNumber: '412-NBO',
      serviceType: 'CVT Tuning & Pulley Upgrade',
      issueDescription: 'Dragging on takeoff',
      assignedMechanic: 'Lance M. Aclan',
      laborFee: 350.0,
      targetBranch: BranchId.patimbao,
    );
    expect(job, isNotNull);
    final quoteOk = await vm.updateJobLaborFee(
      jobId: job!.id,
      laborFee: 350.0,
      extraRepairNote: 'Replace worn drive belt',
      extraRepairFee: 450.0,
    );
    expect(quoteOk, isTrue);
    await vm.approveCustomerExtraRepair(job.id);
    final approvedJob = vm.branchJobOrders.firstWhere((j) => j.id == job.id);
    expect(approvedJob.effectiveLaborFee, 800.0);

    final firstBill = await vm.processServiceJobCheckout(
      job: approvedJob,
      paymentMethod: PaymentMethod.cash,
      amountTendered: 1000.0,
    );
    expect(firstBill, isNotNull);

    // Second billing attempt on the same job must be rejected
    final duplicateBill = await vm.processServiceJobCheckout(
      job: approvedJob,
      paymentMethod: PaymentMethod.cash,
      amountTendered: 1000.0,
    );
    expect(duplicateBill, isNull);
  });
}
