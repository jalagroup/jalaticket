import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jalasupport/FCMService.dart';
import 'package:jalasupport/widgets/in_app_notification_banner.dart';
import 'package:jalasupport/complaints_screen.dart';
import 'package:jalasupport/dashboard_mobile.dart';
import 'package:jalasupport/dashboard_web.dart';
import 'package:jalasupport/firebase_options.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main_mobile.dart' show MyAppMobile;
import 'package:jalasupport/main_web.dart';
import 'api/firebase_api.dart';
import 'package:jalasupport/auth.dart';
import 'package:jalasupport/chat.dart';
import 'package:jalasupport/dashboard.dart';
import 'package:jalasupport/fleet/fleet_management_screen.dart';
import 'package:jalasupport/fleet/fleet_service.dart';
import 'package:jalasupport/fleet/fleet_vehicle_detail_screen.dart';
import 'package:jalasupport/fleet/my_vehicles_screen.dart';
import 'package:jalasupport/managment.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/tickets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jalasupport/main_mobile.dart' show myAppMobileKey;
import 'package:jalasupport/sound_service.dart';
import 'package:jalasupport/ai_dashboard_onboarding.dart';
import 'package:jalasupport/ai_dashboard_screen.dart';
import 'package:jalasupport/custom_complaints/cc_home_screen.dart';
import 'package:jalasupport/user_fields/user_field_service.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart' show usePathUrlStrategy;
import 'package:go_router/go_router.dart';
import 'package:jalasupport/app_router.dart';

import 'dart:ui' as ui;

final StreamController<Locale> localeChangeController =
    StreamController<Locale>.broadcast();
// Initialize Supabase
final supabase = Supabase.instance.client;

// Define app colors
class AppColors {
  static const Color primary = Color(0xFFf16936); // Orange
  static const Color secondary = Color(0xFF135467); // Dark blue-green
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onBackground = Color(0xFF135467);
  static const Color onSurface = Color(0xFF135467);
}

// ✨ NEW: Global keys for accessing app state
final GlobalKey<_MyAppState> myAppKey = GlobalKey<_MyAppState>();

// Tracks which chat room the user is currently viewing.
// Set by tickets.dart when a chat is opened/closed so foreground
// notifications for that room are suppressed.
String? activeChatRoomId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Firebase init (required for FCM on web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase init
  await Supabase.initialize(
    url: 'https://wxibjgzemtfzkattbpue.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4aWJqZ3plbXRmemthdHRicHVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5MTQwMTIsImV4cCI6MjA3MzQ5MDAxMn0.OUXZsVloijKMgFbHtAKIaT7e-c-rAWNKA2Mak1D7SJM',
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Pre-generate tones so first play is instant.
  SoundService.init();

  // Starts the periodic batch processor that flushes queued email
  // notifications (see NotificationService._queueEmailNotification) — without
  // this, emails queued anywhere in the app are never actually sent.
  await NotificationService.initialize();

  // Platform-specific initialization
  if (kIsWeb) {
    runApp(MyApp(key: myAppKey)); // ✨ Pass the key here
  } else {
    runApp(MyAppMobile(key: myAppMobileKey)); // ✨ Pass the key here
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');
  bool _hasInternetConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoadingLocale = true;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _setupAuthListener();
  }

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
            _isLoadingLocale = false;
          });
          print('✅ Locale initialized: $language');
        } else {
          setState(() => _isLoadingLocale = false);
        }
      } else {
        setState(() => _isLoadingLocale = false);
      }
    } catch (e) {
      print('❌ Error initializing locale: $e');
      setState(() => _isLoadingLocale = false);
    }
  }

  void _setupAuthListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session != null) {
        try {
          final response = await supabase
              .from('users')
              .select('language')
              .eq('auth_id', session.user.id)
              .maybeSingle();

          if (response != null && mounted) {
            final language = response['language'] as String? ?? 'en';
            setState(() {
              _locale = Locale(language);
            });
            print('✅ Locale updated on auth change: $language');
          }
        } catch (e) {
          print('❌ Error loading user language: $e');
        }
      } else {
        // No session → show login/signup in Arabic
        if (mounted) {
          setState(() {
            _locale = const Locale('ar');
          });
        }
      }
    });
  }

  // ✨ UPDATED: Broadcast locale change to all listeners
  void changeLanguage(Locale locale) {
    if (mounted) {
      setState(() {
        _locale = locale;
      });
      // ✨ NEW: Notify all listeners about locale change
      localeChangeController.add(locale);
      print('✅ Language changed to: ${locale.languageCode} and broadcasted');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'Jala Support',
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
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'Quicksand',
        fontFamilyFallback: const ['NotoSansArabic'],
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: Colors.white,
          background: AppColors.background,
          onPrimary: AppColors.onPrimary,
          onSecondary: AppColors.onSecondary,
          onSurface: AppColors.onSurface,
          onBackground: AppColors.onBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: AppColors.onBackground,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.onBackground),
          actionsIconTheme: IconThemeData(color: AppColors.onBackground),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.background,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: Colors.grey.withOpacity(0.2),
        ),
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: _locale.languageCode == 'ar'
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
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
        b + ((ds < 0 ? b : (255 - g)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}

Widget getDashboardScreen(
    UserModel currentUser, void Function(String? status) onNavigateToTickets) {
  if (kIsWeb) {
    return DashboardWeb(
      currentUser: currentUser,
      onNavigateToTickets: onNavigateToTickets,
    );
  } else {
    return DashboardMobile(
      currentUser: currentUser,
      onNavigateToTickets: onNavigateToTickets,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  UserModel? _currentUser;
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _hasComplaintPermission = false;
  bool _hasFleetAccess = false;
  // Shown instead of the full Fleet tab for users who drive at least one
  // vehicle but don't have Fleet Access (System Admin / fleet-enabled Super
  // Admin) — mutually exclusive with _hasFleetAccess, since admins already
  // see everything (including their own vehicles) via the full tab.
  bool _hasMyVehicles = false;
  Locale _locale = const Locale('en');

  int _unreadChatRoomsCount = 0;
  Map<String, int> _unreadCounts = {};

  bool _hasInternetConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<Locale>? _localeChangeSubscription; // ✨ NEW

  bool _isNotificationsOpen = false;
  final GlobalKey _notificationButtonKey = GlobalKey();
  bool _hasNavigatedFromFCM = false;

  List<NavigationItem> _webNavItems = [];
  List<NavigationItem> _mobileNavItems = [];

  // KPI tap — navigate to tickets with a pre-selected status tab
  String? _initialTicketStatus;

  // Main dashboard preference
  String _mainDashMode = 'default'; // 'default' | 'saved' | 'custom'
  String? _mainDashSavedId;
  Map<String, dynamic>? _mainDashSavedData;
  String? _mainDashCustomId;
  bool _loadingDashPref = true;
  int _dashRefreshKey = 0;

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription? _notificationsSubscription;
  Timer? _notificationCheckTimer;

  bool _mandatoryFieldsMissing = false;

  /// Setup FCM navigation callbacks
  void _setupFCMNavigationCallbacks() {
    FCMService.setNavigationCallbacks(
      onNavigateToChat: (ticketId, chatRoomId) {
        if (!mounted || _hasNavigatedFromFCM) return;

        print(
            '🎯 FCM Callback: Navigate to chat - ticket: $ticketId, room: $chatRoomId');

        _hasNavigatedFromFCM = true;

        // Web has no separate chat tab; tickets tab (1) is used for both.
        if (kIsWeb) {
          GoRouter.of(context).go('/tickets');
          setState(() => _currentIndex = 1);
        } else {
          setState(() => _currentIndex = 2);
        }

        Future.delayed(const Duration(seconds: 2), () {
          _hasNavigatedFromFCM = false;
        });
      },
      onNavigateToTicket: (String? ticketId, String? type) {
        if (!mounted || _hasNavigatedFromFCM) return;

        print('🎯 FCM Callback: Navigate to ticket - ticket: $ticketId type: $type');

        _hasNavigatedFromFCM = true;
        _navigateToTicket(ticketId, type: type);

        Future.delayed(const Duration(seconds: 2), () {
          _hasNavigatedFromFCM = false;
        });
      },
    );
  }

  void _printScreenDimensions() {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    print('📱 Screen Width: $width');
    print('📱 Screen Height: $height');
    print('📱 Is Mobile (< 600): ${width < 600}');
    print('📱 Is Tablet (600-1024): ${width >= 600 && width < 1024}');
    print('📱 Is Desktop (>= 1024): ${width >= 1024}');
    print('📱 Is Web: $kIsWeb');

    if (width < 600) {
      print('🎯 Current Breakpoint: MOBILE');
    } else if (width >= 600 && width < 1024) {
      print('🎯 Current Breakpoint: TABLET');
    } else {
      print('🎯 Current Breakpoint: DESKTOP');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResults
          .any((result) => result != ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _hasInternetConnection = hasConnection;
        });
      }

      print(
          '🌐 Initial Connectivity Check: ${hasConnection ? "Connected" : "No Connection"}');
      return hasConnection;
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      return true;
    }
  }

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
          print('✅ MainScreen - Locale loaded: $language');
        }
      }
    } catch (e) {
      print('❌ Error initializing locale: $e');
    }
  }

  Future<void> _setupConnectivityMonitoring() async {
    await _checkConnectivity();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (mounted) {
          final hasConnection =
              results.any((result) => result != ConnectivityResult.none);

          setState(() {
            _hasInternetConnection = hasConnection;
          });

          print(
              '🌐 Internet Connection: ${hasConnection ? "Connected" : "Disconnected"}');

          if (!hasConnection) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Text('No internet connection'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            if (_currentUser != null) {
              _loadNotifications();
              _loadUnreadChatRoomsCount();
            }
          }
        }
      },
    );
  }

  void _setupNavigationItems() {
    final l10n = AppLocalizations.safeOf(context);

    // Mobile navigation items
    _mobileNavItems = [
      NavigationItem(icon: Icons.dashboard, label: l10n.dashboard),
      NavigationItem(icon: Icons.confirmation_number, label: l10n.tickets),
      NavigationItem(icon: Icons.chat, label: l10n.chat),
      NavigationItem(
          icon: Icons.notifications, label: l10n.notifications, hasBadge: true),
      NavigationItem(icon: Icons.report_problem, label: l10n.complaints),
      NavigationItem(icon: Icons.dynamic_form_outlined, label: l10n.customComplaints),
      NavigationItem(icon: Icons.settings, label: l10n.management),
      NavigationItem(icon: Icons.local_shipping_outlined, label: _locale.languageCode == 'ar' ? 'الأسطول' : 'Fleet'),
    ];

    // Web navigation items
    _webNavItems = [
      NavigationItem(icon: Icons.dashboard, label: l10n.dashboard),
      NavigationItem(icon: Icons.confirmation_number, label: l10n.tickets),
      NavigationItem(icon: Icons.chat, label: l10n.chat),
      NavigationItem(icon: Icons.report_problem, label: l10n.complaints),
      NavigationItem(icon: Icons.dynamic_form_outlined, label: l10n.customComplaints),
      NavigationItem(icon: Icons.settings, label: l10n.management),
      NavigationItem(icon: Icons.local_shipping_outlined, label: _locale.languageCode == 'ar' ? 'الأسطول' : 'Fleet'),
    ];

    if (mounted) {
      setState(() {});
      print('✅ Navigation items updated with locale: ${_locale.languageCode}');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore the active tab from the URL on web (survives page refresh).
    // Also parse any sub-route params (formId, ticketId, management tab).
    if (kIsWeb) {
      final path = Uri.base.path;
      _currentIndex = tabIndexFromPath(path);
      DeepLinkState.parseFromPath(path);
    }
    _initializeScreen();
    _setupLocaleChangeListener(); // ✨ NEW

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _printScreenDimensions();
    });
  }

  // ✨ NEW: Listen to locale changes and rebuild navigation
  void _setupLocaleChangeListener() {
    _localeChangeSubscription =
        localeChangeController.stream.listen((newLocale) {
      if (mounted && _locale.languageCode != newLocale.languageCode) {
        print(
            '🔄 MainScreen received locale change: ${newLocale.languageCode}');
        setState(() {
          _locale = newLocale;
        });
        // Nav tab labels and body content both update via the single setState
        // above — labels are computed live in _getWebNavLabel/_getMobileNavLabel,
        // and the body is keyed by locale so it fully recreates.
        // No postFrameCallback needed.
      }
    });
  }

  Future<void> _toggleLanguage() async {
    final newLang = _locale.languageCode == 'ar' ? 'en' : 'ar';
    final newLocale = Locale(newLang);

    // Update the UI immediately — don't wait for the DB round-trip.
    if (kIsWeb) {
      myAppKey.currentState?.changeLanguage(newLocale);
    } else {
      myAppMobileKey.currentState?.changeLanguage(newLocale);
    }

    // Persist to DB in the background so the preference survives re-login.
    if (_currentUser != null) {
      try {
        await supabase
            .from('users')
            .update({'language': newLang}).eq('id', _currentUser!.id);
      } catch (e) {
        debugPrint('❌ Error saving language preference: $e');
      }
    }
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadCurrentUser();

      if (_currentUser != null) {
        await _initializeLocale();
        _setupNavigationItems();

        // Show AI Dashboard onboarding once per version for super/system admins
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AiDashboardOnboarding.showIfNeeded(context, _currentUser!);
          }
        });

        // Load main dashboard preference
        _loadMainDashPreference();

        await Future.wait([
          _setupConnectivityMonitoring(),
          _checkComplaintPermission(),
          _checkFleetAccess(),
          _checkMyVehicles(),
          _loadUnreadChatRoomsCount(),
        ]);

        await _setupNotifications();

        await _setupFCMForUser(_currentUser!);
        _setupFCMHandlers();
        _setupFCMNavigationCallbacks();
        await _checkMandatoryUserFields();
      }
    } catch (e) {
      print('❌ Error during screen initialization: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkMandatoryUserFields() async {
    if (_currentUser == null) return;
    try {
      final missing = await UserFieldService.getMissingBlockingFields(_currentUser!.id);
      if (!mounted) return;
      final wasMissing = _mandatoryFieldsMissing;
      setState(() => _mandatoryFieldsMissing = missing.isNotEmpty);
      if (missing.isNotEmpty && !wasMissing) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;
        setState(() => _currentIndex = isMobile ? 7 : 6);
      }
    } catch (_) {}
  }

  void navigateToNotification() {}

  Future<void> _loadMainDashPreference() async {
    if (_currentUser == null) return;
    try {
      final row = await supabase
          .from('user_main_dashboard')
          .select('mode,saved_dashboard_id,custom_dashboard_id')
          .eq('user_id', _currentUser!.id)
          .maybeSingle();
      if (!mounted) return;
      // New user has no saved preference — show the built-in default immediately.
      if (row == null) {
        setState(() { _mainDashMode = 'default'; _loadingDashPref = false; });
        return;
      }
      final mode     = row['mode'] as String? ?? 'default';
      final savedId  = row['saved_dashboard_id'] as String?;
      final customId = row['custom_dashboard_id'] as String?;

      if (mode == 'saved' && savedId != null) {
        final dash = await supabase
            .from('saved_dashboards').select('result').eq('id', savedId).maybeSingle();
        if (dash != null && mounted) {
          setState(() {
            _mainDashMode = 'saved';
            _mainDashSavedId = savedId;
            _mainDashSavedData = Map<String, dynamic>.from(dash['result'] as Map);
          });
        }
      } else if (mode == 'custom' && customId != null) {
        if (mounted) setState(() { _mainDashMode = 'custom'; _mainDashCustomId = customId; });
      } else if (mounted) {
        setState(() { _mainDashMode = 'default'; });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDashPref = false);
  }

  Future<void> _saveMainDashPreference(String mode, String? savedId, {String? customId}) async {
    if (_currentUser == null) return;
    try {
      await supabase.from('user_main_dashboard').upsert(
        {
          'user_id': _currentUser!.id,
          'mode': mode,
          'saved_dashboard_id': savedId,
          'custom_dashboard_id': customId,
        },
        onConflict: 'user_id',
      );
    } catch (_) {}
  }

  Future<void> _showMainDashCustomizer() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    List<Map<String, dynamic>> saved = [];
    try {
      final res = await supabase
          .from('saved_dashboards')
          .select('id,title')
          .eq('created_by', _currentUser!.id)
          .order('created_at', ascending: false);
      saved = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    // Load custom dashboards
    List<Map<String, dynamic>> custom = [];
    try {
      final res = await supabase
          .from('custom_dashboards')
          .select('id,title')
          .eq('user_id', _currentUser!.id)
          .order('updated_at', ascending: false);
      custom = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Text(isAr ? 'تخصيص لوحة التحكم الرئيسية' : 'Customize Main Dashboard',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            // System default
            _dashOptionTile(
              icon: Icons.dashboard_rounded,
              title: isAr ? 'لوحة النظام الافتراضية' : 'System Default Dashboard',
              subtitle: isAr ? 'لوحة التحكم المدمجة' : 'Built-in dashboard',
              selected: _mainDashMode == 'default',
              onTap: () async {
                Navigator.pop(ctx);
                await _saveMainDashPreference('default', null);
                if (mounted) setState(() { _mainDashMode = 'default'; _mainDashSavedData = null; _mainDashCustomId = null; _dashRefreshKey++; });
              },
            ),
            const SizedBox(height: 12),
            // Create new custom dashboard
            _dashOptionTile(
              icon: Icons.add_chart_rounded,
              title: isAr ? 'إنشاء لوحة مخصصة جديدة' : 'Create New Custom Dashboard',
              subtitle: isAr ? 'أضف مكوّنات ببيانات حية' : 'Add components with live data',
              selected: false,
              onTap: () async {
                Navigator.pop(ctx);
                final newId = await Navigator.push<String>(context, MaterialPageRoute(
                  builder: (_) => CustomDashboardScreen(currentUser: _currentUser!),
                ));
                if (newId != null && mounted) {
                  await _saveMainDashPreference('custom', null, customId: newId);
                  setState(() { _mainDashMode = 'custom'; _mainDashCustomId = newId; _mainDashSavedData = null; });
                }
              },
            ),
            // Existing custom dashboards
            if (custom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(isAr ? 'لوحاتي المخصصة:' : 'My Custom Dashboards:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...custom.map((d) {
                final cid = d['id'] as String;
                final isSelected = _mainDashMode == 'custom' && _mainDashCustomId == cid;
                return _dashOptionTile(
                  icon: Icons.dashboard_customize_rounded,
                  title: d['title'] as String? ?? '',
                  subtitle: isAr ? 'انقر للاستخدام كلوحة رئيسية' : 'Tap to use as main dashboard',
                  selected: isSelected,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _saveMainDashPreference('custom', null, customId: cid);
                    if (mounted) setState(() { _mainDashMode = 'custom'; _mainDashCustomId = cid; _mainDashSavedData = null; _dashRefreshKey++; });
                  },
                  extraTrailing: IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    color: Colors.grey[600],
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: isAr ? 'تعديل' : 'Edit',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (_) => CustomDashboardScreen(currentUser: _currentUser!, dashboardId: cid)),
                      );
                      if (!mounted) return;
                      setState(() {
                        if (result != null) {
                          _mainDashMode = 'custom';
                          _mainDashCustomId = result;
                          _mainDashSavedData = null;
                        }
                        _dashRefreshKey++;
                      });
                      if (result != null) await _saveMainDashPreference('custom', null, customId: result);
                    },
                  ),
                );
              }),
            ],
            // Saved AI dashboards
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(isAr ? 'لوحات الذكاء الاصطناعي المحفوظة:' : 'Saved AI Dashboards:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...saved.map((d) => _dashOptionTile(
                icon: Icons.auto_awesome_rounded,
                title: d['title'] as String? ?? '',
                subtitle: isAr ? 'لوحة مولّدة بالذكاء الاصطناعي' : 'AI-generated dashboard',
                selected: _mainDashMode == 'saved' && _mainDashSavedId == d['id'],
                onTap: () async {
                  Navigator.pop(ctx);
                  final dash = await supabase
                      .from('saved_dashboards').select('result').eq('id', d['id']).maybeSingle();
                  if (dash != null && mounted) {
                    await _saveMainDashPreference('saved', d['id'] as String);
                    setState(() {
                      _mainDashMode = 'saved';
                      _mainDashSavedId = d['id'] as String;
                      _mainDashSavedData = Map<String, dynamic>.from(dash['result'] as Map);
                      _mainDashCustomId = null;
                      _dashRefreshKey++;
                    });
                  }
                },
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashOptionTile({required IconData icon, required String title, String? subtitle, required bool selected, required VoidCallback onTap, Widget? extraTrailing}) {
    final trailingWidgets = <Widget>[
      if (extraTrailing != null) extraTrailing,
      if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFFf16936), size: 20),
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Icon(icon, color: selected ? const Color(0xFFf16936) : Colors.grey),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? const Color(0xFFf16936) : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
      trailing: trailingWidgets.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: trailingWidgets),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: selected ? const Color(0xFFf16936).withValues(alpha: 0.07) : null,
      onTap: onTap,
    );
  }

  Future<void> _checkComplaintPermission() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _hasComplaintPermission = false);
      return;
    }

    if (_currentUser!.userType == UserType.systemAdmin) {
      if (mounted) setState(() => _hasComplaintPermission = true);
      return;
    }

    if (_currentUser!.userType == UserType.superAdmin ||
        _currentUser!.userType == UserType.admin) {
      if (_currentUser!.departmentId == null) {
        if (mounted) setState(() => _hasComplaintPermission = false);
        return;
      }

      try {
        final permission = await supabase
            .from('department_complaint_permissions')
            .select()
            .eq('department_id', _currentUser!.departmentId!)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _hasComplaintPermission =
                permission?['can_access_complaints'] ?? false;
          });
        }
      } catch (e) {
        print('Error checking complaint permission: $e');
        if (mounted) setState(() => _hasComplaintPermission = false);
      }
    } else {
      if (mounted) setState(() => _hasComplaintPermission = false);
    }
  }

  Future<void> _checkFleetAccess() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _hasFleetAccess = false);
      return;
    }
    if (_currentUser!.userType == UserType.systemAdmin) {
      if (mounted) setState(() => _hasFleetAccess = true);
      return;
    }
    if (_currentUser!.userType == UserType.superAdmin) {
      try {
        final hasAccess = await FleetService.superAdminHasFleetAccess(_currentUser!.id);
        if (mounted) setState(() => _hasFleetAccess = hasAccess);
      } catch (e) {
        print('Error checking fleet access: $e');
        if (mounted) setState(() => _hasFleetAccess = false);
      }
    } else {
      if (mounted) setState(() => _hasFleetAccess = false);
    }
  }

  Future<void> _checkMyVehicles() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _hasMyVehicles = false);
      return;
    }
    try {
      final vehicles = await FleetService.getVehiclesForUser(_currentUser!.id);
      if (mounted) setState(() => _hasMyVehicles = vehicles.isNotEmpty);
    } catch (e) {
      print('Error checking driven vehicles: $e');
      if (mounted) setState(() => _hasMyVehicles = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsSubscription?.cancel();
    _notificationCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _localeChangeSubscription?.cancel(); // ✨ NEW: Cancel locale subscription
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUser != null) {
      _loadNotifications();
    }
  }

  // Helper method to get responsive breakpoints
  Map<String, bool> _getResponsiveBreakpoints(double width) {
    return {
      'isMobile': width < 600,
      'isTablet': width >= 600 && width < 1024,
      'isDesktop': width >= 1024,
      'isLargeDesktop': width >= 1440,
    };
  }

  // ✨ UPDATED: Faster user loading
  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
        print('✅ Current user loaded: ${user?.email}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('❌ Error loading user: $e');
      }
    }
  }

  Future<void> _loadUnreadChatRoomsCount() async {
    if (_currentUser == null) return;

    try {
      List<dynamic> chatRoomsResponse = await _getChatRoomsForUser();

      if (chatRoomsResponse.isEmpty) {
        if (mounted) setState(() => _unreadChatRoomsCount = 0);
        return;
      }

      final ticketIds = chatRoomsResponse
          .where((room) => room['tickets'] != null)
          .map((room) => room['tickets']['id'] as String)
          .toList();

      if (ticketIds.isEmpty) {
        if (mounted) setState(() => _unreadChatRoomsCount = 0);
        return;
      }

      final unreadCounts = await ChatService.getUnreadCountsForTickets(
        ticketIds,
        _currentUser!.id,
      );

      int roomsWithUnread = 0;
      for (final count in unreadCounts.values) {
        if (count > 0) roomsWithUnread++;
      }

      if (mounted) {
        setState(() {
          _unreadChatRoomsCount = roomsWithUnread;
          _unreadCounts = unreadCounts;
        });
      }
    } catch (e) {
      print('❌ Error loading unread chat rooms count: $e');
    }
  }

  Future<List<dynamic>> _getChatRoomsForUser() async {
    if (_currentUser == null) return [];

    try {
      if (_currentUser!.userType == UserType.admin) {
        final assignedTickets = await supabase
            .from('chat_rooms')
            .select('''
            id, ticket_id,
            tickets!inner (
              id, ticket_number, title, status, created_by, assigned_to,
              target_department_id, place_id, parent_ticket_id, created_at)
          ''')
            .eq('is_active', true)
            .eq('tickets.assigned_to', _currentUser!.id)
            .inFilter('tickets.status', ['inprogress', 'prefinished']);

        final createdTickets = await supabase
            .from('chat_rooms')
            .select('''
            id, ticket_id,
            tickets!inner (
              id, ticket_number, title, status, created_by, assigned_to,
              target_department_id, place_id, parent_ticket_id, created_at
            )
          ''')
            .eq('is_active', true)
            .eq('tickets.created_by', _currentUser!.id)
            .inFilter('tickets.status', ['inprogress', 'prefinished']);

        final allTickets = <String, dynamic>{};
        for (final ticket in [...assignedTickets, ...createdTickets]) {
          allTickets[ticket['id']] = ticket;
        }
        return allTickets.values.toList();
      } else if (_currentUser!.userType == UserType.superAdmin) {
        if (_currentUser!.departmentId != null) {
          final departmentTickets = await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .eq('tickets.target_department_id', _currentUser!.departmentId!)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);

          final createdTickets = await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .eq('tickets.created_by', _currentUser!.id)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);

          final assignedTickets = await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .eq('tickets.assigned_to', _currentUser!.id)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);

          final allTickets = <String, dynamic>{};
          for (final ticket in [
            ...departmentTickets,
            ...createdTickets,
            ...assignedTickets
          ]) {
            allTickets[ticket['id']] = ticket;
          }
          return allTickets.values.toList();
        } else {
          return await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .eq('tickets.created_by', _currentUser!.id)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);
        }
      } else if (_currentUser!.userType == UserType.superUser) {
        if (_currentUser!.placeId != null) {
          final usersInPlace = await supabase
              .from('users')
              .select('id')
              .eq('place_id', _currentUser!.placeId!)
              .eq('user_type', 'user');

          final userIds = [
            _currentUser!.id,
            ...usersInPlace.map((u) => u['id']).cast<String>()
          ];

          return await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .inFilter('tickets.created_by', userIds)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);
        } else {
          return await supabase
              .from('chat_rooms')
              .select('''
              id, ticket_id,
              tickets!inner (
                id, ticket_number, title, status, created_by, assigned_to,
                target_department_id, place_id, parent_ticket_id, created_at
              )
            ''')
              .eq('is_active', true)
              .eq('tickets.created_by', _currentUser!.id)
              .inFilter('tickets.status', ['inprogress', 'prefinished']);
        }
      } else {
        return await supabase
            .from('chat_rooms')
            .select('''
            id, ticket_id,
            tickets!inner (
              id, ticket_number, title, status, created_by, assigned_to,
              target_department_id, place_id, parent_ticket_id, created_at
            )
          ''')
            .eq('is_active', true)
            .eq('tickets.created_by', _currentUser!.id)
            .inFilter('tickets.status', ['inprogress', 'prefinished']);
      }
    } catch (e) {
      print('❌ Error getting chat rooms: $e');
      return [];
    }
  }

  Future<void> _setupFCMForUser(UserModel user) async {
    try {
      await FCMService.setupForUser(user);
      FCMService.setMessageHandlers(
        onForegroundMessage: _handleForegroundMessage,
        onMessageTap: _handleMessageTap,
      );
    } catch (e) {
      print('Error setting up FCM: $e');
    }
  }

  void _setupFCMHandlers() {
    _setupFCMNavigationCallbacks();
  }

  void _handleForegroundMessage(message) {
    if (mounted) {
      // Suppress notification if the user is already viewing that chat room
      final msgChatRoomId = message.data['chat_room_id'];
      final isInSameRoom = msgChatRoomId != null &&
          msgChatRoomId == activeChatRoomId;
      if (!isInSameRoom) {
        _showInAppNotification(message);
      }
      _loadNotifications();
    }
  }

  void _handleMessageTap(message) {
    final ticketId = message.data['ticket_id'];
    final type = message.data['type'];
    final chatRoomId = message.data['chat_room_id'];
    final sourceTable = message.data['source_table'];
    final recordId = message.data['record_id'];

    if (sourceTable == 'fleet_vehicles' && recordId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FleetVehicleDetailScreen(vehicleId: recordId as String, currentUser: _currentUser!),
      ));
    } else if (type == 'new_message' || type == 'chat_mention') {
      _navigateToChat(ticketId, chatRoomId);
    } else {
      _navigateToTicket(ticketId, type: type);
    }
  }

  void _navigateToChat(String? ticketId, String? chatRoomId) {
    if (ticketId == null) return;
    if (kIsWeb) {
      GoRouter.of(context).go('/tickets');
      setState(() => _currentIndex = 1);
    } else {
      setState(() => _currentIndex = 2);
    }
    TicketNavigationService.navigateTo(ticketId, targetStatus: 'inprogress');
  }

  void _navigateToTicket(String? ticketId, {String? type}) {
    if (ticketId == null) return;
    if (kIsWeb) GoRouter.of(context).go('/tickets');
    setState(() => _currentIndex = 1);
    TicketNavigationService.navigateTo(
      ticketId,
      targetStatus: _targetStatusForType(type),
    );
  }

  /// Maps a notification type to the TicketStatus.value the ticket will be in.
  String? _targetStatusForType(String? type) {
    switch (type) {
      case 'ticket_assigned':
      case 'ticket_rejected':
        return 'inprogress';
      case 'ticket_approved':
      case 'ticket_auto_approved':
        return 'closed';
      case 'ticket_created':
        return 'pending';
      case 'ticket_prefinished':
        return 'prefinished';
      default:
        return null;
    }
  }

  void _showInAppNotification(message) {
    final title = message.notification?.title ?? 'New Notification';
    final body = message.notification?.body ?? '';
    final type = message.data['type'] as String?;

    InAppNotificationBanner.show(
      context: context,
      title: title,
      body: body,
      notificationType: type,
      onTap: () => _handleMessageTap(message),
    );
  }

  Future<void> _setupNotifications() async {
    if (_currentUser == null) return;

    await _loadNotifications();
    _subscribeToNotifications();
    _loadUnreadChatRoomsCount();

    _notificationCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _loadNotifications();
        _loadUnreadChatRoomsCount();
      }
    });
  }

  Future<void> _loadNotifications() async {
    if (_currentUser == null) return;

    try {
      final notifications = await NotificationService.getUserNotifications(
        _currentUser!.id,
        limit: 50,
      );

      final unreadCount = await NotificationService.getUnreadNotificationCount(
        _currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _notifications = notifications;
          var title = '';
          final l10n = AppLocalizations.safeOf(context);
          print(l10n.ticketCreated);
          _notifications.forEach(
            (element) => {
              if (element['type'] == 'ticket_created')
                {element['title'] = l10n.ticketCreated}
              else if (element['type'] == 'ticket_assigned')
                {element['title'] = l10n.ticketCreated}
              else if (element['type'] == 'ticket_status_changed')
                {element['title'] = l10n.ticketStatusChanged}
              else if (element['type'] == 'ticket_approved')
                {element['title'] = l10n.ticketApproved}
              else if (element['type'] == 'ticket_rejected')
                {element['title'] = l10n.ticketRejected}
              else if (element['type'] == 'new_message')
                {element['title'] = l10n.newMessage}
              else if (element['type'] == 'chat_mention')
                {element['title'] = l10n.chatMention}
              else if (element['type'] == 'subticket_created')
                {element['title'] = l10n.subticketCreated}
              else if (element['type'] == 'reminder')
                {} // Reminders already carry a specific title from creation — keep it.
              else
                {
                  {element['title'] = ''}
                }

              //               switch (element['type']) {
              //   case 'ticket_created':
              //     title = l10n.ticketCreated;
              //   case 'ticket_assigned':
              //     title = l10n.ticketAssigned;
              //   case 'ticket_status_changed':
              //     title = l10n.ticketStatusChanged;
              //   case 'ticket_approved':
              //     title = l10n.ticketApproved;
              //   case 'ticket_rejected':
              //     title = l10n.ticketRejected;
              //   case 'new_message':
              //     title = l10n.newMessage;
              //   case 'chat_mention':
              //     title = l10n.chatMention;
              //   case 'subticket_created':
              //     title = l10n.subticketCreated;
              //   default:
              //     title = '';
              // }
            },
          );
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  void _subscribeToNotifications() {
    if (_currentUser == null) return;

    _notificationsSubscription = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUser!.id)
        .listen((data) {
          if (mounted) {
            final sorted = List<Map<String, dynamic>>.from(data)
              ..sort((a, b) =>
                (b['created_at'] as String? ?? '')
                    .compareTo(a['created_at'] as String? ?? ''));
            final newUnread = sorted.where((n) => !n['is_read']).length;
            // Play a gentle bell when a new unread notification arrives.
            if (newUnread > _unreadCount) {
              SoundService.playNotification();
            }
            setState(() {
              _notifications = sorted;
              _unreadCount = newUnread;
            });
          }
        });

    supabase.from('chat_messages').stream(primaryKey: ['id']).listen((data) {
      if (mounted) {
        _loadUnreadChatRoomsCount();
      }
    });
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    if (_currentUser == null) return;

    try {
      await NotificationService.markAllNotificationsAsRead(_currentUser!.id);
      _loadNotifications();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  void _toggleNotificationsDropdown() {
    setState(() {
      _isNotificationsOpen = !_isNotificationsOpen;
    });
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'];
    final ticketId = notification['ticket_id'];
    final chatRoomId = notification['chat_room_id'];

    setState(() {
      _isNotificationsOpen = false;
    });

    if (!notification['is_read']) {
      _markNotificationAsRead(notification['id']);
    }

    Map<String, dynamic>? actionData;
    final rawActionData = notification['action_data'];
    if (rawActionData is String && rawActionData.isNotEmpty) {
      try {
        actionData = json.decode(rawActionData) as Map<String, dynamic>;
      } catch (_) {}
    } else if (rawActionData is Map) {
      actionData = Map<String, dynamic>.from(rawActionData);
    }

    if (actionData != null && actionData['source_table'] == 'fleet_vehicles' && actionData['record_id'] != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FleetVehicleDetailScreen(vehicleId: actionData!['record_id'] as String, currentUser: _currentUser!),
      ));
    } else if (type == 'new_message' || type == 'chat_mention') {
      _navigateToChat(ticketId, chatRoomId);
    } else if (ticketId != null) {
      _navigateToTicket(ticketId, type: type);
    }
  }

  /// Underline-style nav tab bar (no ripple, orange indicator like tickets TabBar).
  Widget _buildWebNavTabWidget() {
    if (_webNavItems.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _webNavItems.asMap().entries.where((entry) {
          if (entry.value.icon == Icons.report_problem &&
              !_hasComplaintPermission) return false;
          if (entry.value.icon == Icons.local_shipping_outlined &&
              !_hasFleetAccess && !_hasMyVehicles) return false;
          return true;
        }).map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = _currentIndex == index;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                GoRouter.of(context).go(pathFromTabIndex(index));
                setState(() => _currentIndex = index);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: _locale.languageCode == 'ar' ? 3 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.icon,
                            size: 15,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[600],
                          ),
                          if (item.icon == Icons.chat &&
                              _unreadChatRoomsCount > 0)
                            Positioned(
                              right: -7,
                              top: -7,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 15, minHeight: 15),
                                child: Text(
                                  _unreadChatRoomsCount > 99
                                      ? '99+'
                                      : _unreadChatRoomsCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _getWebNavLabel(index),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey[700],
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Returns the navigation label for the given web-nav index directly from
  /// the current locale, so it always reflects the active language without
  /// relying on the pre-built [_webNavItems] strings.
  String _getWebNavLabel(int index) {
    final l10n = AppLocalizations.safeOf(context);
    switch (index) {
      case 0: return l10n.dashboard;
      case 1: return l10n.tickets;
      case 2: return l10n.chat;
      case 3: return l10n.complaints;
      case 4: return l10n.customComplaints;
      case 5: return l10n.management;
      case 6: return Localizations.localeOf(context).languageCode == 'ar' ? 'الأسطول' : 'Fleet';
      default: return '';
    }
  }

  /// Returns the navigation label for the given mobile-nav actual index.
  String _getMobileNavLabel(int index) {
    final l10n = AppLocalizations.safeOf(context);
    switch (index) {
      case 0: return l10n.dashboard;
      case 1: return l10n.tickets;
      case 2: return l10n.chat;
      case 3: return l10n.notifications;
      case 4: return l10n.complaints;
      case 5: return l10n.customComplaints;
      case 6: return l10n.management;
      case 7: return Localizations.localeOf(context).languageCode == 'ar' ? 'الأسطول' : 'Fleet';
      default: return '';
    }
  }

  Widget _buildMandatoryFieldsLockScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_late_rounded, size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Profile Incomplete',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile has required fields that must be filled before you can use the system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Complete My Profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _navigateToProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_currentUser == null) return Container();

    void navigateToTickets(String? status) {
      if (kIsWeb) GoRouter.of(context).go('/tickets');
      setState(() {
        _currentIndex = 1;
        _initialTicketStatus = status;
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (_mandatoryFieldsMissing) {
      return _buildMandatoryFieldsLockScreen();
    }

    if (isMobile) {
      switch (_currentIndex) {
        case 0:
          return _buildDashboardTab(isMobile, navigateToTickets);
        case 1:
          final status = _initialTicketStatus;
          _initialTicketStatus = null;
          return TicketsScreen(currentUser: _currentUser!, initialStatus: status);
        case 2:
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUnreadChatRoomsCount();
          });
          return ChatScreen(currentUser: _currentUser!);
        case 3:
          return NotificationsScreen(
            notifications: _notifications,
            onMarkAsRead: _markNotificationAsRead,
            onMarkAllAsRead: _markAllNotificationsAsRead,
            onNotificationTap: _handleNotificationTap,
            onClose: () => setState(() => _currentIndex = 0),
          );
        case 4:
          if (_hasComplaintPermission) {
            return ComplaintsScreen(currentUser: _currentUser!);
          } else {
            return _buildNoAccessScreen();
          }
        case 5:
          return CcHomeScreen(currentUser: _currentUser!);
        case 6:
          return ManagementScreen(currentUser: _currentUser!);
        case 7:
          return _hasFleetAccess
              ? FleetManagementScreen(currentUser: _currentUser!)
              : MyVehiclesScreen(currentUser: _currentUser!);
        default:
          return _buildDashboardTab(isMobile, navigateToTickets);
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return _buildDashboardTab(isMobile, navigateToTickets);
        case 1:
          final status = _initialTicketStatus;
          _initialTicketStatus = null;
          // Also consume any deep-link ticket ID (from /tickets/:ticketId refresh).
          final deepTicketId = DeepLinkState.consumeTicketId();
          return TicketsScreen(
            currentUser: _currentUser!,
            initialStatus: status,
            initialTicketId: deepTicketId,
          );
        case 2:
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUnreadChatRoomsCount();
          });
          return ChatScreen(currentUser: _currentUser!);
        case 3:
          if (_hasComplaintPermission) {
            return ComplaintsScreen(currentUser: _currentUser!);
          } else {
            return _buildNoAccessScreen();
          }
        case 4:
          return CcHomeScreen(currentUser: _currentUser!);
        case 5:
          return ManagementScreen(
            currentUser: _currentUser!,
            initialTab: DeepLinkState.consumeManagementTab(),
          );
        case 6:
          return _hasFleetAccess
              ? FleetManagementScreen(currentUser: _currentUser!)
              : MyVehiclesScreen(currentUser: _currentUser!);
        default:
          return _buildDashboardTab(isMobile, navigateToTickets);
      }
    }
  }

  Widget _buildDashboardTab(bool isMobile, void Function(String?) onNavigate) {
    if (_loadingDashPref) {
      return const Center(child: CircularProgressIndicator());
    }
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    Widget dash;
    if (_mainDashMode == 'saved' && _mainDashSavedData != null) {
      dash = SingleChildScrollView(
        key: ValueKey('saved_${_mainDashSavedId}_$_dashRefreshKey'),
        padding: const EdgeInsets.all(16),
        child: AiDashboardView(data: _mainDashSavedData!, showTitle: true, readOnly: true),
      );
    } else if (_mainDashMode == 'custom' && _mainDashCustomId != null) {
      dash = CustomDashboardScreen(
        key: ValueKey('custom_${_mainDashCustomId}_$_dashRefreshKey'),
        currentUser: _currentUser!,
        dashboardId: _mainDashCustomId,
        readOnly: true,
      );
    } else {
      dash = DashboardWeb(currentUser: _currentUser!, onNavigateToTickets: onNavigate);
    }

    return Stack(
      children: [
        dash,
        Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'dashCustomize',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFf16936),
            tooltip: isAr ? 'تخصيص لوحة التحكم' : 'Customize Dashboard',
            elevation: 3,
            onPressed: _showMainDashCustomizer,
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildNoAccessScreen() {
    final l10n = AppLocalizations.safeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noAccessToComplaints,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '${l10n.departmentNoPermission}\n\n${l10n.contactSystemAdmin}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.loading,
                style: TextStyle(color: AppColors.onBackground),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return const AuthWrapper();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 768;
    final isMobile = screenWidth < 768;
    final isWidthNotGood = screenWidth > 1440;

    // ✨ NEW: Check if bottom navigation bar exists
    final hasBottomNavBar = !kIsWeb;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(
          hasBottomNavBar: hasBottomNavBar), // ✨ CHANGED: Pass flag
      body: Stack(
        children: [
          // KeyedSubtree forces a full widget recreation when the locale
          // changes, so every screen (profile, tickets, etc.) rebuilds fresh
          // with the new language strings immediately.
          KeyedSubtree(
            key: ValueKey(_locale.languageCode),
            child: _buildCurrentScreen(),
          ),
          // Transparent barrier — closes dropdown when tapping outside (desktop/tablet)
          if (_isNotificationsOpen && !isMobile)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isNotificationsOpen = false),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          if (_isNotificationsOpen && !isMobile) _buildNotificationsDropdown(),
          if (_isNotificationsOpen && !isLargeScreen)
            NotificationsScreen(
              notifications: _notifications,
              onMarkAsRead: _markNotificationAsRead,
              onMarkAllAsRead: _markAllNotificationsAsRead,
              onNotificationTap: _handleNotificationTap,
              onClose: () => setState(() => _isNotificationsOpen = false),
            )
        ],
      ),
      // ✨ Floating bottom navigation bar for mobile
      bottomNavigationBar:
          hasBottomNavBar ? _buildFloatingBottomNavBar() : null,
      drawer: kIsWeb && !isWidthNotGood ? _buildWebDrawer() : null,
      extendBody: true, // Allow body to extend behind bottom nav
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(
        currentUser: _currentUser!,
        onProfileImageUpdated: _handleProfileImageUpdate,
        onFieldsUpdated: _checkMandatoryUserFields,
      ),
    ));
  }

  Widget _buildLogoLeading({required bool isMobile, required AppLocalizations l10n}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          GoRouter.of(context).go('/dashboard');
          setState(() => _currentIndex = 0);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10),
          child: Row(
            children: [
              Container(
                width: isMobile ? 30 : 34,
                height: isMobile ? 30 : 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.support_agent,
                    color: AppColors.primary,
                    size: isMobile ? 16 : 20,
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Jala Ticketing',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.secondary,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool hasBottomNavBar}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 768;
    final isWidthNotGood = screenWidth > 1440;
    final isMobile = screenWidth < 600;
    final l10n = AppLocalizations.safeOf(context);
    final showNavTabs = kIsWeb && isWidthNotGood && !isMobile;

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      // When showing nav tabs: logo+name in leading, tabs in title.
      // When showing drawer (narrow web): leading = auto hamburger, title = logo+name.
      leadingWidth: showNavTabs ? (isMobile ? 56 : 190) : null,
      leading: showNavTabs
          ? _buildLogoLeading(isMobile: isMobile, l10n: l10n)
          : null,
      title: showNavTabs
          ? _buildWebNavTabWidget()
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  GoRouter.of(context).go('/dashboard');
                  setState(() => _currentIndex = 0);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 30 : 34,
                      height: isMobile ? 30 : 34,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.support_agent,
                          color: AppColors.primary,
                          size: isMobile ? 16 : 20,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                    Text(
                      'Jala Ticketing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 15 : 18,
                        color: AppColors.secondary,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
      centerTitle: false,
      actions: _buildResponsiveActions(
        isMobile: isMobile,
        isLargeScreen: isLargeScreen,
        hasBottomNavBar: hasBottomNavBar,
      ),
    );
  }

// Replace the _buildResponsiveActions method in _MainScreenState:

  List<Widget> _buildResponsiveActions({
    required bool isMobile,
    required bool isLargeScreen,
    required bool hasBottomNavBar,
  }) {
    List<Widget> actions = [];
    final l10n = AppLocalizations.safeOf(context);

    if (isMobile) {
      // ✅ OPTIMIZED: Mobile - Only logout button when bottom nav exists
      // (notifications are in bottom nav bar)
      if (kIsWeb)
        actions.add(
          Container(
            key: _notificationButtonKey,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _isNotificationsOpen
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isNotificationsOpen
                    ? AppColors.primary
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: _toggleNotificationsDropdown,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Notifications',
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      // Language toggle (mobile)
      actions.add(_buildLanguageToggle(compact: true));
      actions.add(
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppColors.secondary,
              size: 20,
            ),
            onPressed: () async {
              await AuthService.signOut();
            },
            tooltip: l10n.logout,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
      );
    } else {
      // Desktop: Full actions with clickable profile
      actions.addAll([
        // ✨ Clickable Profile Image
        GestureDetector(
          onTap: _navigateToProfile,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: _currentUser?.profileImageUrl != null &&
                        _currentUser!.profileImageUrl!.isNotEmpty
                    ? NetworkImage(_currentUser!.profileImageUrl!)
                    : null,
                child: _currentUser?.profileImageUrl == null ||
                        _currentUser!.profileImageUrl!.isEmpty
                    ? Text(
                        _currentUser?.fullName.substring(0, 1).toUpperCase() ??
                            '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        // Clickable Profile Name — constrained so it never crowds the action bar
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: GestureDetector(
            onTap: _navigateToProfile,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _currentUser?.fullName ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Notifications Button
        if (kIsWeb)
          Container(
            key: _notificationButtonKey,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _isNotificationsOpen
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isNotificationsOpen
                    ? AppColors.primary
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: _toggleNotificationsDropdown,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: l10n.notifications,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Language toggle (desktop)
        _buildLanguageToggle(compact: false),
        // Logout Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppColors.secondary,
            ),
            onPressed: () async {
              await AuthService.signOut();
            },
            tooltip: l10n.logout,
          ),
        ),
      ]);
    }

    actions.add(const SizedBox(width: 8));
    return actions;
  }

  Widget _buildLanguageToggle({required bool compact}) {
    final isAr = _locale.languageCode == 'ar';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: Tooltip(
        message: isAr ? 'Switch to English' : 'التبديل إلى العربية',
        child: GestureDetector(
          onTap: _toggleLanguage,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AR',
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                      color: isAr
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '|',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Text(
                    'EN',
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                      color: !isAr
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsDropdown() {
    final RenderBox? buttonBox =
        _notificationButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return const SizedBox.shrink();

    final buttonPosition = buttonBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final l10n = AppLocalizations.safeOf(context);
    print(_locale.languageCode);

    if (_locale.languageCode == 'en') {
      return Positioned(
        top: buttonPosition.dy + buttonBox.size.height + 8,
        right: screenSize.width - buttonPosition.dx - buttonBox.size.width,
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.transparent,
          child: Container(
            width: 400,
            height: 520,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.notifications,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        TextButton.icon(
                          onPressed: _markAllNotificationsAsRead,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: Text(
                            l10n.markAllRead,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _isNotificationsOpen = false),
                          padding: const EdgeInsets.all(6),
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none_outlined,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noNotifications,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.onBackground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.youllSeeUpdatesHere,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final l10n = AppLocalizations.safeOf(context);
                            var title = '';
                            print(_notifications[index]['type'].toString());
                            switch (_notifications[index]['type']) {
                              case 'ticket_created':
                                title = l10n.ticketCreated;
                              case 'ticket_assigned':
                                title = l10n.ticketAssigned;
                              case 'ticket_status_changed':
                                title = l10n.ticketStatusChanged;
                              case 'ticket_approved':
                                title = l10n.ticketApproved;
                              case 'ticket_rejected':
                                title = l10n.ticketRejected;
                              case 'new_message':
                                title = l10n.newMessage;
                              case 'chat_mention':
                                title = l10n.chatMention;
                              case 'subticket_created':
                                title = l10n.subticketCreated;
                              case 'reminder':
                                // Reminders carry a specific title from creation — keep it.
                                title = (_notifications[index]['title'] as String?) ?? '';
                              default:
                                title = '';
                            }
                            _notifications[index]['title'] = title;
                            final notification = _notifications[index];
                            return NotificationDropdownTile(
                              notification: notification,
                              onTap: () => _handleNotificationTap(notification),
                              onMarkAsRead: () =>
                                  _markNotificationAsRead(notification['id']),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Positioned(
        top: buttonPosition.dy + buttonBox.size.height + 8,
        left: buttonPosition.dx,
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.transparent,
          child: Container(
            width: 400,
            height: 520,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.notifications,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        TextButton.icon(
                          onPressed: _markAllNotificationsAsRead,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: Text(
                            l10n.markAllRead,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _isNotificationsOpen = false),
                          padding: const EdgeInsets.all(6),
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none_outlined,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noNotifications,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.onBackground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.youllSeeUpdatesHere,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return NotificationDropdownTile(
                              notification: notification,
                              onTap: () => _handleNotificationTap(notification),
                              onMarkAsRead: () =>
                                  _markNotificationAsRead(notification['id']),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ✨ UPDATED: Floating bottom navigation bar with chat badge
  Widget _buildFloatingBottomNavBar() {
    if (kIsWeb) return const SizedBox.shrink();

    // Show only the 4 primary tabs + a "More" drawer button
    // Indices: 0=Dashboard, 1=Tickets, 2=Chat, 3=Notifications
    final primaryIndices = [0, 1, 2, 3];
    final isAr = _locale.languageCode == 'ar';
    final moreLabel = isAr ? 'المزيد' : 'More';
    final moreActive = !primaryIndices.contains(_currentIndex);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          ...primaryIndices.map((idx) {
            final item = _mobileNavItems[idx];
            final isSelected = _currentIndex == idx;
            int? badge;
            if (idx == 2) badge = _unreadChatRoomsCount > 0 ? _unreadChatRoomsCount : null;
            if (idx == 3) badge = _unreadCount > 0 ? _unreadCount : null;
            return _buildBottomNavItem(
              icon: item.icon,
              label: _getMobileNavLabel(idx),
              isSelected: isSelected,
              badgeCount: badge,
              onTap: () => setState(() { _currentIndex = idx; _isNotificationsOpen = false; }),
            );
          }),
          // "More" button opens drawer
          Expanded(
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: moreActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view_rounded,
                          color: moreActive ? AppColors.primary : Colors.grey[600], size: 24),
                      const SizedBox(height: 4),
                      Text(
                        moreLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: moreActive ? FontWeight.bold : FontWeight.w500,
                          color: moreActive ? AppColors.primary : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: isSelected ? AppColors.primary : Colors.grey[600], size: 24),
                  if (badgeCount != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleProfileImageUpdate() async {
    // Reload current user to get updated profile image
    if (_currentUser != null) {
      try {
        final updatedUser = await AuthService.getCurrentUser();
        if (mounted && updatedUser != null) {
          setState(() {
            _currentUser = updatedUser;
          });
        }
      } catch (e) {
        print('Error reloading user after profile image update: $e');
      }
    }
  }

  int _getCurrentVisibleIndex(Map<int, int> indexMapping) {
    for (final entry in indexMapping.entries) {
      if (entry.value == _currentIndex) {
        return entry.key;
      }
    }
    return 0;
  }

  bool _canAccessManagement() {
    if (_currentUser == null) return false;

    return _currentUser!.userType == UserType.systemAdmin ||
        _currentUser!.userType == UserType.superAdmin ||
        _currentUser!.userType == UserType.superUser ||
        _currentUser!.userType == UserType.admin;
  }

  int _getCurrentFilteredIndex(Map<int, int> indexMapping) {
    for (final entry in indexMapping.entries) {
      if (entry.value == _currentIndex) {
        return entry.key;
      }
    }
    return 0;
  }

  Widget _buildWebDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 768;
    final isMobile = screenWidth < 768;
    final l10n = AppLocalizations.safeOf(context);
    final isWidthNotGood = screenWidth > 1440;

    if (isWidthNotGood) {
      return const SizedBox.shrink();
    }
    final isTablet = MediaQuery.of(context).size.width < 992;
    final drawerNavItems = !isWidthNotGood
        ? isMobile
            ? _mobileNavItems
            : _webNavItems
        : _webNavItems;

    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ✨ Clickable Drawer Header
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close drawer
              _navigateToProfile(); // Navigate to profile
            },
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 28,
                            width: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.support_agent,
                                color: AppColors.primary,
                                size: 24,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jala Ticketing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              _locale.languageCode == 'ar'
                                  ? 'دعم ذكي · نتائج حقيقية'
                                  : 'Smart Support · Real Results',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // ✨ Profile image with border
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: _currentUser?.profileImageUrl !=
                                        null &&
                                    _currentUser!.profileImageUrl!.isNotEmpty
                                ? NetworkImage(_currentUser!.profileImageUrl!)
                                : null,
                            child: _currentUser?.profileImageUrl == null ||
                                    _currentUser!.profileImageUrl!.isEmpty
                                ? Text(
                                    _currentUser?.fullName
                                            .substring(0, 1)
                                            .toUpperCase() ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _currentUser?.fullName ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 14,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentUser?.email ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  l10n.viewProfile,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...drawerNavItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;

            if (item.label == 'Complaints' && !_hasComplaintPermission) {
              return const SizedBox.shrink();
            }

            if (item.icon == Icons.local_shipping_outlined && !_hasFleetAccess && !_hasMyVehicles) {
              return const SizedBox.shrink();
            }

            if (!isWidthNotGood && item.label == 'Notifications') {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.onBackground,
                      size: 22,
                    ),
                    if (item.label == 'Chat' && _unreadChatRoomsCount > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _unreadChatRoomsCount > 99
                                ? '99+'
                                : _unreadChatRoomsCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onBackground,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onTap: () {
                  setState(() => _currentIndex = index);
                  Navigator.pop(context);
                },
              ),
            );
          }),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.secondary,
                size: 22,
              ),
              title: Text(
                l10n.logout,
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final bool hasBadge;

  NavigationItem({
    required this.icon,
    required this.label,
    this.hasBadge = false,
  });
}

class NotificationDropdownTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onMarkAsRead;

  const NotificationDropdownTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMarkAsRead,
  });

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'inprogress':
        return Icons.autorenew;
      case 'prefinished':
        return Icons.hourglass_top;
      case 'closed':
        return Icons.task_alt;
      case 'wrong_info':
      case 'wrongInfo':
        return Icons.report_problem_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.update_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
        return Colors.blue;
      case 'prefinished':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      case 'wrong_info':
      case 'wrongInfo':
        return Colors.red;
      case 'deleted':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String type, {String? newStatus}) {
    if (type == 'ticket_status_changed' && newStatus != null) {
      return _getStatusIcon(newStatus);
    }
    switch (type) {
      case 'ticket_created':
        return Icons.confirmation_number_outlined;
      case 'ticket_assigned':
        return Icons.assignment_ind_outlined;
      case 'ticket_status_changed':
        return Icons.update_outlined;
      case 'ticket_approved':
        return Icons.check_circle_outline;
      case 'ticket_rejected':
        return Icons.cancel_outlined;
      case 'new_message':
        return Icons.message_outlined;
      case 'chat_mention':
        return Icons.alternate_email;
      case 'subticket_created':
        return Icons.account_tree_outlined;
      case 'reminder':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type, {String? newStatus}) {
    if (type == 'ticket_status_changed' && newStatus != null) {
      return _getStatusColor(newStatus);
    }
    switch (type) {
      case 'ticket_created':
        return AppColors.secondary;
      case 'ticket_assigned':
        return Colors.green;
      case 'ticket_status_changed':
        return AppColors.primary;
      case 'ticket_approved':
        return Colors.green;
      case 'ticket_rejected':
        return Colors.red;
      case 'new_message':
        return AppColors.primary;
      case 'chat_mention':
        return AppColors.secondary;
      case 'subticket_created':
        return Colors.teal;
      case 'reminder':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _formatNotificationTime(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM dd').format(dateTime);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'] ?? '';

    String? newStatus;
    final actionDataRaw = notification['action_data'];
    if (actionDataRaw != null) {
      try {
        final actionData = json.decode(actionDataRaw as String);
        newStatus = actionData['new_status'] as String?;
      } catch (_) {}
    }

    final notificationColor = _getNotificationColor(type, newStatus: newStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? Colors.grey.withOpacity(0.12)
              : AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
        // ✨ IMPROVED: Uniform shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: notificationColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: notificationColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notificationColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getNotificationIcon(type, newStatus: newStatus),
                    color: notificationColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 11,
                                color: AppColors.onBackground,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatNotificationTime(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (!isRead) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 3,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onMarkAsRead,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.done,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 14),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
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

class NotificationsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(String) onMarkAsRead;
  final VoidCallback onMarkAllAsRead;
  final Function(Map<String, dynamic>) onNotificationTap;
  final VoidCallback onClose;

  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
    required this.onNotificationTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n['is_read']).length;
    final l10n = AppLocalizations.safeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.notifications,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: onClose,
          color: AppColors.onBackground,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
        actions: [
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton.icon(
                onPressed: onMarkAllAsRead,
                icon: const Icon(
                  Icons.done_all,
                  color: AppColors.primary,
                  size: 18,
                ),
                label: Text(
                  l10n.markAllAsRead,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationTile(
                  notification: notification,
                  onTap: () => onNotificationTap(notification),
                  onMarkAsRead: () => onMarkAsRead(notification['id']),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noNotifications,
            style: const TextStyle(
              fontSize: 20,
              color: AppColors.onBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.youllSeeUpdatesHere,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onMarkAsRead;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMarkAsRead,
  });

  IconData _getNotificationIcon(String type, {String? newStatus}) {
    if (type == 'ticket_status_changed' && newStatus != null) {
      return _getStatusIcon(newStatus);
    }
    switch (type) {
      case 'ticket_created':
        return Icons.confirmation_number_outlined;
      case 'ticket_assigned':
        return Icons.assignment_ind_outlined;
      case 'ticket_status_changed':
        return Icons.update_outlined;
      case 'ticket_approved':
        return Icons.check_circle_outline;
      case 'ticket_rejected':
        return Icons.cancel_outlined;
      case 'new_message':
        return Icons.message_outlined;
      case 'chat_mention':
        return Icons.alternate_email;
      case 'subticket_created':
        return Icons.account_tree_outlined;
      case 'reminder':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'inprogress':
        return Icons.autorenew;
      case 'prefinished':
        return Icons.hourglass_top;
      case 'closed':
        return Icons.task_alt;
      case 'wrong_info':
      case 'wrongInfo':
        return Icons.report_problem_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.update_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
        return Colors.blue;
      case 'prefinished':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      case 'wrong_info':
      case 'wrongInfo':
        return Colors.red;
      case 'deleted':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  Color _getNotificationColor(String type, {String? newStatus}) {
    if (type == 'ticket_status_changed' && newStatus != null) {
      return _getStatusColor(newStatus);
    }
    switch (type) {
      case 'ticket_created':
        return AppColors.secondary;
      case 'ticket_assigned':
        return Colors.green;
      case 'ticket_status_changed':
        return AppColors.primary;
      case 'ticket_approved':
        return Colors.green;
      case 'ticket_rejected':
        return Colors.red;
      case 'new_message':
        return AppColors.primary;
      case 'chat_mention':
        return AppColors.secondary;
      case 'subticket_created':
        return Colors.teal;
      case 'reminder':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _formatNotificationTime(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM dd').format(dateTime);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'] ?? '';

    String? newStatus;
    final actionDataRaw = notification['action_data'];
    if (actionDataRaw != null) {
      try {
        final actionData = json.decode(actionDataRaw as String);
        newStatus = actionData['new_status'] as String?;
      } catch (_) {}
    }

    final notificationColor = _getNotificationColor(type, newStatus: newStatus);

    return Container(
      decoration: BoxDecoration(
        color: isRead ? Colors.white : AppColors.primary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? Colors.grey.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
        // ✨ IMPROVED: Uniform shadow on all sides
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 0), // ✨ CHANGED: Centered shadow
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: notificationColor.withOpacity(0.1),
          highlightColor: notificationColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✨ IMPROVED: Better icon container design
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notificationColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: notificationColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getNotificationIcon(type, newStatus: newStatus),
                    color: notificationColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message as title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.onBackground,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Time badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatNotificationTime(createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Action buttons
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!isRead) ...[
                      // Unread indicator
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Mark as read button
                      GestureDetector(
                        onTap: onMarkAsRead,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.done,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      // Chevron for read notifications
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
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
