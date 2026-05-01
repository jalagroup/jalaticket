import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jalasupport/FCMService.dart';
import 'package:jalasupport/auth.dart';
import 'package:jalasupport/firebase_options.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui' as ui;

// Global navigator key for navigation from FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✨ NEW: Global key for accessing mobile app state
final GlobalKey<_MyAppMobileState> myAppMobileKey =
    GlobalKey<_MyAppMobileState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📱 Background message: ${message.notification?.title}');
  FCMService.handleNotificationTap(message);
}

class MyAppMobile extends StatefulWidget {
  const MyAppMobile({super.key});

  @override
  State<MyAppMobile> createState() => _MyAppMobileState();
}

class _MyAppMobileState extends State<MyAppMobile> {
  bool _isInitializing = true;
  bool _hasInternet = true;
  Locale _locale = const Locale('ar');
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // ✨ NEW: Listen to auth changes and update locale
  void _setupAuthListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session != null) {
        // User logged in - load their language preference
        try {
          final response = await supabase
              .from('users')
              .select('language')
              .eq('auth_id', session.user.id)
              .maybeSingle();

          if (response != null && mounted) {
            final language = response['language'] as String? ?? 'en';
            print(
                '✅ MyAppMobile - Auth changed, updating locale to: $language');
            setState(() {
              _locale = Locale(language);
            });
          }
        } catch (e) {
          print('❌ Error loading user language on auth change: $e');
        }
      } else {
        // User logged out - show login/signup in Arabic
        if (mounted) {
          setState(() {
            _locale = const Locale('ar');
          });
        }
      }
    });
  }

// ✨ UPDATED: Broadcast locale change
  void changeLanguage(Locale locale) {
    if (mounted) {
      setState(() {
        _locale = locale;
      });
      // ✨ NEW: Notify all listeners about locale change
      localeChangeController.add(locale);
      print(
          '✅ MyAppMobile - Language changed to: ${locale.languageCode} and broadcasted');
    }
  }

  Future<void> _initializeApp() async {
    try {
      // ✅ Check internet connectivity first
      await _checkInternetConnection();

      // ✅ Initialize Firebase in parallel
      final firebaseFuture =
          _hasInternet ? _initializeFirebaseInBackground() : Future.value();

      // ✅ Load user locale in parallel
      final localeFuture = _initializeLocale();

      // ✅ Setup auth listener
      _setupAuthListener();

      // ✅ Wait for both to complete
      await Future.wait([firebaseFuture, localeFuture]);
    } catch (e) {
      print('❌ Error during initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // ✨ Load user locale before showing UI
  Future<void> _initializeLocale() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users')
            .select('language')
            .eq('auth_id', user.id)
            .maybeSingle();

        if (response != null && mounted) {
          final language = response['language'] as String? ?? 'en';
          setState(() {
            _locale = Locale(language);
          });
          print('✅ MyAppMobile - Initial locale loaded: $language');
        }
      }
    } catch (e) {
      print('❌ Error loading locale: $e');
      // Keep default locale (en)
    }
  }

  Future<void> _checkInternetConnection() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );

      if (mounted) {
        setState(() {
          _hasInternet = hasConnection;
        });
      }

      print(
        '🌐 Mobile App - Connectivity: ${hasConnection ? "Connected" : "No Connection"}',
      );
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _hasInternet = true; // Assume connected if check fails
        });
      }
    }
  }

  Future<void> _initializeFirebaseInBackground() async {
    try {
      print('🚀 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
      _setupFCMHandlers();
    } catch (e) {
      print('❌ Error initializing Firebase: $e');
    }
  }

  void _setupFCMHandlers() {
    print('📱 Setting up FCM handlers...');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from background notification');
      FCMService.handleNotificationTap(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print('📱 App opened from terminated state');
        Future.delayed(const Duration(seconds: 2), () {
          FCMService.handleNotificationTap(message);
        });
      }
    });

    print('✅ FCM handlers setup complete');
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 MyAppMobile building with locale: ${_locale.languageCode}');

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Jala Ticketing',
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      theme: ThemeData(
        primarySwatch: _createMaterialColor(AppColors.primary),
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      home: _isInitializing ? _buildLoadingScreen() : const AuthWrapper(),
      builder: (context, child) {
        return Directionality(
          textDirection: _locale.languageCode == 'ar'
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: child!,
        );
      },
    );
  }

  // ✨ Better loading screen with logo
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 80,
                width: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.support_agent,
                    color: AppColors.primary,
                    size: 60,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};

    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}
