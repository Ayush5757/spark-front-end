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

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  StompClient? stompClient;

  // Design Colors
  final Color bgDark = const Color(0xFF0A0C10);
  final Color activeColor = const Color(0xFF2DD4BF);
  final Color inactiveColor = const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _initGlobalSocket();
    _setupFCM();
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
            // Backend endpoint jo tumne SparkController mein banaya hai
            await Dio().post(
              "http://192.168.29.114:8080/api/sparks/update-fcm-token",
              data: fcmToken,
              options: Options(
                headers: {"Authorization": "Bearer $authToken"},
                contentType: "text/plain", // String bhej rahe hain
              ),
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
        url: 'ws://192.168.29.114:8080/ws-spark/websocket',
        onConnect: (frame) {
          debugPrint("🌍 Global Socket Connected!");
          stompClient?.subscribe(
            destination: '/topic/user/$myPhone/notifications',
            callback: (frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newMsg = jsonDecode(frame.body!);
                debugPrint("📩 Socket Data: $newMsg");

                // 1. notificationType ko string mein convert karke handle karo (Best Practice)
                final String type = (newMsg['notificationType'] ?? '1').toString();

                if (type == '3') {
                  // ✅ HOME DOT: Spark Notification logic
                  ref.read(HomeNotification.notifier).state = true;
                  if (_currentIndex != 0) {
                    _showTopNotification(newMsg);
                  }
                }
                else if (newMsg['id'] != null && type == '1') {
                  // ✅ CHAT DOT: Normal Message (Type 1)
                  ref.read(hasNewMessageProvider.notifier).state = true;
                  ref.read(lastMessageProvider.notifier).state = newMsg;
                  if (_currentIndex != 1) {
                    _showTopNotification(newMsg);
                  }
                }
                else {
                  // ✅ ALERTS DOT: Baki sab (Likes, Interest etc.)
                  ref.read(newNotification.notifier).state = true;
                  if (_currentIndex != 2) {
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

  // show notification popup
  void _showTopNotification(Map<String, dynamic> msg) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, // Status bar ke thoda niche
        left: 15,
        right: 15,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              // Blue gradient ya solid jo tujhe pasand ho
              color: const Color(0xFF1E293B).withOpacity(0.95), // Dark Premium Look
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
                  // 1. Icon Section (Symbol)
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

                  // 2. Text Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg['title'] ?? "Notification", // Title
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${msg['content']}", // Main Message
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 3. Small Close or Time (Optional)
                  Icon(
                    Icons.drag_handle_rounded,
                    color: Colors.white.withOpacity(0.3),
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

    // 3 second rakhte hain taaki user padh sake
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
    if (index == 1) {
      ref.read(hasNewMessageProvider.notifier).state =
      false; // Reset chat dot on click
    }
    // ALERT DOT RESET: Jab Alerts tab (index 2) par click ho
    if (index == 2) {
      ref.read(newNotification.notifier).state = false;
    }

    if (index == 0) {
      ref.read(HomeNotification.notifier).state = false;
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
    final hasAlert = ref.watch(newNotification); // Alerts provider watch kiya
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
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.home_filled),
                  // ALERT DOT UI: Agar naya notification hai toh blue dot dikhao
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
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.search),
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
              label: 'Find',
            ),
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
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  // ALERT DOT UI: Agar naya notification hai toh blue dot dikhao
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