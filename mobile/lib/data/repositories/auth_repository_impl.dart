import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/api_datasource.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiDatasource api;

  AuthRepositoryImpl(this.api);

  @override
  Future<void> requestOtp(String phone) async {
    await api.dio.post('/auth/request-otp', data: {'phone': phone});
  }

  @override
  Future<String> verifyOtp(String phone, String code) async {
    final response = await api.dio.post('/auth/verify-otp', data: {
      'phone': phone,
      'code': code,
    });
    
    final token = response.data['accessToken'];
    
    // Salva o token localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);

    // After setting the token, we can make authenticated requests to register device
    api.dio.options.headers['Authorization'] = 'Bearer $token';

    // Get FCM Token
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print('FCM Token error: $e');
    }

    final Map<String, dynamic> bundle = {
      'fcm_token': fcmToken,
      'platform': 'mobile',
      'registration_id': 1,
      'identity_key': 'dummy',
      'signed_pre_key': 'dummy',
      'signed_signature': 'dummy',
      'signed_key_id': 1,
      'pre_keys': [],
    };

    // Register device and bundle on the backend
    await api.dio.post('/devices/register', data: bundle);
    
    return token;
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await api.dio.get('/users/me');
    return User.fromJson(response.data);
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}
