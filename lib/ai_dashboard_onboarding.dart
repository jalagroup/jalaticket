import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';

// ─── versioned key ─────────────────────────────────────────────────────────────
// Bump this string for every new release to re-trigger onboarding for all users.
const _kFeatureKey = 'ai_dashboard_v1';

// ─── page data ─────────────────────────────────────────────────────────────────
class _Page {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String? badge;
  const _Page({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.bullets = const [],
    this.badge,
  });
}

const _enPages = [
  _Page(
    gradient: [Color(0xFFf16936), Color(0xFFe85d04)],
    icon: Icons.auto_awesome_rounded,
    badge: '✨  New Feature',
    title: 'AI Dashboard Builder',
    subtitle:
        'Generate beautiful data dashboards from plain-text prompts. '
        'Your ticket data, visualized intelligently — in seconds.',
  ),
  _Page(
    gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
    icon: Icons.dashboard_customize_rounded,
    title: 'Drag, Resize & Rearrange',
    subtitle: 'Full control over your dashboard layout with an intuitive grid editor.',
    bullets: [
      '◀ ▶  Change width — ¼, ½, ¾, or Full row',
      '▲ ▼  Adjust height — Small, Medium, Large',
      '🎨  Tap the color dot to cycle color themes',
      '📊  Tap chart icon to switch Bar / Pie / Line',
      '↕️  Long-press any card to drag it to a new position',
      '➕  Drop into empty slots to rearrange freely',
    ],
  ),
  _Page(
    gradient: [Color(0xFF10B981), Color(0xFF047857)],
    icon: Icons.people_alt_rounded,
    title: 'Employee Analytics',
    subtitle: 'Understand how each admin in your department is performing on tickets.',
    bullets: [
      '✅  Resolved tickets per employee',
      '📈  Resolution rate as a percentage',
      '⏰  Hours worked during official hours (8 am – 3:30 pm)',
      '🌙  After-hours activity tracking',
      '📋  Visit count and average time per visit',
      '🔗  Hourly activity distribution chart',
    ],
  ),
  _Page(
    gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    icon: Icons.bookmarks_rounded,
    title: 'Save, Edit & Revisit',
    subtitle: 'Save any dashboard, fine-tune its layout, and jump between saved dashboards instantly.',
    bullets: [
      '🔒  Choose Private or Public visibility',
      '💾  Edit layout and save changes with one tap',
      '↔️  Side panel to switch between all saved dashboards',
      '🔁  Smart Insights tab — local analysis, no AI needed',
      '📌  Saved data is a snapshot — regenerate for fresh data',
    ],
  ),
];

const _arPages = [
  _Page(
    gradient: [Color(0xFFf16936), Color(0xFFe85d04)],
    icon: Icons.auto_awesome_rounded,
    badge: '✨  ميزة جديدة',
    title: 'منشئ لوحات الذكاء الاصطناعي',
    subtitle:
        'أنشئ لوحات بيانات احترافية بمجرد وصف ما تريده بلغتك الطبيعية. '
        'بياناتك، مرئية وذكية — في ثوانٍ.',
  ),
  _Page(
    gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
    icon: Icons.dashboard_customize_rounded,
    title: 'سحب وتغيير الحجم والترتيب',
    subtitle: 'تحكم كامل في تخطيط لوحتك من خلال محرر شبكة سهل الاستخدام.',
    bullets: [
      '◀ ▶  تغيير العرض — ١/٤ أو ١/٢ أو ٣/٤ أو كامل الصف',
      '▲ ▼  تغيير الارتفاع — صغير أو متوسط أو كبير',
      '🎨  اضغط النقطة الملونة للتنقل بين أنماط الألوان',
      '📊  اضغط أيقونة الرسم للتبديل بين Bar/Pie/Line',
      '↕️  اضغط مطولاً على أي بطاقة لسحبها لمكان جديد',
      '➕  أسقط العناصر في الخانات الفارغة لإعادة الترتيب',
    ],
  ),
  _Page(
    gradient: [Color(0xFF10B981), Color(0xFF047857)],
    icon: Icons.people_alt_rounded,
    title: 'تحليل أداء الموظفين',
    subtitle: 'اعرف كيف يؤدي كل مسؤول في قسمك على التذاكر.',
    bullets: [
      '✅  التذاكر المحلولة لكل موظف',
      '📈  نسبة الحل المئوية',
      '⏰  ساعات العمل خلال الدوام الرسمي (٨ ص – ٣:٣٠ م)',
      '🌙  النشاط خارج ساعات الدوام',
      '📋  عدد الزيارات ومتوسط الوقت لكل زيارة',
      '🔗  رسم توزيع النشاط حسب ساعة اليوم',
    ],
  ),
  _Page(
    gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    icon: Icons.bookmarks_rounded,
    title: 'احفظ وعدّل وارجع',
    subtitle: 'احفظ أي لوحة، عدّل تخطيطها، وانتقل بين اللوحات المحفوظة فوراً.',
    bullets: [
      '🔒  اختر الخصوصية: خاص أو عام',
      '💾  عدّل التخطيط واحفظه بضغطة واحدة',
      '↔️  قائمة جانبية للتنقل بين جميع اللوحات',
      '🔁  تبويب التحليل الذكي — بدون ذكاء اصطناعي خارجي',
      '📌  البيانات المحفوظة لقطة ثابتة — أعد التوليد للحصول على بيانات محدّثة',
    ],
  ),
];

// ─── public entry point ────────────────────────────────────────────────────────
class AiDashboardOnboarding extends StatefulWidget {
  final VoidCallback onDismiss;
  const AiDashboardOnboarding({super.key, required this.onDismiss});

  /// Call from initState (via addPostFrameCallback) for super admins.
  static Future<void> showIfNeeded(
    BuildContext context,
    UserModel user,
  ) async {
    // Only for super admins
    if (user.userType != UserType.superAdmin &&
        user.userType != UserType.systemAdmin) { return; }

    try {
      final row = await supabase
          .from('feature_seen_flags')
          .select('feature_key')
          .eq('user_id', user.id)
          .eq('feature_key', _kFeatureKey)
          .maybeSingle();
      if (row != null) return; // already seen this version
    } catch (_) {
      return; // table not created yet — skip gracefully
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => AiDashboardOnboarding(
          onDismiss: () async {
            Navigator.pop(ctx);
            // Mark as seen — upsert so re-runs are safe
            try {
              await supabase.from('feature_seen_flags').upsert(
                {
                  'user_id': user.id,
                  'feature_key': _kFeatureKey,
                  'seen_at': DateTime.now().toIso8601String(),
                },
                onConflict: 'user_id,feature_key',
              );
            } catch (_) {}
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<AiDashboardOnboarding> createState() => _AiDashboardOnboardingState();
}

class _AiDashboardOnboardingState extends State<AiDashboardOnboarding> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';
  List<_Page> get _pages => _isAr ? _arPages : _enPages;
  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDismiss();
    } else {
      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    }
  }

  void _prev() {
    _ctrl.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              // On wide screens (web/desktop) cap width and height
              final isWide = constraints.maxWidth > 600;
              final cardW = isWide ? 520.0 : double.infinity;
              final cardH = isWide ? 640.0 : double.infinity;
              final hMargin = isWide ? 0.0 : 20.0;
              final vMargin = isWide ? 0.0 : 28.0;
              return Container(
                width: cardW,
                height: cardH,
                margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 8)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
            child: Column(children: [
              // ── Pages ──────────────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: pages.length,
                  itemBuilder: (_, i) => _PageWidget(page: pages[i]),
                ),
              ),
              // ── Bottom bar ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? pages[_page].gradient[0]
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                  const SizedBox(height: 14),
                  // Buttons
                  Row(children: [
                    // Skip / Back
                    if (_page == 0)
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: Text(
                          _isAr ? 'تخطي' : 'Skip',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _prev,
                        child: Text(
                          _isAr ? '→  السابق' : '← Back',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    const Spacer(),
                    // Next / Let's go
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: pages[_page].gradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _next,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Text(
                              _isLast
                                  ? (_isAr ? '🚀  ابدأ الآن!' : '🚀  Get started!')
                                  : (_isAr ? 'التالي  ←' : 'Next  →'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
              );         // closes return Container
            },           // closes builder: (ctx, constraints)
          ),             // closes LayoutBuilder
        ),               // closes Center
      ),                 // closes SafeArea
    );                   // closes Scaffold
  }
}

// ─── single page widget ────────────────────────────────────────────────────────
class _PageWidget extends StatelessWidget {
  final _Page page;
  const _PageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Gradient header
        Container(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: page.gradient,
            ),
          ),
          child: Column(children: [
            if (page.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(page.badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              width: 78, height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, height: 1.3),
            ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.55),
            ),
            if (page.bullets.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...page.bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: page.gradient[0],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b, style: TextStyle(fontSize: 13.5, color: Colors.grey[800], height: 1.45)),
                  ),
                ]),
              )),
            ],
          ]),
        ),
      ]),
    );
  }
}
