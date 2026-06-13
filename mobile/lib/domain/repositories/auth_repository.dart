import '../entities/user.dart';

abstract class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<String> verifyOtp(String phone, String code);
  Future<User> getCurrentUser();
  Future<void> logout();
}
