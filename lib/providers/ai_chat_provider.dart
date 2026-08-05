import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/model/barcode_data.dart';
import '../data/model/bread_history.dart';
import '../data/model/coffee_history.dart';
import '../service/ai_chat_service.dart';
import '../service/shared_preferences_service.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toApi() => {'role': role, 'content': content};
}

class AiChatProvider extends ChangeNotifier {
  AiChatProvider(this._prefs, {AiChatService? service})
    : _service = service ?? AiChatService();

  final SharedPreferencesService _prefs;
  final AiChatService _service;

  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  String? get error => _error;

  Future<Map<String, dynamic>> _buildContext() async {
    final coffee = await _prefs.getCoffee();
    final bread = await _prefs.getBread();
    final barcodes = await _prefs.getBarcodes();
    final coffeeStore = await _prefs.getCoffeeStore();
    final breadStore = await _prefs.getBreadStore();
    return {
      'coffee_history': coffee.map((CoffeeHistory e) => e.toJson()).toList(),
      'bread_history': bread.map((BreadHistory e) => e.toJson()).toList(),
      'barcodes': barcodes.map((BarcodeData e) => e.toJson()).toList(),
      'coffee_store': coffeeStore?.toJson(),
      'bread_store': breadStore?.toJson(),
    };
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _error = null;
    _messages.add(ChatMessage(role: 'user', content: trimmed));
    _loading = true;
    notifyListeners();

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.toApi())
          .toList();
      if (history.isNotEmpty && history.last['role'] == 'user') {
        history.removeLast();
      }

      final reply = await _service.send(
        message: trimmed,
        messages: history,
        context: await _buildContext(),
      );
      _messages.add(ChatMessage(role: 'assistant', content: reply));
    } on DioException catch (e) {
      _error = _humanError(e);
      _messages.add(ChatMessage(role: 'assistant', content: _error!));
    } catch (e) {
      _error = 'Maaf, terjadi gangguan. Coba kirim ulang sebentar lagi.';
      _messages.add(ChatMessage(role: 'assistant', content: _error!));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _humanError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final userMsg = data['user_message'] ?? data['error'];
      if (userMsg is String && userMsg.trim().isNotEmpty) {
        return userMsg.trim();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Koneksi ke asisten terlalu lama. Coba lagi.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak bisa terhubung ke server asisten.';
    }
    return 'Maaf, asisten sedang tidak bisa menjawab. Coba lagi nanti.';
  }

  void clear() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }
}
