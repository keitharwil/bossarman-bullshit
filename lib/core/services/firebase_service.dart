import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Production Firebase Service for BossArman MotoHub & MotoHub Rider.
/// Handles Authentication, Firestore Real-Time Synchronization across apps,
/// Role-Based User documents (`users/{uid}`), and Automated FCM Push Notifications.
///
/// Designed defensively with graceful fallback when running in offline environments,
/// desktop platforms, or test harnesses without Firebase credentials.
/// One document change delivered by a Firestore listener.
class RemoteChange<T> {
  final String id;
  final T? item; // null when [removed]
  final bool removed;
  const RemoteChange({required this.id, this.item, required this.removed});
}

/// A batch of changes from one Firestore snapshot.
class RemoteBatch<T> {
  final List<RemoteChange<T>> changes;
  final bool isFromCache;
  final bool collectionEmpty;
  const RemoteBatch({
    required this.changes,
    required this.isFromCache,
    required this.collectionEmpty,
  });
}

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN-IN CONFIG
  // ---------------------------------------------------------------------------
  // REQUIRED on Android: the *Web application* OAuth client ID, found in
  // Firebase Console > Authentication > Sign-in method > Google > Web SDK
  // configuration > "Web client ID" (ends with .apps.googleusercontent.com).
  //
  // Either paste it below, or pass it at build time:
  //   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '227590854338-7jkfg22u2ajic9jsvd900fbggcmf71al.apps.googleusercontent.com',
  );

  bool get _hasServerClientId =>
      _googleServerClientId.endsWith('.apps.googleusercontent.com') &&
      !_googleServerClientId.startsWith('PASTE_YOUR_WEB_CLIENT_ID');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Last reason Firebase failed to initialize (null when healthy).
  String? _initError;
  String? get initError => _initError;

  Future<void>? _initFuture;

  /// Last Firestore sync error (null when healthy). UI can listen to this to
  /// show a "Cloud sync problem" banner instead of failing silently.
  final ValueNotifier<String?> syncError = ValueNotifier<String?>(null);

  void _recordSyncError(String where, Object e) {
    final msg = '$where: $e';
    debugPrint('[FirebaseService] SYNC ERROR $msg');
    syncError.value = msg;
  }

  void _clearSyncError() {
    if (syncError.value != null) syncError.value = null;
  }

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;
  FirebaseStorage? _storage;

  FirebaseStorage? get storage => _storage;
  String? _cachedFcmToken;
  String? get fcmToken => _cachedFcmToken;
  String? get currentAuthUid => _auth?.currentUser?.uid;
  final Map<String, ({UserRole role, BranchId branch})> _activeBoundUsers = {};

  /// Key under which active user bindings are persisted so a cold-started app
  /// can re-sync its FCM token before login completes.
  static const String _kPersistedBindingsKey = 'fcm_active_bindings';

  /// Safe to call many times / concurrently; only one init ever runs.
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initFuture ??= _doInitialize().whenComplete(() {
      // Allow a retry on the next call if init failed.
      if (!_isInitialized) _initFuture = null;
    });
  }

  Future<void> _doInitialize() async {
    try {
      final isFlutterTest =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (!isFlutterTest &&
          (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        _messaging = FirebaseMessaging.instance;
        try {
          _storage = FirebaseStorage.instanceFor(
            bucket: 'bossarman-760da.firebasestorage.app',
          );
        } catch (_) {
          try {
            _storage = FirebaseStorage.instance;
          } catch (_) {}
        }
        // Offline cache: edits made without signal are queued and uploaded
        // automatically when the phone reconnects.
        try {
          _firestore!.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          debugPrint('[FirebaseService] Firestore settings notice: $e');
        }
        await _ensureSignedIn();
        _isInitialized = true;
        _initError = null;
        _clearSyncError();
        debugPrint('[FirebaseService] Firebase initialized successfully.');

        // Do not block startup on the notification-permission dialog.
        unawaited(_initFcm());
      } else {
        _initError =
            'Firebase is only enabled on Android, iOS and Web. Using local database.';
        debugPrint('[FirebaseService] $_initError');
      }
    } catch (e) {
      _initError = '$e';
      syncError.value =
          'Firebase failed to start: $e (check google-services.json package name matches the app flavor)';
      debugPrint('[FirebaseService] Firebase initialization FAILED: $e');
      debugPrint(
        '[FirebaseService] Check: google-services.json / GoogleService-Info.plist '
        'exists, its package name / bundle ID matches this app, and the '
        'com.google.gms.google-services Gradle plugin is applied.',
      );
      _isInitialized = false;
    }
  }

  /// Firestore rules require `request.auth != null`. Staff/customer logins in
  /// this app are local, so the device signs into Firebase anonymously to be
  /// allowed to read/write. (Enable Authentication > Sign-in method > Anonymous.)
  Future<void> ensureSignedIn() => _ensureSignedIn();

  Future<void> _ensureSignedIn() async {
    try {
      if (_auth != null && _auth!.currentUser == null) {
        await _auth!.signInAnonymously().timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      _recordSyncError(
        'Anonymous sign-in failed (enable the Anonymous provider in Firebase Auth)',
        e,
      );
    }
  }

  Future<void> _initFcm() async {
    try {
      if (_messaging == null) return;
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _cachedFcmToken = await _messaging!.getToken();
        debugPrint('[FirebaseService] FCM Token: $_cachedFcmToken');
      }

      // Restore any previously-bound users and re-merge the current token.
      // When the app is killed/swiped-away, Play Services can rotate the FCM
      // token; without this re-sync the server keeps sending to a dead token
      // and pushes are lost while the app is closed.
      await restoreActiveBindings();
      final token = _cachedFcmToken;
      if (token != null && token.isNotEmpty) {
        await updateAllActiveBindingsWithToken(token);
      }

      _messaging!.onTokenRefresh.listen((newToken) async {
        _cachedFcmToken = newToken;
        debugPrint('[FirebaseService] FCM Token refreshed: $newToken');
        for (final entry in _activeBoundUsers.entries.toList()) {
          await updateUserBinding(
            appUserId: entry.key,
            role: entry.value.role,
            branch: entry.value.branch,
          );
        }
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FirebaseService] Foreground FCM Message received: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('[FirebaseService] FCM init warning: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 1. AUTHENTICATION & ROLE-BASED FIRESTORE USER DOCS
  // ---------------------------------------------------------------------------

  /// Sign In with Email + Password
  Future<StaffAccount?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final cred = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return null;

      final doc = await _firestore?.collection('users').doc(uid).get();
      if (doc != null && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = uid;
        if (_cachedFcmToken != null) {
          await _firestore?.collection('users').doc(uid).set({
            'fcmToken': _cachedFcmToken,
          }, SetOptions(merge: true));
        }
        return StaffAccount.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('[FirebaseService] signInWithEmail error: $e');
      rethrow;
    }
  }

  bool _googleSignInInitialized = false;

  /// Native Google One-Tap / Google Sign-In, linked to Firebase Auth.
  ///
  /// 1. Makes sure Firebase is initialized (and explains why if it is not).
  /// 2. Tries lightweight One-Tap first, then the interactive account picker.
  /// 3. Exchanges the Google ID token for a Firebase credential and signs in
  ///    to Firebase Auth, so Firestore calls are authenticated.
  ///
  /// Returns {'email','displayName','id','photoUrl','uid'} or null if the
  /// user cancelled the dialog. Throws with a readable message on failure.
  Future<Map<String, String?>?> promptNativeGoogleSignIn() async {
    try {
      // --- 1. Firebase must be ready -----------------------------------------
      if (!_isInitialized) {
        await initialize();
      }
      if (!_isInitialized || _auth == null) {
        throw StateError(
          'Firebase is not connected. Reason: ${_initError ?? "unknown"}',
        );
      }

      // --- 2. Google Sign-In must be configured ------------------------------
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw UnsupportedError(
          'Native Google Sign-In is not supported on this platform. Please run on Android or iOS.',
        );
      }

      if (!_googleSignInInitialized) {
        if (defaultTargetPlatform == TargetPlatform.android &&
            !_hasServerClientId) {
          throw StateError(
            'Missing Google Web Client ID. Paste it into _googleServerClientId '
            'in firebase_service.dart (Firebase Console > Authentication > '
            'Sign-in method > Google > Web SDK configuration), or run with '
            '--dart-define=GOOGLE_SERVER_CLIENT_ID=...',
          );
        }
        await GoogleSignIn.instance.initialize(
          serverClientId: _hasServerClientId ? _googleServerClientId : null,
        );
        _googleSignInInitialized = true;
      }

      GoogleSignInAccount? account;
      // 2a. Attempt lightweight One-Tap authentication first
      try {
        account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      } catch (e) {
        debugPrint('[FirebaseService] Lightweight Google One-Tap check note: $e');
        account = null;
      }

      // 2b. If no active session was restored, launch interactive account picker
      account ??= await GoogleSignIn.instance.authenticate();

      // --- 3. Link the Google account to Firebase Auth -----------------------
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an ID token. Make sure the Web Client ID is '
          'correct and your SHA-1 / SHA-256 fingerprints are added to the '
          'Android app in Firebase project settings.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await _auth!.signInWithCredential(credential);

      return {
        'email': account.email,
        'displayName': account.displayName,
        'id': account.id,
        'photoUrl': account.photoUrl,
        'uid': userCred.user?.uid,
      };
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[FirebaseService] Google Sign-In was cancelled by user.');
        return null;
      }
      debugPrint('[FirebaseService] GoogleSignInException: ${e.code} - ${e.description}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseService] Firebase Auth rejected Google credential: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] promptNativeGoogleSignIn error: $e');
      rethrow;
    }
  }

  /// Register new user and persist role-based doc in `users/{uid}`
  Future<StaffAccount?> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    required UserRole role,
    required BranchId branch,
  }) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final cred = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return null;

      final staff = StaffAccount(
        id: uid,
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email.trim(),
        password: password,
        role: role,
        assignedBranch: branch,
        shiftStatus: 'On Duty',
        authProvider: 'password',
        fcmToken: _cachedFcmToken,
        createdAt: DateTime.now(),
      );

      await _firestore?.collection('users').doc(uid).set(staff.toFirestoreDoc());
      return staff;
    } catch (e) {
      debugPrint('[FirebaseService] registerWithEmail error: $e');
      rethrow;
    }
  }

  /// Save or update user FCM token in Firestore
  Future<void> updateUserFcmToken(String uid, String? token) async {
    if (!_isInitialized || _firestore == null || token == null) return;
    try {
      await _firestore!.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] updateUserFcmToken error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. PASSWORD RESET & FIREBASE AUTH PROVISIONING
  // ---------------------------------------------------------------------------

  /// Sends the standard Firebase Auth password-reset email.
  /// Throws [AuthFlowException] with a user-friendly message on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isInitialized || _auth == null) {
      throw const AuthFlowException(
        'Cloud service is unavailable. Check your internet connection and try again.',
      );
    }
    try {
      await _auth!
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 15));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw const AuthFlowException(
            'No account is registered with that email address.',
          );
        case 'invalid-email':
          throw const AuthFlowException('That email address is not valid.');
        case 'too-many-requests':
          throw const AuthFlowException(
            'Too many attempts. Please wait a few minutes and try again.',
          );
        case 'network-request-failed':
          throw const AuthFlowException(
            'Network error. Check your connection and try again.',
          );
        default:
          throw AuthFlowException(
            'Could not send the reset email (${e.code}). Please try again.',
          );
      }
    } on TimeoutException {
      throw const AuthFlowException(
        'The request timed out. Check your connection and try again.',
      );
    }
  }

  /// True when Firebase Auth accepts this email + password. Used as a
  /// fallback by login so passwords changed through the reset email work.
  Future<bool> verifyEmailPassword(String email, String password) async {
    if (!_isInitialized || _auth == null) return false;
    try {
      await _auth!
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Best effort: makes sure a Firebase Auth user exists for an account that
  /// was created locally (so password-reset emails work for it). Never throws.
  Future<void> ensureAuthAccount(String email, String password) async {
    if (!_isInitialized || _auth == null || password.length < 6) return;
    try {
      await _auth!
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 10));
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') return;
    } catch (_) {
      return;
    }
    try {
      await _auth!
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[FirebaseService] ensureAuthAccount note: $e');
    }
  }

  /// Creates a Firebase Auth user WITHOUT touching the current (owner)
  /// session, by using a secondary FirebaseApp instance. Returns the new UID.
  /// The password is sent to Firebase Auth only; it is never stored here.
  Future<String> createAuthUserSecondary({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized || _auth == null) {
      throw const AuthFlowException(
        'Cloud service is unavailable. Staff accounts need an internet connection to be created.',
      );
    }
    const appName = 'staffProvisioning';
    FirebaseApp secondary;
    try {
      secondary = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
      secondary = Firebase.app(appName);
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    try {
      final cred = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      final uid = cred.user?.uid;
      if (uid == null) {
        throw const AuthFlowException('Could not create the staff login.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw const AuthFlowException(
            'That email already has a login. Use a different email.',
          );
        case 'weak-password':
          throw const AuthFlowException(
            'Password is too weak. Use at least 6 characters.',
          );
        case 'invalid-email':
          throw const AuthFlowException('That email address is not valid.');
        case 'network-request-failed':
          throw const AuthFlowException(
            'Network error. Check your connection and try again.',
          );
        default:
          throw AuthFlowException('Could not create login (${e.code}).');
      }
    } finally {
      // Never leave the secondary session signed in.
      await secondaryAuth.signOut();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. AUTOMATED CUSTOMER PUSH NOTIFICATIONS (FCM)
  // ---------------------------------------------------------------------------

  /// Triggered when mechanic transitions Job Order status to `Ready for Pickup`
  Future<void> sendJobReadyPushNotification({
    required String jobId,
    required String bikeModel,
    required String? customerFcmToken,
    required BranchId branch,
  }) async {
    const title = 'Your motorcycle is ready for pickup! 🏍️';
    final body =
        'Job Order #$jobId ($bikeModel) has been completed. View your itemized bill and claim your unit at Boss Arman MotoHub (${branch.shortName}).';

    debugPrint('[FirebaseService] FCM Trigger -> Title: "$title" | Body: "$body" | Target: $customerFcmToken');

    if (!_isInitialized || _firestore == null) return;
    try {
      // Store in Firestore notifications collection to sync directly to customer app
      await _firestore!.collection('customer_notifications').add({
        'jobId': jobId,
        'title': title,
        'body': body,
        'branch': branch.name,
        'fcmToken': customerFcmToken,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('[FirebaseService] sendJobReadyPushNotification note: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 4. CROSS-APP FIRESTORE REAL-TIME SYNCHRONIZATION
  // ---------------------------------------------------------------------------

  Future<void> _upsert(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!
          .collection(collection)
          .doc(id)
          .set(data, SetOptions(merge: true));
      _clearSyncError();
    } catch (e) {
      _recordSyncError('write $collection/$id', e);
    }
  }

  /// Syncs customer booking or active job order directly to Firestore
  Future<void> syncJobOrderToFirestore(JobOrder job) =>
      _upsert('job_orders', job.id, job.toMap());

  /// Removes a job order from Firestore so other devices remove it too.
  Future<void> deleteJobOrderFromFirestore(String id) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('job_orders').doc(id).delete();
      _clearSyncError();
    } catch (e) {
      _recordSyncError('delete job_orders/$id', e);
    }
  }

  /// Syncs an inventory update directly to Firestore
  Future<void> syncInventoryItemToFirestore(InventoryItem item) =>
      _upsert('inventory', item.id, item.toMap());

  /// Removes an inventory item from Firestore so other phones drop it too.
  Future<void> deleteInventoryItemFromFirestore(String id) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('inventory').doc(id).delete();
      _clearSyncError();
    } catch (e) {
      _recordSyncError('delete inventory/$id', e);
    }
  }

  /// One-time read of the whole inventory straight from the SERVER (never
  /// the local cache). Throws when the phone is offline, which is how the
  /// app knows to show "Offline".
  Future<List<InventoryItem>> fetchInventoryFromServer() async {
    if (!_isInitialized || _firestore == null) {
      throw StateError('Firebase is not available on this device.');
    }
    final snap = await _firestore!
        .collection('inventory')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    return snap.docs
        .map((d) => InventoryItem.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  /// Uploads many inventory changes in batches (Firestore allows 500 per batch).
  /// Unlike syncInventoryItemToFirestore this does NOT swallow errors,
  /// so the caller can show Offline / Error correctly.
  Future<void> pushInventoryChanges({
    required List<InventoryItem> upserts,
    required List<String> deletedIds,
  }) async {
    if (!_isInitialized || _firestore == null) {
      throw StateError('Firebase is not available on this device.');
    }
    final col = _firestore!.collection('inventory');
    const chunk = 400;

    for (var i = 0; i < upserts.length; i += chunk) {
      final batch = _firestore!.batch();
      for (final item in upserts.skip(i).take(chunk)) {
        batch.set(col.doc(item.id), item.toMap(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }

    for (var i = 0; i < deletedIds.length; i += chunk) {
      final batch = _firestore!.batch();
      for (final id in deletedIds.skip(i).take(chunk)) {
        batch.delete(col.doc(id));
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }
  }

  /// Live stream of the inventory collection. This is what makes a change on
  /// one phone appear on every other phone without anyone pressing anything.
  Stream<InventorySnapshot> streamInventory() {
    if (!_isInitialized || _firestore == null) {
      return const Stream.empty();
    }
    return _firestore!
        .collection('inventory')
        .snapshots(includeMetadataChanges: true)
        .map(
          (s) => InventorySnapshot(
            items: s.docs
                .map((d) => InventoryItem.fromMap({...d.data(), 'id': d.id}))
                .toList(),
            fromServer: !s.metadata.isFromCache,
            hasPendingWrites: s.metadata.hasPendingWrites,
          ),
        );
  }

  /// Syncs a Click & Collect reservation directly to Firestore
  Future<void> syncClickAndCollectToFirestore(ClickAndCollectOrder order) =>
      _upsert('click_and_collect', order.id, order.toMap());

  /// Removes a Click & Collect reservation from Firestore
  Future<void> deleteClickAndCollectFromFirestore(String id) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('click_and_collect').doc(id).delete();
      _clearSyncError();
    } catch (e) {
      _recordSyncError('delete click_and_collect/$id', e);
    }
  }

  /// Safely executes an atomic reservation transaction in Firestore
  Future<bool> executeReservationTransaction({
    required ClickAndCollectOrder order,
    required InventoryItem updatedItem,
  }) async {
    if (!_isInitialized || _firestore == null) return false;
    try {
      await _firestore!.runTransaction((transaction) async {
        final partRef = _firestore!.collection('inventory').doc(updatedItem.id);
        final partDoc = await transaction.get(partRef);
        if (partDoc.exists) {
          final data = partDoc.data() ?? {};
          final currentPatimbaoStock = (data['stockPatimbao'] as num?)?.toInt() ?? 0;
          final currentGuevaraStock = (data['stockPedroGuevara'] as num?)?.toInt() ?? 0;
          final currentPatimbaoLocked = (data['lockedPatimbao'] as num?)?.toInt() ?? 0;
          final currentGuevaraLocked = (data['lockedPedroGuevara'] as num?)?.toInt() ?? 0;

          final avail = order.pickupBranch == BranchId.patimbao
              ? (currentPatimbaoStock - currentPatimbaoLocked)
              : (currentGuevaraStock - currentGuevaraLocked);
          if (avail < order.quantity) {
            throw Exception('Insufficient available stock: $avail < requested ${order.quantity}');
          }
          final newLockedPatimbao = order.pickupBranch == BranchId.patimbao
              ? currentPatimbaoLocked + order.quantity
              : currentPatimbaoLocked;
          final newLockedPedroGuevara = order.pickupBranch == BranchId.pedroGuevara
              ? currentGuevaraLocked + order.quantity
              : currentGuevaraLocked;
          transaction.update(partRef, {
            'lockedPatimbao': newLockedPatimbao,
            'lockedPedroGuevara': newLockedPedroGuevara,
          });
        }
        final orderRef = _firestore!.collection('click_and_collect').doc(order.id);
        transaction.set(orderRef, order.toMap());
      });
      return true;
    } catch (e) {
      debugPrint('[FirebaseService] Reservation transaction error: $e');
      return false;
    }
  }

  /// Syncs a Stock Transfer directly to Firestore
  Future<void> syncStockTransferToFirestore(StockTransfer transfer) =>
      _upsert('stock_transfers', transfer.id, transfer.toMap());

  /// Syncs a POS Transaction directly to Firestore
  Future<void> syncPosTransactionToFirestore(PosTransaction tx) =>
      _upsert('transactions', tx.id, tx.toMap());

  /// Syncs a staff/admin account (salted password HASH, never plaintext).
  /// Customers go to a separate collection so the internal app never mixes
  /// them with staff.
  Future<void> syncStaffToFirestore(StaffAccount staff) => _upsert(
        staff.role == UserRole.customer ? 'customer_accounts' : 'staff_accounts',
        staff.id,
        staff.toMap(),
      );

  /// Fetches GCash payment QR and account config from Firestore
  Future<Map<String, dynamic>?> fetchGcashConfig() async {
    if (!_isInitialized || _firestore == null) return null;
    try {
      final doc = await _firestore!.collection('settings').doc('gcash_config').get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Syncs GCash payment QR and account config to Firestore
  Future<void> syncGcashConfig(Map<String, dynamic> data) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('settings').doc('gcash_config').set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing GCash config to Firestore: $e');
    }
  }

  /// Fetches published legal document from Firestore ('terms_and_conditions' or 'privacy_policy')
  Future<Map<String, dynamic>?> fetchLegalDocument(String docKey) async {
    if (!_isInitialized || _firestore == null) return null;
    try {
      final doc = await _firestore!.collection('settings').doc('legal_$docKey').get();
      return doc.data();
    } catch (e) {
      debugPrint('[FirebaseService] Error fetching legal doc $docKey: $e');
      return null;
    }
  }

  /// Syncs updated legal document to Firestore (Owner / Admin only)
  Future<bool> syncLegalDocument({
    required String docKey,
    required String content,
    required String title,
    required String updatedBy,
    required String version,
  }) async {
    if (!_isInitialized || _firestore == null) return false;
    try {
      await _firestore!.collection('settings').doc('legal_$docKey').set({
        'docKey': docKey,
        'title': title,
        'content': content,
        'updatedBy': updatedBy,
        'version': version,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[FirebaseService] Error syncing legal doc $docKey: $e');
      return false;
    }
  }

  // ---- Real-time listeners -------------------------------------------------

  Stream<RemoteBatch<T>> _streamCollection<T>(
    String collection,
    T Function(Map<String, dynamic> data) parse, {
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>> c)?
        query,
  }) {
    if (!_isInitialized || _firestore == null) return const Stream.empty();
    final col = _firestore!.collection(collection);
    final q = query != null ? query(col) : col;
    return q
        .snapshots()
        .map((snap) {
          final changes = <RemoteChange<T>>[];
          for (final c in snap.docChanges) {
            if (c.type == DocumentChangeType.removed) {
              changes.add(RemoteChange<T>(id: c.doc.id, removed: true));
              continue;
            }
            try {
              final data = Map<String, dynamic>.from(c.doc.data() ?? {});
              data.putIfAbsent('id', () => c.doc.id);
              changes.add(RemoteChange<T>(
                id: c.doc.id,
                item: parse(data),
                removed: false,
              ));
            } catch (e) {
              debugPrint('[FirebaseService] skip malformed $collection/${c.doc.id}: $e');
            }
          }
          _clearSyncError();
          return RemoteBatch<T>(
            changes: changes,
            isFromCache: snap.metadata.isFromCache,
            collectionEmpty: snap.docs.isEmpty,
          );
        })
        .handleError((Object e) => _recordSyncError('listen $collection', e));
  }

  Stream<RemoteBatch<JobOrder>> streamJobOrders() =>
      _streamCollection('job_orders', JobOrder.fromMap);

  Stream<RemoteBatch<ClickAndCollectOrder>> streamClickCollect() =>
      _streamCollection('click_and_collect', ClickAndCollectOrder.fromMap);

  Stream<RemoteBatch<StockTransfer>> streamStockTransfers() =>
      _streamCollection('stock_transfers', StockTransfer.fromMap);

  Stream<RemoteBatch<PosTransaction>> streamTransactions() =>
      _streamCollection('transactions', PosTransaction.fromMap);

  /// Staff & admin accounts (internal ERP app only).
  Stream<RemoteBatch<StaffAccount>> streamStaffAccounts() =>
      _streamCollection('staff_accounts', StaffAccount.fromMap);

  /// Customer accounts (customer app only).
  Stream<RemoteBatch<StaffAccount>> streamCustomerAccounts() =>
      _streamCollection('customer_accounts', StaffAccount.fromMap);

  /// Updates profile photo in Firestore `users/{uid}`
  Future<void> updateUserProfilePhoto(String uid, String? photoUrl) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('users').doc(uid).set({
        'photoUrl': photoUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] updateUserProfilePhoto warning: $e');
    }
  }

  /// Marks a user account as soft-deleted in Firestore across collections
  Future<void> softDeleteUserDoc(String uid, DateTime recoverableUntil) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      final data = {
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'recoverableUntil': recoverableUntil.toIso8601String(),
      };
      await _firestore!.collection('users').doc(uid).set(data, SetOptions(merge: true));
      await _firestore!.collection('staff_accounts').doc(uid).set(data, SetOptions(merge: true));
      await _firestore!.collection('customer_accounts').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] softDeleteUserDoc warning: $e');
    }
  }

  /// Permanently removes a staff or customer account document from Firestore
  Future<void> deleteStaffFromFirestore(String id) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('staff_accounts').doc(id).delete();
      await _firestore!.collection('customer_accounts').doc(id).delete();
      await _firestore!.collection('users').doc(id).delete();
    } catch (e) {
      debugPrint('[FirebaseService] deleteStaffFromFirestore warning: $e');
    }
  }

  /// Restores a soft-deleted user account in Firestore
  Future<void> restoreUserDoc(String uid) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('users').doc(uid).set({
        'isDeleted': false,
        'deletedAt': null,
        'recoverableUntil': null,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] restoreUserDoc warning: $e');
    }
  }

  /// Deletes customer user data from Firestore and deletes Auth user from Firebase Auth.
  Future<void> deleteCustomerAuthAndData({
    required String uid,
    String? currentPassword,
  }) async {
    final user = _auth?.currentUser;
    if (user != null) {
      if (currentPassword != null && currentPassword.isNotEmpty && user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(cred);
      }
      if (_firestore != null) {
        try {
          await _firestore!.collection('users').doc(uid).delete();
        } catch (e) {
          debugPrint('[FirebaseService] Failed to delete customer doc: $e');
        }
      }
      await user.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // DEVICE BINDING & PUSH NOTIFICATION SYNC
  // ---------------------------------------------------------------------------

  /// Binds device FCM token and Auth UID to user_bindings/{appUserId}
  Future<void> updateUserBinding({
    required String appUserId,
    required UserRole role,
    required BranchId branch,
  }) async {
    _activeBoundUsers[appUserId] = (role: role, branch: branch);
    if (!_isInitialized || _firestore == null) return;
    try {
      final token = _cachedFcmToken ?? await _messaging?.getToken();
      final authUid = _auth?.currentUser?.uid;
      final docRef = _firestore!.collection('user_bindings').doc(appUserId);

      final updateData = <String, dynamic>{
        'appUserId': appUserId,
        'role': role.name,
        'branch': branch.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (authUid != null) {
        updateData['authUids'] = FieldValue.arrayUnion([authUid]);
      }
      if (token != null) {
        updateData['fcmTokens'] = FieldValue.arrayUnion([token]);
      }

      await docRef.set(updateData, SetOptions(merge: true));
      if (role == UserRole.admin && appUserId.toLowerCase() != 'admin') {
        final adminDoc = _firestore!.collection('user_bindings').doc('admin');
        await adminDoc.set({
          'appUserId': 'admin',
          'role': 'admin',
          'branch': branch.name,
          'updatedAt': FieldValue.serverTimestamp(),
          if (authUid != null) 'authUids': FieldValue.arrayUnion([authUid]),
          if (token != null) 'fcmTokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true));
      }
      debugPrint('[FirebaseService] Updated user binding for $appUserId (token: $token)');
      unawaited(persistActiveBindings());
    } catch (e) {
      debugPrint('[FirebaseService] updateUserBinding error: $e');
    }
  }

  /// Removes current device's FCM token from user_bindings/{appUserId} upon logout
  Future<void> unbindUser({required String appUserId}) async {
    _activeBoundUsers.remove(appUserId);
    if (!_isInitialized || _firestore == null) return;
    try {
      final token = _cachedFcmToken ?? await _messaging?.getToken();
      if (token != null) {
        await _firestore!.collection('user_bindings').doc(appUserId).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FirebaseService] Removed FCM token for user $appUserId');
      }
      unawaited(persistActiveBindings());
    } catch (e) {
      debugPrint('[FirebaseService] unbindUser error: $e');
    }
  }

  /// Re-merges a fresh FCM token into every active user binding.
  /// Called on cold start and token refresh so that devices whose app was
  /// killed (and whose token subsequently rotated) keep receiving pushes.
  Future<void> updateAllActiveBindingsWithToken(String token) async {
    if (!_isInitialized || _firestore == null) return;
    _cachedFcmToken = token;
    for (final entry in _activeBoundUsers.entries.toList()) {
      await updateUserBinding(
        appUserId: entry.key,
        role: entry.value.role,
        branch: entry.value.branch,
      );
    }
  }

  /// Restores the active bindings saved by [persistActiveBindings] so a
  /// cold-started app can re-sync its (possibly rotated) FCM token even
  /// before the user completes login.
  Future<void> restoreActiveBindings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPersistedBindingsKey);
      if (raw == null || raw.isEmpty) return;
      for (final entry in raw) {
        final parts = entry.split('|');
        if (parts.length != 3) continue;
        final role = UserRole.values.firstWhere(
          (r) => r.name == parts[1],
          orElse: () => UserRole.customer,
        );
        final branch = BranchId.values.firstWhere(
          (b) => b.name == parts[2],
          orElse: () => BranchId.patimbao,
        );
        _activeBoundUsers[parts[0]] = (role: role, branch: branch);
      }
    } catch (e) {
      debugPrint('[FirebaseService] restoreActiveBindings notice: $e');
    }
  }

  Future<void> persistActiveBindings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _activeBoundUsers.entries
          .map((e) => '${e.key}|${e.value.role.name}|${e.value.branch.name}')
          .toList();
      await prefs.setStringList(_kPersistedBindingsKey, entries);
    } catch (e) {
      debugPrint('[FirebaseService] persistActiveBindings notice: $e');
    }
  }

  /// Creates a cross-device notification document in Firestore `notifications` collection
  Future<void> createFirestoreNotification(AppNotificationItem item) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('notifications').doc(item.id).set(
        item.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FirebaseService] createFirestoreNotification error: $e');
    }
  }

  /// Deletes a cross-device notification document from Firestore `notifications` collection
  Future<void> deleteFirestoreNotification(String id) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('notifications').doc(id).delete();
    } catch (e) {
      debugPrint('[FirebaseService] deleteFirestoreNotification error: $e');
    }
  }

  /// Streams notifications collection from Firestore
  Stream<RemoteBatch<AppNotificationItem>> streamNotifications() {
    if (!_isInitialized || _firestore == null) return const Stream.empty();
    return _streamCollection(
      'notifications',
      AppNotificationItem.fromMap,
      query: (col) => col.orderBy('createdAt', descending: true).limit(50),
    );
  }

  // ---------------------------------------------------------------------------
  // CHAT & ATTACHMENT STORAGE
  // ---------------------------------------------------------------------------

  /// Uploads compressed image file to Firebase Storage under `chat_images/{threadId}/{messageId}.jpg`.
  /// If Cloud Storage fails (bucket not enabled, object-not-found, offline), gracefully falls back
  /// to an inline base64 data URI so message sending never crashes or fails.
  Future<String?> uploadChatImage({
    required String threadId,
    required String messageId,
    required File file,
  }) async {
    // 1. Try Firebase Cloud Storage first
    if (_isInitialized && _storage != null) {
      try {
        final ref = _storage!
            .ref()
            .child('chat_images')
            .child(threadId)
            .child('$messageId.jpg');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'threadId': threadId, 'messageId': messageId},
        );
        final uploadTask = await ref.putFile(file, metadata).timeout(
          const Duration(seconds: 12),
        );
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        if (downloadUrl.isNotEmpty) {
          return downloadUrl;
        }
      } catch (e) {
        debugPrint(
          '[FirebaseService] Cloud Storage upload failed ($e). Falling back to inline base64 encoding.',
        );
      }
    }

    // 2. Reliable Fallback: Base64 data URI ensures photo attachment is NEVER lost
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('[FirebaseService] uploadChatImage fallback encoding failed: $e');
      return null;
    }
  }

  /// Streams chat threads where user is a participant.
  /// When [isStaff] is true (Internal ERP for Admin, Mechanic, Cashier),
  /// all customer conversation threads are streamed so staff never miss any support chat.
  Stream<List<ChatThread>> streamChatThreads({
    required String userId,
    List<String>? candidateIds,
    bool isStaff = false,
  }) async* {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) {
      yield const <ChatThread>[];
      return;
    }
    await _ensureSignedIn();

    if (isStaff) {
      yield* _firestore!
          .collection('chats')
          .snapshots()
          .map((snap) => snap.docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                data.putIfAbsent('id', () => d.id);
                return ChatThread.fromMap(data);
              }).toList());
      return;
    }

    final ids = <String>{
      userId,
      if (candidateIds != null) ...candidateIds,
    }.where((id) => id.trim().isNotEmpty).toList();

    Query<Map<String, dynamic>> query = _firestore!.collection('chats');
    if (ids.length == 1) {
      query = query.where('participantIds', arrayContains: ids.first);
    } else if (ids.length > 1) {
      query = query.where('participantIds', arrayContainsAny: ids.take(10).toList());
    }

    yield* query
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data.putIfAbsent('id', () => d.id);
              return ChatThread.fromMap(data);
            }).toList());
  }

  /// Fetches a single chat thread by ID
  Future<ChatThread?> getChatThread(String threadId) async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) return null;
    try {
      await _ensureSignedIn();
      final doc = await _firestore!.collection('chats').doc(threadId).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data.putIfAbsent('id', () => doc.id);
      return ChatThread.fromMap(data);
    } catch (e) {
      debugPrint('[FirebaseService] getChatThread error: $e');
      return null;
    }
  }

  /// Streams messages in a specific thread ordered by createdAt asc
  Stream<List<ChatMessage>> streamChatMessages(String threadId) async* {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) {
      yield const <ChatMessage>[];
      return;
    }
    await _ensureSignedIn();
    yield* _firestore!
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data.putIfAbsent('id', () => d.id);
              return ChatMessage.fromMap(data);
            }).toList());
  }

  /// Sends a chat message, updates lastMessage & unreadCounts on thread,
  /// and writes a notification document for the recipient
  Future<void> sendChatMessage({
    required ChatThread thread,
    required ChatMessage message,
    required String recipientId,
    String? recipientName,
  }) async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) return;
    await _ensureSignedIn();
    try {
      final threadRef = _firestore!.collection('chats').doc(thread.id);
      final messageRef = threadRef.collection('messages').doc(message.id);

      final threadData = thread.toMap();
      threadData['lastMessage'] = message.text ?? '📷 Photo attachment';
      threadData['lastMessageAt'] = message.createdAt.toIso8601String();
      if (recipientId.isNotEmpty) {
        threadData['unreadCounts.$recipientId'] = FieldValue.increment(1);
      }
      final currentUid = _auth?.currentUser?.uid;
      if (currentUid != null) {
        threadData['authUids'] = FieldValue.arrayUnion([currentUid]);
      }

      final batch = _firestore!.batch();
      batch.set(threadRef, threadData, SetOptions(merge: true));
      batch.set(messageRef, message.toMap());
      await batch.commit();

      // Trigger notification document for Cloud Function FCM delivery
      final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}_${message.id}';
      final senderLabel = (message.senderName != null && message.senderName!.trim().isNotEmpty)
          ? message.senderName!.trim()
          : (message.senderRole == 'customer' ? 'Customer' : message.senderRole.toUpperCase());
      final notif = AppNotificationItem(
        id: notifId,
        title: 'New message from $senderLabel',
        message: message.text ?? 'Sent a photo attachment',
        category: 'chat',
        branch: BranchId.patimbao,
        targetUserId: recipientId.isNotEmpty ? recipientId : null,
        targetRole: message.senderRole == 'customer' ? UserRole.admin : null,
        payload: {
          'type': 'chat',
          'refId': thread.id,
          'senderId': message.senderId,
          'senderRole': message.senderRole,
        },
        createdAt: DateTime.now(),
      );
      await createFirestoreNotification(notif);
    } catch (e) {
      debugPrint('[FirebaseService] sendChatMessage error: $e');
      rethrow;
    }
  }

  /// Clears unread count for user in thread
  Future<void> markThreadRead({
    required String threadId,
    required String userId,
  }) async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('chats').doc(threadId).set({
        'unreadCounts': {userId: 0},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] markThreadRead error: $e');
    }
  }

  /// Deletes/unsends a specific message in a chat thread
  Future<void> deleteChatMessage({
    required String threadId,
    required String messageId,
  }) async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) return;
    try {
      final threadRef = _firestore!.collection('chats').doc(threadId);
      final msgRef = threadRef.collection('messages').doc(messageId);
      await msgRef.delete();

      // Recalculate lastMessage from remaining messages
      final latest = await threadRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isNotEmpty) {
        final lastData = latest.docs.first.data();
        await threadRef.update({
          'lastMessage': lastData['text'] ?? '📷 Photo attachment',
          'lastMessageAt': lastData['createdAt'],
        });
      } else {
        await threadRef.update({
          'lastMessage': null,
          'lastMessageAt': null,
        });
      }
    } catch (e) {
      debugPrint('[FirebaseService] deleteChatMessage error: $e');
      rethrow;
    }
  }

  /// Deletes an entire chat thread and all its subcollection messages
  Future<void> deleteChatThread(String threadId) async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    if (!_isInitialized || _firestore == null) return;
    try {
      final threadRef = _firestore!.collection('chats').doc(threadId);
      final messagesSnap = await threadRef.collection('messages').get();
      final batch = _firestore!.batch();
      for (final doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(threadRef);
      await batch.commit();
    } catch (e) {
      debugPrint('[FirebaseService] deleteChatThread error: $e');
      rethrow;
    }
  }
}

/// User-friendly error raised by auth flows (reset email, staff provisioning).
class AuthFlowException implements Exception {
  final String message;
  const AuthFlowException(this.message);

  @override
  String toString() => message;
}

/// One Firestore inventory snapshot plus where it came from.
class InventorySnapshot {
  final List<InventoryItem> items;

  /// false = served from the phone's local Firestore cache (ignore it)
  final bool fromServer;

  /// true = this phone's own write that the server has not confirmed yet
  final bool hasPendingWrites;

  const InventorySnapshot({
    required this.items,
    required this.fromServer,
    required this.hasPendingWrites,
  });
}