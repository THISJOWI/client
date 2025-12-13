import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/data/models/password_entry.dart';
import 'package:thisjowi/data/models/note.dart';
import 'package:thisjowi/data/repository/passwords_repository.dart';
import 'package:thisjowi/data/repository/notes_repository.dart';
import 'package:thisjowi/data/repository/otp_repository.dart';
import 'package:thisjowi/services/otp_service.dart';
import 'package:thisjowi/components/button.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/screens/password/EditPasswordScreen.dart';
import 'package:thisjowi/screens/notes/EditNoteScreen.dart';
import 'package:thisjowi/i18n/translations.dart';
import 'package:thisjowi/i18n/translation_service.dart';
import 'package:thisjowi/components/bottomNavigation.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

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
    _passwordsRepository = PasswordsRepository();
    _notesRepository = NotesRepository();
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
      final rawPasswords = passwordResult['data'] as List<PasswordEntry>? ?? [];
      // Deduplicate passwords to prevent UI duplicates
      final seenPasswords = <String>{};
      for (final p in rawPasswords) {
        final key = '${p.title}|${p.username}';
        if (!seenPasswords.contains(key)) {
          seenPasswords.add(key);
          passwords.add(p);
        }
      }
    }

    if (notesResult['success'] == true) {
      final rawNotes = notesResult['data'] as List<Note>? ?? [];
      // Deduplicate notes to prevent UI duplicates
      final seenNotes = <String>{};
      for (final n in rawNotes) {
        if (!seenNotes.contains(n.title)) {
          seenNotes.add(n.title);
          notes.add(n);
        }
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      passwords = passwords
          .where((p) =>
              p.title.toLowerCase().contains(query) ||
              p.username.toLowerCase().contains(query))
          .toList();
      notes = notes
          .where((n) =>
              n.title.toLowerCase().contains(query) ||
              n.content.toLowerCase().contains(query))
          .toList();
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

  Future<void> _createOtp() async {
    final otpRepository = OtpRepository();
    final otpService = OtpService();

    final nameController = TextEditingController();
    final issuerController = TextEditingController();
    final secretController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text('Add OTP'.tr(context),
                style: const TextStyle(color: AppColors.text)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.qr_code, color: AppColors.text),
              tooltip: 'Import URI'.tr(context),
              onPressed: () {
                Navigator.pop(context);
                _showImportDialog();
              },
            ),
            if (!(kIsWeb ||
                Platform.isWindows ||
                Platform.isMacOS ||
                Platform.isLinux))
              IconButton(
                icon: const Icon(Icons.camera_alt, color: AppColors.text),
                tooltip: 'Scan QR'.tr(context),
                onPressed: () async {
                  Navigator.pop(context);
                  final result =
                      await Navigator.pushNamed(context, '/otp/qrscan');
                  if (result == true && mounted) {
                    bottomNavigationKey.currentState?.navigateToOtp();
                  }
                },
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOtpTextField(
                controller: nameController,
                label: 'Account name'.tr(context),
                hint: 'user@example.com',
              ),
              const SizedBox(height: 16),
              _buildOtpTextField(
                controller: issuerController,
                label: 'Issuer'.tr(context),
                hint: 'Google, GitHub...',
              ),
              const SizedBox(height: 16),
              _buildOtpTextField(
                controller: secretController,
                label: 'Secret key'.tr(context),
                hint: 'JBSWY3DPEHPK3PXP',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(context),
                style: TextStyle(color: AppColors.text.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Add'.tr(context)),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final secret = secretController.text.trim().replaceAll(' ', '');

      if (name.isEmpty || secret.isEmpty) {
        ErrorSnackBar.show(context, 'Name and secret are required'.tr(context));
        return;
      }

      if (!otpService.isValidSecret(secret)) {
        ErrorSnackBar.show(context, 'Invalid secret key'.tr(context));
        return;
      }

      final addResult = await otpRepository.addOtpEntry({
        'name': name,
        'issuer': issuerController.text.trim(),
        'secret': secret,
      });

      if (addResult['success'] == true) {
        ErrorSnackBar.showSuccess(context, 'OTP added'.tr(context));
        // Navegar a la pestaña de OTP usando la key global
        if (mounted) {
          bottomNavigationKey.currentState?.navigateToOtp();
        }
      } else {
        ErrorSnackBar.show(context, addResult['message'] ?? 'Error');
      }
    }
  }

  Future<void> _showImportDialog() async {
    final otpRepository = OtpRepository();
    final uriController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Import OTP URI'.tr(context),
            style: const TextStyle(color: AppColors.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the otpauth:// URI from your authenticator app'
                    .tr(context),
                style: TextStyle(
                    color: AppColors.text.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildOtpTextField(
                controller: uriController,
                label: 'OTP URI'.tr(context),
                hint: 'otpauth://totp/...',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(context),
                style: TextStyle(color: AppColors.text.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Import'.tr(context)),
          ),
        ],
      ),
    );

    if (result == true) {
      final uri = uriController.text.trim();

      if (!uri.startsWith('otpauth://')) {
        ErrorSnackBar.show(context, 'Invalid OTP URI'.tr(context));
        return;
      }

      final addResult = await otpRepository.addOtpFromUri(uri, '');

      if (addResult['success'] == true) {
        ErrorSnackBar.showSuccess(context, 'OTP imported'.tr(context));
        if (mounted) {
          bottomNavigationKey.currentState?.navigateToOtp();
        }
      } else {
        ErrorSnackBar.show(context, addResult['message'] ?? 'Error');
      }
    }
  }

  Widget _buildOtpTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6)),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withOpacity(0.3)),
        filled: true,
        fillColor: AppColors.text.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.3)),
        ),
      ),
    );
  }

  Future<bool> _showDeletePasswordConfirmation(PasswordEntry entry) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text('Delete password?'.i18n,
                style: TextStyle(color: AppColors.text)),
            content: Text('Are you sure you want to delete "${entry.title}"?',
                style: TextStyle(color: AppColors.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'.i18n,
                    style: TextStyle(color: AppColors.text)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'.i18n, style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deletePassword(PasswordEntry entry) async {
    final confirm = await _showDeletePasswordConfirmation(entry);
    if (!confirm) return;

    final result = await _passwordsRepository.deletePassword(entry.id,
        serverId: entry.serverId);

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
            title: Text('Delete Note?'.i18n,
                style: TextStyle(color: AppColors.text)),
            content: Text(
                '${'Are you sure you want to delete'.i18n} "${note.title}"?',
                style: TextStyle(color: AppColors.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'.i18n,
                    style: TextStyle(color: AppColors.text)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'.i18n, style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await _showDeleteNoteConfirmation(note);
    if (!confirm) return;

    final noteId = note.localId ?? note.id?.toString() ?? '';
    if (noteId.isEmpty) return;

    final result = await _notesRepository.deleteNote(noteId,
        serverId: note.serverId?.toString() ?? note.id?.toString());

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _notes.removeWhere((n) =>
          (n.localId != null && n.localId == note.localId) ||
          (n.id != null && n.id == note.id)));
      ErrorSnackBar.showSuccess(context, 'Note deleted'.i18n);
    } else {
      ErrorSnackBar.show(
          context, result['message'] ?? 'Error deleting note'.i18n);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close,
                              color: AppColors.text.withOpacity(0.6), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (entry.website.isNotEmpty) ...[
                      Text('Website'.i18n,
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.text.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(entry.website,
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (entry.username.isNotEmpty) ...[
                      Text('User',
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.text.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(entry.username,
                                    style: const TextStyle(
                                        color: AppColors.text, fontSize: 14))),
                            IconButton(
                              icon: Icon(Icons.copy,
                                  color: AppColors.text.withOpacity(0.7),
                                  size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: entry.username));
                                ErrorSnackBar.showInfo(
                                    context, 'User copied'.i18n);
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Password'.i18n,
                        style: TextStyle(
                            color: AppColors.text.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.text.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              showPassword
                                  ? entry.password
                                  : '•' * entry.password.length,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  letterSpacing: 1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                                showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppColors.text.withOpacity(0.7),
                                size: 18),
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(right: 8),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.copy,
                                color: AppColors.text.withOpacity(0.7),
                                size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: entry.password));
                              ErrorSnackBar.showInfo(
                                  context, 'Password copied'.i18n);
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'.i18n,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Image(
                      image: NetworkImage(
                          "https://pub-9030d6e053cc40b380e0f63662daf8ed.r2.dev/logo-removebg-preview_resized.png"),
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'THISJOWI'.i18n,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.text.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Search'.i18n,
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.text.withOpacity(0.6), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  color: AppColors.text.withOpacity(0.6),
                                  size: 20),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadData();
                              },
                            )
                          : null,
                      labelStyle: TextStyle(
                          color: AppColors.text.withOpacity(0.6), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadData();
                    },
                  ),
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.text))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.text,
                        child: _passwords.isEmpty && _notes.isEmpty
                            ? _buildEmptyState()
                            : ListView(
                              padding: const EdgeInsets.only(bottom: 150),
                                children: [
                                  // Passwords Section
                                  if (_passwords.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      icon: Icons.lock_outline,
                                      title: 'Passwords'.i18n,
                                      count: _passwords.length,
                                    ),
                                    ..._passwords.map(
                                        (entry) => _buildPasswordItem(entry)),
                                  ],

                                  // Divider between sections
                                  if (_passwords.isNotEmpty &&
                                      _notes.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 8),
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
                                    ..._notes
                                        .map((note) => _buildNoteItem(note)),
                                  ],
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
        // FAB
        Positioned(
          bottom: 110.0,
          right: 16.0,
          child: ExpandableActionButton(
            onCreatePassword: _createPassword,
            onCreateNote: _createNote,
            onCreateOtp: _createOtp,
          ),
        ),
      ],
    ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.key,
                        color: AppColors.text.withOpacity(0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        if (entry.username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.username,
                            style: TextStyle(
                                color: AppColors.text.withOpacity(0.5),
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: AppColors.text.withOpacity(0.5), size: 18),
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
                    icon: Icon(Icons.delete_outline,
                        color: AppColors.text.withOpacity(0.5), size: 18),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: AppColors.text.withOpacity(0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note.content,
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.5),
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: AppColors.text.withOpacity(0.5), size: 18),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.2,
            child: const Icon(
              Icons.house_rounded,
              size: 100,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No data yet'.i18n,
            style: TextStyle(
              color: AppColors.text.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first password or note'.tr(context),
            style: TextStyle(
              color: AppColors.text.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
