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
      if (json.containsKey('contactUser')) {
        return User.fromJson(json['contactUser']);
      }
      return User.fromJson(json);
    }).toList();
  }

  @override
  Future<User> addContact(String phone) async {
    final response = await api.dio.post('/contacts', data: {'phone': phone});
    if (response.data.containsKey('contactUser')) {
        return User.fromJson(response.data['contactUser']);
    }
    return User.fromJson(response.data);
  }
}
