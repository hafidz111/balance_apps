import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get backendBaseUrl {
    const fromEnv = String.fromEnvironment('STARVY_API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }
}

class AiChatService {
  AiChatService({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.backendBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 100),
              headers: {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<String> send({
    required String message,
    required List<Map<String, String>> messages,
    required Map<String, dynamic> context,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/starvy/chat/',
      data: {
        'message': message,
        'messages': messages,
        'context': context,
      },
    );
    final data = res.data;
    final reply = data?['reply'];
    if (reply is! String || reply.isEmpty) {
      throw StateError(data?['error']?.toString() ?? 'Respons AI kosong');
    }
    return reply;
  }
}
