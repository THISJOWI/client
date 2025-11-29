import 'package:flutter/material.dart';
import '../../core/appColors.dart';
import '../../backend/models/note.dart';
import '../../backend/repository/notes_repository.dart';
import '../../components/error_snack_bar.dart';
import '../../i18n/translations.dart';

class EditNoteScreen extends StatefulWidget {
  final NotesRepository notesRepository;
  final Note? note;

  const EditNoteScreen({
    super.key,
    required this.notesRepository,
    this.note,
  });

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  bool _isLoading = false;
  
  // Error states for fields
  String? _titleError;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    // Manual validation with visual feedback
    setState(() {
      _titleError = null;
      _contentError = null;
    });
    
    bool hasError = false;
    
    if (_titleController.text.trim().isEmpty) {
      _titleError = 'Please enter a title'.i18n;
      hasError = true;
    }
    
    if (_contentController.text.trim().isEmpty) {
      _contentError = 'Please enter the content'.i18n;
      hasError = true;
    }
    
    if (hasError) {
      setState(() {});
      ErrorSnackBar.showWarning(context, 'Please fix the highlighted fields'.i18n);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final note = Note(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      late Map<String, dynamic> result;
      if (widget.note == null) {
        // Crear nueva nota
        result = await widget.notesRepository.createNote(note);
      } else {
        // Actualizar nota existente
        final noteId = widget.note!.localId ?? widget.note!.id?.toString() ?? '';
        result = await widget.notesRepository.updateNote(noteId, note);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        final message = result['message'] ?? 'Unknown error';
        if (message.contains('title already exists')) {
          setState(() {
            _titleError = 'A note with this title already exists'.i18n;
          });
        } else {
          ErrorSnackBar.show(context, message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.note == null ? 'New Note'.i18n : 'Edit Note'.i18n,
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        foregroundColor: AppColors.text,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.text,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: Text(
                widget.note == null ? 'Create'.i18n : 'Save'.i18n,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Title field with error styling
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _titleError != null 
                          ? Colors.red.withOpacity(0.08) 
                          : AppColors.text.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _titleError != null 
                            ? Colors.red.withOpacity(0.6) 
                            : AppColors.text.withOpacity(0.1), 
                        width: _titleError != null ? 1.5 : 1,
                      ),
                    ),
                    child: TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: AppColors.text, fontSize: 16),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _contentFocusNode.requestFocus(),
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Title'.i18n,
                        labelStyle: TextStyle(
                          color: _titleError != null ? Colors.red.withOpacity(0.8) : AppColors.text.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.description_outlined, 
                          color: _titleError != null ? Colors.red.withOpacity(0.7) : AppColors.text.withOpacity(0.6), 
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (_titleError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        _titleError!,
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Content field with error styling
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _contentError != null 
                              ? Colors.red.withOpacity(0.08) 
                              : AppColors.text.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _contentError != null 
                                ? Colors.red.withOpacity(0.6) 
                                : AppColors.text.withOpacity(0.1), 
                            width: _contentError != null ? 1.5 : 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          style: const TextStyle(color: AppColors.text, fontSize: 16),
                          onChanged: (_) {
                            if (_contentError != null) {
                              setState(() => _contentError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Content'.i18n,
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(
                              color: _contentError != null ? Colors.red.withOpacity(0.8) : AppColors.text.withOpacity(0.6),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ),
                    if (_contentError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text(
                          _contentError!,
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}