import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/components/error_snack_bar.dart';
import 'package:thisjowi/i18n/translations.dart';
import 'package:thisjowi/screens/auth/register_form.dart';

import 'package:thisjowi/components/bottomNavigation.dart';
import 'package:thisjowi/screens/auth/email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? accountType;
  final String? hostingMode;
  final bool isEmbedded;
  final String? initialCountry;
  final Function(Map<String, dynamic>)? onSuccess;

  const RegisterScreen({
    super.key,
    this.accountType,
    this.hostingMode,
    this.isEmbedded = false,
    this.initialCountry,
    this.onSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  

// ...

  void _handleSuccess(Map<String, dynamic> result) {
    if (widget.onSuccess != null) {
      widget.onSuccess!(result);
      return;
    }

    // Show success and navigate immediately
    // Background sync will happen automatically
    if (mounted) {
      ErrorSnackBar.showSuccess(
        context, 
        'Account created!'.i18n
      );
      
      // Check if we have a token (auto-login successful)
      if (result.containsKey('token')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyBottomNavigation()),
        );
      } else {
        final email = result['email'] as String? ?? '';

        // Navigate to email verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: email),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define the content widget that is shared
    Widget content = Center(
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
                    child: RegisterForm(
                      accountType: widget.accountType,
                      hostingMode: widget.hostingMode,
                      initialCountry: widget.initialCountry,
                      onSuccess: _handleSuccess,
                    ),
                  ),
                ),
                
                if (!widget.isEmbedded) ...[
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
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

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
          
          content,
        ],
      ),
    );
  }
}