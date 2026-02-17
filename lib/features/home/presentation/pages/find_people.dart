import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_service.dart';
import 'user_profile_sheet.dart';

class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({super.key});

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // State Variables
  List<dynamic> users = [];
  int selectedRadius = 5;
  String searchQuery = "";
  int currentPage = 0;
  bool isLoading = false;
  bool isMoreLoading = false;
  bool hasMore = true;

  // Design Colors
  final Color bgBlack = const Color(0xFF0A0C10);
  final Color cardBg = const Color(0xFF1C2128);
  final Color accentColor = const Color(0xFF2DD4BF);
  final Color borderColor = const Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _fetchNearbyUsers();

    // Pagination logic (Scroll listener)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
        if (!isLoading && !isMoreLoading && hasMore) {
          _fetchMoreUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Logic: Search Debounce ---
  _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = query;
      });
      _fetchNearbyUsers();
    });
  }

  // --- API Calls ---

  Future<void> _fetchNearbyUsers() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
      users.clear();
      hasMore = true;
    });

    try {
      final response = await _apiService.dio.get(
        "/api/sparks/nearby-search", // Make sure backend endpoint matches
        queryParameters: {
          "radius": selectedRadius,
          "name": searchQuery,
          "page": currentPage,
          "size": 15, // Page size
        },
      );

      if (response.data['success'] == true) {
        setState(() {
          users = response.data['data'];
          if (users.length < 15) hasMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMoreUsers() async {
    setState(() => isMoreLoading = true);
    currentPage++;

    try {
      final response = await _apiService.dio.get(
        "/api/profile/nearby",
        queryParameters: {
          "radius": selectedRadius,
          "name": searchQuery,
          "page": currentPage,
          "size": 15,
        },
      );

      if (response.data['success'] == true) {
        List newUsers = response.data['data'];
        setState(() {
          if (newUsers.isEmpty) {
            hasMore = false;
          } else {
            users.addAll(newUsers);
            if (newUsers.length < 15) hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching more: $e");
    } finally {
      setState(() => isMoreLoading = false);
    }
  }

  // --- UI Components ---

  void _showCustomKmDialog() {
    TextEditingController customController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Custom Range", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: customController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter km (e.g. 50)",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: () {
              if (customController.text.isNotEmpty) {
                setState(() => selectedRadius = int.parse(customController.text));
                _fetchNearbyUsers();
                Navigator.pop(context);
              }
            },
            child: const Text("Apply", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      appBar: AppBar(
        backgroundColor: bgBlack,
        elevation: 0,
        title: const Text("Radar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white)),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search people nearby...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: accentColor, size: 20),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),

          // 2. Distance Filter + Custom Button
          _buildDistanceRow(),

          // 3. User List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceRow() {
    final List<int> radiusOptions = [2, 5, 10];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Fixed Options
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: radiusOptions.map((km) {
                bool isSelected = selectedRadius == km;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedRadius = km);
                    _fetchNearbyUsers();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${km}km",
                      style: TextStyle(color: isSelected ? Colors.black : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          // Custom / More Button
          GestureDetector(
            onTap: _showCustomKmDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: !radiusOptions.contains(selectedRadius) ? accentColor : cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                !radiusOptions.contains(selectedRadius) ? "${selectedRadius}km" : "Custom +",
                style: TextStyle(
                  color: !radiusOptions.contains(selectedRadius) ? Colors.black : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("❄️", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(searchQuery.isEmpty ? "Aas paas koi nahi mila" : "No user found with '$searchQuery'",
                style: const TextStyle(color: Colors.white60)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length + (isMoreLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == users.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
          );
        }
        return _buildUserTile(users[index]);
      },
    );
  }

  Widget _buildUserTile(dynamic user) {
    String? imageUrl;
    if (user['profileImage'] != null) {
      if (user['profileImage'] is List && user['profileImage'].isNotEmpty) {
        imageUrl = user['profileImage'][0];
      } else if (user['profileImage'] is String) {
        imageUrl = user['profileImage'];
      }
    }

    String? instaHandle = user['instagram'];
    bool hasInsta = instaHandle != null && instaHandle.isNotEmpty;

    return InkWell(
      onTap: () {
        // Modal open ho raha hai aur sirf ID pass kar rahe hain
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => UserProfileModal(userId: user['id']),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: borderColor,
              backgroundImage: NetworkImage(imageUrl ?? 'https://via.placeholder.com/150'),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['fullName'] ?? "Stranger",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    user['bio'] ?? "Vibe check no bio",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (hasInsta)
                    Row(
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png',
                          height: 14,
                          width: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "@$instaHandle",
                          style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.1), size: 14),
          ],
        ),
      ),
    );
  }
}