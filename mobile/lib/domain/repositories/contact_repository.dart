import '../entities/user.dart';

abstract class ContactRepository {
  Future<List<User>> getContacts();
  Future<User> addContact(String phone, [String nickname = '']);
}
