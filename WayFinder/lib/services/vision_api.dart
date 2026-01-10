import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisionApiService {
  static const String _defaultUrl = "https://tristian-weightier-loblolly.ngrok-free.dev";

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url') ?? _defaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  Future<Map<String, dynamic>> smartAnalyze(XFile? image, String? audioPath, {String mode = 'chat', String text = ''}) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/smart-analyze/');

    var request = http.MultipartRequest('POST', uri);
    request.headers['ngrok-skip-browser-warning'] = 'true';
    
    // Add User ID (stub for now, could be device ID)
    request.fields['user_id'] = 'mobile_user_pro';
    request.fields['mode'] = mode;
    request.fields['text'] = text;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    
    if (audioPath != null) {
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Handle explicit UTF-8 decoding
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Failed: $e");
    }
  }

  Future<Map<String, dynamic>> requestNavigation(
    String? audioPath, 
    String text, 
    {double? currentLat, double? currentLon}
  ) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/navigate/');

    var request = http.MultipartRequest('POST', uri);
    request.headers['ngrok-skip-browser-warning'] = 'true';
    
    request.fields['user_id'] = 'mobile_user_pro';
    request.fields['text'] = text;
    
    if (currentLat != null) {
      request.fields['current_lat'] = currentLat.toString();
    }
    if (currentLon != null) {
      request.fields['current_lon'] = currentLon.toString();
    }
    
    if (audioPath != null) {
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Failed: $e");
    }
  }
}
