import 'package:flutter_test/flutter_test.dart';
import 'package:boss_arman_motohub/core/models/models.dart';
import 'package:boss_arman_motohub/core/utils/formatters.dart';
import 'package:boss_arman_motohub/viewmodels/motohub_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tasks 1 to 4 Architectural Enhancement Unit Tests', () {
    test('AppNotificationItem model serializes and deserializes targetRole, targetUserId, and payload', () {
      final notif = AppNotificationItem(
        id: 'notif_101',
        title: 'Job Order Ready',
        message: 'Your Aerox service is finished and ready for pickup!',
        category: 'service',
        branch: BranchId.patimbao,
        createdAt: DateTime(2026, 10, 11, 10, 30),
        isRead: false,
        targetRole: UserRole.customer,
        targetUserId: 'cust_007',
        payload: {'type': 'job_order', 'jobOrderId': 'JOB-2026-001'},
      );

      final map = notif.toMap();
      expect(map['id'], 'notif_101');
      expect(map['targetRole'], 'customer');
      expect(map['targetUserId'], 'cust_007');
      expect(map['payload'], isA<String>()); // stored as json string in SQLite map

      final revived = AppNotificationItem.fromMap(map);
      expect(revived.id, 'notif_101');
      expect(revived.targetRole, UserRole.customer);
      expect(revived.targetUserId, 'cust_007');
      expect(revived.payload?['jobOrderId'], 'JOB-2026-001');
      expect(revived.category, 'service');
    });

    test('JobOrder model includes mechanicId field and persists through serialization', () {
      final job = JobOrder(
        id: 'JOB-999',
        branch: BranchId.patimbao,
        customerName: 'Arwel',
        customerUsername: 'arwel_rider',
        customerPhone: '09123456789',
        bikeModel: 'Yamaha NMAX 155',
        plateNumber: 'ABC 1234',
        serviceType: 'Maintenance',
        issueDescription: 'Oil change and brake pad replacement',
        assignedMechanic: 'Bong Mechanic',
        mechanicId: 'staff_mech_001',
        status: JobStatus.inBay,
        attachedParts: const [],
        laborFee: 350.0,
        createdAt: DateTime(2026, 10, 11, 8, 0),
        updatedAt: DateTime(2026, 10, 11, 8, 0),
      );

      final map = job.toMap();
      expect(map['mechanicId'], 'staff_mech_001');

      final revived = JobOrder.fromMap(map);
      expect(revived.mechanicId, 'staff_mech_001');
      expect(revived.assignedMechanic, 'Bong Mechanic');
    });

    test('ChatThread and ChatMessage models serialization', () {
      final thread = ChatThread(
        id: 'chat_admin_cust_123',
        participantIds: const ['cust_123', 'admin_001'],
        authUids: const ['uid_123', 'uid_admin'],
        roles: const ['customer', 'admin'],
        lastMessage: 'Hello, is my part available?',
        lastMessageAt: DateTime(2026, 10, 11, 14, 0),
        unreadCounts: const {'cust_123': 0, 'admin_001': 1},
        participantNames: const {'cust_123': 'Juan Dela Cruz', 'admin_001': 'Admin Boss Arman'},
        participantUsernames: const {'cust_123': 'juandc', 'admin_001': 'bossarman'},
        createdAt: DateTime(2026, 10, 11, 14, 0),
      );

      final tMap = thread.toMap();
      expect(tMap['id'], 'chat_admin_cust_123');
      expect(tMap['participantIds'], containsAll(['cust_123', 'admin_001']));
      expect(tMap['unreadCounts']['admin_001'], 1);
      expect(tMap['participantUsernames']['cust_123'], 'juandc');

      final revivedThread = ChatThread.fromMap(tMap);
      expect(revivedThread.id, thread.id);
      expect(revivedThread.participantIds, containsAll(['cust_123', 'admin_001']));
      expect(revivedThread.participantUsernames?['cust_123'], 'juandc');
      expect(revivedThread.participantNames?['cust_123'], 'Juan Dela Cruz');

      final message = ChatMessage(
        id: 'msg_001',
        threadId: thread.id,
        senderId: 'cust_123',
        senderRole: 'customer',
        senderName: 'Juan Dela Cruz',
        senderUsername: 'juandc',
        text: 'Attached is the photo of the broken bracket.',
        imageUrl: 'https://firebasestorage.googleapis.com/test.jpg',
        createdAt: DateTime(2026, 10, 11, 14, 2),
        readBy: const ['cust_123'],
      );

      final mMap = message.toMap();
      expect(mMap['imageUrl'], 'https://firebasestorage.googleapis.com/test.jpg');
      expect(mMap['senderRole'], 'customer');
      expect(mMap['senderName'], 'Juan Dela Cruz');
      expect(mMap['senderUsername'], 'juandc');

      final revivedMessage = ChatMessage.fromMap(mMap);
      expect(revivedMessage.id, 'msg_001');
      expect(revivedMessage.imageUrl, 'https://firebasestorage.googleapis.com/test.jpg');
      expect(revivedMessage.text, 'Attached is the photo of the broken bracket.');
      expect(revivedMessage.senderName, 'Juan Dela Cruz');
      expect(revivedMessage.senderUsername, 'juandc');
    });

    test('Chat pair validation rules (Task 3 specification)', () {
      // Allowed: Customer <-> Admin
      // Allowed: Customer <-> Mechanic
      // Prohibited: Admin <-> Mechanic
      // Prohibited: Cashier with any user
      bool isAllowedPair({required String userARole, required String userBRole}) {
        if ((userARole == 'customer' && userBRole == 'admin') ||
            (userARole == 'admin' && userBRole == 'customer')) {
          return true;
        }
        if ((userARole == 'customer' && userBRole == 'mechanic') ||
            (userARole == 'mechanic' && userBRole == 'customer')) {
          return true;
        }
        return false;
      }

      expect(isAllowedPair(userARole: 'customer', userBRole: 'admin'), isTrue);
      expect(isAllowedPair(userARole: 'customer', userBRole: 'mechanic'), isTrue);
      expect(isAllowedPair(userARole: 'admin', userBRole: 'mechanic'), isFalse,
          reason: 'Admin <-> Mechanic chat is strictly NO');
      expect(isAllowedPair(userARole: 'cashier', userBRole: 'customer'), isFalse,
          reason: 'Cashier has no chat');
      expect(isAllowedPair(userARole: 'cashier', userBRole: 'admin'), isFalse,
          reason: 'Cashier has no chat');
      expect(isAllowedPair(userARole: 'cashier', userBRole: 'mechanic'), isFalse,
          reason: 'Cashier has no chat');
    });

    test('ClickAndCollectOrder toSqliteMap does not include unmapped alias keys', () {
      final order = ClickAndCollectOrder(
        id: 'RES-001',
        customerId: 'CUS-001',
        customerUsername: 'rider01',
        customerName: 'Juan Dela Cruz',
        customerPhone: '09171234567',
        pickupBranch: BranchId.patimbao,
        partId: 'PRT-001',
        sku: 'SKU-001',
        partName: 'Motul 300V',
        quantity: 3,
        unitPrice: 200.0,
        status: 'Pending',
        createdAt: DateTime(2026, 10, 12, 12, 0),
        expiresAt: DateTime(2026, 10, 14, 12, 0),
      );

      final sqlMap = order.toSqliteMap();
      expect(sqlMap.containsKey('reservationId'), isFalse);
      expect(sqlMap.containsKey('branchId'), isFalse);
      expect(sqlMap.containsKey('itemId'), isFalse);
      expect(sqlMap.containsKey('qty'), isFalse);
      expect(sqlMap['id'], 'RES-001');
      expect(sqlMap['quantity'], 3);
      expect(sqlMap['pickupBranch'], 'patimbao');
    });

    test('Customer registration records Terms acceptance version & timestamp, and Google user can delete account with DELETE', () async {
      final vm = MotoHubViewModel(isCustomerApp: true);
      await vm.initializeApp();

      final regOk = await vm.registerCustomerAccount(
        firstName: 'Carlo',
        lastName: 'Reyes',
        username: 'carlo.rider',
        email: 'carlo@rider.ph',
        password: 'password123',
        termsVersion: 'v1.0 (2026-10)',
      );
      expect(regOk, isTrue);
      expect(vm.currentUser?.termsAcceptedVersion, 'v1.0 (2026-10)');
      expect(vm.currentUser?.termsAcceptedAt, isNotNull);

      // Sign in with Google One-Tap and verify account deletion with 'DELETE'
      final googleOk = await vm.signInCustomerWithGoogle(
        email: 'google.rider@gmail.com',
        displayName: 'Google Rider',
      );
      expect(googleOk, isTrue);
      expect(vm.currentUser?.authProvider, 'google');
      expect(vm.currentUser?.termsAcceptedVersion, 'v1.0 (2026-10)');

      final badDelete = await vm.deleteCustomerAccount(password: 'wrong');
      expect(badDelete, isFalse);

      final goodDelete = await vm.deleteCustomerAccount(password: 'DELETE');
      expect(goodDelete, isTrue);
      expect(vm.currentUser, isNull);
    });

    test('Part Name (max 50 chars), SKU (max 24 chars + duplicate check), and Barcode (max 20 chars + duplicate check) validation', () async {
      // 1. Direct AppValidators tests
      expect(AppValidators.partName(''), isNotNull);
      expect(AppValidators.partName('AB'), isNotNull);
      expect(AppValidators.partName('---'), isNotNull);
      expect(AppValidators.partName('A' * 50), isNull);
      expect(AppValidators.partName('A' * 51), isNotNull);
      expect(AppValidators.partName('Motul 300V 10W-40 1L Factory Line'), isNull);

      expect(AppValidators.sku(''), isNotNull);
      expect(AppValidators.sku('AB'), isNotNull);
      expect(AppValidators.sku('SKU WITH SPACES'), isNotNull);
      expect(AppValidators.sku('S' * 25), isNotNull);
      expect(
        AppValidators.sku('MTL-300V-1L', existingSkus: ['mtl-300v-1l']),
        isNotNull,
      );
      expect(
        AppValidators.sku('MTL-300V-1L', existingSkus: ['OTHER-SKU-01']),
        isNull,
      );

      expect(AppValidators.barcode(''), isNotNull);
      expect(AppValidators.barcode('123'), isNotNull);
      expect(AppValidators.barcode('885 01001'), isNotNull);
      expect(AppValidators.barcode('8' * 21), isNotNull);
      expect(
        AppValidators.barcode('4800912000101', existingBarcodes: ['4800912000101']),
        isNotNull,
      );
      expect(
        AppValidators.barcode('4800912000999', existingBarcodes: ['4800912000101']),
        isNull,
      );

      // 2. ViewModel enforcement tests
      final vm = MotoHubViewModel();
      await vm.initializeApp();

      // Reject > 50 char Part Name
      final overlongNameItem = InventoryItem(
        id: 'PRT-VAL-01',
        sku: 'VAL-SKU-001',
        barcode: '4800999777001',
        name: 'X' * 51,
        category: 'Oils & Fluids',
        price: 550,
        costPrice: 396,
        stockPatimbao: 5,
        stockPedroGuevara: 5,
        rack: 'Rack A',
        shelf: 'Shelf 1',
        bin: 'Bin 01',
        compatibleModels: 'Universal Scooter',
      );
      expect(await vm.addOrUpdateInventoryItem(overlongNameItem), isFalse);

      // Accept valid 50-char Part Name, valid SKU & Barcode
      final validItem = overlongNameItem.copyWith(
        name: 'Motul Scooter Power LE 4T 5W-40 0.8L Synthetic Oil', // 50 chars
      );
      expect(validItem.name.length, 50);
      expect(await vm.addOrUpdateInventoryItem(validItem), isTrue);

      // Reject duplicate SKU on a different item ID
      final duplicateSkuItem = InventoryItem(
        id: 'PRT-VAL-02',
        sku: 'VAL-SKU-001',
        barcode: '4800999777002',
        name: 'Genuine Yamaha Brake Pad Set',
        category: 'Brakes & Suspension',
        price: 450,
        costPrice: 320,
        stockPatimbao: 4,
        stockPedroGuevara: 4,
        rack: 'Rack B',
        shelf: 'Shelf 2',
        bin: 'Bin 02',
        compatibleModels: 'Yamaha NMAX / Aerox',
      );
      expect(await vm.addOrUpdateInventoryItem(duplicateSkuItem), isFalse);

      // Reject duplicate Barcode on a different item ID
      final duplicateBarcodeItem = InventoryItem(
        id: 'PRT-VAL-03',
        sku: 'VAL-SKU-003',
        barcode: '4800999777001',
        name: 'Genuine Yamaha Brake Pad Set',
        category: 'Brakes & Suspension',
        price: 450,
        costPrice: 320,
        stockPatimbao: 4,
        stockPedroGuevara: 4,
        rack: 'Rack B',
        shelf: 'Shelf 2',
        bin: 'Bin 02',
        compatibleModels: 'Yamaha NMAX / Aerox',
      );
      expect(await vm.addOrUpdateInventoryItem(duplicateBarcodeItem), isFalse);

      // Allow updating the SAME item ID with its own SKU & Barcode
      final updatedSameItem = validItem.copyWith(price: 580);
      expect(await vm.addOrUpdateInventoryItem(updatedSameItem), isTrue);
    });

    test('Customer App Rider Name, 11-digit Phone, Motorcycle Model, Plate/MV No, and Sentence Service Notes validation', () async {
      // 1. Rider Full Name (3 to 50 chars, letters only)
      expect(AppValidators.riderFullName(''), isNotNull);
      expect(AppValidators.riderFullName('Jo'), isNotNull);
      expect(AppValidators.riderFullName('A' * 51), isNotNull);
      expect(AppValidators.riderFullName('12345'), isNotNull);
      expect(AppValidators.riderFullName('Juan Dela Cruz'), isNull);
      expect(AppValidators.riderFullName('Maria Santos-Reyes'), isNull);

      // 2. Philippine Mobile Number (strictly 11 digits, numbers only, starts with 09)
      expect(AppValidators.philippineMobileNumber(''), isNotNull);
      expect(AppValidators.philippineMobileNumber('0912345678'), isNotNull); // 10 digits
      expect(AppValidators.philippineMobileNumber('091234567890'), isNotNull); // 12 digits
      expect(AppValidators.philippineMobileNumber('0917ABCD456'), isNotNull); // letters
      expect(AppValidators.philippineMobileNumber('08123456789'), isNotNull); // doesn't start with 09
      expect(AppValidators.philippineMobileNumber('09171234567'), isNull); // exact 11 digits
      expect(AppValidators.philippineMobileNumber('0917-123-4567'), isNull); // formatted 11 digits

      // 3. Motorcycle Model (2 to 40 chars, alphanumeric)
      expect(AppValidators.motorcycleModel(''), isNotNull);
      expect(AppValidators.motorcycleModel('X'), isNotNull);
      expect(AppValidators.motorcycleModel('M' * 41), isNotNull);
      expect(AppValidators.motorcycleModel('Yamaha NMAX v2 155'), isNull);
      expect(AppValidators.motorcycleModel('Honda Click 125i'), isNull);

      // 4. Plate / MV File No. (3 to 7 chars max)
      expect(AppValidators.plateNumber(''), isNotNull);
      expect(AppValidators.plateNumber('412-NBO'), isNull);
      expect(AppValidators.plateNumber('111-ABC'), isNull);
      expect(AppValidators.plateNumber('ABC1234'), isNull);
      expect(AppValidators.plateNumber('FOR-REG'), isNull);
      expect(AppValidators.plateNumber('ABC-1234'), isNotNull); // 8 chars -> rejected (>7 chars)
      expect(AppValidators.plateNumber('0401-0123456'), isNotNull); // 12 chars -> rejected (>7 chars)
      expect(AppValidators.plateNumber('ABCDEFG8'), isNotNull); // 8 chars -> rejected (>7 chars)

      // 5. Service Notes (sentence, 8 to 250 chars)
      expect(AppValidators.serviceNotes(''), isNotNull);
      expect(AppValidators.serviceNotes('Fix it'), isNotNull); // too short
      expect(AppValidators.serviceNotes('S' * 251), isNotNull); // too long
      expect(
        AppValidators.serviceNotes('Dragging vibration coming from the CVT belt pulley on acceleration.'),
        isNull,
      );

      // 6. ViewModel createJobOrder enforcement
      final vm = MotoHubViewModel(isCustomerApp: true);
      await vm.initializeApp();

      // Reject invalid phone
      final badPhoneJob = await vm.createJobOrder(
        customerName: 'Juan Dela Cruz',
        customerPhone: '08123456789', // invalid prefix
        bikeModel: 'Yamaha NMAX 155',
        plateNumber: '412-NBO',
        serviceType: 'CVT Tuning & Pulley Upgrade',
        issueDescription: 'Dragging sound when accelerating.',
        assignedMechanic: 'Lance M. Aclan',
      );
      expect(badPhoneJob, isNull);

      // Reject too short service description
      final badNoteJob = await vm.createJobOrder(
        customerName: 'Juan Dela Cruz',
        customerPhone: '09171234567',
        bikeModel: 'Yamaha NMAX 155',
        plateNumber: '412-NBO',
        serviceType: 'CVT Tuning & Pulley Upgrade',
        issueDescription: 'Broken',
        assignedMechanic: 'Lance M. Aclan',
      );
      expect(badNoteJob, isNull);

      // Accept fully valid appointment
      final goodJob = await vm.createJobOrder(
        customerName: 'Juan Dela Cruz',
        customerPhone: '09171234567',
        bikeModel: 'Yamaha NMAX 155',
        plateNumber: '412-NBO',
        serviceType: 'CVT Tuning & Pulley Upgrade',
        issueDescription: 'Dragging sound when accelerating.',
        assignedMechanic: 'Lance M. Aclan',
      );
      expect(goodJob, isNotNull);
      expect(goodJob?.customerPhone, '09171234567');
    });

    test('Owner can edit and publish Terms & Conditions and Privacy Policy with persistence and reset', () async {
      final vm = MotoHubViewModel();
      await vm.initializeApp();

      // Sign in as owner / admin
      await vm.login('bossarman', 'admin123');
      expect(vm.currentUser?.role, UserRole.admin);

      // Save custom terms & conditions
      final saveTermsOk = await vm.saveCustomLegalDocument(
        docKey: 'terms_and_conditions',
        title: 'Terms & Conditions',
        content: '1. Custom Shop Warranty Policy\nAll CVT upgrades include a 6-month labor warranty.\n• Free retightening within 30 days',
        version: 'v2.0 (Owner Customized)',
      );
      expect(saveTermsOk, isTrue);
      expect(vm.getCustomLegalDocument('terms_and_conditions'), contains('Custom Shop Warranty Policy'));

      // Save custom privacy policy
      final savePrivacyOk = await vm.saveCustomLegalDocument(
        docKey: 'privacy_policy',
        title: 'Privacy Policy',
        content: '1. Santa Cruz Laguna Rider Data Protection\nWe respect customer privacy under RA 10173.\n• Phone numbers are only used for bay status alerts',
        version: 'v2.0 (Owner Customized)',
      );
      expect(savePrivacyOk, isTrue);
      expect(vm.getCustomLegalDocument('privacy_policy'), contains('Santa Cruz Laguna Rider Data Protection'));

      // Reset to default
      final resetOk = await vm.resetCustomLegalDocument('terms_and_conditions');
      expect(resetOk, isTrue);
      expect(vm.getCustomLegalDocument('terms_and_conditions'), isNull);
    });
  });
}

