import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_service.dart';
import '../../../chat/data/chat_provider.dart';
import 'chat_room_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> activeChats = [];
  bool isLoading = true;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  // Real-time Update Logic
  void _handleIncomingGlobalMessage(Map<String, dynamic> newMsg) {
    setState(() {
      int index = activeChats.indexWhere(
            (c) => c['chatRoomId'] == newMsg['chatRoomId'],
      );

      if (index != -1) {
        var chat = activeChats[index];
        chat['lastMessage'] = newMsg['content'];
        chat['time'] = DateTime.now().toIso8601String();
        chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;

        // Sabse upar move karo
        activeChats.removeAt(index);
        activeChats.insert(0, chat);
      } else {
        // Naya chat room hai toh refresh kar lo list
        _fetchChats();
      }
    });
  }

  Future<void> _fetchChats() async {
    try {
      final response = await _apiService.dio.get("/api/matches/active-chats");
      setState(() {
        activeChats = response.data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Chat list fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ye line naye message ko listen karti hai
    ref.listen(lastMessageProvider, (prev, next) {
      if (next != null) _handleIncomingGlobalMessage(next);
    });

    final filteredChats = activeChats.where((chat) {
      return (chat['userName'] ?? "").toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text(
                "Messages",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchChats,
                color: const Color(0xFF3B82F6),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredChats.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) =>
                      _buildChatItem(filteredChats[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2128),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => setState(() => searchQuery = val),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
            hintText: "Search conversations...",
            hintStyle: TextStyle(color: Color(0xFF64748B)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(dynamic chat) {
    bool hasUnread = (chat['unreadCount'] ?? 0) > 0;

    return ListTile(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoomId: chat['chatRoomId'],
              userName: chat['userName'],
              otherUserPhone: chat['otherUserPhone'],
              instagramHandle: chat['instagramHandle'],
            ),
          ),
        );
        _fetchChats(); // Refresh on back
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(
              chat['profilePic'] ??
                  "https://api.dicebear.com/7.x/avataaars/svg?seed=${chat['userName']}",
            ),
          ),
          if (chat['isOnline'] == true)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat['userName'] ?? "User",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        chat['lastMessage'] ?? "Say hi! 👋",
        maxLines: 1,
        style: TextStyle(
          color: hasUnread ? Colors.white : Colors.grey,
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            chat['time'] != null
                ? DateFormat.jm().format(DateTime.parse(chat['time']))
                : "",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
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
            Icons.message_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            "No messages yet",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Matches hone ke baad baatcheet shuru hogi.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
