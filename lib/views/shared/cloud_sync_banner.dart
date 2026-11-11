import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Shows a small pill when cloud sync is failing, so the owner knows another
/// phone may be out of date. Tap it to read the exact error and retry.
class CloudSyncBanner extends StatefulWidget {
  final Widget child;
  const CloudSyncBanner({super.key, required this.child});

  @override
  State<CloudSyncBanner> createState() => _CloudSyncBannerState();
}

class _CloudSyncBannerState extends State<CloudSyncBanner> {
  bool _expanded = false;
  bool _retrying = false;

  Future<void> _retry(MotoHubViewModel vm) async {
    setState(() => _retrying = true);
    await vm.retryCloudSync();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MotoHubViewModel>();
    return ValueListenableBuilder<String?>(
      valueListenable: vm.cloudSyncStatus,
      builder: (context, error, _) {
        return Stack(
          children: [
            widget.child,
            if (error != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Material(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_off,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Cloud sync problem \u2013 tap for details',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_expanded) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    error,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.white),
                                      onPressed: _retrying
                                          ? null
                                          : () => _retry(vm),
                                      child: Text(_retrying
                                          ? 'Retrying...'
                                          : 'Retry now'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
