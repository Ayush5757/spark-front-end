import 'package:dio/dio.dart';
import 'package:spark/core/network/api_service.dart';

class AuthRepository {
  final Dio _api = ApiService().dio;

  // 1. Send OTP
  Future<bool> sendOtp(String phone) async {
    try {
      final response = await _api.post(
        "/api/auth/send-otp",
        data: {"phoneNumber": phone},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 2. Verify OTP
  Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    try {
      final response = await _api.post(
        "/api/auth/verify-otp",
        data: {"phoneNumber": phone, "otp": otp},
      );
      return response.data; // Response mein token aur newUser flag aayega
    } catch (e) {
      return null;
    }
  }
}
