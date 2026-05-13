import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/auth.dart';

const _kOnboardingDoneKey = 'onboarding_complete_v1';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
}

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

// ─── Entry gate ──────────────────────────────────────────────────────────────

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _done;

  @override
  void initState() {
    super.initState();
    isOnboardingComplete().then((v) {
      if (mounted) setState(() => _done = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_done!) return const AuthWrapper();
    return const OnboardingScreen();
  }
}

// ─── Main onboarding screen ───────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  static const _total = 3;

  // Animation controllers – one per page illustration
  late final AnimationController _anim0;
  late final AnimationController _anim1;
  late final AnimationController _anim2;
  // Page-transition fade/slide
  late final AnimationController _transCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _anim0 = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _anim1 = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _anim2 = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _transCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _transCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _transCtrl, curve: Curves.easeOutCubic));
    _transCtrl.forward();
  }

  @override
  void dispose() {
    _anim0.dispose();
    _anim1.dispose();
    _anim2.dispose();
    _transCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _total - 1) {
      _transCtrl.forward(from: 0);
      _controller.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isRtl =
        Directionality.of(context) == TextDirection.rtl;

    final pages = [
      _PageData(
        titleEn: 'Manage Your\nSupport Tickets',
        titleAr: 'إدارة تذاكر\nالدعم الخاصة بك',
        bodyEn:
            'Create, track and resolve support tickets efficiently from one place.',
        bodyAr:
            'أنشئ وتتبع وحل تذاكر الدعم بكفاءة من مكان واحد.',
        illustration: _TicketIllustration(animation: _anim0),
      ),
      _PageData(
        titleEn: 'Track Progress\nin Real Time',
        titleAr: 'تتبع التقدم\nفي الوقت الفعلي',
        bodyEn:
            'Stay updated on every ticket status change and never miss an update.',
        bodyAr:
            'ابقَ على اطلاع بكل تغيير في حالة التذكرة ولا تفوّتك أي تحديثات.',
        illustration: _ProgressIllustration(animation: _anim1),
      ),
      _PageData(
        titleEn: 'Get Instant\nNotifications',
        titleAr: 'احصل على إشعارات\nفورية',
        bodyEn:
            'Receive real-time alerts for ticket updates, assignments and messages.',
        bodyAr:
            'استقبل تنبيهات فورية لتحديثات التذاكر والتعيينات والرسائل.',
        illustration: _NotificationIllustration(animation: _anim2),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──────────────────────────────────────
            Align(
              alignment:
                  isRtl ? Alignment.centerLeft : Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  isRtl ? 'تخطي الجولة' : 'Skip Tour',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ),
            ),

            // ── PageView ─────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _total,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(
                  data: pages[i],
                  screenSize: size,
                  fade: _fadeAnim,
                  slide: _slideAnim,
                  isActive: i == _page,
                ),
              ),
            ),

            // ── Bottom controls ──────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _total,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _page == _total - 1
                            ? (isRtl ? 'ابدأ الآن' : 'Get Started')
                            : (isRtl ? 'التالي' : 'Next'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single onboarding page ───────────────────────────────────────────────────

class _PageData {
  final String titleEn, titleAr, bodyEn, bodyAr;
  final Widget illustration;
  const _PageData({
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.illustration,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final Size screenSize;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    required this.screenSize,
    required this.fade,
    required this.slide,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final title = isRtl ? data.titleAr : data.titleEn;
    final body = isRtl ? data.bodyAr : data.bodyEn;

    return Column(
      children: [
        // ── Top orange illustration area ─────────────────────────
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              // Background blob shapes
              Positioned.fill(
                child: CustomPaint(painter: _BlobPainter()),
              ),
              // Illustration
              Center(child: data.illustration),
            ],
          ),
        ),

        // ── Wave clip transition ─────────────────────────────────
        CustomPaint(
          size: Size(screenSize.width, 40),
          painter: _WavePainter(),
        ),

        // ── White text area ──────────────────────────────────────
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: isRtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign:
                          isRtl ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign:
                          isRtl ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom painters ──────────────────────────────────────────────────────────

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final c1 = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.2),
          radius: size.width * 0.28));
    canvas.drawPath(c1, paint);

    final c2 = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.75),
          radius: size.width * 0.22));
    canvas.drawPath(c2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.25, 0, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.6, size.width, size.height * 0.1);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Illustration 1: Floating ticket cards ────────────────────────────────────

class _TicketIllustration extends StatelessWidget {
  final AnimationController animation;
  const _TicketIllustration({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        final sine = math.sin(t * math.pi);
        return SizedBox(
          width: 260,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Back card
              Transform.translate(
                offset: Offset(-30 + sine * 8, 30 - sine * 12),
                child: Transform.rotate(
                  angle: -0.12 + sine * 0.04,
                  child: _TicketCard(
                    color: Colors.white.withValues(alpha: 0.5),
                    label: '#1042',
                    status: '⏳',
                    width: 200,
                  ),
                ),
              ),
              // Middle card
              Transform.translate(
                offset: Offset(20, -15 + sine * 14),
                child: Transform.rotate(
                  angle: 0.06 - sine * 0.03,
                  child: _TicketCard(
                    color: Colors.white.withValues(alpha: 0.75),
                    label: '#1041',
                    status: '✅',
                    width: 210,
                  ),
                ),
              ),
              // Front card
              Transform.translate(
                offset: Offset(-10, -40 + sine * 10),
                child: _TicketCard(
                  color: Colors.white,
                  label: '#1043',
                  status: '🔄',
                  width: 220,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Color color;
  final String label, status;
  final double width;
  const _TicketCard(
      {required this.color,
      required this.label,
      required this.status,
      required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(status,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Illustration 2: Animated progress ────────────────────────────────────────

class _ProgressIllustration extends StatelessWidget {
  final AnimationController animation;
  const _ProgressIllustration({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return SizedBox(
          width: 240,
          height: 220,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProgressRow(
                  label: 'Pending',
                  icon: Icons.schedule_rounded,
                  fill: 1.0,
                  delay: 0,
                  t: t),
              const SizedBox(height: 14),
              _ProgressRow(
                  label: 'In Progress',
                  icon: Icons.sync_rounded,
                  fill: 0.65,
                  delay: 0.2,
                  t: t),
              const SizedBox(height: 14),
              _ProgressRow(
                  label: 'Finished',
                  icon: Icons.check_circle_rounded,
                  fill: 0.4,
                  delay: 0.4,
                  t: t),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double fill, delay, t;
  const _ProgressRow(
      {required this.label,
      required this.icon,
      required this.fill,
      required this.delay,
      required this.t});

  @override
  Widget build(BuildContext context) {
    final animated =
        ((t - delay).clamp(0.0, 1.0) * fill).clamp(0.0, fill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: animated,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Illustration 3: Notification bell with ripples ───────────────────────────

class _NotificationIllustration extends StatelessWidget {
  final AnimationController animation;
  const _NotificationIllustration({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ripples
              for (int i = 0; i < 3; i++)
                _Ripple(
                  progress: ((t + i * 0.33) % 1.0),
                  maxRadius: 90.0,
                ),
              // Bell container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Transform.rotate(
                  angle: math.sin(t * math.pi * 2) * 0.25,
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              // Small chat bubble
              Positioned(
                top: 30,
                right: 20,
                child: Transform.scale(
                  scale: 0.8 + math.sin(t * math.pi * 2 + 1) * 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8)
                      ],
                    ),
                    child: const Text('New!',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ripple extends StatelessWidget {
  final double progress, maxRadius;
  const _Ripple({required this.progress, required this.maxRadius});

  @override
  Widget build(BuildContext context) {
    final radius = progress * maxRadius;
    final opacity = (1 - progress) * 0.4;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }
}
