import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import '../shared/confirm_dialog.dart';
import 'image_preview_dialog.dart';

class ChatConversationScreen extends StatefulWidget {
  final String threadId;
  final String? recipientName;
  final String? recipientRole;
  final String? recipientUsername;
  final String? jobOrderId;

  const ChatConversationScreen({
    super.key,
    required this.threadId,
    this.recipientName,
    this.recipientRole,
    this.recipientUsername,
    this.jobOrderId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImageFile;
  bool _isSending = false;
  String? _recipientName;
  String? _recipientUsername;
  String? _recipientRole;
  late Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _recipientName = widget.recipientName;
    _recipientUsername = widget.recipientUsername;
    _recipientRole = widget.recipientRole;
    _messagesStream = FirebaseService.instance.streamChatMessages(widget.threadId);
    _markRead();
    _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant ChatConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId) {
      _messagesStream = FirebaseService.instance.streamChatMessages(widget.threadId);
    }
  }

  Future<void> _loadMetadata() async {
    final vm = context.read<MotoHubViewModel>();
    final currentUserId = vm.currentUser?.id ?? vm.currentUser?.username ?? '';

    // If username is still missing, try thread document from Firestore
    if (_recipientUsername == null || _recipientUsername!.isEmpty) {
      final thread = await FirebaseService.instance.getChatThread(widget.threadId);
      if (thread != null && mounted) {
        String otherId = '';
        for (final p in thread.participantIds) {
          if (p != currentUserId && (widget.jobOrderId == null || p != widget.jobOrderId)) {
            otherId = p;
            break;
          }
        }
        if (otherId.isEmpty && widget.threadId.contains('_')) {
          final parts = widget.threadId.split('_');
          otherId = parts.firstWhere(
            (p) => p != currentUserId && (widget.jobOrderId == null || p != widget.jobOrderId),
            orElse: () => parts.last,
          );
        }

        setState(() {
          if (_recipientName == null || _recipientName!.isEmpty) {
            _recipientName = thread.participantNames?[otherId];
          }
          if (_recipientUsername == null || _recipientUsername!.isEmpty) {
            _recipientUsername = thread.participantUsernames?[otherId];
          }
          if (_recipientRole == null || _recipientRole!.isEmpty) {
            _recipientRole = thread.roles.firstWhere(
              (r) => r != (vm.isCustomerApp ? 'customer' : 'staff'),
              orElse: () => 'Support',
            );
          }
        });
      }
    }

    // If still missing, check staffList
    if ((_recipientUsername == null || _recipientUsername!.isEmpty) && mounted) {
      final staff = vm.staffList.where((s) =>
          s.fullName.toLowerCase() == (_recipientName ?? '').toLowerCase() ||
          s.id == widget.threadId ||
          widget.threadId.contains(s.id) ||
          widget.threadId.contains(s.username)).firstOrNull;
      if (staff != null) {
        setState(() {
          _recipientUsername = staff.username;
          if (_recipientName == null || _recipientName == 'Recipient') {
            _recipientName = staff.fullName;
          }
        });
      }
    }

    // If still missing and jobOrderId is present, check job orders
    if ((_recipientUsername == null || _recipientUsername!.isEmpty) &&
        widget.jobOrderId != null &&
        mounted) {
      final job = vm.branchJobOrders.where((j) => j.id == widget.jobOrderId).firstOrNull ??
          vm.customerJobOrders.where((j) => j.id == widget.jobOrderId).firstOrNull;
      if (job != null) {
        setState(() {
          if (!vm.isCustomerApp) {
            _recipientName = job.customerName;
            _recipientUsername = job.customerUsername;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead() {
    final vm = context.read<MotoHubViewModel>();
    final currentUserId = vm.currentUser?.id ?? vm.currentUser?.username ?? '';
    if (currentUserId.isNotEmpty) {
      FirebaseService.instance.markThreadRead(
        threadId: widget.threadId,
        userId: currentUserId,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() {
          _selectedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.mantle,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppPalette.champagneGold),
              title: const Text('Take Photo with Camera', style: TextStyle(color: AppPalette.textHigh)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppPalette.champagneGold),
              title: const Text('Choose from Photo Library', style: TextStyle(color: AppPalette.textHigh)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImageFile == null) return;
    if (_isSending) return;

    final vm = context.read<MotoHubViewModel>();
    final user = vm.currentUser;
    final senderId = user?.id ?? user?.username ?? (vm.isCustomerApp ? 'customer' : 'staff');
    final senderRole = user?.role.name ?? (vm.isCustomerApp ? 'customer' : 'staff');
    final senderName = user?.fullName ?? (vm.isCustomerApp ? 'Customer' : 'Staff');
    final senderUsername = user?.username ?? (vm.isCustomerApp ? 'customer' : 'staff');

    setState(() => _isSending = true);

    try {
      final messageId = 'msg_${const Uuid().v4()}';
      String? imageUrl;

      if (_selectedImageFile != null) {
        imageUrl = await FirebaseService.instance.uploadChatImage(
          threadId: widget.threadId,
          messageId: messageId,
          file: _selectedImageFile!,
        );
      }

      final message = ChatMessage(
        id: messageId,
        threadId: widget.threadId,
        senderId: senderId,
        senderRole: senderRole,
        senderName: senderName,
        senderUsername: senderUsername,
        text: text.isNotEmpty ? text : null,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        readBy: [senderId],
      );

      // Determine recipient ID and thread roles
      String recipientId = '';
      if (widget.threadId.contains('_')) {
        final parts = widget.threadId.split('_');
        recipientId = parts.firstWhere(
          (p) => p != senderId && (widget.jobOrderId == null || p != widget.jobOrderId),
          orElse: () => parts.last,
        );
      }

      final resolvedRecipientName = _recipientName ?? widget.recipientName ?? 'Recipient';
      final resolvedRecipientUsername = _recipientUsername ?? widget.recipientUsername;
      final resolvedRecipientRole = _recipientRole ?? widget.recipientRole ?? (vm.isCustomerApp ? 'admin' : 'customer');

      if (resolvedRecipientUsername != null && resolvedRecipientUsername.trim().isNotEmpty) {
        if (recipientId.isEmpty || recipientId == widget.jobOrderId) {
          recipientId = resolvedRecipientUsername.trim();
        }
      }

      final currentUid = FirebaseService.instance.currentAuthUid;
      final participantIds = <String>{
        senderId,
        if (senderUsername.isNotEmpty) senderUsername,
        if (recipientId.isNotEmpty) recipientId,
        if (resolvedRecipientUsername != null && resolvedRecipientUsername.isNotEmpty)
          resolvedRecipientUsername,
        if (resolvedRecipientRole == 'admin') 'admin',
      }.toList();

      final thread = ChatThread(
        id: widget.threadId,
        participantIds: participantIds,
        authUids: [if (currentUid != null) currentUid],
        roles: [senderRole, resolvedRecipientRole],
        jobOrderId: widget.jobOrderId,
        lastMessage: text.isNotEmpty ? text : '📷 Photo attachment',
        lastMessageAt: DateTime.now(),
        participantNames: {
          senderId: senderName,
          if (recipientId.isNotEmpty) recipientId: resolvedRecipientName,
        },
        participantUsernames: {
          senderId: senderUsername,
          if (recipientId.isNotEmpty && resolvedRecipientUsername != null)
            recipientId: resolvedRecipientUsername,
        },
        createdAt: DateTime.now(),
      );

      await FirebaseService.instance.sendChatMessage(
        thread: thread,
        message: message,
        recipientId: recipientId,
        recipientName: resolvedRecipientName,
      );

      _textController.clear();
      setState(() {
        _selectedImageFile = null;
      });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final currentUserId = vm.currentUser?.id ?? vm.currentUser?.username ?? '';
    final activeRecipientName = _recipientName ?? widget.recipientName ?? 'Direct Support Chat';
    final activeRecipientUsername = _recipientUsername ?? widget.recipientUsername;
    final activeRecipientRole = _recipientRole ?? widget.recipientRole;

    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeRecipientName,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.textHigh,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppPalette.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    activeRecipientUsername != null &&
                            activeRecipientUsername.isNotEmpty
                        ? '@$activeRecipientUsername • ${activeRecipientRole?.toUpperCase() ?? "DIRECT"}'
                        : (activeRecipientRole?.toUpperCase() ??
                            (widget.jobOrderId != null
                                ? 'JOB #${widget.jobOrderId}'
                                : 'OFFICIAL CHANNEL')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.champagneGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Delete Chat',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppPalette.danger,
              size: 22,
            ),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                destructive: true,
                title: 'Delete Chat Conversation?',
                message:
                    'Are you sure you want to delete this entire chat conversation? All messages will be permanently removed.',
                confirmLabel: 'Delete Chat',
              );
              if (!ok || !context.mounted) return;
              try {
                await FirebaseService.instance.deleteChatThread(widget.threadId);
                if (!context.mounted) return;
                Navigator.of(context).pop();
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
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData &&
                      !snapshot.hasError) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppPalette.champagneGold),
                    );
                  }
                  if (snapshot.hasError && !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              color: AppPalette.champagneGold,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Connecting to chat server...',
                              style: TextStyle(
                                color: AppPalette.textHigh,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _messagesStream = FirebaseService.instance
                                      .streamChatMessages(widget.threadId);
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry Connection'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppPalette.surface1,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppPalette.champagneGold.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 36,
                                color: AppPalette.champagneGold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Start of conversation',
                              style: TextStyle(
                                color: AppPalette.textHigh,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Send a message or attach a bike photo. Notifications will be delivered automatically.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId ||
                          (vm.isCustomerApp && msg.senderRole == 'customer') ||
                          (!vm.isCustomerApp && msg.senderRole != 'customer');
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Image Preview (if picked)
            if (_selectedImageFile != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppPalette.mantle,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImageFile!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Photo attached (ready to send)',
                        style: TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppPalette.danger),
                      onPressed: () => setState(() => _selectedImageFile = null),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppPalette.mantle,
                border: Border(
                  top: BorderSide(color: AppPalette.surface0, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach Photo',
                    icon: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppPalette.champagneGold,
                    ),
                    onPressed: _showImagePickerSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(color: AppPalette.textHigh, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppPalette.surface0,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSending)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.champagneGold,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Send',
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppPalette.champagneGold,
                      ),
                      onPressed: _sendMessage,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (msg.text != null && msg.text!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppPalette.textHigh),
                title: const Text('Copy Text', style: TextStyle(color: AppPalette.textHigh)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: msg.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard.')),
                  );
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger),
                title: const Text(
                  'Unsend Message',
                  style: TextStyle(
                    color: AppPalette.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Remove this message for everyone',
                  style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ok = await showConfirmDialog(
                    context,
                    destructive: true,
                    title: 'Unsend Message?',
                    message:
                        'Are you sure you want to unsend this message? It will be permanently removed for all participants.',
                    confirmLabel: 'Unsend',
                  );
                  if (!ok || !mounted) return;
                  try {
                    await FirebaseService.instance.deleteChatMessage(
                      threadId: widget.threadId,
                      messageId: msg.id,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message unsent.')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to unsend message: $e')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppPalette.surface1 : AppPalette.mantle,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: Border.all(
              color: isMe
                  ? AppPalette.champagneGold.withValues(alpha: 0.3)
                  : AppPalette.surface0,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender info (for non-me messages)
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          msg.senderName != null && msg.senderName!.isNotEmpty
                              ? (msg.senderUsername != null &&
                                      msg.senderUsername!.isNotEmpty
                                  ? '${msg.senderName} (@${msg.senderUsername})'
                                  : msg.senderName!)
                              : (msg.senderUsername != null &&
                                      msg.senderUsername!.isNotEmpty
                                  ? '@${msg.senderUsername}'
                                  : msg.senderRole.toUpperCase()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '• ${msg.senderRole.toUpperCase()}',
                        style: TextStyle(
                          color: AppPalette.champagneGold.withValues(alpha: 0.7),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

            // Image attachment (if any)
            if (msg.imageUrl != null)
              GestureDetector(
                onTap: () => ImagePreviewDialog.show(
                  context,
                  imageUrl: msg.imageUrl!,
                  title: 'Photo from ${msg.senderRole.toUpperCase()}',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Builder(
                          builder: (context) {
                            final imgUrl = msg.imageUrl!;
                            if (imgUrl.startsWith('data:image')) {
                              final raw = imgUrl.contains(',') ? imgUrl.split(',').last : imgUrl;
                              try {
                                return Image.memory(
                                  base64Decode(raw),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 120,
                                    color: AppPalette.surface0,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded, color: Colors.white54),
                                    ),
                                  ),
                                );
                              } catch (_) {
                                return Container(
                                  height: 120,
                                  color: AppPalette.surface0,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_rounded, color: Colors.white54),
                                  ),
                                );
                              }
                            }
                            return Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 160,
                                  color: AppPalette.surface0,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppPalette.champagneGold,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Container(
                                height: 120,
                                color: AppPalette.surface0,
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.white54),
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Text message
            if (msg.text != null && msg.text!.isNotEmpty)
              Text(
                msg.text!,
                style: const TextStyle(
                  color: AppPalette.textHigh,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),

            const SizedBox(height: 4),
            // Timestamp
            Text(
              AppFormatters.relativeTime(msg.createdAt),
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
