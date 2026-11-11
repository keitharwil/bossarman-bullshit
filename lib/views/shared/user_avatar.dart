import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Reusable User Avatar Widget for Boss Arman MotoHub.
/// Displays profile photo in strict priority:
/// 1. Uploaded custom photo (compressed base64 data URI).
/// 2. Google OAuth photo (`photoUrl` from Google sign-in).
/// 3. Initials Avatar: First letter of first name + first letter of last name.
class UserAvatar extends StatelessWidget {
  final StaffAccount? user;
  final String? photoUrl;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final bool isEditable;
  final VoidCallback? onEditPhoto;

  const UserAvatar({
    super.key,
    this.user,
    this.photoUrl,
    this.name,
    this.radius = 24,
    this.onTap,
    this.isEditable = false,
    this.onEditPhoto,
  });

  String get _effectivePhotoUrl => (user?.photoUrl ?? photoUrl ?? '').trim();

  String get _effectiveInitials {
    if (user != null) return user!.initials;
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n.substring(0, 1).toUpperCase();
  }

  ImageProvider? _resolveImageProvider(String rawUrl) {
    if (rawUrl.isEmpty) return null;
    try {
      if (rawUrl.startsWith('data:image/') || (!rawUrl.startsWith('http') && rawUrl.length > 100)) {
        final base64Data = rawUrl.contains(',') ? rawUrl.split(',').last.trim() : rawUrl.trim();
        final bytes = base64Decode(base64Data);
        return MemoryImage(bytes);
      } else if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        return NetworkImage(rawUrl);
      }
    } catch (e) {
      debugPrint('[UserAvatar] Error decoding photoUrl: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = _effectivePhotoUrl;
    final imgProvider = _resolveImageProvider(photo);
    final initials = _effectiveInitials;

    final avatarWidget = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surface1,
        border: Border.all(
          color: AppPalette.champagneGold.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: imgProvider != null
            ? Image(
                image: imgProvider,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorBuilder: (context, error, stackTrace) => _buildInitials(initials),
              )
            : _buildInitials(initials),
      ),
    );

    if (!isEditable) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap ?? onEditPhoto ?? () => showPhotoPickerSheet(context),
          child: avatarWidget,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onEditPhoto ?? () => showPhotoPickerSheet(context),
            child: Container(
              padding: EdgeInsets.all(radius * 0.14),
              decoration: BoxDecoration(
                color: AppPalette.champagneGold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.crust,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: radius * 0.45,
                color: AppPalette.crust,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppPalette.champagneGold,
          fontSize: radius * 0.82,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Displays the photo options sheet (Take Photo, Pick from Gallery, Remove Photo).
  static Future<void> showPhotoPickerSheet(BuildContext context) async {
    final vm = context.read<MotoHubViewModel>();
    final user = vm.currentUser;
    if (user == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppPalette.surface2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload or change your account avatar. Compressed directly to your secure profile.',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppPalette.champagneGold),
                  ),
                  title: const Text('Take Photo', style: TextStyle(color: AppPalette.textHigh, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Capture with device camera', style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickAndCompressImage(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.surface1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppPalette.champagneGold),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(color: AppPalette.textHigh, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Select an image from device storage', style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickAndCompressImage(context, ImageSource.gallery);
                  },
                ),
                if (user.photoUrl != null && user.photoUrl!.isNotEmpty) ...[
                  const Divider(color: AppPalette.surface1, height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: AppPalette.danger, fontWeight: FontWeight.w700)),
                    subtitle: const Text('Revert to initials avatar', style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await vm.updateCurrentUserProfilePhoto(null);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile photo removed. Showing initials.')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _pickAndCompressImage(BuildContext context, ImageSource source) async {
    final vm = context.read<MotoHubViewModel>();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 250 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppPalette.danger,
              content: Text('Selected image is too large. Please select a smaller photo.'),
            ),
          );
        }
        return;
      }

      final base64Uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final ok = await vm.updateCurrentUserProfilePhoto(base64Uri);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? AppPalette.success : AppPalette.danger,
            content: Text(ok ? 'Profile photo updated successfully!' : 'Failed to update profile photo.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[UserAvatar] Error picking photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text('Failed to pick photo: $e'),
          ),
        );
      }
    }
  }
}
