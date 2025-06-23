import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import '../voiceRoom/inroom_message.dart';

class InlineMessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final String currentUserId;
  final int
      maxVisibleMessages; // Now used for auto-scroll threshold, not limiting display
  final Widget welcome;
  final bool historyLoaded;
  final VoidCallback? onLoadMoreHistory;

  const InlineMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.maxVisibleMessages = 5,
    required this.welcome,
    this.historyLoaded = true,
    this.onLoadMoreHistory,
  });

  @override
  State<InlineMessageList> createState() => _InlineMessageListState();
}

class _InlineMessageListState extends State<InlineMessageList> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _showScrollToBottom = false;
  bool _isLoadingMore = false;
  bool _isUserScrolling = false; // Track if user is manually scrolling

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.messages.length;
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isAtBottom = currentScroll >= maxScroll - 100;

    // Show/hide scroll to bottom button
    if (_showScrollToBottom != !isAtBottom) {
      setState(() {
        _showScrollToBottom = !isAtBottom;
      });
    }

    // Detect user scrolling (not at bottom means user is scrolling)
    _isUserScrolling = !isAtBottom;

    // Load more messages when scrolled to top
    if (currentScroll <= 100 &&
        !_isLoadingMore &&
        widget.onLoadMoreHistory != null &&
        widget.messages.isNotEmpty) {
      _loadMoreHistory();
    }
  }

  void _loadMoreHistory() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Store current scroll position to maintain it after loading
    final currentScrollPosition = _scrollController.position.pixels;
    final oldMessageCount = widget.messages.length;

    widget.onLoadMoreHistory?.call();

    // Wait a bit for new messages to load, then adjust scroll position
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });

      // Maintain scroll position after loading more messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            widget.messages.length > oldMessageCount) {
          final newMessagesCount = widget.messages.length - oldMessageCount;
          final estimatedNewHeight =
              newMessagesCount * 80.0; // Estimate message height
          _scrollController.jumpTo(currentScrollPosition + estimatedNewHeight);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // **FIXED: Show ALL messages, not just the last 5**
    final visibleMessages = widget.messages;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Stack(
        children: [
          Column(
            children: [
              // Loading history indicator
              if (!widget.historyLoaded)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading chat history...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Load more indicator at the top
              if (_isLoadingMore)
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading more messages...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'poppins',
                        ),
                      ),
                    ],
                  ),
                ),

              // **FIXED: Messages list showing ALL messages**
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      visibleMessages.length + 1, // +1 for welcome widget
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return widget.welcome;
                    }
                    final message = visibleMessages[index - 1];
                    return _buildMessageItem(
                      message,
                      message.userId == widget.currentUserId,
                      context,
                    );
                  },
                ),
              ),
            ],
          ),

          // Scroll to bottom button
          if (_showScrollToBottom)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => _scrollToBottom(animate: true),
                backgroundColor: Colors.blue.withOpacity(0.8),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ),
            ),

          // **ENHANCED: Message count indicator**
          // if (widget.messages.isNotEmpty)
          //   Positioned(
          //     top: 8,
          //     right: 16,
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withOpacity(0.7),
          //         borderRadius: BorderRadius.circular(12),
          //         border: Border.all(color: Colors.white24),
          //       ),
          //       child: Text(
          //         '${widget.messages.length} messages',
          //         style: const TextStyle(
          //           color: Colors.white70,
          //           fontSize: 10,
          //           fontFamily: 'poppins',
          //         ),
          //       ),
          //     ),
          //   ),

          // **NEW: Scroll indicator to show position**
          // if (widget.messages.length > 10)
          //   Positioned(
          //     top: 8,
          //     left: 16,
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withOpacity(0.7),
          //         borderRadius: BorderRadius.circular(12),
          //         border: Border.all(color: Colors.white24),
          //       ),
          //       child: Text(
          //         _isUserScrolling ? '📜 Viewing History' : '💬 Live Chat',
          //         style: const TextStyle(
          //           color: Colors.white70,
          //           fontSize: 10,
          //           fontFamily: 'poppins',
          //         ),
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _scrollToBottom(animate: animate);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
        _isUserScrolling = false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant InlineMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // **ENHANCED: Only auto-scroll if user is not manually scrolling and new messages arrive**
    if (widget.messages.length > _lastMessageCount && !_isUserScrolling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });
    }
    _lastMessageCount = widget.messages.length;
  }

  Widget _buildMessageItem(
      ChatMessage message, bool isCurrentUser, BuildContext context) {
    // Handle system messages
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message, context);
    }

    // Handle entry messages
    if (message.type == MessageType.entry) {
      return _buildEntryMessage(message, isCurrentUser, context);
    }

    // Special handling for gift messages
    if (message.type == MessageType.gift) {
      return _buildGiftMessageItem(message, isCurrentUser, context);
    }

    // Regular message handling
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentUser ? "You" : message.userName,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                decoration: TextDecoration.none,
                fontFamily: 'poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
                fontSize: 14,
                decoration: TextDecoration.none,
                fontFamily: 'poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // System message widget
  Widget _buildSystemMessage(ChatMessage message, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Text(
            message.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none,
              fontFamily: 'poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Entry message widget
  Widget _buildEntryMessage(
      ChatMessage message, bool isCurrentUser, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        children: [
          // Entry animation if itemUrl is provided
          // Uncomment if you want to show entry animations
          // if (message.itemUrl != null && message.itemUrl!.isNotEmpty)
          //   Container(
          //     height: 80,
          //     alignment: Alignment.center,
          //     margin: const EdgeInsets.only(bottom: 8),
          //     child: SVGASimpleImage(resUrl: message.itemUrl!),
          //   ),

          // Entry message
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.purple.withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.avatarUrl!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  isCurrentUser ? "You" : message.userName,
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                    fontFamily: 'poppins',
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  message.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                    fontFamily: 'poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Gift message widget
  Widget _buildGiftMessageItem(
      ChatMessage message, bool isCurrentUser, BuildContext context) {
    final giftData = message.giftData;
    if (giftData == null) return Container();

    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(0.8),
              Colors.pink.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white54, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gift header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCurrentUser ? 'GIFT SENT' : 'GIFT RECEIVED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                    fontFamily: 'poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Gift details
            Row(
              children: [
                // Gift animation
                if (giftData.giftUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: SVGASimpleImage(resUrl: giftData.giftUrl!),
                    ),
                  ),
                const SizedBox(width: 12),

                // Gift info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'poppins',
                            decoration: TextDecoration.none,
                          ),
                          children: [
                            TextSpan(
                              text: isCurrentUser ? 'You' : message.userName,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: ' sent ',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text:
                                  '${giftData.giftCount}x ${giftData.giftName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: ' to ',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: giftData.receiverUserName,
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Cost display with diamond icon
                      Row(
                        children: [
                          Image.asset(
                            'assets/diamond.png',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${giftData.totalCost}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                              fontFamily: 'poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
