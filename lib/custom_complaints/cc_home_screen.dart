import 'package:flutter/material.dart';
import '../app_router.dart' show DeepLinkState;
import '../main.dart' show AppColors;
import '../models.dart' show UserModel, UserType;
import 'cc_form_builder_screen.dart';
import 'cc_records_screen.dart';
import 'cc_submission_flow_screen.dart';
import 'cc_submission_list_screen.dart';
import 'cc_forms_dashboard_screen.dart';

bool ccIsCreator(UserModel user) =>
    user.userType == UserType.superAdmin ||
    user.userType == UserType.superUser ||
    user.userType == UserType.branchAdmin;

/// Entry point for the Custom Complaints module's nav tab.
/// Creators on web/desktop/large-tablet get a tabbed "My Forms" /
/// "Forms to Fill" view; everyone else (including creators on mobile,
/// since the builder/records UI is desktop-only) sees just their
/// assigned forms to fill out.
class CcHomeScreen extends StatefulWidget {
  final UserModel currentUser;

  const CcHomeScreen({super.key, required this.currentUser});

  @override
  State<CcHomeScreen> createState() => _CcHomeScreenState();
}

class _CcHomeScreenState extends State<CcHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Non-creators never see _CcCreatorHomeScreen, so they cannot consume the
    // deep-link state from there.  Handle their /submit deep-link here instead.
    // (Creators have their state consumed by _CcCreatorHomeScreenState.)
    if (!ccIsCreator(widget.currentUser)) {
      final formId = DeepLinkState.ccFormId;
      final action = DeepLinkState.ccAction;
      if (formId != null && action == 'submit') {
        // Consume so nothing else tries to re-open this.
        DeepLinkState.ccFormId = null;
        DeepLinkState.ccAction = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CcSubmissionFlowScreen(
                formId: formId,
                currentUser: widget.currentUser,
              ),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    if (!ccIsCreator(widget.currentUser) || isMobile) {
      return CcSubmissionListScreen(currentUser: widget.currentUser);
    }
    return _CcCreatorHomeScreen(currentUser: widget.currentUser);
  }
}

class _CcCreatorHomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const _CcCreatorHomeScreen({required this.currentUser});

  @override
  State<_CcCreatorHomeScreen> createState() => _CcCreatorHomeScreenState();
}

class _CcCreatorHomeScreenState extends State<_CcCreatorHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Consume deep-link params atomically so they are acted on once.
    final formId = DeepLinkState.ccFormId;
    final action = DeepLinkState.ccAction;
    DeepLinkState.ccFormId = null;
    DeepLinkState.ccAction = null;

    if (formId != null || action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(formId, action);
      });
    }
  }

  /// Push the appropriate sub-screen based on the deep-link action.
  void _handleDeepLink(String? formId, String? action) {
    if (!mounted) return;
    if (formId != null) {
      switch (action) {
        case 'edit':
        case 'design':
          // Both 'edit' and 'design' open the form builder (design screens are
          // accessed from within the builder's Settings tab).
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CcFormBuilderScreen(
                currentUser: widget.currentUser,
                editFormId: formId,
              ),
            ),
          );
          break;
        case 'records':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CcRecordsScreen(formId: formId)),
          );
          break;
        case 'submit':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CcSubmissionFlowScreen(
                formId: formId,
                currentUser: widget.currentUser,
              ),
            ),
          );
          break;
      }
    }
    // '/custom-complaints/records' (action == 'records', no formId) → stay on
    // the My Forms tab (index 0), which already lists all forms with record access.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.grey.withOpacity(0.1),
          title: Text(isAr ? 'الشكاوى' : 'Complaints', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: isAr ? 'نماذجي' : 'My Forms'),
              Tab(text: isAr ? 'نماذج للتعبئة' : 'Forms to Fill'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            CcFormsDashboardScreen(currentUser: widget.currentUser, embedded: true),
            CcSubmissionListScreen(currentUser: widget.currentUser, embedded: true),
          ],
        ),
      ),
    );
  }
}
