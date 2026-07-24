import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/user_fields/user_field_values_widget.dart';
import 'package:jalasupport/main_mobile.dart';
import 'package:jalasupport/report_problem_screen.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:jalasupport/main.dart' show myAppKey;
import 'package:jalasupport/main_mobile.dart' show myAppMobileKey;
import 'package:jalasupport/fcm_debug_dialog.dart';

// UI Components
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            return const MainScreen();
          }
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _logoError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _precacheLogo();
  }

  Future<void> _precacheLogo() async {
    try {
      await precacheImage(const AssetImage('assets/images/logo.png'), context);
    } catch (_) {
      if (mounted) setState(() => _logoError = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    final success = await AuthService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.\nيرجى التحقق من بياناتك والمحاولة مرة أخرى.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final l10n = AppLocalizations.safeOf(context);

    final formCard = Container(
      padding: EdgeInsets.all(isWide ? 40 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isWide) ...[
              _LogoSection(hasError: _logoError),
              const SizedBox(height: 28),
            ] else ...[
              Text(
                l10n.welcomeBackPleaseSignIn,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
            ],
            _EmailLoginForm(
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              isLoading: _isLoading,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onSignIn: _signIn,
              onClearError: () => setState(() => _errorMessage = null),
              onForgotPassword: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen()),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB71C1C),
                            fontSize: 13.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (kIsWeb) _RegisterLink(onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            )),
          ],
        ),
      ),
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: _LoginBrandPanel(hasError: _logoError),
            ),
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: formCard,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: formCard,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Brand panel (left side on wide screens) ───────────────────────────────────
class _LoginBrandPanel extends StatelessWidget {
  final bool hasError;
  const _LoginBrandPanel({this.hasError = false});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      color: AppColors.secondary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Jala Ticketing',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr ? 'دعم ذكي · نتائج حقيقية' : 'Smart Support · Real Results',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.70),
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 52),
              _BrandFeature(
                icon: Icons.speed_rounded,
                text: isAr ? 'حل التذاكر بسرعة' : 'Fast ticket resolution',
              ),
              const SizedBox(height: 20),
              _BrandFeature(
                icon: Icons.analytics_outlined,
                text: isAr ? 'تحليلات فورية' : 'Real-time analytics',
              ),
              const SizedBox(height: 20),
              _BrandFeature(
                icon: Icons.lock_outline_rounded,
                text: isAr ? 'آمن وموثوق' : 'Secure & reliable',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BrandFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Login form ────────────────────────────────────────────────────────────────
class _EmailLoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onClearError;

  const _EmailLoginForm({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleVisibility,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmailField(controller: emailController, onChanged: (_) => onClearError()),
        const SizedBox(height: 16),
        _PasswordField(
          controller: passwordController,
          obscurePassword: obscurePassword,
          onToggleVisibility: onToggleVisibility,
          onFieldSubmitted: onSignIn,
          onChanged: (_) => onClearError(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            child: Text(l10n.forgotPassword, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 4),
        _LoginButton(isLoading: isLoading, onPressed: onSignIn),
      ],
    );
  }
}

// Update _LogoSection
class _LogoSection extends StatelessWidget {
  final bool hasError;

  const _LogoSection({this.hasError = false});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/logo.png',
            height: 72,
            width: 72,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.support_agent,
                color: AppColors.primary,
                size: 52,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Jala Ticketing',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAr ? 'دعم ذكي · نتائج حقيقية' : 'Smart Support · Real Results',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _EmailField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l10n.emailOrPhone,
        hintText: l10n.locale.languageCode == 'ar'
            ? 'example@email.com  أو  0598XXXXXX'
            : 'example@email.com  or  0598XXXXXX',
        prefixIcon: Icon(Icons.person_outlined, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterYourEmail;
        }
        final v = value.trim();
        // Accept email, +international phone, or local 0XXXXXXXXX
        final isEmail = v.contains('@');
        final isIntlPhone = v.startsWith('+');
        final isLocalPhone = RegExp(r'^0\d{9}$').hasMatch(v);
        if (!isEmail && !isIntlPhone && !isLocalPhone) {
          return l10n.pleaseEnterValidEmail;
        }
        return null;
      },
    );
  }
}

// Update _PasswordField
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.onFieldSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l10n.password,
        prefixIcon: Icon(Icons.lock_outlined, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onFieldSubmitted(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.pleaseEnterYourPassword;
        }
        return null;
      },
    );
  }
}

// Update _LoginButton
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                l10n.signIn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// Update _RegisterLink
class _RegisterLink extends StatelessWidget {
  final VoidCallback onTap;

  const _RegisterLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Center(
      child: TextButton(
        onPressed: onTap,
        child: RichText(
          text: TextSpan(
            text: '${l10n.dontHaveAccount} ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            children: [
              TextSpan(
                text: l10n.registerHere,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedPlaceId;
  List<PlaceModel> _places = [];
  bool _isLoading = false;
  bool _isLoadingPlaces = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _placesError;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });

    try {
      final response = await supabase
          .from('places')
          .select()
          .eq('is_active', true)
          .order('name');

      setState(() {
        _places = response
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
        _isLoadingPlaces = false;
      });
    } catch (e) {
      setState(() {
        _placesError = 'فشل تحميل المواقع. يرجى المحاولة مرة أخرى.';
        _isLoadingPlaces = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userData = {
      'email': _emailController.text.trim(),
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'user_type': UserType.user.value,
      'place_id': _selectedPlaceId,
      'is_active': false, // User will be inactive by default
      'language': 'ar',
    };

    try {
      final success = await AuthService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        userData,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        final l10n = AppLocalizations.safeOf(context);

        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('تم التسجيل بنجاح'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تم إنشاء حسابك بنجاح'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'معلومات مهمة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• حسابك بانتظار التفعيل من المسؤول\n'
                          '• ستتلقى إشعاراً عند تفعيل حسابك\n'
                          '• تواصل مع المسؤول لأي استفسار',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to login screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('الذهاب إلى تسجيل الدخول'),
                ),
              ],
            ),
          ),
        );
      } else {
        // Show error if registration failed
        final l10n = AppLocalizations.safeOf(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.registrationFailed),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Registration error: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التسجيل: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPlaceDropdown() {
    if (_isLoadingPlaces) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          color: Colors.grey.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.location_on, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('جاري التحميل...',
                style: TextStyle(color: Colors.grey)),
            const Spacer(),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
          ],
        ),
      );
    }

    if (_placesError != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              color: Colors.red.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _placesError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _loadPlaces,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_places.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          color: Colors.orange.withValues(alpha: 0.05),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('لا توجد مواقع متاحة', style: TextStyle(color: Colors.orange)),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedPlaceId,
      decoration: InputDecoration(
        labelText: 'اختر موقعك *',
        prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
      ),
      items: _places.map((place) {
        final lang = Localizations.localeOf(context).languageCode;
        return DropdownMenuItem(
          value: place.id,
          child: Text(place.localizedName(lang)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedPlaceId = value);
      },
      validator: (value) {
        if (value == null) {
          return 'الرجاء اختيار الموقع';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 800;

    final formChildren = <Widget>[
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.support_agent,
                                      color: AppColors.primary,
                                      size: 40,
                                    );
                                  },
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(
                                  width: 48), // Balance for back button
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'إنشاء حساب',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أدخل معلوماتك للبدء',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Form Fields
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Full Name
                          TextFormField(
                            controller: _fullNameController,
                            decoration: InputDecoration(
                              labelText: 'الاسم الكامل *',
                              prefixIcon: Icon(Icons.person_outlined,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال الاسم الكامل';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'البريد الإلكتروني *',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال البريد الإلكتروني';
                              }
                              if (!value.contains('@')) {
                                return 'الرجاء إدخال بريد إلكتروني صحيح';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف *',
                              prefixIcon: Icon(Icons.phone_outlined,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال رقم الهاتف';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور *',
                              prefixIcon: Icon(Icons.lock_outlined,
                                  color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال كلمة المرور';
                              }
                              if (value.length < 6) {
                                return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Confirm Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور *',
                              prefixIcon: Icon(Icons.lock_outlined,
                                  color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                            ),
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء تأكيد كلمة المرور';
                              }
                              if (value != _passwordController.text) {
                                return 'كلمات المرور غير متطابقة';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Place Dropdown
                          _buildPlaceDropdown(),

                          const SizedBox(height: 24),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isLoading ||
                                      _isLoadingPlaces ||
                                      _places.isEmpty)
                                  ? null
                                  : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'إنشاء حساب',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Information Card (update the content)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: AppColors.secondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'معلومات التسجيل',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.secondary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoItem(Icons.pending_actions,
                                    'سيتم إنشاء حسابك غير نشط'),
                                const SizedBox(height: 8),
                                _buildInfoItem(Icons.admin_panel_settings,
                                    'مطلوب تفعيل من المسؤول'),
                                const SizedBox(height: 8),
                                _buildInfoItem(Icons.email_outlined,
                                    'ستُحوَّل إلى صفحة تسجيل الدخول'),
                                const SizedBox(height: 8),
                                _buildInfoItem(Icons.warning,
                                    'لا يمكنك تسجيل الدخول حتى يتم تفعيل حسابك'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign In Link
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'لديك حساب بالفعل؟ ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'سجّل دخولك هنا',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    ];

    final formWidget = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: formChildren,
      ),
    );

    if (isLargeScreen) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: Row(
            children: [
              const Expanded(
                flex: 5,
                child: _LoginBrandPanel(),
              ),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: formWidget,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: formWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

void showTestPushDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _TestPushDialog(),
  );
}

class _TestPushDialog extends StatefulWidget {
  const _TestPushDialog();

  @override
  State<_TestPushDialog> createState() => _TestPushDialogState();
}

class _TestPushDialogState extends State<_TestPushDialog> {
  final List<String> _logs = [];
  bool _isLoading = false;
  final _scrollController = ScrollController();

  void _log(String msg) {
    final ts = DateTime.now().toString().substring(11, 19);
    setState(() => _logs.add('[$ts] $msg'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTestPush() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _logs.clear();
    });
    _log('--- Starting test push ---');

    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) {
        _log('❌ Not authenticated');
        return;
      }
      _log('✅ User: ${authUser.email}');

      // Fetch user row
      final rows = await supabase
          .from('users')
          .select('id, fcm_token, fcm_token_web')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (rows == null) {
        _log('❌ No user row found in DB');
        return;
      }

      final mobileToken = rows['fcm_token'] as String?;
      final webToken = rows['fcm_token_web'] as String?;
      final userId = rows['id'] as String;

      _log('Mobile token: ${mobileToken != null ? "${mobileToken.substring(0, 20)}..." : "null"}');
      _log('Web token: ${webToken != null ? "${webToken.substring(0, 20)}..." : "null"}');

      // Insert an in-app notification (works on both mobile and web via realtime)
      _log('Inserting in-app notification...');
      await supabase.from('notifications').insert({
        'user_id': userId,
        'type': 'system_announcement',
        'title': '🔔 Test Notification',
        'message': 'This is a test notification sent from the profile screen.',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      _log('✅ In-app notification inserted — check the bell icon');

      // Send FCM push via edge function (works on all platforms)
      if (mobileToken != null && mobileToken.isNotEmpty) {
        _log('Sending FCM push to mobile token via edge function...');
        await NotificationService.sendTestPush(
          token: mobileToken,
          userId: userId,
        );
        _log('✅ FCM push sent — you should receive a system notification');
      } else {
        _log('⚠️ No mobile FCM token — FCM push skipped');
        _log('   Open the app on a phone and tap "Get FCM Token" in FCM Debug first');
      }

      _log('--- Done ✅ ---');
    } catch (e) {
      _log('❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.deepPurple, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Test Push Notification',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sends a real FCM push + in-app notification to yourself via Supabase Edge Function. Works on all platforms.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Tap "Send Test" to begin',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _logs.length,
                        itemBuilder: (context, i) {
                          final line = _logs[i];
                          Color color = Colors.grey.shade300;
                          if (line.contains('✅')) color = Colors.greenAccent;
                          if (line.contains('❌')) color = Colors.redAccent;
                          if (line.contains('⚠️')) color = Colors.orange;
                          if (line.contains('ℹ️')) {
                            color = Colors.lightBlueAccent;
                          }
                          if (line.contains('---')) color = Colors.yellow;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendTestPush,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(
                _isLoading ? 'Sending...' : 'Send Test',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback? onProfileImageUpdated;
  final VoidCallback? onFieldsUpdated;

  const ProfileScreen({
    super.key,
    required this.currentUser,
    this.onProfileImageUpdated,
    this.onFieldsUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedLanguage = 'en';
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _profileImageUrl;

  bool get _isPhoneUser =>
      widget.currentUser.email.startsWith('phone_') &&
      widget.currentUser.email.endsWith('@phone.user');

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.currentUser.fullName;
    _phoneController.text = widget.currentUser.phone ?? '';
    _selectedLanguage = widget.currentUser.language;
    _profileImageUrl = widget.currentUser.profileImageUrl;
    // For phone users, email field starts empty (they haven't set a real email yet)
    _emailController.text = _isPhoneUser ? '' : widget.currentUser.email;
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploadingImage = true);

    try {
      print('Starting image picker...');

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        print('No image selected');
        return;
      }

      print('Image selected: ${image.name}, size: ${await image.length()}');

      if (!mounted) return;

      String? imageUrl;

      if (kIsWeb) {
        print('Processing for web...');
        final Uint8List imageBytes = await image.readAsBytes();
        imageUrl = await AuthService.uploadProfileImage(
          imageBytes: imageBytes,
          userId: widget.currentUser.id,
          fileName: image.name,
        );
      } else {
        print('Processing for mobile...');
        final File imageFile = File(image.path);
        imageUrl = await AuthService.uploadProfileImage(
          imageFile: imageFile,
          userId: widget.currentUser.id,
          fileName: image.name,
        );
      }

      if (imageUrl != null && mounted) {
        print('Image uploaded successfully: $imageUrl');

        // Update database with new image URL
        final success = await AuthService.updateProfileImage(
            widget.currentUser.id, imageUrl);

        if (success && mounted) {
          setState(() {
            _profileImageUrl = imageUrl;
          });

          // ✨ Notify parent widget to update profile image
          widget.onProfileImageUpdated?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Profile image updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (mounted) {
          throw Exception('Failed to update profile image in database');
        }
      } else if (mounted) {
        throw Exception('Failed to upload image to storage');
      }
    } catch (e) {
      print('Error in _pickAndUploadImage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to upload image: ${e.toString()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadImageWeb() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      // Get image bytes for web
      final Uint8List imageBytes = await image.readAsBytes();
      final String fileName = image.name;

      // Upload image to storage
      final imageUrl = await AuthService.uploadProfileImage(
        imageBytes: imageBytes,
        userId: widget.currentUser.id,
        fileName: fileName,
      );

      if (imageUrl != null) {
        await _updateProfileImageUrl(imageUrl);
      } else if (mounted) {
        throw Exception('Failed to upload image to storage');
      }
    }
  }

  Future<void> _pickAndUploadImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      // Get file for mobile
      final File imageFile = File(image.path);
      final String fileName = image.name;

      // Upload image to storage
      final imageUrl = await AuthService.uploadProfileImage(
        imageFile: imageFile,
        userId: widget.currentUser.id,
        fileName: fileName,
      );

      if (imageUrl != null) {
        await _updateProfileImageUrl(imageUrl);
      } else if (mounted) {
        throw Exception('Failed to upload image to storage');
      }
    }
  }

  Future<void> _updateProfileImageUrl(String imageUrl) async {
    // Update database with new image URL
    final success =
        await AuthService.updateProfileImage(widget.currentUser.id, imageUrl);

    if (success && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile image updated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      throw Exception('Failed to update profile image in database');
    }
  }

  // Rest of your ProfileScreen methods remain the same...
  Widget _buildInitialsAvatar({double size = 120}) {
    final name = widget.currentUser.fullName.trim();
    final parts = name.split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.primary],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.33,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? Image.network(
                    _profileImageUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    headers: const {
                      'Cache-Control': 'no-cache, no-store, must-revalidate',
                      'Pragma': 'no-cache',
                      'Expires': '0',
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialsAvatar();
                    },
                  )
                : _buildInitialsAvatar(),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadImage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Update database
      final updatePayload = {
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'language': _selectedLanguage,
      };
      if (_isPhoneUser) {
        final newEmail = _emailController.text.trim();
        if (newEmail.isNotEmpty && newEmail.contains('@')) {
          updatePayload['email'] = newEmail;
          // Also update auth email without requiring verification (uses service key path)
          try {
            await supabase.functions.invoke('update-user-email', body: {
              'newEmail': newEmail,
            });
          } catch (_) {
            // Non-fatal: DB email is updated; auth email update is best-effort
          }
        }
      }
      await supabase.from('users').update(updatePayload).eq('id', widget.currentUser.id);

      print('✅ Database updated with language: $_selectedLanguage');

      // ✨ Update locale immediately - the broadcast will handle the rest
      final newLocale = Locale(_selectedLanguage);

      if (kIsWeb) {
        final state = myAppKey.currentState;
        if (state != null) {
          state.changeLanguage(
              newLocale); // This will broadcast to all listeners
        }
      } else {
        final state = myAppMobileKey.currentState;
        if (state != null) {
          state.changeLanguage(
              newLocale); // This will broadcast to all listeners
        }
      }

      // Refresh parent so navbar name/info updates immediately
      widget.onProfileImageUpdated?.call();

      if (mounted) {
        // Wait a tiny bit for the UI to update
        await Future.delayed(const Duration(milliseconds: 50));

        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(l10n.profileUpdatedSuccessfully),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Failed to update profile: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
// Replace the build method in _ProfileScreenState with this:

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWeb = kIsWeb;
    final isLargeScreen = screenSize.width > 992;
    final isTablet = screenSize.width < 992;
    final l10n = AppLocalizations.safeOf(context);

    // Calculate bottom navigation bar height
    final bottomNavBarHeight = isTablet && !isWeb ? 90.0 : 0.0;

    double getContainerWidth() {
      if (!isWeb) return double.infinity;
      if (screenSize.width >= 1200) return 1140;
      if (screenSize.width >= 992) return 960;
      if (screenSize.width >= 768) return 720;
      if (screenSize.width >= 576) return 540;
      return screenSize.width * 0.9;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(
          l10n.profile,
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        // ProfileScreen is always reached via Navigator.push now (see
        // main.dart's _navigateToProfile), on both web and mobile — let the
        // default automaticallyImplyLeading (true) show the back button
        // whenever the route can actually be popped.
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_active,
                  color: Colors.deepPurple),
              onPressed: () => showTestPushDialog(context),
              tooltip: 'Test Push Notification',
            ),
          ),
          if (!kIsWeb)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.orange),
                onPressed: () => showFcmDebugDialog(context),
                tooltip: 'FCM Debug',
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                Icons.logout,
                color: AppColors.primary,
              ),
              onPressed: () async {
                await AuthService.signOut();
              },
              tooltip: l10n.signOut,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: isWeb && isLargeScreen ? 32 : 24,
            right: isWeb && isLargeScreen ? 32 : 24,
            top: isWeb && isLargeScreen ? 32 : 24,
            bottom: bottomNavBarHeight + 24,
          ),
          child: Container(
            width: getContainerWidth(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header with Image
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 24),
                        Text(
                          widget.currentUser.fullName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onBackground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.currentUser.email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.currentUser.userType.value
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.tapCameraToChange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Two Column Layout for Web
                  if (isWeb && isLargeScreen)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildEditableSection(),
                              const SizedBox(height: 24),
                              _buildCustomFieldsSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildAccountInfoSection(),
                              const SizedBox(height: 24),
                              _buildSecuritySection(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildEditableSection(),
                        const SizedBox(height: 24),
                        _buildAccountInfoSection(),
                        const SizedBox(height: 24),
                        _buildSecuritySection(),
                        const SizedBox(height: 24),
                        _buildCustomFieldsSection(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFieldsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.extension_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Additional Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          UserFieldValuesWidget(
            targetUserId: widget.currentUser.id,
            currentUserId: widget.currentUser.id,
            isAdmin: false,
            onSaved: widget.onFieldsUpdated,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSection() {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.editInformation,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: l10n.fullName,
              prefixIcon: Icon(Icons.person_outlined, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.pleaseEnterFullName;
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Phone
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: '${l10n.phone} (${l10n.optional})',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 20),

          // Optional email for phone-based accounts
          if (_isPhoneUser) ...[
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: AppLocalizations.safeOf(context).emailForLogin,
                hintText: 'email@example.com',
                helperText: AppLocalizations.safeOf(context).phoneUserEmailHint,
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null; // optional
                if (!value.trim().contains('@')) {
                  return AppLocalizations.safeOf(context).pleaseEnterValidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          // Language
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: InputDecoration(
              labelText: l10n.language,
              prefixIcon: Icon(Icons.language, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (value) {
              setState(() => _selectedLanguage = value!);
            },
          ),

          const SizedBox(height: 32),

          // Update Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.updateProfile,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection() {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.accountInformation,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
              Icons.email_outlined, l10n.email, widget.currentUser.email),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.admin_panel_settings_outlined,
            l10n.userType,
            widget.currentUser.userType.value
                .replaceAll('_', ' ')
                .toUpperCase(),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            widget.currentUser.isActive
                ? Icons.check_circle_outline
                : Icons.pending_outlined,
            l10n.status,
            widget.currentUser.isActive ? l10n.active : l10n.inactive,
            statusColor:
                widget.currentUser.isActive ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            l10n.memberSince,
            DateFormat('dd/MM/yyyy').format(widget.currentUser.createdAt),
          ),
        ],
      ),
    );
  }

  // ── Security Section ──────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(l10n.changePassword,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: l10n.currentPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.currentPassword
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: l10n.newPassword,
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.newPassword;
                      if (v.length < 6) return l10n.passwordTooShort;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: l10n.confirmNewPassword,
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.confirmNewPassword;
                      if (v != newCtrl.text) return l10n.passwordsDoNotMatch;
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      try {
                        await AuthService.changePassword(
                          currentPassword: currentCtrl.text.trim(),
                          newPassword: newCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(l10n.passwordUpdatedSuccessfully),
                              ]),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        final msg = e.toString().contains('invalid')
                            ? l10n.incorrectCurrentPassword
                            : e.toString();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(l10n.changePassword),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordWithOTPDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final emailCtrl =
        TextEditingController(text: widget.currentUser.email);
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool otpSent = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.phonelink_lock, color: Colors.orange[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  otpSent ? l10n.step2EnterOTP : l10n.step1SendOTP,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: otpSent
                    // ── Step 2: OTP + new password ──────────────────────────
                    ? Column(
                        key: const ValueKey('step2'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange[700], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l10n.otpSentToEmail,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: l10n.enterOTP,
                              prefixIcon: const Icon(Icons.pin),
                              counterText: '',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6)
                                return l10n.invalidOTP;
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: newPassCtrl,
                            obscureText: obscureNew,
                            decoration: InputDecoration(
                              labelText: l10n.newPassword,
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                icon: Icon(obscureNew
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setDialogState(
                                    () => obscureNew = !obscureNew),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return l10n.newPassword;
                              if (v.length < 6) return l10n.passwordTooShort;
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmPassCtrl,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: l10n.confirmNewPassword,
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                icon: Icon(obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setDialogState(
                                    () => obscureConfirm = !obscureConfirm),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return l10n.confirmNewPassword;
                              if (v != newPassCtrl.text)
                                return l10n.passwordsDoNotMatch;
                              return null;
                            },
                          ),
                        ],
                      )
                    // ── Step 1: Email + send OTP ─────────────────────────
                    : Column(
  key: const ValueKey('step1'),
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      l10n.email,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    ),
    const SizedBox(height: 6),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[350]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(
            emailCtrl.text,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    ),
  ],
),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            if (otpSent)
              TextButton(
                onPressed: loading
                    ? null
                    : () => setDialogState(() => otpSent = false),
                child: Text(l10n.sendOTP),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      try {
                        if (!otpSent) {
                          await AuthService.sendPasswordResetOTP(
                              emailCtrl.text.trim());
                          setDialogState(() {
                            otpSent = true;
                            loading = false;
                          });
                        } else {
                          await AuthService.verifyOTPAndSetPassword(
                            email: emailCtrl.text.trim(),
                            otp: otpCtrl.text.trim(),
                            newPassword: newPassCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(l10n.passwordUpdatedSuccessfully),
                                ]),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => loading = false);
                        }
                        final msg = e.toString().contains('otp') ||
                                e.toString().contains('token')
                            ? l10n.otpExpiredOrInvalid
                            : e.toString();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(otpSent
                      ? l10n.verifyAndSetPassword
                      : l10n.sendOTP),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.security, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.security,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Change Password button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: const Icon(Icons.lock_outline),
              label: Text(l10n.changePassword,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Reset Password with OTP button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showResetPasswordWithOTPDialog,
              icon: const Icon(Icons.phonelink_lock),
              label: Text(l10n.resetPasswordWithOTP,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[700],
                side: BorderSide(color: Colors.orange[700]!),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          // Report a Problem button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportProblemScreen(
                        currentUser: widget.currentUser),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_rounded),
              label: Text(
                l10n.reportProblem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? statusColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (statusColor ?? AppColors.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (statusColor ?? AppColors.primary).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (statusColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: statusColor ?? AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forgot Password – full screen (replaces the old dialog)
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _otpFocus = FocusNode();
  final _newPassFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  bool _otpSent = false;
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (!_otpSent) {
        await AuthService.sendPasswordResetOTP(_emailCtrl.text.trim());
        if (!mounted) return;
        setState(() {
          _otpSent = true;
          _loading = false;
        });
        // Move focus to OTP field after keyboard settles
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) FocusScope.of(context).requestFocus(_otpFocus);
        });
      } else {
        await AuthService.verifyOTPAndSetPassword(
          email: _emailCtrl.text.trim(),
          otp: _otpCtrl.text.trim(),
          newPassword: _newPassCtrl.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _loading = false;
          _success = true;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final l10n = AppLocalizations.safeOf(context);
      final msg =
          e.toString().contains('otp') || e.toString().contains('token')
              ? l10n.otpExpiredOrInvalid
              : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      // resizeToAvoidBottomInset defaults to true — the Scaffold shifts up
      // when the keyboard appears so inputs are never hidden.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.forgotPassword,
          style: const TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 40 : 24,
              16,
              isWide ? 40 : 24,
              // Extra bottom padding so the button clears the keyboard
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _success
                      ? _SuccessView(key: const ValueKey('success'), l10n: l10n)
                      : _otpSent
                          ? _Step2(
                              key: const ValueKey('step2'),
                              l10n: l10n,
                              otpCtrl: _otpCtrl,
                              newPassCtrl: _newPassCtrl,
                              confirmPassCtrl: _confirmPassCtrl,
                              otpFocus: _otpFocus,
                              newPassFocus: _newPassFocus,
                              confirmPassFocus: _confirmPassFocus,
                              obscureNew: _obscureNew,
                              obscureConfirm: _obscureConfirm,
                              onToggleNew: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                              onToggleConfirm: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                              loading: _loading,
                              onBack: () => setState(() => _otpSent = false),
                              onSubmit: _submit,
                            )
                          : _Step1(
                              key: const ValueKey('step1'),
                              l10n: l10n,
                              emailCtrl: _emailCtrl,
                              loading: _loading,
                              onSubmit: _submit,
                            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Email entry ───────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSubmit;

  const _Step1({
    super.key,
    required this.l10n,
    required this.emailCtrl,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon header
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded,
                size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.step1SendOTP,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.enterYourEmail,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: l10n.emailAddress,
            prefixIcon:
                const Icon(Icons.email_outlined, color: AppColors.primary),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) =>
              (v == null || !v.contains('@')) ? l10n.enterYourEmail : null,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              l10n.sendOTP,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 2: OTP + new passwords ───────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController otpCtrl;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final FocusNode otpFocus;
  final FocusNode newPassFocus;
  final FocusNode confirmPassFocus;
  final bool obscureNew;
  final bool obscureConfirm;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step2({
    super.key,
    required this.l10n,
    required this.otpCtrl,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.otpFocus,
    required this.newPassFocus,
    required this.confirmPassFocus,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.loading,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon header
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                size: 48, color: Colors.green),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.step2EnterOTP,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.orange.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.orange[700], size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.otpSentToEmail,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // OTP field
        TextFormField(
          controller: otpCtrl,
          focusNode: otpFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 6,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(newPassFocus),
          decoration: InputDecoration(
            labelText: l10n.enterOTP,
            prefixIcon:
                const Icon(Icons.pin_rounded, color: AppColors.primary),
            counterText: '',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) =>
              (v == null || v.length < 6) ? l10n.invalidOTP : null,
        ),
        const SizedBox(height: 16),
        // New password
        TextFormField(
          controller: newPassCtrl,
          focusNode: newPassFocus,
          obscureText: obscureNew,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(confirmPassFocus),
          decoration: InputDecoration(
            labelText: l10n.newPassword,
            prefixIcon:
                const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                obscureNew ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggleNew,
            ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return l10n.newPassword;
            if (v.length < 6) return l10n.passwordTooShort;
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Confirm password
        TextFormField(
          controller: confirmPassCtrl,
          focusNode: confirmPassFocus,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: l10n.confirmNewPassword,
            prefixIcon:
                const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggleConfirm,
            ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return l10n.confirmNewPassword;
            if (v != newPassCtrl.text) return l10n.passwordsDoNotMatch;
            return null;
          },
        ),
        const SizedBox(height: 24),
        // Verify button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              l10n.verifyAndSetPassword,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back to step 1
        TextButton.icon(
          onPressed: loading ? null : onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(l10n.sendOTP),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// ── Success state ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final AppLocalizations l10n;

  const _SuccessView({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 64, color: Colors.green),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.passwordUpdatedSuccessfully,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.forgotPassword,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
