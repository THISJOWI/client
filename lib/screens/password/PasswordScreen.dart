import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/appColors.dart';
import '../../models/password_entry.dart';
import '../../services/password_service.dart';
import '../../services/notes_service.dart';
import '../../services/auth_service.dart';
import '../../components/button.dart';
import '../../components/error_snack_bar.dart';
import 'EditPasswordScreen.dart';
import 'EditNoteScreen.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final PasswordService _passwordService = PasswordService();
  List<PasswordEntry> _passwords = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }


  
  Future<void> _loadPasswords() async {
    setState(() => _isLoading = true);
    final result = await _passwordService.fetchPasswords();
    if (!mounted) return;
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      final passwords = data.map((e) => PasswordEntry.fromJson(e)).toList();
      setState(() {
        _passwords = _searchQuery.isEmpty
            ? passwords
            : passwords.where((p) => p.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _passwords = [];
        _isLoading = false;
      });
      ErrorSnackBar.show(context, result['message'] ?? 'Error loading passwords');
    }
  }
  
  Future<bool> _showDeleteConfirmation(PasswordEntry entry) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text('Delete password?', style: TextStyle(color: AppColors.text)),
            content: Text('Are you sure you want to delete "${entry.title}"?', style: TextStyle(color: AppColors.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: AppColors.text)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }
  
  Future<void> _deletePassword(PasswordEntry entry) async {
    final confirm = await _showDeleteConfirmation(entry);
    if (!confirm) return;
    final result = await _passwordService.deletePassword(entry.id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _passwords.removeWhere((p) => p.id == entry.id);
      });
      ErrorSnackBar.showSuccess(context, 'Password deleted');
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Error deleting');
    }
  }
  
  void _showPasswordDetails(PasswordEntry entry) {
    bool showPassword = false;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, color: AppColors.text.withOpacity(0.6), size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (entry.website.isNotEmpty) ...[
                    Text('Sitio web', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(entry.website, style: const TextStyle(color: AppColors.text, fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (entry.username.isNotEmpty) ...[
                    Text('User', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(entry.username, style: const TextStyle(color: AppColors.text, fontSize: 14))),
                          IconButton(
                            icon: Icon(Icons.copy, color: AppColors.text.withOpacity(0.7), size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: entry.username));
                              ErrorSnackBar.showInfo(context, 'User copied');
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Password', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            showPassword ? entry.password : '•' * entry.password.length,
                            style: const TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            showPassword ? Icons.visibility : Icons.visibility_off,
                            color: AppColors.text.withOpacity(0.7),
                            size: 18,
                          ),
                          onPressed: () => setState(() => showPassword = !showPassword),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: AppColors.text.withOpacity(0.7), size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: entry.password));
                            ErrorSnackBar.showInfo(context, 'Password copied');
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  if (entry.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Notas', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(entry.notes, style: const TextStyle(color: AppColors.text, fontSize: 14)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.text.withOpacity(0.1),
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPassword() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPasswordScreen(
          passwordService: _passwordService,
        ),
      ),
    );
    if (created == true) {
      _loadPasswords();
    }
  }

  Future<void> _createNote() async {
    final notesService = NotesService(AuthService());
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          notesService: notesService,
        ),
      ),
    );
    if (created == true) {
      // The note was created successfully, the user is back in PasswordScreen
      // No action needed
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.text.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Search passwords',
                      prefixIcon: Icon(Icons.search, color: AppColors.text.withOpacity(0.6), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: AppColors.text.withOpacity(0.6), size: 20),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadPasswords();
                              },
                            )
                          : null,
                      labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadPasswords();
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.text))
                  : _passwords.isEmpty
                      ? Center(
                          child: Text('No passwords stored', style: TextStyle(color: AppColors.text)),
                        )
                      : ListView.builder(
                          itemCount: _passwords.length,
                          itemBuilder: (context, index) {
                            final entry = _passwords[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.text.withOpacity(0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showPasswordDetails(entry),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.title,
                                                  style: const TextStyle(
                                                    color: AppColors.text,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  entry.username.isNotEmpty ? entry.username : entry.website,
                                                  style: TextStyle(
                                                    color: AppColors.text.withOpacity(0.6),
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: Icon(Icons.edit, color: AppColors.text.withOpacity(0.7), size: 20),
                                            onPressed: () async {
                                              final edited = await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditPasswordScreen(
                                                    passwordService: _passwordService,
                                                    passwordEntry: entry,
                                                  ),
                                                ),
                                              );
                                              if (edited == true) {
                                                _loadPasswords();
                                              }
                                            },
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: AppColors.text.withOpacity(0.7), size: 20),
                                            onPressed: () => _deletePassword(entry),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: ExpandableActionButton(
            onCreatePassword: _createPassword,
            onCreateNote: _createNote,
          ),
        ),
      ],
    );
  }
}