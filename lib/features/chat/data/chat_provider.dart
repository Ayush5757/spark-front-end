import 'package:flutter_riverpod/legacy.dart';

// Blue dot ke liye provider
final hasNewMessageProvider = StateProvider<bool>((ref) => false);

// Naye message ka data handle karne ke liye
final lastMessageProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final newNotification = StateProvider<bool>((ref) => false);

final HomeNotification = StateProvider<bool>((ref) => false);