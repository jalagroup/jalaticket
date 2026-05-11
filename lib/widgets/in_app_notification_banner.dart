import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';

class InAppNotificationBanner {
  static OverlayEntry? _currentEntry;
  static _NotificationBannerWidgetState? _currentState;

  static void show({
    required BuildContext context,
    required String title,
    required String body,
    String? notificationType,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    dismiss();

    final overlayState = Overlay.of(context);
    final icon = _iconForType(notificationType);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationBannerWidget(
        title: title,
        body: body,
        icon: icon,
        onTap: onTap,
        duration: duration,
        onDismiss: dismiss,
        onStateCreated: (s) => _currentState = s,
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  static void dismiss() {
    _currentState?._dismiss();
    _currentState = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static IconData _iconForType(String? type) {
    switch (type) {
      case 'new_message':
      case 'chat_mention':
        return Icons.chat_bubble_rounded;
      case 'ticket_created':
        return Icons.confirmation_number_rounded;
      case 'ticket_assigned':
        return Icons.assignment_ind_rounded;
      case 'ticket_approved':
        return Icons.check_circle_rounded;
      case 'ticket_rejected':
        return Icons.cancel_rounded;
      case 'ticket_status_changed':
        return Icons.update_rounded;
      case 'ticket_auto_approved':
        return Icons.auto_awesome_rounded;
      case 'subticket_created':
        return Icons.account_tree_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;
  final Duration duration;
  final VoidCallback onDismiss;
  final void Function(_NotificationBannerWidgetState) onStateCreated;

  const _NotificationBannerWidget({
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
    required this.duration,
    required this.onDismiss,
    required this.onStateCreated,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  double _dragOffset = 0;
  bool _isDismissing = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _slideController.forward();
    _progressController.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    setState(() => _isDismissing = true);
    _dismissTimer?.cancel();
    _progressController.stop();
    await _slideController.reverse();
    if (mounted) widget.onDismiss();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy < 0) {
      setState(() => _dragOffset += details.delta.dy);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset < -40 || details.velocity.pixelsPerSecond.dy < -300) {
      _dismiss();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Transform.translate(
            offset: Offset(0, _dragOffset.clamp(-300.0, 0.0)),
            child: GestureDetector(
              onTap: () {
                _dismiss();
                widget.onTap?.call();
              },
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Material(
                  elevation: 10,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App icon / notification type icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(widget.icon,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              // Title + body
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF111111),
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.body.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.body,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF555555),
                                          height: 1.35,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Close button
                              GestureDetector(
                                onTap: _dismiss,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Countdown progress bar
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (_, __) => ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                            ),
                            child: LinearProgressIndicator(
                              value: 1 - _progressController.value,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary.withValues(alpha: 0.5)),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
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
