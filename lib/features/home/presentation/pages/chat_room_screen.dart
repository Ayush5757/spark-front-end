import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_service.dart';
import 'package:dio/dio.dart' as dio_pkg;

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String? userName; // Nullable banaya taaki error na aaye
  final String otherUserPhone;
  final String? instagramHandle;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    this.userName, // Required se hata kar optional kiya safety ke liye
    required this.otherUserPhone,
    this.instagramHandle,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> messages = [];
  String myPhone = "";
  StompClient? stompClient;
  int page = 0;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _setupChat();
    _scrollController.addListener(_onScroll);
  }

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
                final data = jsonDecode(frame.body!);

                if (data['type'] == 'SEEN_EVENT') {
                  if (data['seenBy'].toString() != myPhone) {
                    setState(() {
                      for (var msg in messages) {
                        if (msg['senderPhone'].toString() == myPhone) {
                          msg['seen'] = true;
                        }
                      }
                    });
                  }
                  return;
                }

                final newMsg = data;
                setState(() {
                  int index = messages.indexWhere((m) =>
                  (m['id'] != null && m['id'] == newMsg['id']) ||
                      (m['id'] == null &&
                          m['content'] == newMsg['content'] &&
                          m['senderPhone'] == newMsg['senderPhone']));
                  if (index != -1) {
                    messages[index] = newMsg;
                  } else {
                    messages.insert(0, newMsg);
                  }
                });

                if (newMsg['senderPhone'].toString() != myPhone) {
                  _markAsSeen();
                }
              }
            },
          );
        },
        reconnectDelay: const Duration(seconds: 5),
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
          'connection-type': 'CHAT_ROOM',
          'heart-beat': '10000,10000',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
          'connection-type': 'CHAT_ROOM',
        },
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
          messages.addAll(newMsgs);
          if (newMsgs.length < 20) hasMore = false;
        });
      }
    } catch (e) {
      debugPrint("Load More Error: $e");
      page--;
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
      messages.insert(0, localMsg);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send")),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      try {
        String fileName = image.path.split('/').last;
        dio_pkg.FormData formData = dio_pkg.FormData.fromMap({
          "file": await dio_pkg.MultipartFile.fromFile(image.path,
              filename: fileName),
        });

        var response =
        await _apiService.dio.post("/api/chat/upload", data: formData);
        String imageUrl = response.data['url'];

        _sendImageMessage(imageUrl);
      } catch (e) {
        print("Upload error: $e");
      }
    }
  }

  void _sendImageMessage(String imageUrl) async {
    final localMsg = {
      'chatRoomId': widget.chatRoomId,
      'receiverPhone': widget.otherUserPhone,
      'senderPhone': myPhone,
      'content': imageUrl,
      'type': 'IMAGE',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'seen': false,
    };

    setState(() {
      messages.insert(0, localMsg);
    });

    await _apiService.dio.post("/api/chat/send", data: {
      'chatRoomId': widget.chatRoomId,
      'receiverPhone': widget.otherUserPhone,
      'content': imageUrl,
      'type': 'IMAGE',
    });
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
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
              widget.userName ?? "User",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Text(
              "Spark Match",
              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (widget.instagramHandle != null &&
              widget.instagramHandle!.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFFE4405F),
              ),
              onPressed: () async {
                final handle = widget.instagramHandle!.replaceAll('@', '');
                final url = Uri.parse("https://instagram.com/$handle");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
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
              reverse: true,
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
                    (msg['senderPhone']?.toString() ?? "") == myPhone;
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
    bool isSeen = msg['seen'] ?? false;
    bool isImage = msg['type'] == 'IMAGE';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF3B82F6) : const Color(0xFF1C2128),
          borderRadius: BorderRadius.circular(12),
        ),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isImage)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, msg['content']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg['content'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  msg['content']?.toString() ?? "",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            const SizedBox(height: 2),
            if (isMine)
              Icon(
                isSeen ? Icons.done_all : Icons.done,
                size: 14,
                color: isSeen ? Colors.greenAccent : Colors.white70,
              ),
          ],
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
          IconButton(
            icon: const Icon(Icons.image, color: Color(0xFF3B82F6)),
            onPressed: _pickAndSendImage,
          ),
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