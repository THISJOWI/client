import 'package:flutter/material.dart';
import '../core/appColors.dart';
import '../backend/service/connectivity_service.dart';

/// Widget to display connectivity and sync status
/// 
/// Shows:
/// - Online/Offline indicator
/// - Sync status icon
/// - Tap to force sync
class SyncStatusIndicator extends StatefulWidget {
  final VoidCallback? onTapSync;

  const SyncStatusIndicator({
    super.key,
    this.onTapSync,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivityService.isOnline;
    
    // Listen to connectivity changes
    _connectivityService.connectionStatus.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTapSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isOnline 
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isOnline 
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: _isOnline ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: _isOnline ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner widget to show at the top of screens
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivityService.isOnline;
    _showBanner = !_isOnline;
    
    // Listen to connectivity changes
    _connectivityService.connectionStatus.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _showBanner = !isOnline;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: Colors.orange.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Working offline. Changes will sync when connection is restored.',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Snackbar style notification for sync events
class SyncNotification {
  static void showSyncComplete(BuildContext context, {int? itemsSynced}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              itemsSynced != null 
                  ? 'Synced $itemsSynced items' 
                  : 'Sync completed',
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
      ),
    );
  }

  static void showSyncFailed(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Sync failed: $error')),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
      ),
    );
  }

  static void showOfflineMode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Text('Working offline'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
      ),
    );
  }

  static void showBackOnline(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text('Back online - syncing...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
      ),
    );
  }
}
