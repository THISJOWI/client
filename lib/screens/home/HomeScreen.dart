import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/backend/models/password_entry.dart';
import 'package:thisjowi/backend/models/note.dart';
import 'package:thisjowi/backend/repository/passwords_repository.dart';
import 'package:thisjowi/backend/repository/notes_repository.dart';
import 'package:thisjowi/services/password_service.dart';
import 'package:thisjowi/services/notes_service.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/components/button.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/screens/password/EditPasswordScreen.dart';
import 'package:thisjowi/screens/notes/EditNoteScreen.dart';
import 'package:thisjowi/i18n/translations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PasswordsRepository _passwordsRepository;
  late final NotesRepository _notesRepository;
  
  List<PasswordEntry> _passwords = [];
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initRepositories();
    _loadData();
  }

  void _initRepositories() {
    final passwordService = PasswordService();
    _passwordsRepository = PasswordsRepository(passwordService);
    
    final authService = AuthService();
    final notesService = NotesService(authService);
    _notesRepository = NotesRepository(notesService);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load both in parallel
    final results = await Future.wait([
      _passwordsRepository.getAllPasswords(),
      _notesRepository.getAllNotes(),
    ]);
    
    if (!mounted) return;
    
    final passwordResult = results[0];
    final notesResult = results[1];
    
    List<PasswordEntry> passwords = [];
    List<Note> notes = [];
    
    if (passwordResult['success'] == true) {
      passwords = passwordResult['data'] as List<PasswordEntry>? ?? [];
    }
    
    if (notesResult['success'] == true) {
      notes = notesResult['data'] as List<Note>? ?? [];
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      passwords = passwords.where((p) => 
        p.title.toLowerCase().contains(query) ||
        p.username.toLowerCase().contains(query)
      ).toList();
      notes = notes.where((n) => 
        n.title.toLowerCase().contains(query) ||
        n.content.toLowerCase().contains(query)
      ).toList();
    }
    
    setState(() {
      _passwords = passwords;
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _createPassword() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPasswordScreen(
          passwordsRepository: _passwordsRepository,
        ),
      ),
    );
    if (created == true) _loadData();
  }

  Future<void> _createNote() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          notesRepository: _notesRepository,
        ),
      ),
    );
    if (created == true) _loadData();
  }

  Future<bool> _showDeletePasswordConfirmation(PasswordEntry entry) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Delete password?'.i18n, style: TextStyle(color: AppColors.text)),
        content: Text('Are you sure you want to delete "${entry.title}"?', style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.i18n, style: TextStyle(color: AppColors.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.i18n, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deletePassword(PasswordEntry entry) async {
    final confirm = await _showDeletePasswordConfirmation(entry);
    if (!confirm) return;
    
    final result = await _passwordsRepository.deletePassword(entry.id);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      setState(() => _passwords.removeWhere((p) => p.id == entry.id));
      ErrorSnackBar.showSuccess(context, 'Password deleted'.i18n);
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Error deleting');
    }
  }

  Future<bool> _showDeleteNoteConfirmation(Note note) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Delete Note?'.i18n, style: TextStyle(color: AppColors.text)),
        content: Text('${'Are you sure you want to delete'.i18n} "${note.title}"?', style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.i18n, style: TextStyle(color: AppColors.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.i18n, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await _showDeleteNoteConfirmation(note);
    if (!confirm) return;
    
    final noteId = note.localId ?? note.id?.toString() ?? '';
    if (noteId.isEmpty) return;
    
    final result = await _notesRepository.deleteNote(noteId, note.serverId ?? note.id);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      setState(() => _notes.removeWhere((n) => 
        (n.localId != null && n.localId == note.localId) || 
        (n.id != null && n.id == note.id)
      ));
      ErrorSnackBar.showSuccess(context, 'Note deleted'.i18n);
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Error deleting note'.i18n);
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
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
                          style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold),
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
                    Text('Website'.i18n, style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.text.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Text(entry.website, style: const TextStyle(color: AppColors.text, fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (entry.username.isNotEmpty) ...[
                    Text('User', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.text.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(entry.username, style: const TextStyle(color: AppColors.text, fontSize: 14))),
                          IconButton(
                            icon: Icon(Icons.copy, color: AppColors.text.withOpacity(0.7), size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: entry.username));
                              ErrorSnackBar.showInfo(context, 'User copied'.i18n);
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Password'.i18n, style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.text.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
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
                          icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, color: AppColors.text.withOpacity(0.7), size: 18),
                          onPressed: () => setState(() => showPassword = !showPassword),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 8),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, color: AppColors.text.withOpacity(0.7), size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: entry.password));
                            ErrorSnackBar.showInfo(context, 'Password copied'.i18n);
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
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
                      child: Text('Close'.i18n, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Search bar
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
                      labelText: 'Search'.i18n,
                      prefixIcon: Icon(Icons.search, color: AppColors.text.withOpacity(0.6), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: AppColors.text.withOpacity(0.6), size: 20),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadData();
                              },
                            )
                          : null,
                      labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadData();
                    },
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.text))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.text,
                      child: _passwords.isEmpty && _notes.isEmpty
                          ? Center(
                              child: Text(
                                'No data yet'.i18n,
                                style: TextStyle(color: AppColors.text),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(bottom: 80),
                              children: [
                                // Passwords Section
                                if (_passwords.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    icon: Icons.lock_outline,
                                    title: 'Passwords'.i18n,
                                    count: _passwords.length,
                                  ),
                                  ..._passwords.map((entry) => _buildPasswordItem(entry)),
                                ],
                                
                                // Divider between sections
                                if (_passwords.isNotEmpty && _notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Divider(
                                      color: AppColors.text.withOpacity(0.1),
                                      thickness: 1,
                                    ),
                                  ),
                                
                                // Notes Section
                                if (_notes.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    icon: Icons.description_outlined,
                                    title: 'Notes'.i18n,
                                    count: _notes.length,
                                  ),
                                  ..._notes.map((note) => _buildNoteItem(note)),
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
        // FAB
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.text.withOpacity(0.7), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.text.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.text.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: AppColors.text.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordItem(PasswordEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.text.withOpacity(0.12), width: 1),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.key, color: AppColors.text.withOpacity(0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        if (entry.username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.username,
                            style: TextStyle(color: AppColors.text.withOpacity(0.5), fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: AppColors.text.withOpacity(0.5), size: 18),
                    onPressed: () async {
                      final edited = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditPasswordScreen(
                            passwordsRepository: _passwordsRepository,
                            passwordEntry: entry,
                          ),
                        ),
                      );
                      if (edited == true) _loadData();
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.text.withOpacity(0.5), size: 18),
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
  }

  Widget _buildNoteItem(Note note) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.text.withOpacity(0.12), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final edited = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => EditNoteScreen(
                    notesRepository: _notesRepository,
                    note: note,
                  ),
                ),
              );
              if (edited == true) _loadData();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined, color: AppColors.text.withOpacity(0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note.content,
                          style: TextStyle(color: AppColors.text.withOpacity(0.5), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.text.withOpacity(0.5), size: 18),
                    onPressed: () => _deleteNote(note),
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
  }
}
