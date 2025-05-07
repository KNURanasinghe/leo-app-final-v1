import 'package:flutter/material.dart';
import 'package:leo_app_01/services/api_service.dart';
import 'package:leo_app_01/widgets/status_share_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/status_model.dart';
import '../services/socket_service.dart';
import 'package:video_player/video_player.dart';

class StatusViewScreen extends StatefulWidget {
  final String currentUserId;
  final String statusUserId;
  final String? userName;
  final String imageUrl;

  const StatusViewScreen(
      {super.key,
      required this.currentUserId,
      required this.statusUserId,
      required this.userName,
      required this.imageUrl});

  @override
  _StatusViewScreenState createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen> {
  final SocketService _socketService = SocketService();
  final UserApiService _userApiService =
      UserApiService(baseUrl: 'http://145.223.21.62:8090');
  final TextEditingController _replyController = TextEditingController();
  List<Status> _statuses = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isReplying = false;

  // PageController for TikTok-style vertical scrolling
  late PageController _pageController;

  // Video player controllers map - one for each status
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _videoInitialized = {};
  final Map<int, String?> _videoErrors = {};
  final Map<int, bool> _downloadingVideos = {};
  final Map<int, double> _downloadProgress = {};

  final Map<String, bool> _likedStatuses = {};
  final Map<String, int> _likesCounts = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupSocketListeners();
    _loadStatuses();
  }

  void _showStatusLikesDialog() {
    final currentStatus = _statuses[_currentIndex];

    _socketService.getStatusLikes(currentStatus.statusId);
  }

  void _setupSocketListeners() {
    _socketService.onUserStatuses = (userId, statuses) {
      if (userId == widget.statusUserId) {
        setState(() {
          _statuses = statuses;
          _isLoading = false;
        });

        // Initialize the first status
        if (_statuses.isNotEmpty) {
          _preloadStatus(0);

          // Check if current user has liked each status
          for (var status in statuses) {
            _checkStatusLike(status.statusId);
          }

          // Preload the next status if available
          if (_statuses.length > 1) {
            _preloadStatus(1, autoPlay: false);
          }
        }
      }
    };
    _socketService.onStatusLikeStatus = (statusId, hasLiked, likeCount) {
      setState(() {
        _likedStatuses[statusId] = hasLiked;
        _likesCounts[statusId] = likeCount;
      });
    };

    _socketService.onStatusLiked = (statusId, likeCount) {
      setState(() {
        _likedStatuses[statusId] = true;
        _likesCounts[statusId] = likeCount;
      });
    };

    _socketService.onStatusUnliked = (statusId, likeCount) {
      setState(() {
        _likedStatuses[statusId] = false;
        _likesCounts[statusId] = likeCount;
      });
    };
    _socketService.onStatusLikes = (statusId, likedBy, likeCount) async {
      _socketService.onStatusLikes = (statusId, likedBy, likeCount) async {
        if (mounted) {
          showModalBottomSheet(
            backgroundColor: const Color(0xff111014),
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32.0),
                topRight: Radius.circular(32.0),
              ),
            ),
            isDismissible: true,
            isScrollControlled: true,
            builder: (BuildContext context) {
              // We'll use this map to store user info as it's loaded
              Map<String, User> usersMap = {};

              return StatefulBuilder(
                builder:
                    (BuildContext context, StateSetter setBottomSheetState) {
                  // Fetch user data for each ID
                  for (String userId in likedBy) {
                    // Only fetch if we haven't already
                    if (!usersMap.containsKey(userId)) {
                      // Set a placeholder while loading
                      setBottomSheetState(() {});

                      // Fetch the actual data
                      _userApiService.getUserById(userId).then((user) {
                        setBottomSheetState(() {
                          usersMap[userId] = user;
                        });
                      }).catchError((error) {
                        print('Error fetching user $userId: $error');
                        setBottomSheetState(() {
                          // Create a placeholder user
                          usersMap[userId] = User(
                            id: userId,
                            firstname: 'User',
                            lastname: userId.substring(0, 4),
                            phonenumber: 0,
                            moto: '',
                            bio: '',
                            wallet: 0,
                            country: '',
                            gender: '',
                            is_notification_off: false,
                            player_id: '',
                            is_admin: false,
                          );
                        });
                      });
                    }
                  }

                  return AnimatedPadding(
                    padding: MediaQuery.of(context).viewInsets,
                    duration: const Duration(milliseconds: 50),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Add a drag handle at the top
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          // Title
                          Center(
                            child: Text(
                              'Likes ($likeCount)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Content
                          likedBy.isEmpty
                              ? const Center(
                                  child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No likes yet',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ))
                              : Container(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                            0.5,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: likedBy.length,
                                    itemBuilder: (context, index) {
                                      final userId = likedBy[index];
                                      final user = usersMap[userId];
                                      final bool isLoading = user == null;

                                      return SizedBox(
                                        height: 60,
                                        child: Center(
                                          child: ListTile(
                                            leading: user?.profileImage !=
                                                        null &&
                                                    user!
                                                        .profileImage.isNotEmpty
                                                ? CircleAvatar(
                                                    backgroundImage: NetworkImage(
                                                        'http://145.223.21.62:8090/api/files/users/$userId/${user.profileImage}'),
                                                    onBackgroundImageError:
                                                        (_, __) => const Icon(
                                                            Icons.person,
                                                            color:
                                                                Colors.white),
                                                  )
                                                : const CircleAvatar(
                                                    backgroundColor:
                                                        Colors.grey,
                                                    child: Icon(Icons.person,
                                                        color: Colors.white),
                                                  ),
                                            title: Text(
                                              isLoading
                                                  ? 'Loading...'
                                                  : '${user.firstname} ${user.lastname}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            subtitle: isLoading
                                                ? const LinearProgressIndicator(
                                                    backgroundColor:
                                                        Colors.grey,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          // Close button
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
      };
    };
  }

  void _checkStatusLike(String statusId) {
    _socketService.checkStatusLike(widget.currentUserId, statusId);
  }

  void _handleLikeStatus(bool isCurrentlyLiked) {
    final currentStatus = _statuses[_currentIndex];
    _socketService.likeStatus(widget.currentUserId, currentStatus.statusId);

    // Show message based on what the NEW state will be (opposite of current)
    if (!isCurrentlyLiked) {
      // If it wasn't liked and we're liking it now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liked status')),
      );
    } else {
      // If it was liked and we're unliking it now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unliked status')),
      );
    }
  }

  void _loadStatuses() {
    _socketService.getUserStatuses(widget.statusUserId);
  }

  void _onPageChanged(int index) {
    // Pause current video if any
    if (_videoControllers[_currentIndex] != null &&
        _videoControllers[_currentIndex]!.value.isInitialized &&
        _videoControllers[_currentIndex]!.value.isPlaying) {
      _videoControllers[_currentIndex]!.pause();
    }

    setState(() {
      _currentIndex = index;
      _isReplying = false;
    });

    // Play current video
    _preloadStatus(index);

    // Preload next video if available
    if (index < _statuses.length - 1) {
      _preloadStatus(index + 1, autoPlay: false);
    }

    // Preload previous video if available
    if (index > 0) {
      _preloadStatus(index - 1, autoPlay: false);
    }

    // Dispose videos that are far away
    for (int i = 0; i < _statuses.length; i++) {
      if (i < index - 1 || i > index + 1) {
        _disposeVideoController(i);
      }
    }
  }

  void _preloadStatus(int index, {bool autoPlay = true}) {
    if (index < 0 || index >= _statuses.length) return;

    final status = _statuses[index];

    // If this is a video status that hasn't been initialized yet
    if (status.statusType == 'video' &&
        status.fileUrl != null &&
        status.fileUrl!.isNotEmpty &&
        (_videoControllers[index] == null || !_videoInitialized[index]!)) {
      _handleVideoPlayback(status.fileUrl!, index, autoPlay: autoPlay);
    }
  }

  Future<void> _handleVideoPlayback(String videoUrl, int index,
      {bool autoPlay = true}) async {
    try {
      setState(() {
        _videoInitialized[index] = false;
        _downloadingVideos[index] = true;
        _downloadProgress[index] = 0.0;
      });

      print('Preparing video at index $index: $videoUrl');

      // First try direct network playback
      await _tryDirectVideoPlayback(videoUrl, index, autoPlay: autoPlay);
    } catch (e) {
      print('Direct video playback failed for index $index: $e');

      // If direct playback fails, try downloading and using a local file
      try {
        await _downloadAndPlayVideo(videoUrl, index, autoPlay: autoPlay);
      } catch (e) {
        print('Local video playback failed for index $index: $e');
        setState(() {
          _videoErrors[index] =
              'Video playback not supported on this device: $e';
          _downloadingVideos[index] = false;
        });
      }
    }
  }

  Future<void> _tryDirectVideoPlayback(String videoUrl, int index,
      {bool autoPlay = true}) async {
    // Dispose any existing controller
    _disposeVideoController(index);

    _videoControllers[index] = VideoPlayerController.network(
      videoUrl,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );

    // Set up error listener
    bool hasError = false;
    _videoControllers[index]!.addListener(() {
      if (_videoControllers[index]!.value.hasError && !hasError) {
        hasError = true;
        print(
            'Network video error for index $index: ${_videoControllers[index]!.value.errorDescription}');
        throw Exception(_videoControllers[index]!.value.errorDescription);
      }
    });

    // Try to initialize with timeout
    await _videoControllers[index]!.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Video initialization timed out');
      },
    );

    if (_videoControllers[index]!.value.isInitialized) {
      print('Direct network playback successful for index $index');

      // Set video to loop
      await _videoControllers[index]!.setLooping(true);

      // Start playing if autoPlay is true and this is the current index
      if (autoPlay && index == _currentIndex) {
        await _videoControllers[index]!.play();
      }

      setState(() {
        _videoInitialized[index] = true;
        _downloadingVideos[index] = false;
      });
    } else {
      throw Exception('Video failed to initialize properly');
    }
  }

  Future<void> _downloadAndPlayVideo(String videoUrl, int index,
      {bool autoPlay = true}) async {
    setState(() {
      _downloadingVideos[index] = true;
      _downloadProgress[index] = 0.0;
    });

    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName =
          'status_video_${index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final localVideoPath = '${directory.path}/$fileName';

      // Download the file with progress updates
      final response =
          await http.Client().send(http.Request('GET', Uri.parse(videoUrl)));

      final contentLength = response.contentLength ?? 0;
      int bytesReceived = 0;

      final file = File(localVideoPath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress[index] = bytesReceived / contentLength;
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      print('Video downloaded to: $localVideoPath');

      // Dispose existing controller if any
      _disposeVideoController(index);

      // Initialize player with local file
      _videoControllers[index] =
          VideoPlayerController.file(File(localVideoPath));

      await _videoControllers[index]!.initialize();

      if (_videoControllers[index]!.value.isInitialized) {
        // Set video to loop
        await _videoControllers[index]!.setLooping(true);

        // Start playing if autoPlay is true and this is the current index
        if (autoPlay && index == _currentIndex) {
          await _videoControllers[index]!.play();
        }

        setState(() {
          _videoInitialized[index] = true;
          _downloadingVideos[index] = false;
        });
      } else {
        throw Exception('Local video failed to initialize');
      }
    } catch (e) {
      print('Error playing downloaded video for index $index: $e');
      setState(() {
        _videoErrors[index] = 'Error playing video: $e';
        _downloadingVideos[index] = false;
      });
    }
  }

  void _disposeVideoController(int index) {
    if (_videoControllers[index] != null) {
      _videoControllers[index]!.removeListener(() {});
      _videoControllers[index]!.dispose();
      _videoControllers[index] = null;
    }

    _videoInitialized[index] = false;
  }

  void _toggleReplyInput() {
    setState(() {
      _isReplying = !_isReplying;
    });

    if (_isReplying) {
      if (_videoControllers[_currentIndex] != null &&
          _videoControllers[_currentIndex]!.value.isInitialized &&
          _videoControllers[_currentIndex]!.value.isPlaying) {
        _videoControllers[_currentIndex]!.pause();
      }
    } else {
      if (_videoControllers[_currentIndex] != null &&
          _videoControllers[_currentIndex]!.value.isInitialized &&
          !_videoControllers[_currentIndex]!.value.isPlaying) {
        _videoControllers[_currentIndex]!.play();
      }
    }
  }

  void _replyToStatus() {
    if (_replyController.text.trim().isEmpty) return;

    final currentStatus = _statuses[_currentIndex];

    _socketService.replyToStatus(
      statusId: currentStatus.statusId,
      message: _replyController.text.trim(),
      senderId: widget.currentUserId,
      receiverId: widget.statusUserId,
    );

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reply sent')),
    );

    setState(() {
      _isReplying = false;
      _replyController.clear();
    });

    if (_videoControllers[_currentIndex] != null &&
        _videoControllers[_currentIndex]!.value.isInitialized &&
        !_videoControllers[_currentIndex]!.value.isPlaying) {
      _videoControllers[_currentIndex]!.play();
    }
  }

  void _handleShareStatus() {
    final currentStatus = _statuses[_currentIndex];

    // Pause video if playing
    if (_videoControllers[_currentIndex] != null &&
        _videoControllers[_currentIndex]!.value.isInitialized &&
        _videoControllers[_currentIndex]!.value.isPlaying) {
      _videoControllers[_currentIndex]!.pause();
    }

    // Show share dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatusShareDialog(
          statusId: currentStatus.statusId,
          mediaUrl: currentStatus.fileUrl ?? '',
          mediaType: currentStatus.statusType,
          caption: currentStatus.content,
          statusOwnerName: widget.userName ?? 'User',
        );
      },
    ).then((_) {
      // Resume video playback when dialog is closed if needed
      if (_videoControllers[_currentIndex] != null &&
          _videoControllers[_currentIndex]!.value.isInitialized &&
          !_videoControllers[_currentIndex]!.value.isPlaying) {
        _videoControllers[_currentIndex]!.play();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();

    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      if (controller != null) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // title: Text(
        //   widget.userName ?? 'Status',
        //   style: const TextStyle(color: Colors.black),
        // ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _statuses.isEmpty
              ? _buildNoStatus()
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  itemCount: _statuses.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return _buildStatusPage(index);
                  },
                ),
    );
  }

  Widget _buildNoStatus() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'No active status found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPage(int index) {
    final status = _statuses[index];
    print('Status ID: ${status.statusId}');

    final bool isLiked = _likedStatuses[status.statusId] ?? false;
    final int likeCount = _likesCounts[status.statusId] ?? 0;
    print('likecount: ${_likesCounts[status.statusId]}');
    return Stack(
      children: [
        // Status Content (takes full screen)
        Positioned.fill(
          child: _buildStatusContent(status, index),
        ),

        // User info at top
        Positioned(
          top: kToolbarHeight + 20,
          left: 10,
          right: 70,
          child: Row(
            children: [
              if (widget.imageUrl.isNotEmpty)
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  radius: 20,
                )
              else
                const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getTimeAgo(status.timestamp),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (status.userId == widget.currentUserId)
          Positioned(
            top: kToolbarHeight,
            right: 10,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (String value) {
                if (value == 'likes') {
                  _showStatusLikesDialog();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'likes',
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Likes '),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Caption text (if any)
        if (status.content.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 16,
            right: 70, // Leave space for action buttons
            child: Text(
              status.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black54,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (status.userId == widget.currentUserId)
          ...[]
        else
        // Action buttons (like, share, reply)
        if (!_isReplying)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Like button
                _buildActionButton(
                  icon: Icons.favorite,
                  label: 'Like',
                  onTap: () => _handleLikeStatus(isLiked),
                  isActive: isLiked == true ? true : false,
                  count: likeCount,
                ),
                const SizedBox(height: 20),
                // Share button
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: _handleShareStatus,
                ),
                const SizedBox(height: 20),

                // Reply button
                _buildActionButton(
                  icon: Icons.reply,
                  label: 'Reply',
                  onTap: _toggleReplyInput,
                ),
              ],
            ),
          ),

        // Reply input (when active)
        if (_isReplying)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildReplyInput(),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.red : Colors.black38,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count != null && count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.red : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(Status status, int index) {
    switch (status.statusType) {
      case 'image':
        return GestureDetector(
          onTap: () {
            // Toggle play/pause for video on tap
            if (_videoControllers[index] != null &&
                _videoControllers[index]!.value.isInitialized) {
              if (_videoControllers[index]!.value.isPlaying) {
                _videoControllers[index]!.pause();
              } else {
                _videoControllers[index]!.play();
              }
              setState(() {});
            }
          },
          child: Container(
            color: Colors.black,
            child: Image.network(
              status.fileUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                );
              },
            ),
          ),
        );

      case 'video':
        if (_downloadingVideos[index] == true) {
          // Show download progress
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: _downloadProgress[index] != null &&
                          _downloadProgress[index]! > 0
                      ? _downloadProgress[index]
                      : null,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  _downloadProgress[index] != null &&
                          _downloadProgress[index]! > 0
                      ? 'Loading video... ${(_downloadProgress[index]! * 100).toStringAsFixed(0)}%'
                      : 'Loading video...',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        // If there's a video error
        if (_videoErrors[index] != null) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      size: 60,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Video could not be played',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If video is initialized, show the video player
        if (_videoControllers[index] != null &&
            _videoInitialized[index] == true &&
            _videoControllers[index]!.value.isInitialized) {
          return GestureDetector(
            onTap: () {
              // Toggle play/pause on tap
              if (_videoControllers[index]!.value.isPlaying) {
                _videoControllers[index]!.pause();
              } else {
                _videoControllers[index]!.play();
              }
              setState(() {});
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: _videoControllers[index]!.value.aspectRatio,
                    child: VideoPlayer(_videoControllers[index]!),
                  ),
                ),

                // Play/pause overlay
                if (!_videoControllers[index]!.value.isPlaying)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          );
        }

        // Loading state
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );

      case 'text':
      default:
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Widget _buildReplyInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: const InputDecoration(
                hintText: 'Reply to status...',
                border: InputBorder.none,
              ),
              autofocus: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.green),
            onPressed: _replyToStatus,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _toggleReplyInput,
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final statusTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(statusTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Yesterday';
    }
  }
}
