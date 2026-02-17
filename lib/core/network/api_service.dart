import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.29.114:8080",
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // SharedPreferences se token nikalna
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null) {
            // Header mein Bearer Token add karna
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options); // Request continue karo
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            print("erroronprint : ");
            print(e);
            // Agar token expire ho gaya toh logout logic yahan aayega
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
