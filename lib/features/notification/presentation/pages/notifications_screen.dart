import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_service.dart';
import '../../../home/presentation/pages/chat_room_screen.dart';
// ✅ UserProfileModal ka import (Apne folder structure ke hisaab se path check kar lena)
import '../../../home/presentation/pages/user_profile_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  // State Variables
  List<dynamic> notifications = [];
  bool isLoading = true;
  bool isRefreshing = false;
  bool isMoreLoading = false;
  bool hasMore = true;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialNotifications();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
        if (!isMoreLoading && hasMore) {
          _fetchMoreNotifications();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialNotifications({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (!silent) isLoading = true;
      else isRefreshing = true;
      currentPage = 0;
      hasMore = true;
    });

    try {
      final response = await _apiService.dio.get(
        "/api/matches/my-notifications",
        queryParameters: {"page": 0, "size": 10},
      );

      final responseData = response.data as Map<String, dynamic>;
      final List fetchedList = responseData['content'] ?? [];
      final bool isLast = responseData['last'] ?? true;

      if (mounted) {
        setState(() {
          notifications = fetchedList;
          isLoading = false;
          isRefreshing = false;
          hasMore = !isLast;
        });
      }
    } catch (e) {
      debugPrint("Notif Initial Fetch Error: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
        _showSnackBar("Error", "Oops! The vibe is lagging. Try again? ⚡");
      }
    }
  }

  Future<void> _fetchMoreNotifications() async {
    if (isMoreLoading || !hasMore) return;

    setState(() => isMoreLoading = true);
    int nextPage = currentPage + 1;

    try {
      final response = await _apiService.dio.get(
        "/api/matches/my-notifications",
        queryParameters: {"page": nextPage, "size": 10},
      );

      final responseData = response.data as Map<String, dynamic>;
      final List fetchedList = responseData['content'] ?? [];
      final bool isLast = responseData['last'] ?? true;

      if (mounted) {
        setState(() {
          if (fetchedList.isNotEmpty) {
            notifications.addAll(fetchedList);
            currentPage = nextPage;
          }
          hasMore = !isLast;
          isMoreLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Notif Load More Error: $e");
      if (mounted) setState(() => isMoreLoading = false);
    }
  }

  Future<void> _handleAccept(int matchId) async {
    try {
      await _apiService.dio.post("/api/matches/accept/$matchId");
      _showSuccessDialog("Matched! 🎉", "It’s a Match! 🎉 Start the spark now.");
      _fetchInitialNotifications(silent: true);
    } on DioException catch (e) {
      String errorMsg = e.response?.data?.toString() ?? "Action failed. Let's give it another shot!";
      _showSnackBar("Oops!", errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchInitialNotifications(silent: true),
                color: const Color(0xFF3B82F6),
                backgroundColor: const Color(0xFF1C2128),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                    : notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notifications.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      );
                    }
                    return _buildNotificationCard(notifications[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic item) {
    bool isReceived = item['type'] == "RECEIVED_INTEREST";
    bool isAccepted = item['status'] == "ACCEPTED";
    bool isPending = item['status'] == "PENDING";
    String? profilePic = item['profilePic'];

    // ✅ Click par Profile open karne ke liye InkWell add kiya
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => UserProfileModal(userId: item['userID']),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPending
                ? const Color(0xFF3B82F6).withOpacity(0.4)
                : const Color(0xFF1E293B),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: profilePic ?? "",
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: 27,
                backgroundImage: imageProvider,
              ),
              placeholder: (context, url) => const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFF1E293B),
                child: CircularProgressIndicator(strokeWidth: 1, color: Color(0xFF3B82F6)),
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF1E293B),
                backgroundImage: NetworkImage(
                  "https://api.dicebear.com/7.x/avataaars/svg?seed=${item['userName']}",
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isAccepted
                              ? "${item['userName'] ?? 'Someone'} & You Matched! ⚡"
                              : "${item['userName'] ?? 'Someone'} is Interested",
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item['createdAt']),
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAccepted
                        ? "You & ${item['userName'] ?? 'User'} just sparked a connection for ${item['sparkCategory']}!"
                        : "${item['userName'] ?? 'User'} is interested in your ${item['sparkCategory']} Spark! ✨",
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  if (isPending && isReceived) ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _handleAccept(item['matchId']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text(
                        "Accept Interest",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (isAccepted) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomScreen(
                              chatRoomId: item['chatRoomId'],
                              userName: item['userName'] ?? "User",
                              otherUserPhone: item['otherUserPhone'],
                              instagramHandle: item['instagramHandle'] ?? "",
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        minimumSize: const Size(150, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.message_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                      label: const Text(
                        "Start Chatting",
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "Abhi";
    try {
      final DateTime date = DateTime.parse(dateStr);
      final Duration diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (e) {
      return "";
    }
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 48,
                color: Color(0xFF1E293B),
              ),
              SizedBox(height: 12),
              Text(
                "All quiet here! No new sparks yet. 🧊",
                style: TextStyle(color: Color(0xFF475569), fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title: $msg"),
        backgroundColor: const Color(0xFF1C2128),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          content,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF3B82F6))),
          ),
        ],
      ),
    );
  }
}