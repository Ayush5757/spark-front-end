import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_service.dart';
import '../../../home/presentation/pages/chat_room_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // --- API: Fetch Notifications ---
  Future<void> _fetchNotifications() async {
    try {
      final response = await _apiService.dio.get(
        "/api/matches/my-notifications",
      );
      setState(() {
        notifications = response.data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Notif Error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- API: Accept Interest ---
  Future<void> _handleAccept(int matchId) async {
    try {
      await _apiService.dio.post("/api/matches/accept/$matchId");
      _showSuccessDialog("Matched! 🎉", "Ab aap chat kar sakte hain.");
      _fetchNotifications(); // List refresh karo
    } on DioException catch (e) {
      String errorMsg = e.response?.data?.toString() ?? "Kuch gadbad ho gayi";
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchNotifications,
                color: const Color(0xFF3B82F6),
                backgroundColor: const Color(0xFF1C2128),
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF3B82F6),
                  ),
                )
                    : notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) =>
                      _buildNotificationCard(notifications[index]),
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

    return Container(
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
          // Avatar
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: NetworkImage(
              "https://api.dicebear.com/7.x/avataaars/svg?seed=${item['userName']}",
            ),
          ),
          const SizedBox(width: 14),
          // Content
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
                            ? "${item['userName']} & You Matched! ⚡"
                            : "${item['userName']} is Interested",
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Text(
                      "Just now",
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAccepted
                      ? "You and ${item['userName']} are now connected for ${item['sparkCategory']}. Let's chat!"
                      : "${item['userName']} wants to join your ${item['sparkCategory']} spark.",
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    // lineHeight: 1.4,
                  ),
                ),

                // Action Buttons
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
                    icon: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
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
                            userName: item['userName'],
                            otherUserPhone: item['otherUserPhone'],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 48,
            color: const Color(0xFF1E293B),
          ),
          const SizedBox(height: 12),
          const Text(
            "No notifications yet",
            style: TextStyle(color: Color(0xFF475569), fontSize: 16),
          ),
        ],
      ),
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
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          content,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
