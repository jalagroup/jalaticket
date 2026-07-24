import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jalasupport/auth.dart';
import 'package:jalasupport/custom_complaints/cc_external_screen.dart';

// ── Tab path mapping (web: indices 0-6) ───────────────────────────────────────

const List<String> kWebTabPaths = [
  '/dashboard',         // 0
  '/tickets',           // 1
  '/chat',              // 2
  '/complaints',        // 3
  '/custom-complaints', // 4
  '/management',        // 5
  '/fleet',             // 6
];

/// Returns the tab index (0-6) for the given path, or 0 if not found.
int tabIndexFromPath(String path) {
  final exact = kWebTabPaths.indexOf(path);
  if (exact >= 0) return exact;
  for (int i = 0; i < kWebTabPaths.length; i++) {
    if (path.startsWith('${kWebTabPaths[i]}/')) return i;
  }
  return 0;
}

/// Returns the URL path for the given tab index.
String pathFromTabIndex(int index) {
  if (index >= 0 && index < kWebTabPaths.length) return kWebTabPaths[index];
  return '/dashboard';
}

// ── Deep-link state ───────────────────────────────────────────────────────────

/// Holds sub-route parameters parsed from the initial URL when the app starts.
/// Fields are consumed (nulled) by the first widget that reads them.
class DeepLinkState {
  static String? ccFormId;
  static String? ccAction;    // 'edit' | 'records' | 'submit' | 'design'
  static String? ticketId;
  static String? managementTab;

  /// Parse [path] and populate the static fields. Called once from initState.
  static void parseFromPath(String path) {
    ccFormId = null;
    ccAction = null;
    ticketId = null;
    managementTab = null;

    final ccFormRe = RegExp(r'^/custom-complaints/form/([^/]+)/([^/]+)$');
    final ccFormMatch = ccFormRe.firstMatch(path);
    if (ccFormMatch != null) {
      ccFormId = ccFormMatch.group(1);
      ccAction = ccFormMatch.group(2);
      return;
    }

    if (path == '/custom-complaints/records') {
      ccAction = 'records';
      return;
    }

    final ticketRe = RegExp(r'^/tickets/([^/]+)$');
    final ticketMatch = ticketRe.firstMatch(path);
    if (ticketMatch != null) {
      ticketId = ticketMatch.group(1);
      return;
    }

    final mgmtRe = RegExp(r'^/management/([^/]+)$');
    final mgmtMatch = mgmtRe.firstMatch(path);
    if (mgmtMatch != null) {
      managementTab = mgmtMatch.group(1);
      return;
    }
  }

  static String? consumeCcFormId() {
    final v = ccFormId; ccFormId = null; return v;
  }

  static String? consumeCcAction() {
    final v = ccAction; ccAction = null; return v;
  }

  static String? consumeTicketId() {
    final v = ticketId; ticketId = null; return v;
  }

  static String? consumeManagementTab() {
    final v = managementTab; managementTab = null; return v;
  }
}

// ── Auth-state notifier ───────────────────────────────────────────────────────

class _AuthChangeNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  _AuthChangeNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthChangeNotifier();

// ── Shared page builder helper ────────────────────────────────────────────────

/// All authenticated tab-level routes share this page so _MainScreenState
/// is never recreated when navigating between tabs.
MaterialPage<void> _mainPage(BuildContext ctx, GoRouterState state) =>
    const MaterialPage<void>(key: ValueKey('main_screen'), child: AuthWrapper());

// ── Auth helpers ──────────────────────────────────────────────────────────────

bool _isUnauthenticatedRoute(String location) {
  return location == '/login' ||
      location == '/register' ||
      location == '/forgot-password' ||
      location.startsWith('/c/submit/');
}

// ── Router ────────────────────────────────────────────────────────────────────

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  refreshListenable: _authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final location = state.uri.path;

    if (location.startsWith('/c/submit/')) return null;

    if (!isLoggedIn && !_isUnauthenticatedRoute(location)) return '/login';

    if (isLoggedIn &&
        (location == '/login' ||
            location == '/register' ||
            location == '/forgot-password')) {
      return '/dashboard';
    }

    if (location == '/') return isLoggedIn ? '/dashboard' : '/login';

    return null;
  },
  routes: [
    // ── Auth screens ──────────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

    // ── Public external complaint form ────────────────────────────────────────
    GoRoute(
      path: '/c/submit/:formId',
      builder: (_, s) => CcExternalScreen(formId: s.pathParameters['formId']!),
    ),

    // ── Dashboard ─────────────────────────────────────────────────────────────
    GoRoute(path: '/dashboard', pageBuilder: _mainPage),

    // ── Tickets + deep-link sub-route ─────────────────────────────────────────
    // NOTE: sub-routes are nested so go_router's prefix-matching finds them.
    // The child route stores params in DeepLinkState then redirects to the
    // parent tab URL so _MainScreenState stays alive and initState-based
    // deep-linking kicks in on the next frame.
    GoRoute(
      path: '/tickets',
      pageBuilder: _mainPage,
      routes: [
        GoRoute(
          path: ':ticketId',
          redirect: (_, s) {
            DeepLinkState.ticketId = s.pathParameters['ticketId'];
            return '/tickets';
          },
        ),
      ],
    ),

    // ── Chat ──────────────────────────────────────────────────────────────────
    GoRoute(path: '/chat', pageBuilder: _mainPage),

    // ── Complaints ────────────────────────────────────────────────────────────
    GoRoute(path: '/complaints', pageBuilder: _mainPage),

    // ── Custom Complaints + deep-link sub-routes ──────────────────────────────
    GoRoute(
      path: '/custom-complaints',
      pageBuilder: _mainPage,
      routes: [
        GoRoute(
          path: 'records',
          redirect: (_, __) {
            DeepLinkState.ccAction = 'records';
            return '/custom-complaints';
          },
        ),
        GoRoute(
          path: 'form/:formId/edit',
          redirect: (_, s) {
            DeepLinkState.ccFormId = s.pathParameters['formId'];
            DeepLinkState.ccAction = 'edit';
            return '/custom-complaints';
          },
        ),
        GoRoute(
          path: 'form/:formId/design',
          redirect: (_, s) {
            DeepLinkState.ccFormId = s.pathParameters['formId'];
            DeepLinkState.ccAction = 'design';
            return '/custom-complaints';
          },
        ),
        GoRoute(
          path: 'form/:formId/submit',
          redirect: (_, s) {
            DeepLinkState.ccFormId = s.pathParameters['formId'];
            DeepLinkState.ccAction = 'submit';
            return '/custom-complaints';
          },
        ),
        GoRoute(
          path: 'form/:formId/records',
          redirect: (_, s) {
            DeepLinkState.ccFormId = s.pathParameters['formId'];
            DeepLinkState.ccAction = 'records';
            return '/custom-complaints';
          },
        ),
      ],
    ),

    // ── Management + deep-link sub-route ──────────────────────────────────────
    GoRoute(
      path: '/management',
      pageBuilder: _mainPage,
      routes: [
        GoRoute(
          path: ':tab',
          redirect: (_, s) {
            DeepLinkState.managementTab = s.pathParameters['tab'];
            return '/management';
          },
        ),
      ],
    ),

    // ── Fleet ─────────────────────────────────────────────────────────────────
    GoRoute(path: '/fleet', pageBuilder: _mainPage),

    // ── Root ──────────────────────────────────────────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const AuthWrapper()),
  ],
);
