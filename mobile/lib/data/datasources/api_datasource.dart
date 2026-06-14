import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class ApiDatasource {
  late Dio dio;

  ApiDatasource() {
    dio = Dio(BaseOptions(
      baseUrl: '${AppConstants.baseUrl}/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<String> uploadMedia(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await dio.post('/media/upload', data: formData);
    return response.data['id']; // Assumes the backend returns { id: "media_id" }
  }

  Future<List<int>> downloadMedia(String id) async {
    final response = await dio.get('/media/download/$id', options: Options(responseType: ResponseType.bytes));
    return response.data;
  }
}
