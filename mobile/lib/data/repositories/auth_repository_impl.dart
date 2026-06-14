import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/api_datasource.dart';

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
