import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jalasupport/FCMService.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/sound_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';

// Define app colors from main.dart
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

// ============================================================================
// RESPONSIVE CHAT UTILITY
// ============================================================================
class ChatResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isWeb() {
    return kIsWeb;
  }

  static bool isDesktop() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }
}

// ============================================================================
// UPDATED CHAT WIDGET WITH THEME CONSISTENCY AND ANIMATIONS
// ============================================================================
class ChatWidget extends StatefulWidget {
  final String chatRoomId;
  final UserModel currentUser;
  final VoidCallback? onMessageSent;
  final bool isFullScreen;
  final String? ticketNumber;
  final String? ticketTitle;
  const ChatWidget({
    super.key,
    required this.chatRoomId,
    required this.currentUser,
    this.onMessageSent,
    this.isFullScreen = false,
    this.ticketNumber,
    this.ticketTitle,
  });
  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessageModel> _messages = [];
  // Optimistic messages shown instantly before server confirms them.
  final List<ChatMessageModel> _pendingMessages = [];
  StreamSubscription? _messagesSubscription;
  bool _isLoading = false;
  bool _isSending = false;

  List<ChatMessageModel> get _displayMessages =>
      [..._messages, ..._pendingMessages];
  final FocusNode _focusNode = FocusNode();
  AnimationController? _messageAddAnimationController;
  Animation<Offset>? _messageSlideAnimation;
  Animation<double>? _messageFadeAnimation;
  String? _lastAnimatedMessageId;
  Timer? _readMarkTimer;
  bool _isAtBottom = true;
  bool _hasUnreadMessages = false;
  int _retryCount = 0;
// Message sending queue for fast consecutive sends
  final List<String> _sendQueue = [];
  bool _isProcessingQueue = false;
  @override
  bool get wantKeepAlive => true; // Keep state alive when scrolling away
  @override
  void initState() {
    super.initState();
    print('🏁 ChatWidget initialized for room: ${widget.chatRoomId}');
// LAZY: Don't initialize animations until first send
    _setupScrollListener();
    _loadInitialMessages();
    _subscribeToMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsReadDelayed();
    });
  }

  void _ensureAnimationsInitialized() {
    if (_messageAddAnimationController != null) return;
    _messageAddAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _messageSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _messageAddAnimationController!,
      curve: Curves.easeOutBack,
    ));

    _messageFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _messageAddAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final currentScroll = _scrollController.position.pixels;
      final isAtBottom = currentScroll <= 100;

      if (_isAtBottom != isAtBottom) {
        if (mounted) {
          setState(() {
            _isAtBottom = isAtBottom;
          });
        }

        if (isAtBottom && _hasUnreadMessages) {
          _markAsReadDelayed();
        }
      }
    });
  }

  @override
  void dispose() {
    print('🧹 ChatWidget disposing for room: ${widget.chatRoomId}');
    _messagesSubscription?.cancel();
    _readMarkTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();

    _messageAddAnimationController?.dispose();

    _lastAnimatedMessageId = null;
    _retryCount = 0;
    _sendQueue.clear();
    _pendingMessages.clear();

    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    if (_isLoading) return;
    print('📥 Loading initial messages...');
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final messages = await ChatService.getMessages(widget.chatRoomId);
      print('✅ Loaded ${messages.length} initial messages');

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _hasUnreadMessages =
              messages.any((m) => m.senderId != widget.currentUser.id);
        });

        _retryCount = 0;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });

        if (messages.isNotEmpty) {
          _markAsReadDelayed();
        }
      }
    } catch (e) {
      print('❌ Error loading initial messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.safeOf(context);
        _showErrorSnackBar('${l10n.error}: ${l10n.retry}');

        Timer(Duration(seconds: math.min(5, 3 + _retryCount)), () {
          if (mounted) {
            _retryCount++;
            _loadInitialMessages();
          }
        });
      }
    }
  }

  void _subscribeToMessages() {
    print('🔄 Setting up real-time subscription...');
    _messagesSubscription?.cancel();
    _messagesSubscription =
        ChatService.subscribeToMessages(widget.chatRoomId).listen(
      (newMessages) {
        if (!mounted) return;

        print('📨 Received ${newMessages.length} messages from subscription');

        final oldCount = _messages.length;

        // Count newly confirmed messages sent by us that aren't already in
        // _messages — each one "consumes" one pending optimistic bubble.
        final confirmedOurMessages = newMessages.where((msg) =>
            msg.senderId == widget.currentUser.id &&
            !_messages.any((e) => e.id == msg.id)).length;

        final hasNewFromOthers = newMessages.any((msg) =>
            msg.senderId != widget.currentUser.id &&
            !_messages.any((e) => e.id == msg.id));

        setState(() {
          _messages = newMessages;
          // Drop confirmed pending messages (oldest first).
          for (var i = 0; i < confirmedOurMessages && _pendingMessages.isNotEmpty; i++) {
            _pendingMessages.removeAt(0);
          }
          _hasUnreadMessages = hasNewFromOthers ||
              newMessages.any((m) => m.senderId != widget.currentUser.id);
        });

        // Play receive sound for messages from other users.
        if (hasNewFromOthers) {
          SoundService.playMessageReceived();
        }

        if (newMessages.length > oldCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
              if (_isAtBottom) {
                _markAsReadDelayed();
                widget.onMessageSent?.call();
              }
            }
          });
        }

        if (hasNewFromOthers && _isAtBottom) {
          _markAsReadDelayed();
          widget.onMessageSent?.call();
        }
      },
      onError: (error) {
        print('❌ Subscription error: $error');
        _handleSubscriptionError();
      },
    );
  }

  void _handleSubscriptionError() {
    if (!mounted) return;
    final retryDelay = Duration(seconds: math.min(30, 3 * (_retryCount + 1)));
    _retryCount++;

    print(
        '🔄 Scheduling reconnection attempt #$_retryCount in ${retryDelay.inSeconds}s');

    Timer(retryDelay, () {
      if (mounted) {
        print('🔄 Attempting to reconnect subscription...');
        _subscribeToMessages();
      }
    });
  }

  void _markAsReadDelayed() {
    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(const Duration(milliseconds: 500), () async {
      if (mounted && _hasUnreadMessages) {
        try {
          await ChatService.markChatAsRead(
              widget.chatRoomId, widget.currentUser.id);
          if (mounted) {
            setState(() {
              _hasUnreadMessages = false;
            });
            widget.onMessageSent?.call();
          }
        } catch (e) {
          print('❌ Error marking chat as read: $e');
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();
    _ensureAnimationsInitialized();

    // 1. Play send sound immediately.
    SoundService.playMessageSent();

    // 2. Show optimistic bubble instantly.
    _addOptimisticMessage(messageText);

    // 3. Enqueue the actual network call.
    _sendQueue.add(messageText);
    if (!_isProcessingQueue) {
      _processMessageQueue();
    }
  }

  void _addOptimisticMessage(String text) {
    final pending = ChatMessageModel(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      chatRoomId: widget.chatRoomId,
      senderId: widget.currentUser.id,
      message: text,
      createdAt: DateTime.now(),
      senderName: widget.currentUser.fullName,
      senderProfileImage: widget.currentUser.profileImageUrl,
      isPending: true,
    );
    setState(() => _pendingMessages.add(pending));

    // Scroll to bottom to reveal the new bubble.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processMessageQueue() async {
    if (_isProcessingQueue || _sendQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_sendQueue.isNotEmpty && mounted) {
      final messageText = _sendQueue.removeAt(0);

      if (mounted) setState(() => _isSending = true);

      try {
        final success =
            await ChatService.sendMessage(widget.chatRoomId, messageText, null);

        if (success) {
          // The realtime subscription will remove the pending bubble when the
          // confirmed message arrives — nothing extra needed here.
          widget.onMessageSent?.call();
          await ChatService.markChatAsRead(
              widget.chatRoomId, widget.currentUser.id);
        } else {
          if (mounted) {
            // Remove the optimistic bubble and restore text to input.
            setState(() {
              if (_pendingMessages.isNotEmpty) _pendingMessages.removeAt(0);
            });
            _messageController.text = messageText;
            final l10n = AppLocalizations.safeOf(context);
            _showErrorSnackBar('${l10n.error}: ${l10n.retry}');
          }
          break;
        }
      } catch (e) {
        print('❌ Error sending message: $e');
        if (mounted) {
          setState(() {
            if (_pendingMessages.isNotEmpty) _pendingMessages.removeAt(0);
          });
          _messageController.text = messageText;
          final l10n = AppLocalizations.safeOf(context);
          _showErrorSnackBar('${l10n.error}: $e');
        }
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isSending = false;
        _isProcessingQueue = false;
      });
      _focusNode.requestFocus();
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.safeOf(context);
    if (widget.isFullScreen && ChatResponsiveHelper.isMobile(context)) {
      return _buildChatWidgetMobile(context, l10n);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildChatContent(l10n),
    );
  }

  Widget _buildChatWidgetMobile(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticketNumber ?? l10n.chat,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.ticketTitle != null)
              Text(
                widget.ticketTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.secondary.withOpacity(0.4),
        surfaceTintColor: AppColors.secondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isAtBottom && _messages.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                tooltip: l10n.scrollToLatest,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildChatContent(l10n),
      resizeToAvoidBottomInset: true,
    );
  }

  Widget _buildChatContent(AppLocalizations l10n) {
    return Column(
      children: [
// Connection status - only show when actually disconnected
        if (_messagesSubscription == null && _retryCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.reconnecting,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        // Messages list
        Expanded(
          child: Container(
            color: const Color(0xFFF0F4F7),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState(l10n)
                    : _buildMessagesList(l10n),
          ),
        ),

        // Scroll to bottom button
        if (!_isAtBottom && _messages.isNotEmpty)
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(25),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

        // Message input
        _buildMessageInput(l10n),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMessagesYet,
            style: TextStyle(
              color: AppColors.onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startConversation,
            style: TextStyle(
              color: AppColors.onBackground.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

// OPTIMIZED: Use ListView.builder with itemExtent for better performance
  Widget _buildMessagesList(AppLocalizations l10n) {
    final msgs = _displayMessages;
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      itemCount: msgs.length,
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        final reversedIndex = msgs.length - 1 - index;
        final message = msgs[reversedIndex];
        final isMe = message.senderId == widget.currentUser.id;
        final localTime = message.createdAt.toLocal();
        bool showTimestamp = false;
        if (reversedIndex == 0) {
          showTimestamp = true;
        } else {
          final previousMessage = msgs[reversedIndex - 1];
          final previousTime = previousMessage.createdAt.toLocal();
          final timeDifference =
              localTime.difference(previousTime).inMinutes.abs();
          showTimestamp = timeDifference > 5;
        }

        Widget messageWidget = Column(
          children: [
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.secondary.withOpacity(0.15),
                        thickness: 1,
                        endIndent: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateFormat('MMM dd, yyyy · HH:mm').format(localTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.secondary.withOpacity(0.15),
                        thickness: 1,
                        indent: 12,
                      ),
                    ),
                  ],
                ),
              ),
            _buildMessageBubble(message, isMe, localTime, l10n),
          ],
        );

        if (index == 0 &&
            message.senderId == widget.currentUser.id &&
            message.id == _lastAnimatedMessageId &&
            _messageAddAnimationController != null &&
            _messageAddAnimationController!.status == AnimationStatus.forward) {
          return SlideTransition(
            position: _messageSlideAnimation!,
            child: FadeTransition(
              opacity: _messageFadeAnimation!,
              child: messageWidget,
            ),
          );
        }

        return messageWidget;
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe,
      DateTime localTime, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildUserAvatar(
              profileImageUrl: message.senderProfileImage,
              senderName: message.senderName,
              isMe: false,
              l10n: l10n,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isMe ? 0.12 : 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? AppColors.onPrimary : const Color(0xFF1A1A2E),
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(localTime),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? AppColors.onPrimary.withOpacity(0.8)
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          message.isPending
                              ? Icons.access_time_rounded
                              : Icons.done_all,
                          size: 12,
                          color: AppColors.onPrimary.withOpacity(
                              message.isPending ? 0.6 : 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(
              profileImageUrl: widget.currentUser.profileImageUrl,
              senderName: widget.currentUser.fullName,
              isMe: true,
              l10n: l10n,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserAvatar({
    String? profileImageUrl,
    String? senderName,
    required bool isMe,
    required AppLocalizations l10n,
  }) {
    final displayName = senderName ?? (isMe ? l10n.you : l10n.user);
    final fallbackChar = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? AppColors.primary : AppColors.secondary.withOpacity(0.1),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.secondary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? Image.network(
                profileImageUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                // Add caching
                cacheWidth: 72,
                cacheHeight: 72,
                errorBuilder: (context, error, stackTrace) {
                  return _buildAvatarFallback(fallbackChar, isMe);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildAvatarFallback(fallbackChar, isMe);
                },
              )
            : _buildAvatarFallback(fallbackChar, isMe),
      ),
    );
  }

  Widget _buildAvatarFallback(String char, bool isMe) {
    return Container(
      width: 36,
      height: 36,
      color: isMe ? AppColors.primary : AppColors.secondary.withOpacity(0.1),
      child: Center(
        child: Text(
          char,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isMe ? AppColors.onPrimary : AppColors.secondary,
          ),
        ),
      ),
    );
  }

// OPTIMIZED: Message input with keyboard persistence
  Widget _buildMessageInput(AppLocalizations l10n) {
// Build hint text with queue count
    String hintText;
    if (_sendQueue.isNotEmpty) {
      hintText = l10n.sendingMessages
          .replaceAll('{count}', _sendQueue.length.toString());
    } else {
      hintText = l10n.typeMessage;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.secondary.withOpacity(0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _isSending
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.secondary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  color: _isSending
                      ? AppColors.primary.withOpacity(0.05)
                      : const Color(0xFFF4F6F8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: _isSending
                          ? AppColors.primary.withOpacity(0.6)
                          : AppColors.onBackground.withOpacity(0.45),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                  ),
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  // Allow typing even while sending
                  enabled: true,
                  maxLines: null,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  // Keep keyboard behavior
                  keyboardType: TextInputType.text,
                  onChanged: (text) {
                    if (text.isNotEmpty && _hasUnreadMessages) {
                      _markAsReadDelayed();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            _buildSendButton(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(AppLocalizations l10n) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: (_isSending || _sendQueue.isNotEmpty)
            ? AppColors.secondary
            : AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (_isSending || _sendQueue.isNotEmpty)
                ? AppColors.secondary.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _sendMessage,
          child: Container(
            width: 50,
            height: 50,
            child: (_isSending || _sendQueue.isNotEmpty)
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.onSecondary),
                        ),
                      ),
                      if (_sendQueue.isNotEmpty)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            constraints:
                                BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              _sendQueue.length.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  )
                : Icon(
                    Icons.send_rounded,
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UPDATED CHAT SCREEN WITH ENHANCED THEMING
// ============================================================================
class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  const ChatScreen({super.key, required this.currentUser});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _chatRooms = [];
  String? _selectedChatRoomId;
  String? _selectedChatRoomTitle;
  String? _selectedTicketNumber;
  bool _isLoading = false;
  StreamSubscription? _chatRoomsSubscription;
  Map<String, int> _unreadCounts = {};
  bool _isRefreshing = false;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _readStatusSubscription;
  Timer? _updateTimer;
// Debounce controller
  Timer? _debounceTimer;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _readStatusSubscription?.cancel();
    _updateTimer?.cancel();
    _debounceTimer?.cancel();
    ChatService.disposeAllStreams();
    super.dispose();
  }

  Future<void> _refreshChatRooms() async {
    if (_isRefreshing) return;
    try {
      setState(() {
        _isRefreshing = true;
      });

      print('🔄 Refreshing chat rooms due to new message...');

      final previouslySelectedId = _selectedChatRoomId;
      await _loadChatRooms();

      if (previouslySelectedId != null && mounted) {
        setState(() {
          _selectedChatRoomId = previouslySelectedId;
        });
      }
    } catch (e) {
      print('❌ Error refreshing chat rooms: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    if (ChatResponsiveHelper.isMobile(context)) {
      return MobileChatRoomsScreen(currentUser: widget.currentUser);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _selectedTicketNumber != null
              ? '$_selectedTicketNumber - ${_selectedChatRoomTitle ?? l10n.chat}'
              : l10n.chatRooms,
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        surfaceTintColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          if (_unreadCounts.values.any((count) => count > 0))
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCounts.values
                          .fold(0, (sum, count) => sum + count)
                          .toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: AppColors.secondary),
              onPressed: _isLoading ? null : _loadChatRooms,
              tooltip: l10n.refresh,
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  right: BorderSide(
                    color: AppColors.secondary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.secondary.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.recentConversations,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onBackground,
                            ),
                          ),
                        ),
                        if (_unreadCounts.values.any((count) => count > 0))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_unreadCounts.values.fold(0, (sum, count) => sum + count)} ${l10n.unread}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildChatRoomsList(l10n)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _selectedChatRoomId != null
                ? ChatWidget(
                    key: ValueKey(_selectedChatRoomId),
                    chatRoomId: _selectedChatRoomId!,
                    currentUser: widget.currentUser,
                    onMessageSent: _onMessageSent,
                    ticketNumber: _selectedTicketNumber,
                    ticketTitle: _selectedChatRoomTitle,
                  )
                : _buildEmptyState(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.selectConversationToStartChatting,
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chooseFromActiveTicketsOnLeft,
              style: TextStyle(
                color: AppColors.onBackground.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatRoomsList(AppLocalizations l10n) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadingChatRooms,
              style: TextStyle(
                color: AppColors.onBackground.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noActiveChatRooms,
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatRoomsAppearWhenTicketsInProgress,
              style: TextStyle(
                color: AppColors.onBackground.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

// Calculate bottom navigation bar height for mobile
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: bottomNavBarHeight + 8,
      ),
      itemCount: _chatRooms.length,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        final chatRoom = _chatRooms[index];
        final ticket = chatRoom['tickets'];

        if (ticket == null) {
          return const SizedBox.shrink();
        }

        final isSelected = _selectedChatRoomId == chatRoom['id'];
        final unreadCount = chatRoom['unread_count'] as int? ?? 0;
        final hasUnread = unreadCount > 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : (hasUnread
                    ? AppColors.primary.withOpacity(0.05)
                    : AppColors.background),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.3)
                  : (hasUnread
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.secondary.withOpacity(0.1)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _onChatRoomSelected(chatRoom['id'], ticket['id']),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getStatusColor(ticket['status']),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: _getStatusColor(ticket['status'])
                                  .withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(ticket['status'])
                                    .withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              ticket['ticket_number']
                                  .toString()
                                  .substring(3, 6),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 20, minHeight: 20),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket['ticket_number'],
                                  style: TextStyle(
                                    fontWeight: hasUnread
                                        ? FontWeight.bold
                                        : (isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600),
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.onBackground,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                _getLastMessageTime(chatRoom, l10n),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasUnread
                                      ? AppColors.primary
                                      : AppColors.onBackground.withOpacity(0.6),
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.8)
                                  : AppColors.onBackground.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getLastMessagePreview(chatRoom, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? AppColors.onBackground.withOpacity(0.8)
                                  : AppColors.onBackground.withOpacity(0.6),
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(ticket['status'])
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getStatusColor(ticket['status'])
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatStatus(ticket['status'], l10n),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(ticket['status']),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
        return AppColors.secondary;
      case 'prefinished':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      case 'wrong_info':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'inprogress':
        return l10n.inProgress;
      case 'prefinished':
        return l10n.prefinished;
      case 'closed':
        return l10n.closed;
      case 'wrong_info':
        return l10n.wrongInfo;
      default:
        return status;
    }
  }

  String _getLastMessagePreview(
      Map<String, dynamic> chatRoom, AppLocalizations l10n) {
    final lastMessage = chatRoom['last_message'] as String?;
    final senderId = chatRoom['last_message_sender_id'] as String?;
    final senderName = chatRoom['last_message_sender_name'] as String?;
    if (lastMessage == null) return l10n.noMessagesYet;

    final isMe = senderId == widget.currentUser.id;
    final displayName =
        isMe ? l10n.you : (senderName?.split(' ').first ?? l10n.someone);

    final truncated = lastMessage.length > 35
        ? '${lastMessage.substring(0, 35)}...'
        : lastMessage;

    return '$displayName: $truncated';
  }

  String _getLastMessageTime(
      Map<String, dynamic> chatRoom, AppLocalizations l10n) {
    final lastMessageTime = chatRoom['last_message_time'] as DateTime?;
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessageTime.toLocal());

    if (difference.inDays > 7) {
      return DateFormat('MMM dd').format(lastMessageTime.toLocal());
    } else if (difference.inDays > 0) {
      return '${difference.inDays}${l10n.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}${l10n.hour}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}${l10n.minute}';
    } else {
      return l10n.now;
    }
  }

// OPTIMIZED: Debounced message sent handler
  void _onMessageSent() {
    print('📤 Message sent, scheduling chat room update...');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performChatRoomsUpdate();
      }
    });
  }

  void _onChatRoomSelected(String chatRoomId, String ticketId) async {
    final selectedRoom =
        _chatRooms.firstWhere((room) => room['id'] == chatRoomId);
    final ticket = selectedRoom['tickets'];
    setState(() {
      _selectedChatRoomId = chatRoomId;
      _selectedChatRoomTitle = ticket['title'];
      _selectedTicketNumber = ticket['ticket_number'];
    });

    try {
      await ChatService.markChatAsRead(chatRoomId, widget.currentUser.id);

      if (mounted) {
        setState(() {
          _unreadCounts[ticketId] = 0;
          final roomIndex =
              _chatRooms.indexWhere((room) => room['id'] == chatRoomId);
          if (roomIndex != -1) {
            _chatRooms[roomIndex]['unread_count'] = 0;
          }
        });
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  Future<void> _loadChatRooms() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      print('Loading chat rooms for user type: ${widget.currentUser.userType}');

      List<dynamic> response = await _getChatRoomsQuery();
      print('Found ${response.length} chat rooms');

      final ticketIds =
          response.map((room) => room['tickets']['id'] as String).toList();

      Map<String, int> unreadCounts = {};
      if (ticketIds.isNotEmpty) {
        unreadCounts = await ChatService.getUnreadCountsForTickets(
            ticketIds, widget.currentUser.id);
      }

      List<Map<String, dynamic>> chatRoomsWithLastMessage = [];

      for (final chatRoom in response) {
        final processedRoom =
            await _processChatRoomData(chatRoom, unreadCounts);
        if (processedRoom != null) {
          chatRoomsWithLastMessage.add(processedRoom);
        }
      }

      _sortChatRooms(chatRoomsWithLastMessage);

      if (mounted) {
        setState(() {
          _chatRooms = chatRoomsWithLastMessage;
          _unreadCounts = unreadCounts;
          _isLoading = false;
        });

        // Setup subscriptions after loading
        _setupRealtimeSubscriptions();

        print('Loaded ${_chatRooms.length} chat rooms successfully');
      }
    } catch (e) {
      print('Error loading chat rooms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<dynamic>> _getChatRoomsQuery() async {
// [Keep existing implementation - already optimized]
    if (widget.currentUser.userType == UserType.admin) {
      final assignedTickets = await supabase
          .from('chat_rooms')
          .select('''
id, ticket_id,
tickets!inner (
id, ticket_number, title, status, created_by, assigned_to,
target_department_id, place_id, parent_ticket_id, created_at)
''')
          .eq('is_active', true)
          .eq('tickets.assigned_to', widget.currentUser.id)
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
          .eq('tickets.created_by', widget.currentUser.id)
          .inFilter('tickets.status', ['inprogress', 'prefinished']);

      final allTickets = <String, dynamic>{};
      for (final ticket in [...assignedTickets, ...createdTickets]) {
        allTickets[ticket['id']] = ticket;
      }
      return allTickets.values.toList();
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      if (widget.currentUser.departmentId != null) {
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
            .eq('tickets.target_department_id',
                widget.currentUser.departmentId!)
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
            .eq('tickets.created_by', widget.currentUser.id)
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
            .eq('tickets.assigned_to', widget.currentUser.id)
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
            .eq('tickets.created_by', widget.currentUser.id)
            .inFilter('tickets.status', ['inprogress', 'prefinished']);
      }
    } else if (widget.currentUser.userType == UserType.superUser) {
      if (widget.currentUser.placeId != null) {
        final usersInPlace = await supabase
            .from('users')
            .select('id')
            .eq('place_id', widget.currentUser.placeId!)
            .eq('user_type', 'user');

        final userIds = [
          widget.currentUser.id,
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
            .eq('tickets.created_by', widget.currentUser.id)
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
          .eq('tickets.created_by', widget.currentUser.id)
          .inFilter('tickets.status', ['inprogress', 'prefinished']);
    }
  }

  Future<Map<String, dynamic>?> _processChatRoomData(
      Map<String, dynamic> chatRoom, Map<String, int> unreadCounts) async {
    final ticket = chatRoom['tickets'];
    if (ticket == null) return null;
    try {
      final lastMessageResponse = await supabase
          .from('chat_messages')
          .select('message, created_at, sender_id, users!sender_id(full_name)')
          .eq('chat_room_id', chatRoom['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String? lastMessageText;
      DateTime? lastMessageTime;
      String? lastMessageSenderId;
      String? lastMessageSenderName;

      if (lastMessageResponse != null) {
        lastMessageText = lastMessageResponse['message'];
        lastMessageTime = DateTime.parse(lastMessageResponse['created_at']);
        lastMessageSenderId = lastMessageResponse['sender_id'];
        final senderData = lastMessageResponse['users'];
        lastMessageSenderName = senderData?['full_name'];
      }

      final unreadCount = unreadCounts[ticket['id']] ?? 0;

      return {
        ...chatRoom,
        'last_message': lastMessageText,
        'last_message_time': lastMessageTime,
        'last_message_sender_id': lastMessageSenderId,
        'last_message_sender_name': lastMessageSenderName,
        'unread_count': unreadCount,
      };
    } catch (e) {
      print('❌ Error processing chat room ${chatRoom['id']}: $e');
      return null;
    }
  }

  void _sortChatRooms(List<Map<String, dynamic>> chatRooms) {
    chatRooms.sort((a, b) {
      final aTime = a['last_message_time'] as DateTime?;
      final bTime = b['last_message_time'] as DateTime?;
      if (aTime == null && bTime == null) {
        final aCreated = DateTime.parse(a['tickets']['created_at']);
        final bCreated = DateTime.parse(b['tickets']['created_at']);
        return bCreated.compareTo(aCreated);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });
  }

  void _setupRealtimeSubscriptions() {
// Cancel existing subscriptions
    _messagesSubscription?.cancel();
    _readStatusSubscription?.cancel();
    if (_chatRooms.isEmpty) return;

    final chatRoomIds = _chatRooms.map((room) => room['id'] as String).toList();

    _messagesSubscription = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .inFilter('chat_room_id', chatRoomIds)
        .listen((data) {
          print('📨 Messages updated via realtime');
          _updateChatRoomsFromMessages(data);
        });

    _readStatusSubscription = supabase
        .from('chat_read_status')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.currentUser.id)
        .listen((data) {
          print('👁️ Read status updated via realtime');
          _updateUnreadCounts();
        });
  }

  void _updateChatRoomsFromMessages(List<Map<String, dynamic>> messages) {
    if (!mounted || _chatRooms.isEmpty) return;
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performChatRoomsUpdate();
    });
  }

  Future<void> _performChatRoomsUpdate() async {
    if (!mounted) return;
    try {
      bool hasChanges = false;

      for (int i = 0; i < _chatRooms.length; i++) {
        final chatRoom = _chatRooms[i];
        final chatRoomId = chatRoom['id'] as String;

        final lastMessageResponse = await supabase
            .from('chat_messages')
            .select(
                'message, created_at, sender_id, users!sender_id(full_name)')
            .eq('chat_room_id', chatRoomId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final currentLastMessage = chatRoom['last_message'] as String?;
        final currentLastTime = chatRoom['last_message_time'] as DateTime?;

        String? newLastMessage;
        DateTime? newLastTime;
        String? newSenderId;
        String? newSenderName;

        if (lastMessageResponse != null) {
          newLastMessage = lastMessageResponse['message'];
          newLastTime = DateTime.parse(lastMessageResponse['created_at']);
          newSenderId = lastMessageResponse['sender_id'];
          final senderData = lastMessageResponse['users'];
          newSenderName = senderData?['full_name'];
        }

        if (newLastMessage != currentLastMessage ||
            newLastTime != currentLastTime) {
          _chatRooms[i] = {
            ...chatRoom,
            'last_message': newLastMessage,
            'last_message_time': newLastTime,
            'last_message_sender_id': newSenderId,
            'last_message_sender_name': newSenderName,
          };
          hasChanges = true;
        }
      }

      final ticketIds =
          _chatRooms.map((room) => room['tickets']['id'] as String).toList();
      final newUnreadCounts = await ChatService.getUnreadCountsForTickets(
          ticketIds, widget.currentUser.id);

      bool unreadChanged = false;
      for (final entry in newUnreadCounts.entries) {
        if ((_unreadCounts[entry.key] ?? 0) != entry.value) {
          unreadChanged = true;
          break;
        }
      }

      if (unreadChanged) {
        for (int i = 0; i < _chatRooms.length; i++) {
          final ticketId = _chatRooms[i]['tickets']['id'];
          _chatRooms[i]['unread_count'] = newUnreadCounts[ticketId] ?? 0;
        }
        hasChanges = true;
      }

      if (hasChanges && mounted) {
        _sortChatRooms(_chatRooms);
        setState(() {
          _unreadCounts = newUnreadCounts;
        });

        if (_messagesSubscription == null) {
          _setupRealtimeSubscriptions();
        }

        print('Chat rooms updated and sorted by recent activity');
      }
    } catch (e) {
      print('Error updating chat rooms: $e');
    }
  }

  Future<void> _updateUnreadCounts() async {
    if (!mounted || _chatRooms.isEmpty) return;
    try {
      final ticketIds =
          _chatRooms.map((room) => room['tickets']['id'] as String).toList();
      final newUnreadCounts = await ChatService.getUnreadCountsForTickets(
          ticketIds, widget.currentUser.id);

      bool hasChanges = false;
      for (final entry in newUnreadCounts.entries) {
        if ((_unreadCounts[entry.key] ?? 0) != entry.value) {
          hasChanges = true;
          break;
        }
      }

      if (hasChanges && mounted) {
        for (int i = 0; i < _chatRooms.length; i++) {
          final ticketId = _chatRooms[i]['tickets']['id'];
          _chatRooms[i]['unread_count'] = newUnreadCounts[ticketId] ?? 0;
        }

        _sortChatRooms(_chatRooms);
        setState(() {
          _unreadCounts = newUnreadCounts;
        });
        print('Unread counts updated, sorted by recent activity');
      }
    } catch (e) {
      print('Error updating unread counts: $e');
    }
  }
}

// ============================================================================
// NEW MOBILE CHAT ROOMS SCREEN
// ============================================================================
class MobileChatRoomsScreen extends StatefulWidget {
  final UserModel currentUser;
  const MobileChatRoomsScreen({super.key, required this.currentUser});
  @override
  State<MobileChatRoomsScreen> createState() => _MobileChatRoomsScreenState();
}

class _MobileChatRoomsScreenState extends State<MobileChatRoomsScreen> {
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = false;
  StreamSubscription? _chatRoomsSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _readStatusSubscription;
  Map<String, int> _unreadCounts = {};
  Timer? _updateTimer;
  bool _hasHandledPendingNavigation = false;
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  /// Handle pending FCM navigation
  Future<void> _handlePendingNavigation() async {
    if (_hasHandledPendingNavigation) return;
    final navigation = FCMService.getPendingNavigation();
    if (navigation == null) return;

    final action = navigation['action'] as String?;
    if (action != 'open_chat') return;

    final chatRoomId = navigation['chat_room_id'] as String?;
    final ticketId = navigation['ticket_id'] as String?;

    if (chatRoomId == null || ticketId == null) {
      FCMService.clearPendingNavigation();
      return;
    }

    print(
        '🎯 Processing FCM chat navigation: room=$chatRoomId, ticket=$ticketId');

// Mark as handled
    _hasHandledPendingNavigation = true;

// Wait a bit to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

// Find the chat room
    final chatRoom = _chatRooms.firstWhere(
      (room) => room['id'] == chatRoomId,
      orElse: () => <String, dynamic>{},
    );

    if (chatRoom.isEmpty) {
      print('⚠️ Chat room not found: $chatRoomId');
      FCMService.clearPendingNavigation();
      return;
    }

    final ticket = chatRoom['tickets'];
    if (ticket == null) {
      print('⚠️ Ticket not found in chat room');
      FCMService.clearPendingNavigation();
      return;
    }

    print('✅ Opening chat room: $chatRoomId');

// Clear the pending navigation BEFORE navigating
    FCMService.clearPendingNavigation();

// Navigate to the chat room
    _onChatRoomSelected(chatRoom, ticket);
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _readStatusSubscription?.cancel();
    _updateTimer?.cancel();
    ChatService.disposeAllStreams();
    super.dispose();
  }

  Future<void> _loadChatRooms() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      print('Loading chat rooms for user type: ${widget.currentUser.userType}');

      List<dynamic> response = await _getChatRoomsQuery();
      print('Found ${response.length} chat rooms');

      final ticketIds = response
          .where((room) => room['tickets'] != null)
          .map((room) => room['tickets']['id'] as String)
          .toList();

      Map<String, int> unreadCounts = {};
      if (ticketIds.isNotEmpty) {
        unreadCounts = await ChatService.getUnreadCountsForTickets(
            ticketIds, widget.currentUser.id);
      }

      List<Map<String, dynamic>> chatRoomsWithLastMessage = [];

      for (final chatRoom in response) {
        final processedRoom =
            await _processChatRoomData(chatRoom, unreadCounts);
        if (processedRoom != null) {
          chatRoomsWithLastMessage.add(processedRoom);
        }
      }

      _sortChatRooms(chatRoomsWithLastMessage);

      if (mounted) {
        setState(() {
          _chatRooms = chatRoomsWithLastMessage;
          _unreadCounts = unreadCounts;
          _isLoading = false;
        });

        // Setup subscriptions after loading
        _setupRealtimeSubscriptions();

        // Handle pending FCM navigation AFTER rooms are loaded
        if (!_hasHandledPendingNavigation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handlePendingNavigation();
          });
        }
      }
    } catch (e) {
      print('Error loading chat rooms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<List<dynamic>> _getChatRoomsQuery() async {
    if (widget.currentUser.userType == UserType.admin) {
      final assignedTickets = await supabase
          .from('chat_rooms')
          .select('''
id, ticket_id,
tickets!inner (
id, ticket_number, title, status, created_by, assigned_to,
target_department_id, place_id, parent_ticket_id, created_at)
''')
          .eq('is_active', true)
          .eq('tickets.assigned_to', widget.currentUser.id)
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
          .eq('tickets.created_by', widget.currentUser.id)
          .inFilter('tickets.status', ['inprogress', 'prefinished']);

      final allTickets = <String, dynamic>{};
      for (final ticket in [...assignedTickets, ...createdTickets]) {
        allTickets[ticket['id']] = ticket;
      }
      return allTickets.values.toList();
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      if (widget.currentUser.departmentId != null) {
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
            .eq('tickets.target_department_id',
                widget.currentUser.departmentId!)
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
            .eq('tickets.created_by', widget.currentUser.id)
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
            .eq('tickets.assigned_to', widget.currentUser.id)
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
            .eq('tickets.created_by', widget.currentUser.id)
            .inFilter('tickets.status', ['inprogress', 'prefinished']);
      }
    } else if (widget.currentUser.userType == UserType.superUser) {
      if (widget.currentUser.placeId != null) {
        final usersInPlace = await supabase
            .from('users')
            .select('id')
            .eq('place_id', widget.currentUser.placeId!)
            .eq('user_type', 'user');

        final userIds = [
          widget.currentUser.id,
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
            .eq('tickets.created_by', widget.currentUser.id)
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
          .eq('tickets.created_by', widget.currentUser.id)
          .inFilter('tickets.status', ['inprogress', 'prefinished']);
    }
  }

  Future<Map<String, dynamic>?> _processChatRoomData(
      Map<String, dynamic> chatRoom, Map<String, int> unreadCounts) async {
    final ticket = chatRoom['tickets'];
    if (ticket == null) return null;

    try {
      final lastMessageResponse = await supabase
          .from('chat_messages')
          .select('message, created_at, sender_id, users!sender_id(full_name)')
          .eq('chat_room_id', chatRoom['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String? lastMessageText;
      DateTime? lastMessageTime;
      String? lastMessageSenderId;
      String? lastMessageSenderName;

      if (lastMessageResponse != null) {
        lastMessageText = lastMessageResponse['message'];
        lastMessageTime = DateTime.parse(lastMessageResponse['created_at']);
        lastMessageSenderId = lastMessageResponse['sender_id'];
        final senderData = lastMessageResponse['users'];
        lastMessageSenderName = senderData?['full_name'];
      }

      final unreadCount = unreadCounts[ticket['id']] ?? 0;

      return {
        ...chatRoom,
        'last_message': lastMessageText,
        'last_message_time': lastMessageTime,
        'last_message_sender_id': lastMessageSenderId,
        'last_message_sender_name': lastMessageSenderName,
        'unread_count': unreadCount,
      };
    } catch (e) {
      print('Error processing chat room ${chatRoom['id']}: $e');
      return null;
    }
  }

  void _sortChatRooms(List<Map<String, dynamic>> chatRooms) {
    chatRooms.sort((a, b) {
      final aTime = a['last_message_time'] as DateTime?;
      final bTime = b['last_message_time'] as DateTime?;

      if (aTime == null && bTime == null) {
        final aCreated = DateTime.parse(a['tickets']['created_at']);
        final bCreated = DateTime.parse(b['tickets']['created_at']);
        return bCreated.compareTo(aCreated);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });
  }

  void _setupRealtimeSubscriptions() {
    if (_chatRooms.isEmpty) return;

    final chatRoomIds = _chatRooms.map((room) => room['id'] as String).toList();

    _messagesSubscription = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .inFilter('chat_room_id', chatRoomIds)
        .listen((data) {
          print('Messages updated via realtime');
          _updateChatRoomsFromMessages(data);
        });

    _readStatusSubscription = supabase
        .from('chat_read_status')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.currentUser.id)
        .listen((data) {
          print('Read status updated via realtime');
          _updateUnreadCounts();
        });
  }

  void _updateChatRoomsFromMessages(List<Map<String, dynamic>> messages) {
    if (!mounted || _chatRooms.isEmpty) return;

    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performChatRoomsUpdate();
    });
  }

  Future<void> _performChatRoomsUpdate() async {
    if (!mounted) return;

    try {
      bool hasChanges = false;

      for (int i = 0; i < _chatRooms.length; i++) {
        final chatRoom = _chatRooms[i];
        final chatRoomId = chatRoom['id'] as String;

        final lastMessageResponse = await supabase
            .from('chat_messages')
            .select(
                'message, created_at, sender_id, users!sender_id(full_name)')
            .eq('chat_room_id', chatRoomId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final currentLastMessage = chatRoom['last_message'] as String?;
        final currentLastTime = chatRoom['last_message_time'] as DateTime?;

        String? newLastMessage;
        DateTime? newLastTime;
        String? newSenderId;
        String? newSenderName;

        if (lastMessageResponse != null) {
          newLastMessage = lastMessageResponse['message'];
          newLastTime = DateTime.parse(lastMessageResponse['created_at']);
          newSenderId = lastMessageResponse['sender_id'];
          final senderData = lastMessageResponse['users'];
          newSenderName = senderData?['full_name'];
        }

        if (newLastMessage != currentLastMessage ||
            newLastTime != currentLastTime) {
          _chatRooms[i] = {
            ...chatRoom,
            'last_message': newLastMessage,
            'last_message_time': newLastTime,
            'last_message_sender_id': newSenderId,
            'last_message_sender_name': newSenderName,
          };
          hasChanges = true;
        }
      }

      final ticketIds =
          _chatRooms.map((room) => room['tickets']['id'] as String).toList();
      final newUnreadCounts = await ChatService.getUnreadCountsForTickets(
          ticketIds, widget.currentUser.id);

      bool unreadChanged = false;
      for (final entry in newUnreadCounts.entries) {
        if ((_unreadCounts[entry.key] ?? 0) != entry.value) {
          unreadChanged = true;
          break;
        }
      }

      if (unreadChanged) {
        for (int i = 0; i < _chatRooms.length; i++) {
          final ticketId = _chatRooms[i]['tickets']['id'];
          _chatRooms[i]['unread_count'] = newUnreadCounts[ticketId] ?? 0;
        }
        hasChanges = true;
      }

      if (hasChanges && mounted) {
        _sortChatRooms(_chatRooms);
        setState(() {
          _unreadCounts = newUnreadCounts;
        });

        if (_messagesSubscription == null) {
          _setupRealtimeSubscriptions();
        }

        print('Chat rooms updated and sorted by recent activity');
      }
    } catch (e) {
      print('Error updating chat rooms: $e');
    }
  }

  Future<void> _updateUnreadCounts() async {
    if (!mounted || _chatRooms.isEmpty) return;

    try {
      final ticketIds =
          _chatRooms.map((room) => room['tickets']['id'] as String).toList();
      final newUnreadCounts = await ChatService.getUnreadCountsForTickets(
          ticketIds, widget.currentUser.id);

      bool hasChanges = false;
      for (final entry in newUnreadCounts.entries) {
        if ((_unreadCounts[entry.key] ?? 0) != entry.value) {
          hasChanges = true;
          break;
        }
      }

      if (hasChanges && mounted) {
        for (int i = 0; i < _chatRooms.length; i++) {
          final ticketId = _chatRooms[i]['tickets']['id'];
          _chatRooms[i]['unread_count'] = newUnreadCounts[ticketId] ?? 0;
        }

        _sortChatRooms(_chatRooms);
        setState(() {
          _unreadCounts = newUnreadCounts;
        });
        print('Unread counts updated, sorted by recent activity');
      }
    } catch (e) {
      print('Error updating unread counts: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
        return AppColors.secondary;
      case 'prefinished':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      case 'wrong_info':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'inprogress':
        return l10n.inProgress;
      case 'prefinished':
        return l10n.prefinished;
      case 'closed':
        return l10n.closed;
      case 'wrong_info':
        return l10n.wrongInfo;
      default:
        return status;
    }
  }

  String _getLastMessagePreview(
      Map<String, dynamic> chatRoom, AppLocalizations l10n) {
    final lastMessage = chatRoom['last_message'] as String?;
    final senderId = chatRoom['last_message_sender_id'] as String?;
    final senderName = chatRoom['last_message_sender_name'] as String?;

    if (lastMessage == null) return l10n.noMessagesYet;

    final isMe = senderId == widget.currentUser.id;
    final displayName =
        isMe ? l10n.you : (senderName?.split(' ').first ?? l10n.someone);

    final truncated = lastMessage.length > 35
        ? '${lastMessage.substring(0, 35)}...'
        : lastMessage;

    return '$displayName: $truncated';
  }

  String _getLastMessageTime(
      Map<String, dynamic> chatRoom, AppLocalizations l10n) {
    final lastMessageTime = chatRoom['last_message_time'] as DateTime?;

    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessageTime.toLocal());

    if (difference.inDays > 7) {
      return DateFormat('MMM dd').format(lastMessageTime.toLocal());
    } else if (difference.inDays > 0) {
      return '${difference.inDays}${l10n.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}${l10n.hour}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}${l10n.minute}';
    } else {
      return l10n.now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.chatRooms,
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        surfaceTintColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          if (_unreadCounts.values.any((count) => count > 0))
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCounts.values
                          .fold(0, (sum, count) => sum + count)
                          .toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh,
                color: AppColors.secondary,
              ),
              onPressed: _loadChatRooms,
              tooltip: l10n.refresh,
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingChatRooms,
                    style: TextStyle(
                      color: AppColors.onBackground.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _chatRooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noActiveChatRooms,
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.chatRoomsAppearWhenTicketsInProgress,
                        style: TextStyle(
                          color: AppColors.onBackground.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.secondary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.recentConversations,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onBackground,
                              ),
                            ),
                          ),
                          if (_unreadCounts.values.any((count) => count > 0))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_unreadCounts.values.fold(0, (sum, count) => sum + count)} ${l10n.unread}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Chat rooms list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _chatRooms.length,
                        itemBuilder: (context, index) {
                          final chatRoom = _chatRooms[index];
                          final ticket = chatRoom['tickets'];

                          if (ticket == null) {
                            return const SizedBox.shrink();
                          }

                          final unreadCount =
                              chatRoom['unread_count'] as int? ?? 0;
                          final hasUnread = unreadCount > 0;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: hasUnread
                                  ? AppColors.primary.withOpacity(0.05)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasUnread
                                    ? AppColors.primary.withOpacity(0.2)
                                    : AppColors.secondary.withOpacity(0.1),
                                width: hasUnread ? 2 : 1,
                              ),
                              boxShadow: hasUnread
                                  ? [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _onChatRoomSelected(chatRoom, ticket),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                  ticket['status']),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                        ticket['status'])
                                                    .withOpacity(0.3),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _getStatusColor(
                                                          ticket['status'])
                                                      .withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                ticket['ticket_number']
                                                    .toString()
                                                    .substring(3, 6),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (hasUnread)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppColors.background,
                                                    width: 2,
                                                  ),
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 20,
                                                        minHeight: 20),
                                                child: Text(
                                                  unreadCount > 99
                                                      ? '99+'
                                                      : unreadCount.toString(),
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
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ticket['ticket_number'],
                                                    style: TextStyle(
                                                      fontWeight: hasUnread
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      color: AppColors
                                                          .onBackground,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _getLastMessageTime(
                                                      chatRoom, l10n),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: hasUnread
                                                        ? AppColors.primary
                                                        : AppColors.onBackground
                                                            .withOpacity(0.6),
                                                    fontWeight: hasUnread
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              ticket['title'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: hasUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: AppColors.onBackground
                                                    .withOpacity(0.8),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _getLastMessagePreview(
                                                  chatRoom, l10n),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: hasUnread
                                                    ? AppColors.onBackground
                                                        .withOpacity(0.8)
                                                    : AppColors.onBackground
                                                        .withOpacity(0.6),
                                                fontWeight: hasUnread
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                        ticket['status'])
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: _getStatusColor(
                                                          ticket['status'])
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                _formatStatus(
                                                    ticket['status'], l10n),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _getStatusColor(
                                                      ticket['status']),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _onChatRoomSelected(
      Map<String, dynamic> chatRoom, Map<String, dynamic> ticket) async {
    final chatRoomId = chatRoom['id'] as String;
    final ticketId = ticket['id'] as String;

    // Mark as read first
    try {
      await ChatService.markChatAsRead(chatRoomId, widget.currentUser.id);
      if (mounted) {
        setState(() {
          _unreadCounts[ticketId] = 0;
          final roomIndex =
              _chatRooms.indexWhere((room) => room['id'] == chatRoomId);
          if (roomIndex != -1) {
            _chatRooms[roomIndex]['unread_count'] = 0;
          }
        });
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    }

    // Navigate to full-screen chat
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatWidget(
            chatRoomId: chatRoomId,
            currentUser: widget.currentUser,
            isFullScreen: true,
            ticketNumber: ticket['ticket_number'],
            ticketTitle: ticket['title'],
            onMessageSent: () {
              // Refresh chat rooms when returning
              _loadChatRooms();
            },
          ),
        ),
      );
    }
  }
}
