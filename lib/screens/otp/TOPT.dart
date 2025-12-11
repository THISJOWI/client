import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/data/models/otp_entry.dart';
import 'package:thisjowi/data/repository/otp_repository.dart';
import 'package:thisjowi/i18n/translation_service.dart';
import 'package:thisjowi/services/otp_service.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final OtpRepository _otpRepository;
  final OtpService _otpService = OtpService();
  
  List<OtpEntry> _entries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Initialize repository (local-first with background sync)
    _otpRepository = OtpRepository();
    _loadEntries();
    // Update codes every second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    
    final result = await _otpRepository.getAllOtpEntries();
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      final entries = result['data'] as List<OtpEntry>? ?? [];
      setState(() {
        _entries = _searchQuery.isEmpty
            ? entries
            : entries.where((e) => 
                e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.issuer.toLowerCase().contains(_searchQuery.toLowerCase())
              ).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _entries = [];
        _isLoading = false;
      });
      ErrorSnackBar.show(context, result['message'] ?? 'Error loading OTP entries');
    }
  }

  void _copyCode(OtpEntry entry) {
    try {
      final code = _otpService.generateTotp(
        secret: entry.secret,
        digits: entry.digits,
        period: entry.period,
        algorithm: entry.algorithm,
      );
      
      Clipboard.setData(ClipboardData(text: code));
      ErrorSnackBar.showSuccess(context, 'Code copied'.tr(context));
    } catch (e) {
      ErrorSnackBar.show(context, 'Invalid secret key'.tr(context));
    }
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final issuerController = TextEditingController();
    final secretController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add OTP'.tr(context), style: const TextStyle(color: AppColors.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: nameController,
                label: 'Account name'.tr(context),
                hint: 'user@example.com',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: issuerController,
                label: 'Issuer'.tr(context),
                hint: 'Google, GitHub...',
              ),
              const SizedBox(height: 16),
              _buildTextField(
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
            child: Text('Cancel'.tr(context), style: TextStyle(color: AppColors.text.withOpacity(0.6))),
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
      
      if (!_otpService.isValidSecret(secret)) {
        ErrorSnackBar.show(context, 'Invalid secret key'.tr(context));
        return;
      }
      
      final addResult = await _otpRepository.addOtpEntry({
        'name': name,
        'issuer': issuerController.text.trim(),
        'secret': secret,
      });
      
      if (addResult['success'] == true) {
        ErrorSnackBar.showSuccess(context, 'OTP added'.tr(context));
        _loadEntries();
      } else {
        ErrorSnackBar.show(context, addResult['message'] ?? 'Error');
      }
    }
  }

  Future<void> _showImportDialog() async {
    final uriController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Import OTP URI'.tr(context), style: const TextStyle(color: AppColors.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the otpauth:// URI from your authenticator app'.tr(context),
                style: TextStyle(color: AppColors.text.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: uriController,
                label: 'OTP URI'.tr(context),
                hint: 'otpauth://totp/...',
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(context), style: TextStyle(color: AppColors.text.withOpacity(0.6))),
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
      
      final addResult = await _otpRepository.addOtpFromUri(uri, '');
      
      if (addResult['success'] == true) {
        ErrorSnackBar.showSuccess(context, 'OTP imported'.tr(context));
        _loadEntries();
      } else {
        ErrorSnackBar.show(context, addResult['message'] ?? 'Error');
      }
    }
  }

  Future<void> _deleteEntry(OtpEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(30, 30, 30, 1.0),
        title: Text('Delete OTP?'.tr(context), style: const TextStyle(color: AppColors.text)),
        content: Text(
          'Are you sure you want to delete "${entry.issuer.isNotEmpty ? entry.issuer : entry.name}"?',
          style: const TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(context), style: TextStyle(color: AppColors.text.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.tr(context), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final result = await _otpRepository.deleteOtpEntry(
        entry.id,
        serverId: entry.serverId,
      );
      
      if (result['success'] == true) {
        ErrorSnackBar.showSuccess(context, 'OTP deleted'.tr(context));
        _loadEntries();
      } else {
        ErrorSnackBar.show(context, result['message'] ?? 'Error');
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.text.withOpacity(0.7)),
        hintStyle: TextStyle(color: AppColors.text.withOpacity(0.3)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.text.withOpacity(0.05),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Authenticator'.tr(context),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showImportDialog,
                    icon: const Icon(Icons.qr_code, color: AppColors.text),
                    tooltip: 'Import URI'.tr(context),
                  ),
                  IconButton(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    tooltip: 'Add OTP'.tr(context),
                  ),
                  if (!(kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                    IconButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(context, '/otp/qrscan');
                        if (result == true) _loadEntries();
                      },
                      icon: const Icon(Icons.camera_alt, color: AppColors.primary),
                      tooltip: 'Scan QR'.tr(context),
                    ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) {
                  _searchQuery = value;
                  _loadEntries();
                },
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search...'.tr(context),
                  hintStyle: TextStyle(color: AppColors.text.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: AppColors.text.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.text.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadEntries,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) => _buildOtpCard(_entries[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 80,
            color: AppColors.text.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No OTP entries yet'.tr(context),
            style: TextStyle(
              color: AppColors.text.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first authenticator code'.tr(context),
            style: TextStyle(
              color: AppColors.text.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.qr_code),
                label: Text('Import URI'.tr(context)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: AppColors.text.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: Text('Add manually'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              if (!(kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/otp/qrscan');
                    if (result == true) _loadEntries();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: Text('Scan QR'.tr(context)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard(OtpEntry entry) {
    String code;
    bool isValidSecret = true;
    
    try {
      code = _otpService.generateTotp(
        secret: entry.secret,
        digits: entry.digits,
        period: entry.period,
        algorithm: entry.algorithm,
      );
    } catch (e) {
      code = 'INVALID';
      isValidSecret = false;
    }
    
    // Si el secreto es inválido, mostrar una tarjeta de error sin información sensible
    if (!isValidSecret) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(40, 30, 30, 1.0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invalid OTP Entry'.tr(context),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Secret key is corrupted'.tr(context),
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteEntry(entry),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.withOpacity(0.5),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final formattedCode = _otpService.formatCode(code);
    final remainingSeconds = _otpService.getRemainingSeconds(period: entry.period);
    final progress = _otpService.getProgress(period: entry.period);
    
    // Color del progreso: verde > amarillo > rojo
    Color progressColor;
    if (remainingSeconds > 10) {
      progressColor = Colors.green;
    } else if (remainingSeconds > 5) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(30, 30, 30, 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.text.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyCode(entry),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon with issuer initial
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          () {
                            final text = entry.issuer.isNotEmpty ? entry.issuer : entry.name;
                            return text.isNotEmpty ? text.substring(0, 1).toUpperCase() : '?';
                          }(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.issuer.isNotEmpty ? entry.issuer : entry.name,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (entry.issuer.isNotEmpty)
                            Text(
                              entry.name,
                              style: TextStyle(
                                color: AppColors.text.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Delete button
                    IconButton(
                      onPressed: () => _deleteEntry(entry),
                      icon: Icon(
                        Icons.delete_outline,
                        color: AppColors.text.withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Code and timer
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Code
                    Expanded(
                      child: Text(
                        formattedCode,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    
                    // Timer
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: AppColors.text.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                        Text(
                          '$remainingSeconds',
                          style: TextStyle(
                            color: progressColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Copy hint
                Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: AppColors.text.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to copy'.tr(context),
                      style: TextStyle(
                        color: AppColors.text.withOpacity(0.3),
                        fontSize: 12,
                      ),
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
}