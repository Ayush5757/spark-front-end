import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spark/models/nearby_user.dart';
import '../../../../core/network/api_service.dart';
import 'user_profile_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // State Variables (Typed)
  List<NearbyUser> users = [];
  int selectedRadius = 5;
  String searchQuery = "";
  int currentPage = 0;

  // Loading Flags
  bool isLoading = false;
  bool isRefreshing = false;
  bool isMoreLoading = false;
  bool hasMore = true;

  // Design System (Black & Green Theme)
  final Color bgBlack = const Color(0xFF0A0C10);
  final Color cardBg = const Color(0xFF1C2128);
  final Color accentColor = const Color(0xFF2DD4BF);
  final Color borderColor = const Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _fetchInitialUsers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
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

  // API Call: First Load or Refresh
  Future<void> _fetchInitialUsers({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) isLoading = true;
      else isRefreshing = true;
      currentPage = 0;
      users.clear(); // Clear existing list on new search/radius
      hasMore = true;
    });

    try {
      final response = await _apiService.dio.get("/api/sparks/nearby-search", queryParameters: {
        "radius": selectedRadius,
        "name": searchQuery,
        "page": 0,
        "size": 10,
      });

      if (response.data['success'] == true) {
        final List rawData = response.data['data'];
        final List<NearbyUser> fetchedUsers = rawData.map((e) => NearbyUser.fromJson(e)).toList();

        setState(() {
          users = fetchedUsers;
          if (fetchedUsers.isEmpty) hasMore = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Out of range! 📡 Let's try expanding your horizons.");
    } finally {
      if (mounted) setState(() { isLoading = false; isRefreshing = false; });
    }
  }

// API Call: Load More (Optimized Logic)
  Future<void> _fetchMoreUsers() async {
    if (isMoreLoading || !hasMore) return;

    setState(() => isMoreLoading = true);

    // ✅ Safety Timer: 5 second se zyada loader nahi dikhayega
    Timer(const Duration(seconds: 5), () {
      if (mounted && isMoreLoading) {
        setState(() => isMoreLoading = false);
      }
    });

    int nextPage = currentPage + 1;

    try {
      final response = await _apiService.dio.get("/api/sparks/nearby-search", queryParameters: {
        "radius": selectedRadius,
        "name": searchQuery,
        "page": nextPage,
        "size": 10,
      });

      if (response.data['success'] == true) {
        final List rawData = response.data['data'];
        final newItems = rawData.map((e) => NearbyUser.fromJson(e)).toList();

        setState(() {
          if (newItems.isEmpty) {
            hasMore = false;
          } else {
            users.addAll(newItems);
            currentPage = nextPage;
          }
        });
      }
    } catch (e) {
      debugPrint("Pagination Error: $e");
    } finally {
      if (mounted) setState(() => isMoreLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      setState(() => searchQuery = query);
      _fetchInitialUsers(silent: true);
    });
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }



  // --- UI Layout ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      appBar: AppBar(
        backgroundColor: bgBlack,
        elevation: 0,
        title: const Text("Radar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)))),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildRadiusBar(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : RefreshIndicator(
              onRefresh: () => _fetchInitialUsers(silent: true),
              color: accentColor,
              backgroundColor: cardBg,
              child: _buildMainList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search people nearby...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: accentColor, size: 20),
          filled: true,
          fillColor: cardBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildRadiusBar() {
    final List<int> options = [2, 5, 10, 25];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length + 1,
        itemBuilder: (context, index) {
          if (index == options.length) {
            bool isCustom = !options.contains(selectedRadius);
            return _buildRadiusChip(isCustom ? "${selectedRadius}km" : "Custom +", isCustom, true);
          }
          int val = options[index];
          return _buildRadiusChip("${val}km", selectedRadius == val, false, val: val);
        },
      ),
    );
  }

  Widget _buildRadiusChip(String label, bool isSelected, bool isCustomBtn, {int? val}) {
    return GestureDetector(
      onTap: () {
        if (isCustomBtn) _showCustomKmDialog();
        else {
          setState(() => selectedRadius = val!);
          _fetchInitialUsers(silent: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : borderColor, width: 1),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildMainList() {
    if (users.isEmpty && !isLoading) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: Text("❄️", style: TextStyle(fontSize: 50))),
          const SizedBox(height: 10),
          const Center(child: Text("It’s a bit quiet here. 🧊 Try moving to a livelier spot!", style: TextStyle(color: Colors.white60))),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // ✅ Change: hasMore ki jagah isMoreLoading check ho raha hai
      itemCount: users.length + (isMoreLoading ? 1 : 0),
      separatorBuilder: (context, index) => Divider(color: borderColor.withOpacity(0.3), height: 1),
      itemBuilder: (context, index) {
        if (index == users.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
          );
        }
        return _buildUserTile(users[index]);
      },
    );
  }

  Widget _buildUserTile(NearbyUser user) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => UserProfileModal(userId: user.id),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: user.imageUrl ?? "",
                  imageBuilder: (context, imageProvider) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Colors.white54),
                  ),
                ),

              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 5),
                      Text("• ${user.distance.toStringAsFixed(1)}km", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(user.bio, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  // if (user.instaHandle != null) ...[
                  //   const SizedBox(height: 6),
                  //   Text("${user.instaHandle}", style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  // ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
          ],
        ),
      ),
    );
  }

  void _showCustomKmDialog() {
    TextEditingController customController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text("Set Range", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: customController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: "Enter km", hintStyle: TextStyle(color: Colors.white24), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: () {
              if (customController.text.isNotEmpty) {
                setState(() => selectedRadius = int.parse(customController.text));
                _fetchInitialUsers(silent: true);
                Navigator.pop(context);
              }
            },
            child: const Text("Apply", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}