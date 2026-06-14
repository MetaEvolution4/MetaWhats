import '../../domain/entities/user.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/api_datasource.dart';

class ContactRepositoryImpl implements ContactRepository {
  final ApiDatasource api;

  ContactRepositoryImpl(this.api);

  @override
  Future<List<User>> getContacts() async {
    final response = await api.dio.get('/contacts');
    final List data = response.data;
    return data.map((json) {
      if (json.containsKey('contact')) {
        final contactData = json['contact'] as Map<String, dynamic>;
        // Use nickname from parent if available
        if (json['nickname'] != null && json['nickname'].toString().isNotEmpty) {
          contactData['name'] = json['nickname'];
        }
        return User.fromJson(contactData);
      }
      return User.fromJson(json);
    }).toList();
  }

  @override
  Future<User> addContact(String phone, [String nickname = '']) async {
    final response = await api.dio.post('/contacts', data: {
      'phone': phone,
      'nickname': nickname,
    });
    if (response.data.containsKey('contact')) {
        final contactData = response.data['contact'] as Map<String, dynamic>;
        if (response.data['nickname'] != null && response.data['nickname'].toString().isNotEmpty) {
          contactData['name'] = response.data['nickname'];
        }
        return User.fromJson(contactData);
    }
    return User.fromJson(response.data);
  }
}
