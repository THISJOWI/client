import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/appColors.dart';
import '../../backend/models/password_entry.dart';
import '../../backend/repository/passwords_repository.dart';
import '../../components/error_snack_bar.dart';
import '../../i18n/translations.dart';

class EditPasswordScreen extends StatefulWidget {
  final PasswordsRepository passwordsRepository;
  final PasswordEntry? passwordEntry;

  const EditPasswordScreen({
    super.key,
    required this.passwordsRepository,
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
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _websiteFocusNode = FocusNode();
  bool _isSaving = false;
  bool _showPassword = false;
  
  // Error states for each field
  String? _titleError;
  String? _usernameError;
  String? _passwordError;
  String? _websiteError;

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
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _websiteFocusNode.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _titleError = null;
      _usernameError = null;
      _passwordError = null;
      _websiteError = null;
    });
  }

  Future<void> _save() async {
    final titleText = _titleController.text.trim();
    final usernameText = _usernameController.text.trim();
    final passwordText = _passwordController.text.trim();
    final websiteText = _websiteController.text.trim();
    
    // Reset errors
    _clearErrors();
    
    bool hasError = false;
    
    // Validate all fields and show all errors at once
    if (titleText.isEmpty) {
      _titleError = 'Please enter a title'.i18n;
      hasError = true;
    }
    
    if (usernameText.isEmpty) {
      _usernameError = 'Please enter a username'.i18n;
      hasError = true;
    }
    
    if (passwordText.isEmpty) {
      _passwordError = 'Please enter a password'.i18n;
      hasError = true;
    }
    
    // Validate website format (optional, but if provided must have http/https)
    if (websiteText.isNotEmpty && 
        !websiteText.startsWith('http://') && 
        !websiteText.startsWith('https://')) {
      _websiteError = 'Website must start with http:// or https://'.i18n;
      hasError = true;
    }
    
    if (hasError) {
      setState(() {});
      ErrorSnackBar.showWarning(context, 'Please fix the highlighted fields'.i18n);
      return;
    }
    
    setState(() => _isSaving = true);
    final data = {
      'title': titleText,
      'username': usernameText,
      'password': passwordText,
      'website': websiteText,
    };
    final isEdit = widget.passwordEntry != null;
    final id = widget.passwordEntry?.id;
    final result = isEdit
        ? await widget.passwordsRepository.updatePassword(id!, data)
        : await widget.passwordsRepository.addPassword(data);
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error saving password'.i18n)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.passwordEntry == null ? 'Add Password'.i18n : 'Edit Password'.i18n,
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
                  label: 'Title'.i18n,
                  icon: Icons.title,
                  nextFocusNode: _usernameFocusNode,
                  errorText: _titleError,
                  onChanged: (_) { if (_titleError != null) setState(() => _titleError = null); },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username'.i18n,
                  icon: Icons.person,
                  focusNode: _usernameFocusNode,
                  nextFocusNode: _passwordFocusNode,
                  errorText: _usernameError,
                  onChanged: (_) { if (_usernameError != null) setState(() => _usernameError = null); },
                ),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _websiteController,
                  label: 'Website'.i18n,
                  icon: Icons.link,
                  focusNode: _websiteFocusNode,
                  isLast: true,
                  errorText: _websiteError,
                  onChanged: (_) { if (_websiteError != null) setState(() => _websiteError = null); },
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
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool isLast = false,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: hasError 
                ? Colors.red.withOpacity(0.08) 
                : AppColors.text.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError 
                  ? Colors.red.withOpacity(0.6) 
                  : AppColors.text.withOpacity(0.1), 
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onFieldSubmitted: (_) {
              if (isLast) {
                if (!_isSaving) _save();
              } else {
                nextFocusNode?.requestFocus();
              }
            },
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: hasError ? Colors.red.withOpacity(0.8) : AppColors.text.withOpacity(0.6), 
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon, 
                color: hasError ? Colors.red.withOpacity(0.7) : AppColors.text.withOpacity(0.6), 
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final hasError = _passwordError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: hasError 
                ? Colors.red.withOpacity(0.08) 
                : AppColors.text.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError 
                  ? Colors.red.withOpacity(0.6) 
                  : AppColors.text.withOpacity(0.1), 
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _websiteFocusNode.requestFocus(),
            onChanged: (_) { if (_passwordError != null) setState(() => _passwordError = null); },
            decoration: InputDecoration(
              labelText: 'Password'.i18n,
              labelStyle: TextStyle(
                color: hasError ? Colors.red.withOpacity(0.8) : AppColors.text.withOpacity(0.6), 
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.lock, 
                color: hasError ? Colors.red.withOpacity(0.7) : AppColors.text.withOpacity(0.6), 
                size: 20,
              ),
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
                    SnackBar(content: Text('Password copied'.i18n)),
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
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              _passwordError!,
              style: TextStyle(
                color: Colors.red.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
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
                widget.passwordEntry == null ? 'Create Password'.i18n : 'Save Changes'.i18n,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
