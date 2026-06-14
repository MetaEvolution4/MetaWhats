import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/api_datasource.dart';
import '../data/datasources/local_db_datasource.dart';
import '../data/datasources/websocket_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../data/repositories/contact_repository_impl.dart';
import 'encryption.dart';

final apiDatasourceProvider = Provider((ref) => ApiDatasource());
final localDbDatasourceProvider = Provider((ref) => LocalDbDatasource());
final webSocketDatasourceProvider = Provider((ref) => WebSocketDatasource());
final encryptionServiceProvider = Provider((ref) => EncryptionService());

final authRepositoryProvider = Provider((ref) {
  return AuthRepositoryImpl(ref.watch(apiDatasourceProvider));
});

final contactRepositoryProvider = Provider((ref) {
  return ContactRepositoryImpl(ref.watch(apiDatasourceProvider));
});

final chatRepositoryProvider = Provider((ref) {
  return ChatRepositoryImpl(
    ref.watch(apiDatasourceProvider),
    ref.watch(webSocketDatasourceProvider),
    ref.watch(localDbDatasourceProvider),
  );
});

// Controla visualmente se o usuário está logado
final authStateProvider = StateProvider<bool>((ref) => false);
