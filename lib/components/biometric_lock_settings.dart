import 'package:flutter/material.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/core/appColors.dart';

/// Widget to configure biometric app lock settings
class BiometricLockSettings extends StatefulWidget {
  const BiometricLockSettings({super.key});

  @override
  State<BiometricLockSettings> createState() => _BiometricLockSettingsState();
}

class _BiometricLockSettingsState extends State<BiometricLockSettings> {
  final BiometricService _biometricService = BiometricService();
  
  bool _isLoading = true;
  bool _canUseBiometric = false;
  bool _isLockEnabled = false;
  String _biometricTypeName = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final canUse = await _biometricService.canUseBiometricLock();
    final isEnabled = await _biometricService.isBiometricLockEnabled();
    final typeName = await _biometricService.getBiometricTypeName();
    
    if (mounted) {
      setState(() {
        _canUseBiometric = canUse;
        _isLockEnabled = isEnabled;
        _biometricTypeName = typeName;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometricLock(bool enabled) async {
    if (enabled) {
      // Verify biometric before enabling
      final success = await _biometricService.authenticate(
        localizedReason: 'Verifica tu identidad para activar el bloqueo biométrico',
      );
      
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo verificar tu identidad'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    await _biometricService.setBiometricLockEnabled(enabled);
    
    if (mounted) {
      setState(() => _isLockEnabled = enabled);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Bloqueo con $_biometricTypeName activado'
                : 'Bloqueo con $_biometricTypeName desactivado',
          ),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  IconData _getBiometricIcon() {
    if (_biometricTypeName.contains('Face')) {
      return Icons.face;
    } else if (_biometricTypeName.contains('Touch') || 
               _biometricTypeName.contains('Fingerprint')) {
      return Icons.fingerprint;
    }
    return Icons.lock;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Cargando...'),
      );
    }

    if (!_canUseBiometric) {
      return ListTile(
        leading: Icon(
          Icons.lock_outline,
          color: AppColors.text.withOpacity(0.4),
        ),
        title: Text(
          'Bloqueo biométrico',
          style: TextStyle(
            color: AppColors.text.withOpacity(0.4),
          ),
        ),
        subtitle: Text(
          'No disponible en este dispositivo',
          style: TextStyle(
            color: AppColors.text.withOpacity(0.3),
            fontSize: 12,
          ),
        ),
      );
    }

    return ListTile(
      leading: Icon(
        _getBiometricIcon(),
        color: _isLockEnabled ? AppColors.primary : AppColors.text.withOpacity(0.6),
      ),
      title: Text(
        'Bloquear con $_biometricTypeName',
        style: TextStyle(
          color: AppColors.text,
        ),
      ),
      subtitle: Text(
        _isLockEnabled 
            ? 'Se pedirá $_biometricTypeName al abrir la app'
            : 'La app se abrirá sin verificación',
        style: TextStyle(
          color: AppColors.text.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: _isLockEnabled,
        onChanged: _toggleBiometricLock,
        activeColor: AppColors.primary,
      ),
    );
  }
}

/// Compact card version of biometric lock settings
class BiometricLockSettingsCard extends StatefulWidget {
  const BiometricLockSettingsCard({super.key});

  @override
  State<BiometricLockSettingsCard> createState() => _BiometricLockSettingsCardState();
}

class _BiometricLockSettingsCardState extends State<BiometricLockSettingsCard> {
  final BiometricService _biometricService = BiometricService();
  
  bool _isLoading = true;
  bool _canUseBiometric = false;
  bool _isLockEnabled = false;
  String _biometricTypeName = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final canUse = await _biometricService.canUseBiometricLock();
    final isEnabled = await _biometricService.isBiometricLockEnabled();
    final typeName = await _biometricService.getBiometricTypeName();
    
    if (mounted) {
      setState(() {
        _canUseBiometric = canUse;
        _isLockEnabled = isEnabled;
        _biometricTypeName = typeName;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometricLock(bool enabled) async {
    if (enabled) {
      final success = await _biometricService.authenticate(
        localizedReason: 'Verifica tu identidad para activar el bloqueo biométrico',
      );
      
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo verificar tu identidad'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    await _biometricService.setBiometricLockEnabled(enabled);
    
    if (mounted) {
      setState(() => _isLockEnabled = enabled);
    }
  }

  IconData _getBiometricIcon() {
    if (_biometricTypeName.contains('Face')) {
      return Icons.face;
    } else if (_biometricTypeName.contains('Touch') || 
               _biometricTypeName.contains('Fingerprint')) {
      return Icons.fingerprint;
    }
    return Icons.lock;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_canUseBiometric) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLockEnabled 
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.text.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getBiometricIcon(),
                color: _isLockEnabled ? AppColors.primary : AppColors.text.withOpacity(0.4),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bloqueo con $_biometricTypeName',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLockEnabled 
                        ? 'Activado'
                        : 'Desactivado',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isLockEnabled ? Colors.green : AppColors.text.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isLockEnabled,
              onChanged: _toggleBiometricLock,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
