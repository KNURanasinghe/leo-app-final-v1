import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Add_Status.dart';

// Constants for API
const String baseUrl = 'http://145.223.21.62:8090';

class Status {
  final String id;
  final String userId;
  final String caption;
  final String? statusImage;
  final String? statusVideo;
  final DateTime created;

  Status({
    required this.id,
    required this.userId,
    required this.caption,
    this.statusImage,
    this.statusVideo,
    required this.created,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['id'],
      userId: json['userId'],
      caption: json['caption'],
      statusImage: json['status_img'],
      statusVideo: json['status_video'],
      created: DateTime.parse(json['created']),
    );
  }

  String getImageUrl() {
    if (statusImage == null) return '';
    return '$baseUrl/api/files/Status/$id/$statusImage';
  }

  String getVideoUrl() {
    if (statusVideo == null) return '';
    return '$baseUrl/api/files/Status/$id/$statusVideo';
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final StoryController controller = StoryController();
  final PageController pageController = PageController();
  List<Status> statuses = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    fetchStatuses();
  }

  Future<void> fetchStatuses() async {
    try {
      final response = await http
          .get(
        Uri.parse('$baseUrl/api/collections/Status/records'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          statuses = (data['items'] as List)
              .map((item) => Status.fromJson(item))
              .toList();
          isLoading = false;
          hasError = false;
        });
      } else {
        throw Exception('Failed to load statuses: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error loading statuses: ${e.toString()}';
      });
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              isLoading = true;
              hasError = false;
            });
            fetchStatuses();
          },
        ),
      ),
    );
  }

  List<StoryItem> _buildStoryItems(Status status) {
    List<StoryItem> items = [];

    // Prioritize video or image over text
    if (status.statusVideo != null && status.statusVideo!.isNotEmpty) {
      items.add(StoryItem.pageVideo(
        status.getVideoUrl(),
        controller: controller,
        caption: Text(
          status.caption,
          style: const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.black54,
            fontSize: 17,
          ),
        ),
        duration: const Duration(seconds: 30), // Adjust duration as needed
      ));
    } else if (status.statusImage != null && status.statusImage!.isNotEmpty) {
      items.add(StoryItem.pageImage(
        url: status.getImageUrl(),
        controller: controller,
        caption: Text(
          status.caption,
          style: const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.black54,
            fontSize: 17,
          ),
        ),
        duration: const Duration(seconds: 5),
      ));
    } else {
      items.add(StoryItem.text(
        title: status.caption,
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoading = true;
                hasError = false;
              });
              fetchStatuses();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              // final result = await Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) => const AddStatusScreen()),
              // );
              // if (result == true) {
              //   setState(() {
              //     isLoading = true;
              //   });
              //   fetchStatuses();
              // }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Error loading statuses',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            hasError = false;
                          });
                          fetchStatuses();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : statuses.isEmpty
                  ? const Center(
                      child: Text(
                        'No statuses yet',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : PageView.builder(
                      scrollDirection: Axis.vertical,
                      controller: pageController,
                      itemCount: statuses.length,
                      onPageChanged: (index) {
                        setState(() {
                          currentPage = index;
                          // Reset controller for the new page
                          controller.pause();
                          controller.play();
                        });
                      },
                      itemBuilder: (context, index) {
                        return Container(
                          color: Colors.black,
                          child: Stack(
                            children: [
                              StoryView(
                                storyItems: _buildStoryItems(statuses[index]),
                                controller: controller,
                                onComplete: () {
                                  // Auto-scroll to next status
                                  if (index < statuses.length - 1) {
                                    pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                onVerticalSwipeComplete: (direction) {
                                  if (direction == Direction.down &&
                                      index > 0) {
                                    pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  } else if (direction == Direction.up &&
                                      index < statuses.length - 1) {
                                    pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                progressPosition: ProgressPosition.top,
                              ),
                              Positioned(
                                bottom: 50,
                                left: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statuses[index].caption,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTimeAgo(statuses[index].created),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class StoryViewPage extends StatelessWidget {
  final List<StoryItem> storyItems;
  final StoryController controller = StoryController();

  StoryViewPage({super.key, required this.storyItems});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StoryView(
          storyItems: storyItems,
          controller: controller,
          onComplete: () {
            Navigator.pop(context);
          },
          onVerticalSwipeComplete: (direction) {
            if (direction == Direction.down) {
              Navigator.pop(context);
            }
          },
          progressPosition: ProgressPosition.top,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
  }
}
