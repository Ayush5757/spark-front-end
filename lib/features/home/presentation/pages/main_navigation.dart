import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/features/home/presentation/pages/home_screen.dart';
import 'package:spark/features/notification/presentation/pages/notifications_screen.dart';
import 'package:spark/features/profile/presentation/pages/profile_screen.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import './chats_screen.dart';
import '../../../chat/data/chat_provider.dart';
import 'find_people.dart';
import '../../../../core/network/api_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  StompClient? stompClient;
  final ApiService _apiService = ApiService();

  // Design Colors
  final Color bgDark = const Color(0xFF0A0C10);
  final Color activeColor = const Color(0xFF2DD4BF);
  final Color inactiveColor = const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _checkTokenExpiry();
    _initGlobalSocket();
    _setupFCM();
  }

  Future<void> _checkTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final String? expiryStr = prefs.getString('token_expiry');

    if (expiryStr != null) {
      final DateTime expiryDate = DateTime.parse(expiryStr);
      final DateTime now = DateTime.now();

      if (now.isAfter(expiryDate)) {
        _forceLogout(prefs);
      }
    }
  }

  Future<void> _forceLogout(SharedPreferences prefs) async {
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
    }
  }

  void _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? fcmToken = await messaging.getToken();
      debugPrint("My FCM Token: $fcmToken");

      if (fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        final String? authToken = prefs.getString('auth_token');

        if (authToken != null) {
          try {
            await _apiService.dio.post(
              "/api/sparks/update-fcm-token",
              data: authToken,
              options: Options(contentType: "text/plain"),
            );
            debugPrint("FCM Token synced with Backend ✅");
          } catch (e) {
            debugPrint("Error syncing FCM Token: $e");
          }
        }
      }
    }
  }

  void _initGlobalSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('auth_token') ?? "";
    final String myPhone = prefs.getString('user_phone') ?? "";

    if (token.isEmpty || myPhone.isEmpty) return;

    stompClient = StompClient(
      config: StompConfig(
        url: 'wss://sparkbackend-production.up.railway.app/ws-spark/websocket',
        onConnect: (frame) {
          debugPrint("🌍 Global Socket Connected!");
          stompClient?.subscribe(
            destination: '/topic/user/$myPhone/notifications',
            callback: (frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newMsg = jsonDecode(frame.body!);
                debugPrint("📩 Socket Data: $newMsg");

                final String type = (newMsg['notificationType'] ?? '1').toString();

                if (type == '3') {
                  // HOME DOT: Index 0
                  ref.read(HomeNotification.notifier).state = true;
                  if (_currentIndex != 0) {
                    _showTopNotification(newMsg);
                  }
                }
                else if (newMsg['id'] != null && type == '1') {
                  // CHAT DOT: Index 2 (Find ke baad)
                  ref.read(hasNewMessageProvider.notifier).state = true;
                  ref.read(lastMessageProvider.notifier).state = newMsg;
                  if (_currentIndex != 2) {
                    _showTopNotification(newMsg);
                  }
                }
                else {
                  // ALERTS DOT: Index 3
                  ref.read(newNotification.notifier).state = true;
                  if (_currentIndex != 3) {
                    _showTopNotification(newMsg);
                  }
                }
              }
            },
          );
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    stompClient?.activate();
  }

  void _showTopNotification(Map<String, dynamic> msg) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 15,
        right: 15,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg['title'] ?? "Notification",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,

                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${msg['content']}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.drag_handle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onItemTapped(int index) {
    // Index 0: Home Reset
    if (index == 0) {
      ref.read(HomeNotification.notifier).state = false;
    }
    // Index 1: Find (Yahan koi dot reset nahi hai)

    // Index 2: Chat Reset
    if (index == 2) {
      ref.read(hasNewMessageProvider.notifier).state = false;
    }
    // Index 3: Alerts Reset
    if (index == 3) {
      ref.read(newNotification.notifier).state = false;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNewMsg = ref.watch(hasNewMessageProvider);
    final hasAlert = ref.watch(newNotification);
    final hasHomeAlert = ref.watch(HomeNotification);

    return Scaffold(
      backgroundColor: bgDark,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          HomeScreen(),
          FindPeopleScreen(),
          ChatsScreen(),
          NotificationsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          backgroundColor: bgDark,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: activeColor,
          unselectedItemColor: inactiveColor,
          items: [
            // Home - Index 0
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.home_filled),
                  if (hasHomeAlert)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Home',
            ),
            // Find - Index 1 (No Dot)
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Find',
            ),
            // Chats - Index 2
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.message_rounded),
                  if (hasNewMsg)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Chats',
            ),
            // Alerts - Index 3
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (hasAlert)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Alerts',
            ),
            // Profile - Index 4
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}