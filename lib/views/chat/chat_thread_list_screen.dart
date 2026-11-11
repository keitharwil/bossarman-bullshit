import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';
import 'chat_conversation_screen.dart';

class ChatThreadListScreen extends StatefulWidget {
  const ChatThreadListScreen({super.key});

  @override
  State<ChatThreadListScreen> createState() => _ChatThreadListScreenState();
}

class _ChatThreadListScreenState extends State<ChatThreadListScreen> {
  Stream<List<ChatThread>>? _threadsStream;
  String? _cachedKey;

  Stream<List<ChatThread>> _getThreadsStream({
    required String userId,
    required String? username,
    required UserRole role,
    required bool isStaff,
  }) {
    final key = '$userId|${username ?? ""}|${role.name}|$isStaff';
    if (_threadsStream == null || _cachedKey != key) {
      _cachedKey = key;
      _threadsStream = FirebaseService.instance.streamChatThreads(
        userId: userId,
        candidateIds: [
          if (username != null && username.isNotEmpty) username,
          if (role == UserRole.admin) 'admin',
        ],
        isStaff: isStaff,
      );
    }
    return _threadsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;
    final userId = user?.id ?? user?.username ?? (vm.isCustomerApp ? 'customer' : 'staff');
    final role = user?.role ?? (vm.isCustomerApp ? UserRole.customer : UserRole.admin);
    final threadsStream = _getThreadsStream(
      userId: userId,
      username: user?.username,
      role: role,
      isStaff: !vm.isCustomerApp,
    );

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        title: const Text(
          'Messages & Direct Support',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppPalette.textHigh,
          ),
        ),
      ),
      floatingActionButton: role == UserRole.customer
          ? FloatingActionButton.extended(
              backgroundColor: AppPalette.champagneGold,
              foregroundColor: AppPalette.crust,
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text(
                'Message Admin',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                final customerId = userId;
                final threadId = '${customerId}_admin';
                final adminStaff = vm.staffList
                    .where((s) => s.role == UserRole.admin)
                    .firstOrNull;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatConversationScreen(
                      threadId: threadId,
                      recipientName: 'Admin Support',
                      recipientUsername: adminStaff?.username ?? 'admin',
                      recipientRole: 'admin',
                    ),
                  ),
                );
              },
            )
          : null,
      body: StreamBuilder<List<ChatThread>>(
        stream: threadsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              !snapshot.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: AppPalette.champagneGold),
            );
          }

          final allThreads = snapshot.data ?? [];
          // Allowed pair validation:
          // 1. Customer <-> Admin
          // 2. Customer <-> Mechanic
          // Admin <-> Mechanic is disallowed.
          final validThreads = allThreads.where((t) {
            final roles = t.roles.map((r) => r.toLowerCase()).toList();
            if (roles.contains('admin') && roles.contains('mechanic')) {
              return false; // disallowed
            }
            return true;
          }).toList();

          validThreads.sort((a, b) {
            final aTime = a.lastMessageAt ?? a.createdAt;
            final bTime = b.lastMessageAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });

          if (validThreads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppPalette.surface1,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppPalette.champagneGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        size: 42,
                        color: AppPalette.champagneGold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Active Conversations',
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role == UserRole.customer
                          ? 'Tap "Message Admin" below or message your mechanic from your active repair order.'
                          : 'Customer conversations and repair inquiries will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: validThreads.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final thread = validThreads[index];
              final unread = thread.unreadCounts[userId] ?? 0;

              // Extract other participant's info
              String otherUserId = '';
              for (final pid in thread.participantIds) {
                if (pid != userId) {
                  otherUserId = pid;
                  break;
                }
              }
              if (otherUserId.isEmpty && thread.id.contains('_')) {
                final parts = thread.id.split('_');
                otherUserId = parts.firstWhere((p) => p != userId, orElse: () => parts.last);
              }

              String displayName = 'Chat';
              String displayUsername = '';
              String roleSubtitle = 'Support';

              if (thread.participantNames != null && thread.participantNames!.containsKey(otherUserId)) {
                displayName = thread.participantNames![otherUserId]!;
              } else if (thread.participantNames != null) {
                for (final entry in thread.participantNames!.entries) {
                  if (entry.key != userId) {
                    displayName = entry.value;
                    break;
                  }
                }
              }

              if (thread.participantUsernames != null && thread.participantUsernames!.containsKey(otherUserId)) {
                displayUsername = thread.participantUsernames![otherUserId]!;
              } else if (thread.participantUsernames != null) {
                for (final entry in thread.participantUsernames!.entries) {
                  if (entry.key != userId) {
                    displayUsername = entry.value;
                    break;
                  }
                }
              }

              // Fallback for staff
              if (displayUsername.isEmpty || displayName == 'Chat') {
                final matchingStaff = vm.staffList
                    .where((s) => s.id == otherUserId || s.username == otherUserId)
                    .firstOrNull;
                if (matchingStaff != null) {
                  if (displayName == 'Chat') displayName = matchingStaff.fullName;
                  if (displayUsername.isEmpty) displayUsername = matchingStaff.username;
                }
              }

              // Fallback for job orders (e.g. customer name & username from job)
              if ((displayUsername.isEmpty || displayName == 'Chat') && thread.jobOrderId != null) {
                final matchingJob = vm.branchJobOrders.where((j) => j.id == thread.jobOrderId).firstOrNull ??
                    vm.customerJobOrders.where((j) => j.id == thread.jobOrderId).firstOrNull;
                if (matchingJob != null) {
                  if (displayName == 'Chat') displayName = matchingJob.customerName;
                  if (displayUsername.isEmpty) displayUsername = matchingJob.customerUsername;
                }
              }

              if (thread.roles.contains('admin') && role != UserRole.admin) {
                roleSubtitle = 'Boss Arman Admin';
              } else if (thread.roles.contains('mechanic') && role != UserRole.mechanic) {
                roleSubtitle = 'Assigned Mechanic';
              } else if (thread.roles.contains('customer') && role != UserRole.customer) {
                roleSubtitle = 'Customer';
              }

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatConversationScreen(
                        threadId: thread.id,
                        recipientName: displayName,
                        recipientUsername: displayUsername,
                        recipientRole: roleSubtitle,
                        jobOrderId: thread.jobOrderId,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: unread > 0 ? AppPalette.surface1 : AppPalette.mantle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unread > 0
                          ? AppPalette.champagneGold.withValues(alpha: 0.5)
                          : AppPalette.surface0,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppPalette.surface0,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppPalette.champagneGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          roleSubtitle.contains('Mechanic')
                              ? Icons.handyman_rounded
                              : (roleSubtitle.contains('Admin')
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.person_rounded),
                          color: AppPalette.champagneGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayUsername.isNotEmpty
                                        ? '$displayName (@$displayUsername)'
                                        : displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppPalette.textHigh,
                                      fontSize: 14.5,
                                      fontWeight: unread > 0
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (thread.lastMessageAt != null)
                                  Text(
                                    AppFormatters.relativeTime(thread.lastMessageAt!),
                                    style: TextStyle(
                                      color: unread > 0
                                          ? AppPalette.champagneGold
                                          : AppPalette.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.surface0,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    roleSubtitle,
                                    style: const TextStyle(
                                      color: AppPalette.champagneGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (thread.jobOrderId != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppPalette.crust,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Job #${thread.jobOrderId}',
                                      style: const TextStyle(
                                        color: AppPalette.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    thread.lastMessage ?? 'No messages yet',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unread > 0
                                          ? AppPalette.textHigh
                                          : AppPalette.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppPalette.champagneGold,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: AppPalette.crust,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppPalette.danger,
                          size: 20,
                        ),
                        tooltip: 'Delete Chat',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final ok = await showConfirmDialog(
                            context,
                            destructive: true,
                            title: 'Delete Chat Conversation?',
                            message:
                                'Are you sure you want to delete this chat conversation with $displayName? All messages will be permanently deleted.',
                            confirmLabel: 'Delete Chat',
                          );
                          if (!ok || !context.mounted) return;
                          try {
                            await FirebaseService.instance.deleteChatThread(thread.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chat conversation deleted.')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete chat: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
