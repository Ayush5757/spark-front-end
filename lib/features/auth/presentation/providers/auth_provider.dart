import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/auth_repository.dart';

// Loading state ke liye ek simple provider
final authLoadingProvider = StateProvider<bool>((ref) => false);

// Repository ka provider
final authRepositoryProvider = Provider((ref) => AuthRepository());

// Auth Logic ka class
class AuthNotifier {
  final AuthRepository _repository;
  final WidgetRef _ref;

  AuthNotifier(this._repository, this._ref);

  Future<bool> sendOtp(String phone) async {
    _ref.read(authLoadingProvider.notifier).state = true; // Loading shuru
    final success = await _repository.sendOtp(phone);
    _ref.read(authLoadingProvider.notifier).state = false; // Loading khatam
    return success;
  }
}
