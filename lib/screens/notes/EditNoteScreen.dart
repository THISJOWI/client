import 'package:flutter/material.dart';
import '../../core/appColors.dart';
import '../../models/note.dart';
import '../../services/notes_service.dart';
import '../../components/error_snack_bar.dart';

class EditNoteScreen extends StatefulWidget {
  final NotesService notesService;
  final Note? note;

  const EditNoteScreen({
    super.key,
    required this.notesService,
    this.note,
  });

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  String? _titleError;

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
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _titleError = null;
    });

    try {
      final note = Note(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      late Map<String, dynamic> result;
      if (widget.note == null) {
        result = await widget.notesService.createNote(note);
      } else {
        result = await widget.notesService.updateNote(widget.note!.title, note);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        final message = result['message'] ?? 'Unknown error';
        if (message.contains('title already exists')) {
          setState(() {
            _titleError = 'A note with this title already exists';
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
          widget.note == null ? 'New Note' : 'Edit Note',
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
                widget.note == null ? 'Create' : 'Save',
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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.text.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.text.withOpacity(0.1), width: 1),
                ),
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AppColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(
                      color: _titleError != null ? Colors.red : AppColors.text.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.note, color: AppColors.text.withOpacity(0.6), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    errorText: _titleError,
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_titleError != null) {
                      setState(() {
                        _titleError = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.text.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.text.withOpacity(0.1), width: 1),
                  ),
                  child: TextFormField(
                    controller: _contentController,
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Content',
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(
                        color: AppColors.text.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the content';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}