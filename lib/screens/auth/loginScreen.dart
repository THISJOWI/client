import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/backend/repository/auth_repository.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/backend/service/database_service.dart';
import 'package:thisjowi/backend/service/connectivity_service.dart';
import 'package:thisjowi/backend/service/secure_storage_service.dart';
import 'package:thisjowi/components/bottomNavigation.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/i18n/translations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final BiometricService _biometricService = BiometricService();
  AuthRepository? _authRepository;
  bool _isLoading = false;
  bool _hasSavedSession = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _initAuthRepository();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final authService = AuthService();
    final token = await authService.getToken();
    final canCheck = await _biometricService.canCheckBiometrics();
    final isEnabled = await _biometricService.isBiometricEnabled();
    final biometricType = await _biometricService.getBiometricTypeName();
    
    if (mounted) {
      setState(() {
        _hasSavedSession = token != null && token.isNotEmpty;
        _biometricAvailable = canCheck && isEnabled && _hasSavedSession;
        _biometricType = biometricType;
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Authenticate to access ThisJowi'.i18n,
    );
    
    if (authenticated && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ErrorSnackBar.show(context, 'Authentication failed'.i18n);
    }
  }

  void _initAuthRepository() {
    _authRepository = AuthRepository(
      authService: AuthService(),
      databaseService: DatabaseService(),
      connectivityService: ConnectivityService(),
      secureStorageService: SecureStorageService(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ErrorSnackBar.show(context, 'Please complete email and password'.i18n);
      return;
    }

    if (_authRepository == null) {
      _initAuthRepository();
    }

    setState(() => _isLoading = true);
    final result = await _authRepository!.login(email, password);
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Show message if offline login
      if (result['offline'] == true && mounted) {
        ErrorSnackBar.showSuccess(context, 'Logged in offline mode'.i18n);
      }
      
      // Navigate to main screen replacing the stack
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
      );
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Login failed'.i18n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    Text(
                      "Welcome".i18n,
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign in to your account".i18n,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              /* EMAIL */
              SizedBox(
                width: 300,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.text.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.text.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.email,
                        color: AppColors.text.withOpacity(0.6),
                        size: 20,
                      ),
                      labelText: "Email".i18n,
                      labelStyle: TextStyle(
                        color: AppColors.text.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              /* PASSWORD */
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 300,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.text.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: AppColors.text, fontSize: 16),
                      obscureText: true,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.lock,
                          color: AppColors.text.withOpacity(0.6),
                          size: 20,
                        ),
                        labelText: "Password".i18n,
                        labelStyle: TextStyle(
                          color: AppColors.text.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              /* LOGIN BUTTON */
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Sign In".i18n,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              /* BIOMETRIC LOGIN */
              if (_biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Text(
                        'or'.i18n,
                        style: TextStyle(
                          color: AppColors.text.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _isLoading ? null : _handleBiometricLogin,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.text.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.text.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _biometricType == 'Face ID'
                                ? Icons.face_rounded
                                : Icons.fingerprint_rounded,
                            size: 40,
                            color: AppColors.text.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use %s'.i18n.fill([_biometricType]),
                        style: TextStyle(
                          color: AppColors.text.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              /* REGISTER LINK */
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ".i18n,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text.withOpacity(0.7),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, "/register");
                      },
                      child: Text(
                        "Sign Up".i18n,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
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