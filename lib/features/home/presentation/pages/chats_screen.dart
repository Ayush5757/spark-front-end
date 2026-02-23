import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Added
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
  final ScrollController _scrollController = ScrollController(); // ✅ For Pagination

  // State Variables
  List<dynamic> activeChats = [];
  int currentPage = 0;
  bool hasMore = true;
  bool isLoading = true;
  bool isMoreLoading = false;
  bool isRefreshing = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchInitialChats(); // Initial load

    // ✅ Pagination Listener: Jab user 85% scroll kar lega, next page fetch hoga
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
        if (!isMoreLoading && hasMore && searchQuery.isEmpty) {
          _fetchMoreChats();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ Cleanup
    super.dispose();
  }

  // Real-time Update Logic (Kept exactly as yours, just ensured dynamic typing)
  void _handleIncomingGlobalMessage(Map<String, dynamic> newMsg) {
    if (!mounted) return;
    setState(() {
      int index = activeChats.indexWhere(
            (c) => c['chatRoomId'] == newMsg['chatRoomId'],
      );

      if (index != -1) {
        var chat = Map<String, dynamic>.from(activeChats[index]);
        chat['lastMessage'] = newMsg['content'];
        chat['time'] = DateTime.now().toIso8601String();
        chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;

        activeChats.removeAt(index);
        activeChats.insert(0, chat);
      } else {
        // Naya chat hai toh silently refresh karo taaki top par dikhe
        _fetchInitialChats(silent: true);
      }
    });
  }

  // API Call: First Load or Refresh
  Future<void> _fetchInitialChats({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) isLoading = true;
      else isRefreshing = true;
      currentPage = 0;
      hasMore = true;
    });

    try {
      final response = await _apiService.dio.get("/api/matches/active-chats", queryParameters: {
        "page": 0,
        "size": 15,
      });

      // 🔥 LOG DEKHNE KE LIYE (Check console)
      debugPrint("API Response Data: ${response.data}");

      // Spring Page object returns data in 'content' field
      // Hum check kar rahe hain ki response.data Map hai ya List

      // final Map<String, dynamic> responseData = response.data is String
      //     ? Map<String, dynamic>.from(response.data)
      //     : response.data;

      final responseData = response.data as Map<String, dynamic>;

      final List fetchedData = responseData['content'] ?? [];
      final bool isLastPage = responseData['last'] ?? true; // Spring bhejta hai 'last'

      if (mounted) {
        setState(() {
          activeChats = fetchedData;
          isLoading = false;
          isRefreshing = false;
          hasMore = !isLastPage; // Agar last page hai toh hasMore false
        });
      }
    } catch (e) {
      debugPrint("Initial fetch error: $e");
      if (mounted) setState(() { isLoading = false; isRefreshing = false; });
    }
  }

  // API Call: Fetch More (Pagination)
  Future<void> _fetchMoreChats() async {
    if (isMoreLoading || !hasMore) return;
    setState(() => isMoreLoading = true);

    int nextPage = currentPage + 1;

    try {
      final response = await _apiService.dio.get("/api/matches/active-chats", queryParameters: {
        "page": nextPage,
        "size": 15,
      });

      final Map<String, dynamic> responseData = response.data;
      final List fetchedData = responseData['content'] ?? [];
      final bool isLastPage = responseData['last'] ?? true;

      if (mounted) {
        setState(() {
          if (fetchedData.isNotEmpty) {
            activeChats.addAll(fetchedData);
            currentPage = nextPage;
          }
          hasMore = !isLastPage;
          isMoreLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load more error: $e");
      if (mounted) setState(() => isMoreLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod listener for global messages
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Messages",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                ],
              ),
            ),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchInitialChats(silent: true),
                color: const Color(0xFF3B82F6),
                backgroundColor: const Color(0xFF1C2128),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                    : filteredChats.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: searchQuery.isEmpty
                      ? filteredChats.length + (hasMore ? 1 : 0)
                      : filteredChats.length,
                  itemBuilder: (context, index) {
                    if (index == filteredChats.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))),
                      );
                    }
                    return _buildChatItem(filteredChats[index]);
                  },
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
        _fetchInitialChats(silent: true); // Back aane par silently update
      },
      leading: Stack(
        children: [
          // ✅ Optimized with CachedNetworkImage
          CachedNetworkImage(
            imageUrl: chat['profilePic'] ?? "",
            imageBuilder: (context, imageProvider) => CircleAvatar(
              radius: 30,
              backgroundImage: imageProvider,
            ),
            placeholder: (context, url) => Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(color: Color(0xFF1C2128), shape: BoxShape.circle),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 1, color: Color(0xFF3B82F6))),
            ),
            errorWidget: (context, url, error) => CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                "https://api.dicebear.com/7.x/avataaars/svg?seed=${chat['userName']}",
              ),
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
        overflow: TextOverflow.ellipsis,
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(), // Pull-to-refresh works even when empty
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
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
        ),
      ],
    );
  }
}