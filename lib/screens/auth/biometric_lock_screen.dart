import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/i18n/translations.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({
    super.key,
    required this.child,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService();
  bool _isLocked = true;
  bool _isAuthenticating = false;
  bool _biometricEnabled = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Lock when app goes to background
      if (_biometricEnabled && mounted) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Try to authenticate when app resumes
      if (_isLocked && _biometricEnabled) {
        _authenticate();
      }
    }
  }

  Future<void> _checkBiometricStatus() async {
    final enabled = await _biometricService.isBiometricEnabled();
    final biometricType = await _biometricService.getBiometricTypeName();

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricType = biometricType;
        _isLocked = enabled;
      });
    }

    if (enabled) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Authenticate to access ThisJowi'.i18n,
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        if (authenticated) {
          _isLocked = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_biometricEnabled || !_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.text.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: AppColors.text.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'App Locked'.i18n,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Authenticate to continue'.i18n,
                style: TextStyle(
                  color: AppColors.text.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),

              // Biometric button
              GestureDetector(
                onTap: _isAuthenticating ? null : _authenticate,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.text.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.text.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: _isAuthenticating
                      ? SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.text.withOpacity(0.6),
                          ),
                        )
                      : Icon(
                          _biometricType == 'Face ID'
                              ? Icons.face_rounded
                              : Icons.fingerprint_rounded,
                          size: 48,
                          color: AppColors.text.withOpacity(0.8),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Biometric type label
              Text(
                _isAuthenticating
                    ? 'Authenticating...'.i18n
                    : 'Tap to use %s'.i18n.fill([_biometricType]),
                style: TextStyle(
                  color: AppColors.text.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
