import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/motohub_viewmodel.dart';

enum LegalDocumentType {
  privacyPolicy,
  termsAndConditions,
  accountDeletionPolicy,
}

enum LegalAppTarget {
  adminApp,
  customerApp,
}

class LegalDocumentSection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalDocumentSection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

/// Dedicated Legal Documents Screen (Privacy Policy, Terms & Conditions, and
/// Account Deletion & Data Retention Disclosures) for both:
/// - Boss Arman MotoHub Admin/Internal ERP Application (`com.bossarman.motohub`)
/// - Boss Arman MotoHub Customer Rider Application (`com.bossarman.rider`)
class LegalDocumentsScreen extends StatefulWidget {
  final LegalDocumentType initialDocument;
  final LegalAppTarget appTarget;

  const LegalDocumentsScreen({
    super.key,
    required this.initialDocument,
    required this.appTarget,
  });

  static const String currentTermsVersion = 'v1.0 (2026-10)';
  static const String effectiveDate = 'October 30, 2026';

  static Future<void> openPrivacyPolicy(
    BuildContext context, {
    required bool isCustomerApp,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentsScreen(
          initialDocument: LegalDocumentType.privacyPolicy,
          appTarget: isCustomerApp
              ? LegalAppTarget.customerApp
              : LegalAppTarget.adminApp,
        ),
      ),
    );
  }

  static Future<void> openTermsAndConditions(
    BuildContext context, {
    required bool isCustomerApp,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentsScreen(
          initialDocument: LegalDocumentType.termsAndConditions,
          appTarget: isCustomerApp
              ? LegalAppTarget.customerApp
              : LegalAppTarget.adminApp,
        ),
      ),
    );
  }

  static Future<void> openAccountDeletionPolicy(
    BuildContext context, {
    required bool isCustomerApp,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentsScreen(
          initialDocument: LegalDocumentType.accountDeletionPolicy,
          appTarget: isCustomerApp
              ? LegalAppTarget.customerApp
              : LegalAppTarget.adminApp,
        ),
      ),
    );
  }

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  late LegalDocumentType _selectedDoc;

  @override
  void initState() {
    super.initState();
    _selectedDoc = widget.initialDocument;
  }

  String get _appTitle => widget.appTarget == LegalAppTarget.customerApp
      ? 'MotoHub Rider (Customer App)'
      : 'BossArman MotoHub (Admin & Staff ERP)';

  String get _docTitle {
    switch (_selectedDoc) {
      case LegalDocumentType.privacyPolicy:
        return 'Privacy Policy';
      case LegalDocumentType.termsAndConditions:
        return 'Terms & Conditions';
      case LegalDocumentType.accountDeletionPolicy:
        return 'Account Deletion & Data Retention';
    }
  }

  List<LegalDocumentSection> get _sections {
    switch (_selectedDoc) {
      case LegalDocumentType.privacyPolicy:
        return widget.appTarget == LegalAppTarget.customerApp
            ? _customerPrivacySections
            : _adminPrivacySections;
      case LegalDocumentType.termsAndConditions:
        return widget.appTarget == LegalAppTarget.customerApp
            ? _customerTermsSections
            : _adminTermsSections;
      case LegalDocumentType.accountDeletionPolicy:
        return _accountDeletionSections;
    }
  }

  String get _docKey {
    switch (_selectedDoc) {
      case LegalDocumentType.privacyPolicy:
        return 'privacy_policy';
      case LegalDocumentType.termsAndConditions:
        return 'terms_and_conditions';
      case LegalDocumentType.accountDeletionPolicy:
        return 'account_deletion_policy';
    }
  }

  bool _isOwner(BuildContext context) {
    final user = context.watch<MotoHubViewModel>().currentUser;
    if (user != null) {
      return user.role == UserRole.admin ||
          user.username.toLowerCase() == 'bossarman' ||
          user.username.toLowerCase() == 'lanceadmin' ||
          user.username.toLowerCase() == 'keithadmin';
    }
    return widget.appTarget == LegalAppTarget.adminApp;
  }

  List<LegalDocumentSection> _buildCustomSections(String raw) {
    final lines = raw.split('\n');
    final List<LegalDocumentSection> result = [];
    String? currentTitle;
    final List<String> paragraphs = [];
    final List<String> bullets = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#') ||
          (line.length > 2 && RegExp(r'^\d+\.').hasMatch(line))) {
        if (currentTitle != null ||
            paragraphs.isNotEmpty ||
            bullets.isNotEmpty) {
          result.add(LegalDocumentSection(
            title: currentTitle ?? 'Policy Section',
            paragraphs: List.from(paragraphs),
            bullets: List.from(bullets),
          ));
          paragraphs.clear();
          bullets.clear();
        }
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
      } else if (line.startsWith('•') ||
          line.startsWith('-') ||
          line.startsWith('*')) {
        bullets.add(line.substring(1).trim());
      } else {
        paragraphs.add(line);
      }
    }
    if (currentTitle != null || paragraphs.isNotEmpty || bullets.isNotEmpty) {
      result.add(LegalDocumentSection(
        title: currentTitle ?? 'Policy Section',
        paragraphs: List.from(paragraphs),
        bullets: List.from(bullets),
      ));
    }
    return result.isNotEmpty
        ? result
        : [
            LegalDocumentSection(
              title: _docTitle,
              paragraphs:
                  raw.split('\n\n').where((p) => p.trim().isNotEmpty).toList(),
            ),
          ];
  }

  String _serializeSectionsToText(List<LegalDocumentSection> secs) {
    final buffer = StringBuffer();
    for (final sec in secs) {
      buffer.writeln(sec.title);
      for (final p in sec.paragraphs) {
        buffer.writeln(p);
      }
      for (final b in sec.bullets) {
        buffer.writeln('• $b');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final vm = context.read<MotoHubViewModel>();
    final currentCustom = vm.getCustomLegalDocument(_docKey);
    final initialText = currentCustom ?? _serializeSectionsToText(_sections);
    final textCtrl = TextEditingController(text: initialText);
    final versionCtrl = TextEditingController(text: 'v1.1 (Owner Update)');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.surface0,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: AppPalette.champagneGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit $_docTitle',
                            style: const TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Owner / Admin Document Publishing',
                            style: TextStyle(
                              color: AppPalette.champagneGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Policy Version & Note',
                    hintText: 'e.g. v1.1 (Owner Update)',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Document Content (Supports sections, paragraphs & bullet points):',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: TextFormField(
                    controller: textCtrl,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                    decoration: InputDecoration(
                      hintText:
                          'Enter updated legal terms or privacy policy clauses...',
                      filled: true,
                      fillColor: AppPalette.surface0,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppPalette.surface1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                          side: const BorderSide(color: AppPalette.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text(
                          'Reset Default',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final ok = await vm.resetCustomLegalDocument(_docKey);
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Reset $_docTitle to official default.'
                                    : 'Failed to reset.',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.champagneGold,
                          foregroundColor: AppPalette.crust,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.publish_rounded, size: 16),
                        label: const Text(
                          'Save & Publish',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () async {
                          final text = textCtrl.text.trim();
                          if (text.isEmpty) return;
                          final ok = await vm.saveCustomLegalDocument(
                            docKey: _docKey,
                            title: _docTitle,
                            content: text,
                            version: versionCtrl.text.trim(),
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor:
                                  ok ? AppPalette.success : AppPalette.danger,
                              content: Text(
                                ok
                                    ? 'Published updated $_docTitle to all devices.'
                                    : (vm.statusMessage ?? 'Failed to publish.'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    textCtrl.dispose();
    versionCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final customContent = vm.getCustomLegalDocument(_docKey);
    final hasCustom = customContent != null && customContent.trim().isNotEmpty;
    final sections =
        hasCustom ? _buildCustomSections(customContent) : _sections;
    final isOwner = _isOwner(context);

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _docTitle,
              style: const TextStyle(
                color: AppPalette.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _appTitle,
              style: const TextStyle(
                color: AppPalette.champagneGold,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (isOwner)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.champagneGold,
              ),
              onPressed: () => _showEditDialog(context),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'EDIT (OWNER)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppPalette.mantle,
              border: Border(
                bottom: BorderSide(color: AppPalette.surface0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip(
                        type: LegalDocumentType.privacyPolicy,
                        label: 'Privacy Policy',
                        icon: Icons.privacy_tip_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        type: LegalDocumentType.termsAndConditions,
                        label: 'Terms & Conditions',
                        icon: Icons.gavel_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        type: LegalDocumentType.accountDeletionPolicy,
                        label: 'Data & Deletion',
                        icon: Icons.manage_accounts_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: AppPalette.champagneGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasCustom
                            ? 'Owner Published Custom Policy • Active & Synced • RA 10173'
                            : 'Version ${LegalDocumentsScreen.currentTermsVersion} • Effective ${LegalDocumentsScreen.effectiveDate} • RA 10173 Compliant',
                        style: TextStyle(
                          color: hasCustom
                              ? AppPalette.champagneGold
                              : AppPalette.textMuted,
                          fontSize: 11,
                          fontWeight:
                              hasCustom ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sec = sections[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.mantle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.surface0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sec.title,
                        style: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final p in sec.paragraphs) ...[
                        Text(
                          p,
                          style: const TextStyle(
                            color: AppPalette.textBody,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final b in sec.bullets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AppPalette.champagneGold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(
                                    color: AppPalette.textBody,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required LegalDocumentType type,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedDoc == type;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _selectedDoc = type),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppPalette.crust : AppPalette.champagneGold,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppPalette.crust : AppPalette.textHigh,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      selectedColor: AppPalette.champagneGold,
      backgroundColor: AppPalette.surface1,
      side: BorderSide(
        color: selected
            ? AppPalette.champagneGold
            : AppPalette.champagneGold.withValues(alpha: 0.3),
      ),
    );
  }
}

// =============================================================================
// 1. PRIVACY POLICY — ADMIN & STAFF ERP APPLICATION (com.bossarman.motohub)
// =============================================================================

const List<LegalDocumentSection> _adminPrivacySections = [
  LegalDocumentSection(
    title: '1. Overview & Scope (Admin & Staff ERP Application)',
    paragraphs: [
      'This Privacy Policy governs the BossArman MotoHub Admin & Staff ERP Application (application ID: com.bossarman.motohub), operated for Boss Arman MotoHub branches in Santa Cruz, Laguna (Branch 1: Patimbao and Branch 2: Pedro Guevara).',
      'This policy explains how personal, employee, customer, operational, and device data are collected, processed, stored, and protected in accordance with Republic Act No. 10173, otherwise known as the Philippine Data Privacy Act of 2012, and its Implementing Rules and Regulations.',
    ],
  ),
  LegalDocumentSection(
    title: '2. Information Collected & Processed',
    paragraphs: [
      'The Admin & Staff Application collects and processes only the information necessary to operate multi-branch retail Point-of-Sale (POS), inventory management, inter-branch stock transfers, and mechanic repair bay workflows:',
    ],
    bullets: [
      'Employee & Staff Account Information: First name, last name, username, email address, role assignment (Admin, Cashier, or Mechanic), assigned branch (Patimbao, Pedro Guevara, or Both), shift status, optional profile photo, and PBKDF2-HMAC-SHA256 hashed password credentials.',
      'Authentication Data: Firebase Authentication UIDs, Google Sign-In profile identifiers (email, display name, photo URL) when staff authenticate via Google One-Tap, and local session state.',
      'Customer Service & Order Records: Customer name, username, contact phone number, motorcycle model, license plate number, service issue descriptions, repair status, attached parts, and Click & Collect reservation records.',
      'Point-of-Sale & Financial Audit Records: Official receipt numbers (OR), itemized purchases, labor fees, payment method (Cash, GCash, or Split Payment), last 4+ digits of GCash reference numbers, optional GCash payment proof images, cash drawer float/cashout logs, and end-of-shift Z-Reading reconciliation audits.',
      'Customer Support Communications: Text messages and photo attachments exchanged with customers through the in-app support chat.',
      'Device & Push Notification Data: Firebase Cloud Messaging (FCM) device registration tokens stored in user_bindings to deliver real-time alerts for new orders, service bookings, stock transfers, and customer messages.',
      'Camera & Media Access: Camera permission is used strictly on-demand for scanning product barcodes/QR codes and capturing optional profile or transaction proof photos.',
    ],
  ),
  LegalDocumentSection(
    title: '3. How Information Is Used',
    bullets: [
      'Enforcing role-based access control (RBAC) and branch-level permissions across Patimbao and Pedro Guevara branches.',
      'Synchronizing real-time inventory stock levels, locked part holds, job orders, and Click & Collect reservations across authorized shop terminals.',
      'Maintaining accurate cash drawer ledgers, shift reconciliation logs, and Z-Reading reports for store accounting.',
      'Sending real-time push notifications and local alerts to staff and customers regarding repair progress, reservation status, and support inquiries.',
    ],
  ),
  LegalDocumentSection(
    title: '4. Database, Cloud Storage & Third-Party Services',
    paragraphs: [
      'BossArman MotoHub uses an offline-first architecture combining a local SQLite database (via sqflite on the device) with Google Firebase cloud infrastructure:',
    ],
    bullets: [
      'Google Firebase Authentication: Manages authenticated cloud sessions and Google Sign-In verification.',
      'Google Cloud Firestore: Synchronizes accounts, inventory, job_orders, click_and_collect, stock_transfers, transactions, chats, notifications, and user_bindings.',
      'Google Firebase Cloud Storage: Stores chat photo attachments and optional profile/proof images.',
      'Google Firebase Cloud Messaging (FCM) & Cloud Functions: Routes push notifications to registered Android devices.',
    ],
  ),
  LegalDocumentSection(
    title: '5. Data Sharing & Disclosure',
    paragraphs: [
      'Boss Arman MotoHub does NOT sell, rent, or trade employee or customer personal data to third parties, advertisers, or data brokers.',
      'Data is shared only among authorized Boss Arman MotoHub personnel according to their role, with Google Firebase as our cloud infrastructure processor, or when required by Philippine law or competent government authorities.',
    ],
  ),
  LegalDocumentSection(
    title: '6. Data Security Measures',
    bullets: [
      'All account passwords are salted and hashed using PBKDF2-HMAC-SHA256 prior to storage.',
      'All network traffic between the application and Firebase services is encrypted in transit via HTTPS/TLS.',
      'Firestore Security Rules restrict database reads and writes to authenticated sessions and enforce collection-level validation.',
      'Sensitive financial actions (deleting POS receipts, modifying cash drawer ledger entries, and overriding shift shortages) are restricted to Administrator accounts.',
    ],
  ),
  LegalDocumentSection(
    title: '7. Data Retention & Staff Account Deletion',
    bullets: [
      'Staff Account Soft-Delete & Recovery: When a staff account is deleted, it enters a 30-day soft-delete recovery window (recoverableUntil) before permanent removal from active directories, or may be permanently removed immediately by an Administrator.',
      'FCM Token Unbinding: Logging out or deleting an account automatically removes the device FCM token from user_bindings.',
      'Transactional & Audit Retention: Historical POS transactions, cash drawer ledger entries, stock transfer logs, and Z-Reading reports are retained as business accounting records in compliance with Philippine tax and commercial record-keeping regulations.',
    ],
  ),
  LegalDocumentSection(
    title: '8. Rights Under the Philippine Data Privacy Act (RA 10173)',
    paragraphs: [
      'Under Republic Act No. 10173, data subjects have the right to be informed, to object, to access, to rectify inaccurate data, to erasure or blocking of personal data (subject to legal and accounting retention obligations), and to data portability.',
    ],
  ),
  LegalDocumentSection(
    title: '9. Contact Information',
    paragraphs: [
      'For privacy inquiries, data access requests, or account management assistance, please contact Boss Arman MotoHub:',
    ],
    bullets: [
      'Business Name: Boss Arman MotoHub',
      'Branch 1 Address: Patimbao, Santa Cruz, Laguna, Philippines',
      'Branch 2 Address: Pedro Guevara Ave., Santa Cruz, Laguna, Philippines',
      'Data Protection Contact Email: bossarman@motohub.ph [OWNER CONFIRMATION REQUIRED: Confirm official public support email]',
      'Shop Contact Number: [OWNER CONFIRMATION REQUIRED: Insert official shop telephone/mobile number]',
    ],
  ),
];

// =============================================================================
// 2. PRIVACY POLICY — CUSTOMER RIDER APPLICATION (com.bossarman.rider)
// =============================================================================

const List<LegalDocumentSection> _customerPrivacySections = [
  LegalDocumentSection(
    title: '1. Overview & Scope (MotoHub Rider Customer Application)',
    paragraphs: [
      'This Privacy Policy applies to the MotoHub Rider Customer Application (application ID: com.bossarman.rider) for Boss Arman MotoHub in Santa Cruz, Laguna.',
      'We respect your privacy and process your personal data in compliance with the Philippine Data Privacy Act of 2012 (Republic Act No. 10173). This policy explains what data we collect when you register an account, reserve motorcycle parts via Click & Collect, book service bay appointments, or message our shop.',
    ],
  ),
  LegalDocumentSection(
    title: '2. Personal Data We Collect',
    paragraphs: [
      'We collect only the information you provide or that is generated when you use the MotoHub Rider app:',
    ],
    bullets: [
      'Account & Profile Information: First name, last name, username, email address, optional profile photo, password hash (PBKDF2-HMAC-SHA256) or Google Sign-In identifier, and your Terms & Conditions acceptance version and timestamp.',
      'Service Booking & Motorcycle Details: Contact phone number, motorcycle model, license plate number, requested service type, issue description, preferred branch (Patimbao or Pedro Guevara), and preferred schedule.',
      'Click & Collect Part Reservations: Reserved part SKU/name, quantity, pickup branch, contact phone number, and reservation status.',
      'Customer Support Chat: Text messages and optional photo attachments you send to Boss Arman MotoHub staff for part inquiries or repair updates.',
      'Device & Push Notification Identifiers: Firebase Cloud Messaging (FCM) registration token bound to your account in user_bindings so your device can receive live repair and order status notifications.',
    ],
  ),
  LegalDocumentSection(
    title: '3. Why We Collect & How We Use Your Data',
    bullets: [
      'To create and authenticate your MotoHub Rider account via Email/Password or Google One-Tap Sign-In.',
      'To reserve genuine motorcycle parts at your chosen Santa Cruz branch and hold your stock for counter pickup.',
      'To schedule your motorcycle repair or maintenance appointment and display live bay progress (Pending Acceptance, In-Bay Repairing, Waiting for Parts, Ready for Pickup, Completed).',
      'To notify you when a mechanic recommends optional extra repairs requiring your approval, or when your motorcycle or reserved part is ready for pickup.',
      'To enable direct customer support chat with our branch mechanics, cashiers, and administrators.',
    ],
  ),
  LegalDocumentSection(
    title: '4. Cloud Services, Local Storage & Permissions',
    bullets: [
      'Local Offline Cache: The app uses a local SQLite database (sqflite) and SharedPreferences on your device so you can view your active bookings and reservations even during brief network interruptions.',
      'Google Firebase Services: We use Firebase Authentication, Cloud Firestore, Firebase Cloud Storage (for chat/profile images), and Firebase Cloud Messaging (for push alerts).',
      'Device Permissions: POST_NOTIFICATIONS (Android 13+) is requested to display order and repair alerts. Camera/photo picker access is used only when you choose to upload a profile picture or send an image in chat.',
    ],
  ),
  LegalDocumentSection(
    title: '5. Data Sharing & Third Parties',
    paragraphs: [
      'Boss Arman MotoHub does NOT sell, rent, or share your personal information with third-party marketers or data brokers. Your information is accessible only to authorized Boss Arman MotoHub staff fulfilling your orders or servicing your motorcycle, and to Google Firebase as our secure cloud hosting provider.',
    ],
  ),
  LegalDocumentSection(
    title: '6. Data Retention & Self-Service Account Deletion',
    bullets: [
      'In-App Account Deletion: You can permanently delete your customer account at any time by going to My Garage (Profile Tab) -> Delete My Account.',
      'What Is Deleted Immediately: Your customer profile record (users and customer_accounts), your Firebase Authentication credentials, your saved profile photo, and your device push notification bindings (user_bindings).',
      'History Management: You can also delete individual or all past Click & Collect reservations and completed/cancelled job order history directly from the app.',
      'Legitimate Business Retention: Completed in-store Official Receipts (POS transactions) and store accounting ledgers are retained by Boss Arman MotoHub for tax, audit, and financial compliance under Philippine law, without keeping your active login account.',
    ],
  ),
  LegalDocumentSection(
    title: '7. Your Rights Under RA 10173 (Data Privacy Act of 2012)',
    paragraphs: [
      'As a data subject in the Philippines, you have the right to be informed, to access your personal data, to correct inaccuracies, to object to processing, to request erasure or deletion of your account, and to lodge a complaint with the National Privacy Commission (NPC).',
    ],
  ),
  LegalDocumentSection(
    title: '8. Contact Us',
    paragraphs: [
      'If you have questions about this Privacy Policy or wish to submit an account or data deletion request outside the app, please contact us:',
    ],
    bullets: [
      'Business Name: Boss Arman MotoHub',
      'Branch 1: Patimbao, Santa Cruz, Laguna, Philippines',
      'Branch 2: Pedro Guevara Ave., Santa Cruz, Laguna, Philippines',
      'Email: bossarman@motohub.ph [OWNER CONFIRMATION REQUIRED: Confirm official customer support email]',
      'Phone: [OWNER CONFIRMATION REQUIRED: Insert official shop contact number]',
    ],
  ),
];

// =============================================================================
// 3. TERMS AND CONDITIONS — ADMIN & STAFF ERP APPLICATION
// =============================================================================

const List<LegalDocumentSection> _adminTermsSections = [
  LegalDocumentSection(
    title: '1. Acceptance of Terms (Admin & Staff ERP)',
    paragraphs: [
      'By accessing or signing in to the BossArman MotoHub Admin & Staff ERP Application (com.bossarman.motohub), you agree to comply with these Terms and Conditions and all internal operational policies of Boss Arman MotoHub.',
      'Access to this application is strictly restricted to authorized administrators, cashiers, and mechanics of Boss Arman MotoHub.',
    ],
  ),
  LegalDocumentSection(
    title: '2. Authorized Application Services',
    bullets: [
      'Admin Role: Full multi-branch oversight across Patimbao and Pedro Guevara, staff account provisioning, branch assignment, inventory CRUD, POS checkout, cash drawer management, Z-Reading generation, and receipt/ledger administration.',
      'Cashier Role: Branch-locked retail and service POS checkout, Click & Collect reservation handoff, inter-branch stock transfer requests/receipts, cash drawer float/cashout logging, and customer chat support.',
      'Mechanic Role: Branch-locked repair bay queue management, accepting customer bookings, locking/attaching parts to job orders, updating labor and extra repair quotes, and customer chat support.',
    ],
  ),
  LegalDocumentSection(
    title: '3. Staff Responsibilities & Account Security',
    bullets: [
      'Staff members must keep their login credentials confidential and must not share accounts across unauthorized devices.',
      'Google Sign-In on the Internal ERP app is permitted only for email addresses pre-registered by the Administrator.',
      'Every POS checkout, cash drawer entry, stock transfer approval, and job status update is logged with the acting staff member’s name and timestamp.',
    ],
  ),
  LegalDocumentSection(
    title: '4. POS Transactions, Cash Drawer & Inventory Integrity',
    bullets: [
      'Cashiers must verify physical cash tendered and/or confirm at least the last 4 digits of the GCash reference number before completing any checkout.',
      'End-of-shift physical cash counts must be accurately recorded in the Shift Reconciliation Audit and Z-Reading report. Shortages require Administrator override verification.',
      'Deletion of POS transaction receipts and cash drawer ledger entries is strictly restricted to the Administrator.',
    ],
  ),
  LegalDocumentSection(
    title: '5. Customer Data Confidentiality & Prohibited Activities',
    bullets: [
      'Staff must treat all customer contact numbers, vehicle plate numbers, and chat messages as confidential business information under RA 10173.',
      'Unauthorized export, falsification of inventory counts, manipulation of cash drawer records, or misuse of customer contact details is strictly prohibited and grounds for immediate account revocation and disciplinary or legal action.',
    ],
  ),
  LegalDocumentSection(
    title: '6. Service Availability, Suspension & Governing Law',
    paragraphs: [
      'The application operates on an offline-first SQLite + Firebase Cloud Firestore architecture. Staff must allow devices to synchronize with the cloud whenever internet connectivity is available.',
      'Boss Arman MotoHub management reserves the right to suspend, reassign, or terminate any staff account at any time. These Terms are governed by the laws of the Republic of the Philippines, with venue in Santa Cruz, Laguna.',
    ],
  ),
];

// =============================================================================
// 4. TERMS AND CONDITIONS — CUSTOMER RIDER APPLICATION
// =============================================================================

const List<LegalDocumentSection> _customerTermsSections = [
  LegalDocumentSection(
    title: '1. Acceptance of Terms',
    paragraphs: [
      'Welcome to MotoHub Rider (com.bossarman.rider), the official customer mobile application of Boss Arman MotoHub in Santa Cruz, Laguna.',
      'By creating an account, signing in, reserving parts, or booking a service appointment, you agree to be bound by these Terms and Conditions (Version ${LegalDocumentsScreen.currentTermsVersion}). If you do not agree, please do not use the application.',
    ],
  ),
  LegalDocumentSection(
    title: '2. Application Services',
    bullets: [
      'Click & Collect Reservations: Browse real-time branch inventory and reserve motorcycle parts and accessories for in-store pickup at Branch 1 (Patimbao) or Branch 2 (Pedro Guevara).',
      'Service Bay Appointment Booking: Schedule motorcycle maintenance, CVT tuning, oil changes, electrical work, or general repairs.',
      'Live Repair Bay Tracker: Monitor your motorcycle’s real-time service status, attached parts, labor estimate, and approve recommended extra repairs.',
      'Direct Shop Support Chat: Message Boss Arman MotoHub staff regarding part compatibility, reservation status, or repair progress.',
    ],
  ),
  LegalDocumentSection(
    title: '3. User Responsibilities & Account Security',
    bullets: [
      'You must provide accurate contact information (full name, active mobile phone number, and valid motorcycle plate number/model) when booking services or reserving parts.',
      'You are responsible for maintaining the confidentiality of your account password or Google Sign-In session.',
      'Submitting false reservations, prank bookings, or abusive messages in chat is prohibited and may result in account suspension.',
    ],
  ),
  LegalDocumentSection(
    title: '4. Click & Collect Ordering, Pricing & In-Store Payment',
    bullets: [
      'Reservation Hold Window: Approved Click & Collect reservations hold stock at your selected branch for up to 48 hours from creation unless cancelled or claimed earlier.',
      'Payment Upon Pickup: The MotoHub Rider app does not process automated online card charges. Payment (Cash, GCash, or Split Payment) is completed in person at the branch counter upon part inspection and pickup.',
      'Stock & Pricing Accuracy: Prices are displayed in Philippine Pesos (PHP). While inventory syncs in real time, Boss Arman MotoHub reserves the right to verify physical stock condition upon pickup.',
    ],
  ),
  LegalDocumentSection(
    title: '5. Service Bookings, Estimates & Extra Repair Approvals',
    bullets: [
      'Initial labor fees and part attachments shown in the app are estimates based on your selected service type.',
      'If a mechanic identifies additional needed repairs while your motorcycle is in the bay, an Extra Repair Recommendation with the corresponding fee will be sent to your app for your explicit approval before the additional work is billed.',
    ],
  ),
  LegalDocumentSection(
    title: '6. Cancellations, Returns & Refunds Policy',
    bullets: [
      'Reservation & Booking Cancellations: You may cancel a pending Click & Collect reservation or pending service booking directly inside the app before it is completed, which automatically releases any held parts back to store inventory.',
      'In-Store Returns & Warranty: [OWNER CONFIRMATION REQUIRED: Specify official shop return/exchange window, e.g., 7-day replacement for factory-defective parts with official receipt, and exclusions for installed electrical parts or opened fluids].',
    ],
  ),
  LegalDocumentSection(
    title: '7. Account Suspension & Self-Service Termination',
    paragraphs: [
      'You may delete your account at any time from My Garage -> Delete My Account. Boss Arman MotoHub may suspend or terminate accounts that repeatedly fail to claim reserved stock (no-shows) or violate these Terms.',
    ],
  ),
  LegalDocumentSection(
    title: '8. Limitation of Liability & Governing Law',
    paragraphs: [
      'Boss Arman MotoHub provides the MotoHub Rider application on an "as-is" and "as-available" basis. To the fullest extent permitted by Philippine law, Boss Arman MotoHub shall not be liable for indirect or incidental damages arising from temporary network interruptions or Force-Stopped device notification delays.',
      'These Terms are governed by the laws of the Republic of the Philippines. Any disputes shall be resolved in the appropriate courts of Santa Cruz, Laguna.',
    ],
  ),
  LegalDocumentSection(
    title: '9. Contact Information',
    bullets: [
      'Business Name: Boss Arman MotoHub',
      'Branches: Patimbao & Pedro Guevara Ave., Santa Cruz, Laguna, Philippines',
      'Support Email: bossarman@motohub.ph [OWNER CONFIRMATION REQUIRED: Confirm official support email]',
      'Support Phone: [OWNER CONFIRMATION REQUIRED: Confirm official support phone number]',
    ],
  ),
];

// =============================================================================
// 5. ACCOUNT DELETION & DATA RETENTION POLICY (BOTH APPS)
// =============================================================================

const List<LegalDocumentSection> _accountDeletionSections = [
  LegalDocumentSection(
    title: '1. How to Delete Your Account In-App (Immediate Self-Service)',
    paragraphs: [
      'MotoHub Rider customers can permanently delete their account directly inside the mobile application without contacting support:',
    ],
    bullets: [
      'Step 1: Open the MotoHub Rider app and sign in to your account.',
      'Step 2: Tap the "My Garage" (Profile) tab on the bottom navigation bar.',
      'Step 3: Scroll to the bottom and tap "Delete My Account".',
      'Step 4: Review the deletion disclosure and confirm using your account password (for Email/Password accounts) or by typing "DELETE" (for Google Sign-In accounts).',
    ],
  ),
  LegalDocumentSection(
    title: '2. How to Request Account Deletion Outside the App (Web / Email)',
    paragraphs: [
      'If you have uninstalled the application or cannot access your device, you may request account deletion through our public Account Deletion page or by emailing our Data Protection Officer at bossarman@motohub.ph with the subject "Account Deletion Request" from your registered email address.',
      'Verified external deletion requests are processed within 7 business days.',
    ],
  ),
  LegalDocumentSection(
    title: '3. Data Permanently Deleted Upon Account Deletion',
    bullets: [
      'Your user profile document in Cloud Firestore (users and customer_accounts collections) and local SQLite record.',
      'Your Firebase Authentication login record (email/password or linked Google Sign-In UID).',
      'Your uploaded profile photo.',
      'Your Firebase Cloud Messaging (FCM) device token bindings in user_bindings.',
    ],
  ),
  LegalDocumentSection(
    title: '4. Data Retained for Legitimate Legal & Business Compliance',
    paragraphs: [
      'In accordance with Google Play User Data policies and the Philippine Data Privacy Act of 2012 (RA 10173), certain transactional records are retained strictly for tax, accounting, and audit purposes:',
    ],
    bullets: [
      'Completed Point-of-Sale Official Receipts (OR-*), cash drawer ledger entries, and end-of-shift Z-Reading financial summaries are retained as part of the store’s immutable accounting audit trail.',
      'These retained store receipts do not keep your active login credentials or receive push notifications.',
      'Active Click & Collect stock holds should be cancelled or completed prior to deleting your account.',
    ],
  ),
];

