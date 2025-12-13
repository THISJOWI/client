import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/data/repository/auth_repository.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/services/connectivity_service.dart';
import 'package:thisjowi/data/local/secure_storage_service.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/i18n/translations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  AuthRepository? _authRepository;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initAuthRepository();
  }

  void _initAuthRepository() {
    _authRepository = AuthRepository(
      authService: AuthService(),
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

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ErrorSnackBar.show(context, 'Please complete all fields'.i18n);
      return;
    }

    if (_authRepository == null) {
      _initAuthRepository();
    }

    setState(() => _isLoading = true);
    
    // Registration is now instant (offline-first with background sync)
    final result = await _authRepository!.register(email, email.split('@')[0], password);
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Show success and navigate immediately
      // Background sync will happen automatically
      ErrorSnackBar.showSuccess(
        context, 
        'Account created! Syncing in background...'.i18n
      );
      
      // Navigate to home or main screen instead of login
      // User can start using the app immediately
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Register failed'.i18n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative background elements
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Logo/Icon
                  Icon(
                    Icons.person_add_rounded,
                    size: 80,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 24),
                  
                  // Welcome Text
                  Text(
                    "Create Account".i18n,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign up to get started".i18n,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Register Form
                  Card(
                    elevation: 8,
                    color: const Color.fromRGBO(32, 32, 32, 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: AppColors.text.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: AppColors.text),
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.secondary),
                              labelText: "Email".i18n,
                              labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.text.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.text),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _isLoading ? null : _handleRegister(),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.secondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.text.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              labelText: "Password".i18n,
                              labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.text.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: AppColors.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: AppColors.background,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Create Account".i18n,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ".i18n,
                        style: TextStyle(color: AppColors.text.withOpacity(0.7)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Sign In".i18n,
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}