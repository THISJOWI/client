import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/data/repository/auth_repository.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/services/connectivity_service.dart';
import 'package:thisjowi/data/local/secure_storage_service.dart';
import 'package:thisjowi/components/bottomNavigation.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/components/social_login_button.dart';
import 'package:thisjowi/i18n/translations.dart';
import 'package:thisjowi/i18n/translation_service.dart';
import 'package:thisjowi/screens/auth/forgot_password_screen.dart';

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
  bool _obscurePassword = true;

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
      localizedReason: 'Authenticate to access ThisJowi'.tr(context),
    );
    
    if (authenticated && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ErrorSnackBar.show(context, 'Authentication failed'.tr(context));
    }
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

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    
    // Use AuthRepository to ensure local persistence
    final authRepository = AuthRepository(
      authService: AuthService(),
      connectivityService: ConnectivityService(),
      secureStorageService: SecureStorageService(),
    );
    
    final result = await authRepository.loginWithGoogle();
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
        );
      } else {
        ErrorSnackBar.show(context, result['message'] ?? 'Google Sign In failed');
      }
    }
  }
  Future<void> _handleGitHubLogin() async {
    setState(() => _isLoading = true);
    
    final authRepository = AuthRepository(
      authService: AuthService(),
      connectivityService: ConnectivityService(),
      secureStorageService: SecureStorageService(),
    );
    
    final result = await authRepository.loginWithGitHub();
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
        );
      } else {
        ErrorSnackBar.show(context, result['message'] ?? 'GitHub login failed');
      }
    }
  }
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ErrorSnackBar.show(context, 'Please complete email and password'.tr(context));
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
        ErrorSnackBar.showSuccess(context, 'Logged in offline mode'.tr(context));
      }
      
      // Navigate to main screen replacing the stack
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
      );
    } else {
      ErrorSnackBar.show(context, result['message'] ?? 'Login failed'.tr(context));
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
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.05),
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
                    Icons.lock_person_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  
                  // Welcome Text
                  Text(
                    "Welcome Back".tr(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign in to continue".tr(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Form
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
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                              labelText: "Email".tr(context),
                              labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.text.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
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
                              labelText: "Password".tr(context),
                              labelStyle: TextStyle(color: AppColors.text.withOpacity(0.6)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.text.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                          ),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?'.tr(context),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
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
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Sign In".tr(context),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google
                              SocialLoginButton(
                                imagePath: 'assets/google_logo.png',
                                onTap: _isLoading ? null : _handleGoogleLogin,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 20),
                              // GitHub
                              SocialLoginButton(
                                imagePath: 'assets/github_logo.png',
                                onTap: _isLoading ? null : _handleGitHubLogin,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Biometric Button
                  if (_biometricAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          Text(
                            'or'.tr(context),
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

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ".tr(context),
                        style: TextStyle(color: AppColors.text.withOpacity(0.7)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: Text(
                          "Sign Up".tr(context),
                          style: const TextStyle(
                            color: AppColors.primary,
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

