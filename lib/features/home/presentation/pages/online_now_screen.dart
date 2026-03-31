import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spark/core/network/api_service.dart';
import 'package:spark/features/home/presentation/pages/user_profile_sheet.dart';
import 'package:spark/models/active_user.dart';


class OnlineNowScreen extends StatefulWidget {
  const OnlineNowScreen({super.key});

  @override
  State<OnlineNowScreen> createState() => _OnlineNowScreenState();
}

class _OnlineNowScreenState extends State<OnlineNowScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  // State Variables
  List<ActiveUser> activeUsers = [];
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
  final Color onlineGreen = const Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _fetchInitialActiveUsers();

    // 85% Scroll Threshold logic
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
        if (!isLoading && !isMoreLoading && hasMore) {
          _fetchMoreActiveUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // API Call: First Load
  Future<void> _fetchInitialActiveUsers({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (!silent) isLoading = true;
      else isRefreshing = true;
      currentPage = 0;
      activeUsers.clear();
      hasMore = true;
    });

    try {
      final response = await _apiService.dio.get("/api/presence/active-now", queryParameters: {
        "page": 0,
        "size": 15,
      });

      // Handling response with 'data' wrapper or direct list
      final List rawData = response.data['data'] ?? response.data;
      final List<ActiveUser> fetched = rawData.map((e) => ActiveUser.fromJson(e)).toList();

      setState(() {
        activeUsers = fetched;
        if (fetched.isEmpty || fetched.length < 15) hasMore = false;
      });
    } catch (e) {
      _showErrorSnackBar("Unable to reach the spark radar. Please try again.");
    } finally {
      if (mounted) setState(() { isLoading = false; isRefreshing = false; });
    }
  }

  // API Call: Load More (Pagination)
  Future<void> _fetchMoreActiveUsers() async {
    if (isMoreLoading || !hasMore) return;

    setState(() => isMoreLoading = true);

    // Safety Timeout for Loader
    Timer(const Duration(seconds: 5), () {
      if (mounted && isMoreLoading) {
        setState(() => isMoreLoading = false);
      }
    });

    int nextPage = currentPage + 1;

    try {
      final response = await _apiService.dio.get("/api/presence/active-now", queryParameters: {
        "page": nextPage,
        "size": 15,
      });

      final List rawData = response.data['data'] ?? response.data;
      final List<ActiveUser> newItems = rawData.map((e) => ActiveUser.fromJson(e)).toList();

      setState(() {
        if (newItems.isEmpty) {
          hasMore = false;
        } else {
          activeUsers.addAll(newItems);
          currentPage = nextPage;
          if (newItems.length < 15) hasMore = false;
        }
      });
    } catch (e) {
      debugPrint("❌ Pagination Error: $e");
    } finally {
      if (mounted) setState(() => isMoreLoading = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      appBar: AppBar(
        backgroundColor: bgBlack,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Online Now",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white),
        ),
        actions: [
          if (isRefreshing)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : RefreshIndicator(
        onRefresh: () => _fetchInitialActiveUsers(silent: true),
        color: accentColor,
        backgroundColor: cardBg,
        child: _buildMainList(),
      ),
    );
  }

  Widget _buildMainList() {
    if (activeUsers.isEmpty && !isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // Items + Bottom Loader
      itemCount: activeUsers.length + (isMoreLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == activeUsers.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
          );
        }
        return _buildUserTile(activeUsers[index]);
      },
    );
  }

  Widget _buildUserTile(ActiveUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: ListTile(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => UserProfileModal(userId: user.id),
          );
        },
        leading: Stack(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: user.profilePic ?? "",
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: borderColor),
                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white24),
                ),
              ),
            ),
            // Pulsing Online Indicator
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardBg, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: onlineGreen.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        title: Text(
          user.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: onlineGreen, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              "Active now",
              style: TextStyle(color: onlineGreen, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Icon(Icons.chat_bubble_outline, color: accentColor.withOpacity(0.4), size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(child: Text("🧊", style: TextStyle(fontSize: 60))),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            "The radar is clear right now.",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 5),
        const Center(
          child: Text(
            "Pull down to refresh or check back later!",
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      ],
    );
  }
}