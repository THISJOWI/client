import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/backend/repository/auth_repository.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/backend/service/database_service.dart';
import 'package:thisjowi/backend/service/connectivity_service.dart';
import 'package:thisjowi/backend/service/secure_storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initAuthRepository();
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
                      "Create Account".i18n,
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign up to get started".i18n,
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
                      onFieldSubmitted: (_) => _isLoading ? null : _handleRegister(),
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

              /* REGISTER BUTTON */
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
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
                          "Create account".i18n,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              /* LOGIN LINK */
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ".i18n,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text.withOpacity(0.7),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, "/login");
                      },
                      child: Text(
                        "Sign In".i18n,
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