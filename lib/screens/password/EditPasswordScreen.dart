import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/appColors.dart';
import '../../models/password_entry.dart';
import '../../services/password_service.dart';

class EditPasswordScreen extends StatefulWidget {
  final PasswordService passwordService;
  final PasswordEntry? passwordEntry;

  const EditPasswordScreen({
    super.key,
    required this.passwordService,
    this.passwordEntry,
  });

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _websiteController;
  bool _isSaving = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.passwordEntry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _usernameController = TextEditingController(text: entry?.username ?? '');
    _passwordController = TextEditingController(text: entry?.password ?? '');
    _websiteController = TextEditingController(text: entry?.website ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final titleText = _titleController.text.trim();
    final usernameText = _usernameController.text.trim();
    final passwordText = _passwordController.text.trim();
    final websiteText = _websiteController.text.trim();
    
    // Validate title
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    
    // Validate password
    if (passwordText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }
    
    // Validate username
    if (usernameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }
    
    // Validate website format (optional, but if provided must have http/https)
    if (websiteText.isNotEmpty && 
        !websiteText.startsWith('http://') && 
        !websiteText.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website must start with http:// or https://')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    final data = {
      'title': titleText,              // ← Changed from 'name' to 'title'
      'username': usernameText,
      'password': passwordText,
      'website': websiteText,
    };
    final isEdit = widget.passwordEntry != null;
    final id = widget.passwordEntry?.id;
    final result = isEdit
        ? await widget.passwordService.updatePassword(id!, data)
        : await widget.passwordService.addPassword(data);
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error saving password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.passwordEntry == null ? 'Add Password' : 'Edit Password',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _titleController,
                  label: 'Title',
                  icon: Icons.title,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _websiteController,
                  label: 'Website',
                  icon: Icons.link,
                ),
                const SizedBox(height: 40),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.text.withOpacity(0.1), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppColors.text, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.text.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.text.withOpacity(0.1), width: 1),
      ),
      child: TextFormField(
        controller: _passwordController,
        style: const TextStyle(color: AppColors.text, fontSize: 16),
        obscureText: !_showPassword,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(Icons.lock, color: AppColors.text.withOpacity(0.6), size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.text.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: AppColors.text.withOpacity(0.6), size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _passwordController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password copied')),
                  );
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          disabledBackgroundColor: AppColors.text.withOpacity(0.5),
        ),
        child: _isSaving
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: AppColors.background,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.passwordEntry == null ? 'Create Password' : 'Save Changes',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
