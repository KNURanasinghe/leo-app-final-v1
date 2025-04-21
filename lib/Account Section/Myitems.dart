import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Import Rive with a prefix to avoid name conflicts
import 'package:rive/rive.dart' as rive;
// Import services
import '../services/rive_service.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String selectedTab = "Leo Store";
  bool isLoading = false;
  List<dynamic> myItems = [];
  int currentPage = 1;
  int totalPages = 1;
  int totalItems = 0;
  final int pageSize = 10; // Number of items per page
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

  static const String baseUrl = 'http://145.223.21.62:8090';

  // Dummy data for store items with network image URLs
  final List<Map<String, dynamic>> storeItems = [
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "1 day",
      "price": 5000,
      "name": "Basic Package"
    },
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "3 days",
      "price": 15000,
      "name": "Standard Package"
    },
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "7 days",
      "price": 35000,
      "name": "Premium Package"
    },
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "7 days",
      "price": 70000,
      "name": "Gold Package"
    },
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "3 days",
      "price": 45000,
      "name": "Silver Package"
    },
    {
      "image": "https://thumbs.dreamstime.com/b/car-gift-22638825.jpg",
      "duration": "7 days",
      "price": 55000,
      "name": "Platinum Package"
    },
  ];

  @override
  void initState() {
    super.initState();
    loadMyItems();
  }

  Future<void> loadMyItems() async {
    if (selectedTab == "My Items") {
      setState(() {
        isLoading = true;
      });

      try {
        final result = await HttpService.getMyItems(
          page: currentPage,
          pageSize: pageSize,
          sortField: 'created', // Sort by creation date
          descending: true, // Most recent first
        );

        setState(() {
          myItems = result['items'];
          totalPages = result['totalPages'];
          totalItems = result['totalItems'];
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load items: $e')),
        );
      }
    }
  }

  Future<void> searchItems(String query) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await HttpService.searchMyItems(
        query: query,
        page: 1, // Start from first page for search
        pageSize: pageSize,
      );

      setState(() {
        myItems = result['items'];
        totalPages = result['totalPages'];
        totalItems = result['totalItems'];
        currentPage = 1; // Reset to first page
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to search items: $e')),
      );
    }
  }

  Future<void> buyItem(Map<String, dynamic> item) async {
    setState(() {
      isLoading = true;
    });

    try {
      await HttpService.purchaseItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item purchased successfully!')),
      );

      // Switch to My Items tab and reload
      setState(() {
        selectedTab = "My Items";
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

  Future<void> markAsUsed(String itemId) async {
    setState(() {
      isLoading = true;
    });

    try {
      await HttpService.markItemAsUsed(itemId);
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
      loadMyItems();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
      });
      loadMyItems();
    }
  }

  Widget buildLeoStore() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: storeItems.length,
      itemBuilder: (context, index) {
        final item = storeItems[index];
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
                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item["image"],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Duration
                Text(
                  item["duration"],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                // Price
                Text(
                  "💰 ${item['price']}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                // Buy Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => buyItem(item),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
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
    );
  }

  Widget buildMyItems() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "You haven't purchased any items yet",
              style: TextStyle(fontSize: 16),
            ),
            if (isSearching)
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
            itemCount: myItems.length,
            itemBuilder: (context, index) {
              final item = myItems[index];
              final bool isUsed = item['is_used'] ?? false;

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
                      // Image or Rive animation
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item['rive_file'] != null
                                  ? rive.RiveAnimation.network(
                                      '$baseUrl/api/files/${item['collectionId']}/${item['id']}/${item['riveFile']}',
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      item["image"] ??
                                          "https://via.placeholder.com/150",
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            ),
                            if (isUsed)
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
                        item["name"] ?? "Unknown Item",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Duration
                      Text(
                        item["duration"] ?? "N/A",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Price
                      Text(
                        "💰 ${item['price'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  isUsed ? null : () => markAsUsed(item['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Use",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                            ),
                          ),
                          // If you want to re-enable the Upload button, uncomment these lines
                          // const SizedBox(width: 8),
                          // Expanded(
                          //   child: OutlinedButton(
                          //     onPressed: () {
                          //       // Show dialog to upload Rive file
                          //       _showUploadDialog(item['id']);
                          //     },
                          //     style: OutlinedButton.styleFrom(
                          //       side: const BorderSide(color: Colors.green),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(8),
                          //       ),
                          //     ),
                          //     child: const Text(
                          //       "Upload",
                          //       style: TextStyle(
                          //           fontSize: 12,
                          //           color: Colors.green,
                          //           fontWeight: FontWeight.bold),
                          //     ),
                          //   ),
                          // ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Uncomment if you want to re-enable the upload dialog
  // void _showUploadDialog(String itemId) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Upload Rive File'),
  //       content: const Text(
  //           'Would you like to upload a Rive animation file for this item?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () async {
  //             Navigator.pop(context);
  //             // Use the file picker service to pick and upload a Rive file
  //             await FilePickerService.pickAndUploadRiveFile(context, itemId);
  //             // Reload my items to show the updated item with Rive file
  //             loadMyItems();
  //           },
  //           child: const Text('Upload'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          "Store",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (selectedTab == "My Items")
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
          // Search bar (only for My Items tab)
          if (selectedTab == "My Items" && isSearching)
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["Leo Store", "My Items"]
                  .map((tab) => InkWell(
                        onTap: () {
                          setState(() {
                            selectedTab = tab;
                            currentPage =
                                1; // Reset to first page when switching tabs
                            isSearching =
                                false; // Reset search when switching tabs
                            searchController.clear();
                          });
                          if (tab == "My Items") {
                            loadMyItems();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == tab
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selectedTab == tab
                                  ? Colors.blue
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child:
                  selectedTab == "Leo Store" ? buildLeoStore() : buildMyItems(),
            ),
          ),
        ],
      ),
    );
  }
}
