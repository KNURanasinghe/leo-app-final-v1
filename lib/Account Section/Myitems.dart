import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:leo_app_01/services/rive_service.dart';
import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

import '../services/pb_service.dart';

class StoreScreen extends StatefulWidget {
  final bool startWithMyItems;
  const StoreScreen({super.key, this.startWithMyItems = false});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  // App bar state
  String appBarTitle = "Store";
  bool isViewingMyItems = false;

  // Tab state
  late TabController _tabController;
  final List<String> _tabs = ["Frames", "Themes", "Entry Effects"];

  // Data state
  bool isLoading = false;
  List<RecordModel> storeItems = [];
  List<RecordModel> myItems = [];
  int currentPage = 1;
  int totalPages = 1;
  int totalItems = 0;
  final int pageSize = 10;

  // Search state
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

  // PocketBase setup
  static const String baseUrl = 'http://145.223.21.62:8090';
  final PocketBase pb = PbService.instance.pb;
  String? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    if (widget.startWithMyItems) {
      isViewingMyItems = true;
      appBarTitle = "Mine";
    }
    _initialize();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      loadItems();
    }
  }

  Future<void> _initialize() async {
    userId = await HttpService.getUserId();
    loadItems();
  }

  void toggleViewMode() {
    setState(() {
      isViewingMyItems = !isViewingMyItems;
      appBarTitle = isViewingMyItems ? "Mine" : "Store";
      currentPage = 1; // Reset to first page
      isSearching = false; // Reset search
      searchController.clear();
    });
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (isViewingMyItems) {
        await loadMyItems();
      } else {
        await loadStoreItems();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load items: $e')),
      );
    }
  }

  String getFilterForCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return 'is_border=true';
      case 1:
        return 'is_theme=true';
      case 2:
        return 'is_rive=true';
      default:
        return '';
    }
  }

  Future<void> loadStoreItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get filter based on current tab
      String filter = getFilterForCurrentTab();

      // Fetch items from item_collection
      final result = await pb.collection('item_collection').getList(
            page: currentPage,
            perPage: pageSize,
            sort: '-created',
            filter: filter,
          );

      setState(() {
        storeItems = result.items;
        totalPages = result.totalPages;
        totalItems = result.totalItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load store items: $e')),
      );
    }
  }

  Future<void> loadMyItems() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to view your items')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Get filter based on current tab
      String tabFilter = getFilterForCurrentTab();
      String filter = 'userId = "$userId" && $tabFilter';

      // For search queries
      if (isSearching && searchController.text.isNotEmpty) {
        filter += ' && name ~ "${searchController.text}"';
      }

      // Fetch items from myItems where userId matches current user and the appropriate type filter
      final result = await pb.collection('myItems').getList(
            page: currentPage,
            perPage: pageSize,
            sort: '-created',
            filter: filter,
          );

      setState(() {
        myItems = result.items;
        totalPages = result.totalPages;
        totalItems = result.totalItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load your items: $e')),
      );
    }
  }

  Future<void> searchItems(String query) async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
      isSearching = true;
      currentPage = 1; // Reset to first page for search
    });

    // Loading with search is handled in loadMyItems()
    loadMyItems();
  }

  Future<void> buyItem(RecordModel item) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to purchase items')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // First, create a simpler data structure with just the basic information
      final Map<String, dynamic> data = {
        'name': item.data['name'],
        'price': item.data['price'],
        'userId': userId,
        'is_used': false,
        'isborder_used': false,
      };

      // Set the appropriate type flags based on the source item
      if (item.data['is_rive'] != null) {
        data['is_rive'] = item.data['is_rive'];
      }

      if (item.data['is_border'] != null) {
        data['is_border'] = item.data['is_border'];
      }

      if (item.data['is_theme'] != null) {
        data['is_theme'] = item.data['is_theme'];
      }

      // Include image if present
      if (item.data['image'] != null) {
        data['image'] = item.data['image'];
      }

      // Create the record first without file references
      final createdRecord = await pb.collection('myItems').create(body: data);

      // Now handle file references separately if they exist
      List<Future> fileTransfers = [];

      // If there's a rive_file, transfer it
      if (item.data['rive_file'] != null) {
        final sourceUrl =
            '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['rive_file']}';
        fileTransfers.add(
            _transferFileToRecord(sourceUrl, createdRecord.id, 'rive_file'));
      }

      // If there's a border, transfer it
      if (item.data['border'] != null) {
        final sourceUrl =
            '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['border']}';
        fileTransfers
            .add(_transferFileToRecord(sourceUrl, createdRecord.id, 'border'));
      }

      // If there's a theme, transfer it
      if (item.data['theme'] != null) {
        final sourceUrl =
            '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['theme']}';
        fileTransfers
            .add(_transferFileToRecord(sourceUrl, createdRecord.id, 'theme'));
      }

      // Wait for all file transfers to complete
      if (fileTransfers.isNotEmpty) {
        await Future.wait(fileTransfers);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item purchased successfully!')),
      );

      // Switch to My Items tab and reload
      setState(() {
        isViewingMyItems = true;
        appBarTitle = "Mine";
        isLoading = false;
      });
      loadMyItems();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to purchase item: $e')),
      );
    }
  }

  // Helper method to transfer files from one record to another
  Future<void> _transferFileToRecord(
      String sourceUrl, String recordId, String fieldName) async {
    try {
      // Download the file from the source URL
      final response = await http.get(Uri.parse(sourceUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file from $sourceUrl');
      }

      // Create a form data request to upload the file
      final request = http.MultipartRequest('PATCH',
          Uri.parse('$baseUrl/api/collections/myItems/records/$recordId'));

      // Create a multipart file from the response bytes
      final filename = sourceUrl.split('/').last;
      final multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        response.bodyBytes,
        filename: filename,
        contentType: MediaType.parse(_getContentType(filename)),
      );

      // Add the file to the request
      request.files.add(multipartFile);

      // Send the request
      final uploadResponse = await request.send();

      if (uploadResponse.statusCode != 200) {
        final responseBody = await uploadResponse.stream.bytesToString();
        throw Exception('Failed to upload file: $responseBody');
      }
    } catch (e) {
      print('Error transferring file: $e');
      rethrow;
    }
  }

  // Helper to determine content type based on filename
  String _getContentType(String filename) {
    if (filename.endsWith('.svga')) {
      return 'application/octet-stream';
    } else if (filename.endsWith('.png')) {
      return 'image/png';
    } else if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (filename.endsWith('.gif')) {
      return 'image/gif';
    } else {
      return 'application/octet-stream';
    }
  }

  Future<void> markItemAsUsed(String itemId, String itemType) async {
    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> updateData = {};

      // Set the appropriate field based on item type
      switch (_tabController.index) {
        case 0: // Frames
          updateData = {'isborder_used': true};
          break;
        case 1: // Themes
          updateData = {'is_theme_used': true};
          break;
        case 2: // Entry Effects (Rive)
          updateData = {'is_rive_used': true};
          break;
      }

      await pb.collection('myItems').update(itemId, body: updateData);
      loadMyItems(); // Reload to update UI
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark item as used: $e')),
      );
    }
  }

  void nextPage() {
    if (currentPage < totalPages) {
      setState(() {
        currentPage++;
      });
      loadItems();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
      });
      loadItems();
    }
  }

  Widget buildItemGrid(List<RecordModel> items) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isViewingMyItems
                  ? "You haven't purchased any items of this type yet"
                  : "No items available in the store right now",
              style: const TextStyle(fontSize: 16),
            ),
            if (isSearching && isViewingMyItems)
              TextButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    isSearching = false;
                  });
                  loadMyItems();
                },
                child: const Text("Clear Search"),
              )
          ],
        ),
      );
    }

    return Column(
      children: [
        // Grid of items
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              // Determine item type and used status based on current tab
              bool isUsed = false;
              bool hasRiveFile = item.data['rive_file'] != null;
              bool hasBorder = item.data['border'] != null;
              bool hasTheme = item.data['theme'] != null;

              if (isViewingMyItems) {
                switch (_tabController.index) {
                  case 0: // Frames
                    isUsed = item.data['isborder_used'] ?? false;
                    break;
                  case 1: // Themes
                    isUsed = item.data['is_theme_used'] ?? false;
                    break;
                  case 2: // Entry Effects
                    isUsed = item.data['is_rive_used'] ?? false;
                    break;
                }
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Preview container with appropriate content
                      Expanded(
                        child: Stack(
                          children: [
                            // Border frame if available
                            if (hasBorder && _tabController.index == 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SVGASimpleImage(
                                    resUrl:
                                        '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['border']}',
                                  ),
                                ),
                              ),

                            // Theme if available
                            if (hasTheme && _tabController.index == 1)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.network(
                                    '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['theme']}',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                            // Rive animation if available
                            if (hasRiveFile && _tabController.index == 2)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SVGASimpleImage(
                                  resUrl:
                                      '$baseUrl/api/files/${item.collectionId}/${item.id}/${item.data['rive_file']}',
                                ),
                              ),

                            // Fallback if no preview available
                            if ((!hasBorder && _tabController.index == 0) ||
                                (!hasTheme && _tabController.index == 1) ||
                                (!hasRiveFile && _tabController.index == 2))
                              Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child:
                                      Icon(Icons.image_not_supported, size: 40),
                                ),
                              ),

                            // Overlay for used items
                            if (isViewingMyItems && isUsed)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "USED",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Item name
                      Text(
                        item.data["name"] ?? "Unknown Item",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Price
                      Text(
                        "💎 ${item.data['price'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Action Button - Buy or Use
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: isViewingMyItems
                                ? ElevatedButton(
                                    onPressed: isUsed
                                        ? null
                                        : () => markItemAsUsed(item.id,
                                            _tabs[_tabController.index]),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _getButtonColor(_tabController.index),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      "Use ${_getItemTypeName(_tabController.index)}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white),
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: () => buyItem(item),
                                    style: OutlinedButton.styleFrom(
                                      side:
                                          const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      "Buy Now",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Pagination
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: currentPage > 1 ? previousPage : null,
                ),
                Text('$currentPage / $totalPages'),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: currentPage < totalPages ? nextPage : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getButtonColor(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Colors.amber; // Frame
      case 1:
        return Colors.green; // Theme
      case 2:
        return Colors.blue; // Entry Effect
      default:
        return Colors.blue;
    }
  }

  String _getItemTypeName(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return "Frame";
      case 1:
        return "Theme";
      case 2:
        return "Effect";
      default:
        return "Item";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: toggleViewMode,
            child: Text(
              isViewingMyItems ? "Store" : "Mine",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (isViewingMyItems)
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search,
                  color: Colors.white),
              onPressed: () {
                setState(() {
                  isSearching = !isSearching;
                  if (!isSearching) {
                    searchController.clear();
                    loadMyItems();
                  }
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (only for My Items)
          if (isViewingMyItems && isSearching)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    searchItems(value);
                  } else {
                    loadMyItems();
                  }
                },
              ),
            ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.blue,
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Frames tab
                  buildItemGrid(isViewingMyItems ? myItems : storeItems),
                  // Themes tab
                  buildItemGrid(isViewingMyItems ? myItems : storeItems),
                  // Entry Effects tab
                  buildItemGrid(isViewingMyItems ? myItems : storeItems),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
