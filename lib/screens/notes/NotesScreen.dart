import 'package:flutter/material.dart';
import '../../core/appColors.dart';
import '../../models/note.dart';
import '../../services/notes_service.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../components/button.dart';
import '../../components/error_snack_bar.dart';
import 'EditNoteScreen.dart';
import 'EditPasswordScreen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NotesService _notesService = NotesService(AuthService());
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      setState(() => _isLoading = true);
      final result = _searchQuery.isEmpty
          ? await _notesService.getAllNotes()
          : await _notesService.searchNotes(_searchQuery);

      if (!mounted) return;

      if (result['success'] == true) {
        final notes = result['data'] as List<Note>? ?? [];
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      } else {
        ErrorSnackBar.show(context, result['message'] ?? 'Error loading notes');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, 'Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmation(Note note) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(
              'Delete Note?',
              style: TextStyle(color: AppColors.text),
            ),
            content: Text(
              'Are you sure you want to delete "${note.title}"?',
              style: TextStyle(color: AppColors.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.text),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await _showDeleteConfirmation(note);
    if (!confirm) return;

    try {
      if (note.id == null) {
        throw StateError('La nota no tiene ID');
      }
      final result = await _notesService.deleteNote(note.id!);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _notes.removeWhere((n) => n.id == note.id);
        });
        ErrorSnackBar.showSuccess(context, 'Nota eliminada');
      } else {
        ErrorSnackBar.show(context, result['message'] ?? 'Error al eliminar la nota');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, 'Error al eliminar la nota: $e');
    }
  }

  Future<void> _createNote() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          notesService: _notesService,
        ),
      ),
    );
    if (created == true) {
      _loadNotes();
    }
  }

  Future<void> _createPassword() async {
    final passwordService = PasswordService();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPasswordScreen(
          passwordService: passwordService,
        ),
      ),
    );
    if (created == true) {
      // The password was created successfully, the user is back in NotesScreen
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
                      labelText: 'Search notes',
                      prefixIcon: Icon(Icons.search, color: AppColors.text.withOpacity(0.6), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: AppColors.text.withOpacity(0.6), size: 20),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadNotes();
                              },
                            )
                          : null,
                      labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadNotes();
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.text))
                  : _notes.isEmpty
                      ? Center(
                          child: Text(
                            'No have notes yet',
                            style: TextStyle(color: AppColors.text),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
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
                                    onTap: () async {
                                      final edited = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditNoteScreen(
                                            notesService: _notesService,
                                            note: note,
                                          ),
                                        ),
                                      );
                                      if (edited == true) {
                                        _loadNotes();
                                      }
                                    },
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
                                                  note.title,
                                                  style: const TextStyle(
                                                    color: AppColors.text,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  note.content,
                                                  style: TextStyle(
                                                    color: AppColors.text.withOpacity(0.6),
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: AppColors.text.withOpacity(0.7), size: 20),
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