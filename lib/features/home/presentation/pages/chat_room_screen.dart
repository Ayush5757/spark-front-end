import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String userName;
  final String otherUserPhone;
  final String? instagramHandle;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.userName,
    required this.otherUserPhone,
    this.instagramHandle,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> messages = [];
  String myPhone = "";
  StompClient? stompClient;
  int page = 0;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool isInitialLoading = true; // Naya: Initial load ke liye loader

  @override
  void initState() {
    super.initState();
    _setupChat();
    _scrollController.addListener(_onScroll);
  }

  // Scroll logic: Reverse list mein maxScrollExtent matlab "Top of the chat"
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _setupChat() async {
    final prefs = await SharedPreferences.getInstance();
    myPhone = prefs.getString('user_phone') ?? "";
    final token = prefs.getString('auth_token') ?? "";

    await _fetchHistory();
    _connectWebSocket(token);
    _markAsSeen();
  }

  void _connectWebSocket(String token) {
    stompClient = StompClient(
      config: StompConfig(
        url: 'ws://192.168.29.114:8080/ws-spark/websocket',
        onConnect: (frame) {
          debugPrint("✅ Connected to WebSocket");
          stompClient?.subscribe(
            destination: '/topic/chat/${widget.chatRoomId}',
            callback: (frame) {
              if (frame.body != null) {
                final newMsg = jsonDecode(frame.body!);

                setState(() {
                  // Duplicate check using content, sender and timestamp type
                  messages.removeWhere(
                        (m) =>
                    m['content'] == newMsg['content'] &&
                        m['senderPhone'] == newMsg['senderPhone'] &&
                        m['timestamp'] is int,
                  );

                  messages.insert(
                    0,
                    newMsg,
                  ); // Naya message hamesha bottom pe (index 0 because reverse: true)
                });

                if (newMsg['senderPhone'].toString() != myPhone) {
                  _markAsSeen();
                }
              }
            },
          );
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onWebSocketError: (error) => debugPrint("❌ Socket Error: $error"),
        onStompError: (frame) => debugPrint("❌ Stomp Error: ${frame.body}"),
      ),
    );
    stompClient?.activate();
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await _apiService.dio.get(
        "/api/chat/history/${widget.chatRoomId}?page=0&size=20",
      );
      final fetched = res.data['content'] ?? res.data;
      setState(() {
        messages = List.from(fetched);
        isInitialLoading = false;
        if (fetched.length < 20) hasMore = false;
      });
    } catch (e) {
      debugPrint("History Error: $e");
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      page++;
      final res = await _apiService.dio.get(
        "/api/chat/history/${widget.chatRoomId}?page=$page&size=20",
      );
      final newMsgs = res.data['content'] ?? res.data;

      if (newMsgs.isEmpty) {
        hasMore = false;
      } else {
        setState(() {
          messages.addAll(newMsgs); // Purane messages list ke end mein judenge
          if (newMsgs.length < 20) hasMore = false;
        });
      }
    } catch (e) {
      debugPrint("Load More Error: $e");
      page--; // Error aaye toh page count wapas le jao
    } finally {
      setState(() => isLoadingMore = false);
    }
  }

  void _markAsSeen() async {
    try {
      await _apiService.dio.post("/api/chat/mark-seen/${widget.chatRoomId}");
    } catch (e) {}
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final content = _controller.text.trim();
    _controller.clear();

    final localMsg = {
      'chatRoomId': widget.chatRoomId,
      'receiverPhone': widget.otherUserPhone,
      'senderPhone': myPhone,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'seen': false,
    };

    setState(() {
      messages.insert(0, localMsg); // Reverse list mein index 0 matlab bottom
    });

    try {
      await _apiService.dio.post(
        "/api/chat/send",
        data: {
          'chatRoomId': widget.chatRoomId,
          'receiverPhone': widget.otherUserPhone,
          'content': content,
        },
      );
    } catch (e) {
      setState(() {
        messages.removeAt(0);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to send")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Text(
              "Spark Match",
              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (widget.instagramHandle != null)
            IconButton(
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFFE4405F),
              ),
              onPressed: () => launchUrl(
                Uri.parse(
                  "https://instagram.com/${widget.instagramHandle!.replaceAll('@', '')}",
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              reverse: true, // Naye niche, Purane upar
              itemCount: messages.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final msg = messages[index];
                final bool isMine =
                    msg['senderPhone'].toString() == myPhone;
                return _buildMessageBubble(msg, isMine);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF3B82F6) : const Color(0xFF1C2128),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Text(
          msg['content'] ?? "",
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Message...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: const Color(0xFF3B82F6),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
