import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/data/repository/auth_repository.dart';
import 'package:thisjowi/services/connectivity_service.dart';
import 'package:thisjowi/data/local/secure_storage_service.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/i18n/translations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';
  
  AuthRepository? _authRepository;

  @override
  void initState() {
    super.initState();
    _initRepository();
    _loadBiometricStatus();
  }
  
  void _initRepository() {
    _authRepository = AuthRepository(
      authService: _authService,
      connectivityService: ConnectivityService(),
      secureStorageService: SecureStorageService(),
    );
  }

  Future<void> _loadBiometricStatus() async {
    final canCheck = await _biometricService.canCheckBiometrics();
    final isSupported = await _biometricService.isDeviceSupported();
    final isEnabled = await _biometricService.isBiometricEnabled();
    final biometricType = await _biometricService.getBiometricTypeName();
    
    if (mounted) {
      setState(() {
        _biometricAvailable = canCheck && isSupported;
        _biometricEnabled = isEnabled;
        _biometricType = biometricType;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Authenticate before enabling
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to enable biometric lock'.i18n,
      );
      
      if (authenticated) {
        await _biometricService.setBiometricEnabled(true);
        if (mounted) {
          setState(() => _biometricEnabled = true);
          ErrorSnackBar.showSuccess(context, 'Biometric enabled'.i18n);
        }
      } else {
        if (mounted) {
          ErrorSnackBar.show(context, 'Authentication failed'.i18n);
        }
      }
    } else {
      await _biometricService.setBiometricEnabled(false);
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ErrorSnackBar.showSuccess(context, 'Biometric disabled'.i18n);
      }
    }
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.text.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? AppColors.text.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: AppColors.text.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: trailing,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
    Color confirmColor = Colors.red,
  }) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SizedBox(
          width: 400,
          child: Dialog(
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: AppColors.text.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel'.i18n,
                            style: TextStyle(
                              color: AppColors.text.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDeleteAccount() async {
    _showConfirmationDialog(
      title: 'Delete Account'.i18n,
      content: 'Are you sure you want to delete your account? This action cannot be undone.'.i18n,
      onConfirm: () async {
        try {
          final result = await _authRepository!.deleteAccount();
          
          if (!mounted) return;
          
          if (result['success'] == true) {
            Navigator.pushReplacementNamed(context, '/login');
            ErrorSnackBar.showSuccess(context, 'Account deleted successfully'.i18n);
          } else {
            ErrorSnackBar.show(context, result['message'] ?? 'Error deleting account'.i18n);
          }
        } catch (e) {
          if (!mounted) return;
          ErrorSnackBar.show(context, '${'Error deleting account'.i18n}: $e');
        }
      },
    );
  }

  void _handleLogout() {
    _showConfirmationDialog(
      title: 'Logout'.i18n,
      content: 'Are you sure you want to logout?'.i18n,
      onConfirm: () {
        Navigator.pushReplacementNamed(context, '/login');
      },
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Center(
          child: SizedBox(
            width: 400,
            child: Dialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Password'.i18n,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            color: AppColors.text.withOpacity(0.6),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'New Password'.i18n,
                      obscure: _obscureNewPassword,
                      onVisibilityToggle: () =>
                          setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password'.i18n,
                      obscure: _obscureConfirmPassword,
                      onVisibilityToggle: () =>
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel'.i18n,
                              style: TextStyle(
                                color: AppColors.text.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleChangePassword(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.text,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Change'.i18n,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onVisibilityToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.text.withOpacity(0.1), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.text, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppColors.text.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.lock,
            color: AppColors.text.withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.text.withOpacity(0.7),
                size: 24,
              ),
              onPressed: onVisibilityToggle,
              tooltip: obscure ? 'Show Password'.i18n : 'Hide Password'.i18n,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _handleChangePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // New password and confirmation are required
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ErrorSnackBar.show(context, 'Please complete the new password'.i18n);
      return;
    }

    if (newPassword != confirmPassword) {
      ErrorSnackBar.show(context, 'The new passwords do not match'.i18n);
      return;
    }

    if (newPassword.length < 6) {
      ErrorSnackBar.show(context, 'Password must be at least 6 characters'.i18n);
      return;
    }

    try {
      // Ensure repository is initialized
      if (_authRepository == null) {
        _initRepository();
      }
      
      // Use AuthRepository for offline-first password change (no current password needed)
      final result = await _authRepository!.changePasswordDirect(newPassword);
      if (!mounted) return;
      
      // Check if password change was successful
      if (result['success'] != true) {
        ErrorSnackBar.show(context, result['message'] ?? 'Failed to change password'.i18n);
        return;
      }
      
      // Clear the text fields and close the dialog
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      Navigator.pop(context);

      ErrorSnackBar.showSuccess(context, 'Password changed successfully'.i18n);
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, '${'Error changing password'.i18n}: $e');
    }
  }

  void _showEditCountryDialog() {
    LatLng? selectedLocation;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Country'.i18n,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.text.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: const LatLng(20.0, 0.0),
                        initialZoom: 2.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            selectedLocation = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'uk.thisjowi.client',
                        ),
                        if (selectedLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selectedLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'.i18n, style: TextStyle(color: AppColors.text.withOpacity(0.7))),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedLocation == null) return;
                        final countryString = "${selectedLocation!.latitude}, ${selectedLocation!.longitude}";
                        
                        try {
                          final result = await _authRepository!.updateUser(country: countryString);
                          if (!mounted) return;
                          if (result['success'] == true) {
                            Navigator.pop(context);
                            ErrorSnackBar.showSuccess(context, 'Country updated'.i18n);
                          } else {
                            ErrorSnackBar.show(context, result['message'] ?? 'Failed'.i18n);
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ErrorSnackBar.show(context, 'Error: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Save'.i18n),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditBirthdateDialog() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.background,
              onSurface: AppColors.text,
            ), dialogTheme: DialogThemeData(backgroundColor: AppColors.background),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final dateString = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      try {
        final result = await _authRepository!.updateUser(birthdate: dateString);
        if (!mounted) return;
        if (result['success'] == true) {
          ErrorSnackBar.showSuccess(context, 'Birthdate updated'.i18n);
        } else {
          ErrorSnackBar.show(context, result['message'] ?? 'Failed'.i18n);
        }
      } catch (e) {
        if (!mounted) return;
        ErrorSnackBar.show(context, 'Error: $e');
      }
    }
  }

  void _showEditAccountTypeDialog() {
    String? accountType;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text('Account Type'.i18n, style: const TextStyle(color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Business', 'Community'].map((type) => RadioListTile<String>(
              title: Text(type, style: const TextStyle(color: AppColors.text)),
              value: type,
              groupValue: accountType,
              activeColor: AppColors.primary,
              onChanged: (value) => setState(() => accountType = value),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.i18n, style: TextStyle(color: AppColors.text.withOpacity(0.7))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (accountType == null) return;
                try {
                  final result = await _authRepository!.updateUser(accountType: accountType);
                  if (!mounted) return;
                  if (result['success'] == true) {
                    Navigator.pop(context);
                    ErrorSnackBar.showSuccess(context, 'Account Type updated'.i18n);
                  } else {
                    ErrorSnackBar.show(context, result['message'] ?? 'Failed'.i18n);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ErrorSnackBar.show(context, 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text('Save'.i18n),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHostingModeDialog() {
    String? hostingMode;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text('Hosting Mode'.i18n, style: const TextStyle(color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Cloud', 'Self-Hosted'].map((mode) => RadioListTile<String>(
              title: Text(mode, style: const TextStyle(color: AppColors.text)),
              value: mode,
              groupValue: hostingMode,
              activeColor: AppColors.primary,
              onChanged: (value) => setState(() => hostingMode = value),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.i18n, style: TextStyle(color: AppColors.text.withOpacity(0.7))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (hostingMode == null) return;
                try {
                  final result = await _authRepository!.updateUser(hostingMode: hostingMode);
                  if (!mounted) return;
                  if (result['success'] == true) {
                    Navigator.pop(context);
                    ErrorSnackBar.showSuccess(context, 'Hosting Mode updated'.i18n);
                  } else {
                    ErrorSnackBar.show(context, result['message'] ?? 'Failed'.i18n);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ErrorSnackBar.show(context, 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text('Save'.i18n),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.settings,
                          color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Settings'.i18n,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                      // Profile Section
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, top: 24.0, bottom: 12.0),
                        child: Text(
                          'Profile'.i18n,
                          style: TextStyle(
                            color: AppColors.text.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildSettingItem(
                        icon: Icons.public,
                        title: 'Country'.i18n,
                        subtitle: 'Update your country'.i18n,
                        onTap: _showEditCountryDialog,
                      ),
                      _buildSettingItem(
                        icon: Icons.cake,
                        title: 'Birthdate'.i18n,
                        subtitle: 'Update your birthdate'.i18n,
                        onTap: _showEditBirthdateDialog,
                      ),
                      _buildSettingItem(
                        icon: Icons.business,
                        title: 'Account Type'.i18n,
                        subtitle: 'Update account type'.i18n,
                        onTap: _showEditAccountTypeDialog,
                      ),
                      _buildSettingItem(
                        icon: Icons.cloud_queue,
                        title: 'Hosting Mode'.i18n,
                        subtitle: 'Update hosting mode'.i18n,
                        onTap: _showEditHostingModeDialog,
                      ),

                      // Security Section
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Security'.i18n,
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.password,
            title: 'Change Password'.i18n,
            subtitle: 'Update your password'.i18n,
            onTap: _showChangePasswordDialog,
          ),
          if (_biometricAvailable)
            _buildSettingItem(
              icon: _biometricType == 'Face ID' 
                  ? Icons.face_rounded 
                  : Icons.fingerprint_rounded,
              title: 'Biometric Authentication'.i18n,
              subtitle: 'Use %s to unlock app'.i18n.fill([_biometricType]),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: _toggleBiometric,
                activeThumbColor: AppColors.text,
                activeTrackColor: AppColors.text.withOpacity(0.3),
                inactiveThumbColor: AppColors.text.withOpacity(0.5),
                inactiveTrackColor: AppColors.text.withOpacity(0.1),
              ),
            ),

          // About Section
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Information'.i18n,
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'Application Version'.i18n,
            subtitle: '1.0.0',
          ),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Account & Privacy'.i18n,
            onTap: () {
              // TODO: Implement help
            },
          ),

          // Account Section
          Padding(
            padding: const EdgeInsets.only(left: 30.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Account'.i18n,
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'Logout'.i18n,
            iconColor: Colors.orange,
            onTap: _handleLogout,
          ),
          _buildSettingItem(
            icon: Icons.delete_forever,
            title: 'Delete Account'.i18n,
            subtitle: 'This action cannot be undone'.i18n,
            iconColor: Colors.red,
            onTap: _handleDeleteAccount,
          ),
                      const SizedBox(height: 24, width: 20,),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
