import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class OllamaClient {
  final String baseUrl;

  OllamaClient({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      // Use the same host the page was loaded from, so LAN/mobile access works
      final pageHost = Uri.base.host;
      return 'http://$pageHost:11434';
    }
    return 'http://127.0.0.1:11434';
  }

  Future<ChatMessage> chat(String model, List<ChatMessage> messages) async {
    final url = Uri.parse('$baseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': false,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
        body: body,
      );

      if (response.statusCode == 200) {
        String rawBody = response.body.trim();
        try {
          final data = jsonDecode(rawBody);
          return ChatMessage.fromJson(data['message']);
        } catch (e) {
          if (rawBody.contains('}{')) {
            List<String> parts = rawBody.split('}{');
            for (var part in parts) {
              String fixedPart = (part.startsWith('{') ? '' : '{') + part + (part.endsWith('}') ? '' : '}');
              try {
                final data = jsonDecode(fixedPart);
                if (data.containsKey('message')) return ChatMessage.fromJson(data['message']);
              } catch (_) {}
            }
          }
          rethrow;
        }
      } else {
        throw Exception('Ollama returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Ollama at $baseUrl.\nDetails: $e');
    }
  }

  Stream<String> chatStream(String model, List<ChatMessage> messages) async* {
    final url = Uri.parse('$baseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': '*/*',
      });
      request.body = body;

      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          // A chunk might contain multiple JSON objects
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final data = jsonDecode(line);
              if (data.containsKey('message')) {
                yield data['message']['content'] as String;
              }
            } catch (e) {
              print('Chunk parse error: $e for line: $line');
            }
          }
        }
      } else {
        throw Exception('Ollama stream error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Stream connection failed: $e');
    } finally {
      client.close();
    }
  }

  Future<List<String>> listModels() async {
    final url = Uri.parse('$baseUrl/api/tags');
    print('Ollama GET tags from $url');
    try {
      final response = await http.get(url, headers: {'Accept': '*/*'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((m) => m['name'] as String)
            .toList();
        print('Ollama found models: $models');
        return models;
      }
      print('Ollama tags returned status ${response.statusCode}');
      throw Exception('Ollama tags returned status ${response.statusCode}');
    } catch (e) {
      print('Ollama tags Error: $e');
      rethrow;
    }
  }
}
