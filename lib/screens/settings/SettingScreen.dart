import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/components/error_snack_bar.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final AuthService _authService = AuthService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

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
                            'Cancelar',
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
      title: 'Delete Account',
      content: 'Are you sure you want to delete your account? This action cannot be undone.',
      onConfirm: () async {
        try {
          // TODO: Implement account deletion in AuthService
          await _authService.deleteAccount();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
          ErrorSnackBar.showSuccess(context, 'Cuenta eliminada exitosamente');
        } catch (e) {
          if (!mounted) return;
          ErrorSnackBar.show(context, 'Error al eliminar cuenta: $e');
        }
      },
    );
  }

  void _handleLogout() {
    _showConfirmationDialog(
      title: 'Logout',
      content: 'Are you sure you want to logout?',
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
                        const Text(
                          'Change Password',
                          style: TextStyle(
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
                      label: 'New Password',
                      obscure: _obscureNewPassword,
                      onVisibilityToggle: () =>
                          setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
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
                              'Cancel',
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
                            child: const Text(
                              'Change',
                              style: TextStyle(
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
              tooltip: obscure ? 'Show Password' : 'Hide Password',
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
      ErrorSnackBar.show(context, 'Please complete the new password');
      return;
    }

    if (newPassword != confirmPassword) {
      ErrorSnackBar.show(context, 'The new passwords do not match');
      return;
    }

    try {
      // Send empty string for currentPassword since it's optional on backend
      final result = await _authService.changePassword('', newPassword, confirmPassword);
      if (!mounted) return;
      
      // Check if password change was successful
      if (result['success'] != true) {
        ErrorSnackBar.show(context, result['message'] ?? 'Failed to change password');
        return;
      }
      
      // Clear the text fields and close the dialog
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      Navigator.pop(context);

      ErrorSnackBar.showSuccess(context, 'Password changed successfully');
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, 'Error changing password: $e');
    }
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        foregroundColor: AppColors.text,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [

          // Security Section
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Security',
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.password,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: _showChangePasswordDialog,
          ),

          // About Section
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Information',
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'Application Version',
            subtitle: '1.0.1',
          ),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Account & Privacy',
            onTap: () {
              // TODO: Implement help
            },
          ),

          // Account Section
          Padding(
            padding: const EdgeInsets.only(left: 30.0, top: 24.0, bottom: 12.0),
            child: Text(
              'Account',
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'Logout',
            iconColor: Colors.orange,
            onTap: _handleLogout,
          ),
          _buildSettingItem(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'This action cannot be undone',
            iconColor: Colors.red,
            onTap: _handleDeleteAccount,
          ),
          const SizedBox(height: 24, width: 20,),
        ],
      ),
    );
  }
}
