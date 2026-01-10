import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String baseUrl = 'https://tristian-weightier-loblolly.ngrok-free.dev'; 
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '134229584480-334prfbri8hbkbu0qanram8j3nvcgr9q.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  
  // Сохранение токена
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  // Получение токена
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  // Удаление токена
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
  
  // Проверка авторизации
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Google Sign-In
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In flow...');
      
      // 1. Trigger Google Sign In flow (native)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ User cancelled Google Sign-In');
        return {'success': false, 'error': 'Sign in aborted by user'};
      }

      print('✅ Google user signed in: ${googleUser.email}');

      // 2. Get auth headers (ID token)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('❌ Failed to get ID Token from Google');
        return {'success': false, 'error': 'Failed to get ID Token from Google'};
      }

      print('✅ ID Token received (length: ${idToken.length})');
      print('🔑 ID Token preview: ${idToken.substring(0, 50)}...');

      // 3. Send ID Token to Backend
      print('📡 Sending token to backend: $baseUrl/api/auth/google/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'access_token': idToken, // We send ID token as 'access_token' field
        }),
      );

      print('📥 Backend response status: ${response.statusCode}');
      print('📥 Backend response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print('✅ Backend authentication successful');
        await saveToken(data['token']);
        print('✅ Token saved locally');
        return {'success': true, 'user': data['user']};
      } else {
        print('❌ Backend authentication failed: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Backend validation failed'};
      }

    } on Exception catch (e) {
      print('❌ Google Sign-In Exception: $e');
      
      // Handle specific error codes
      String errorMessage = e.toString();
      if (errorMessage.contains('ApiException: 10')) {
        errorMessage = 'Google Sign-In configuration error (API 10). Possible fixes:\n'
            '1. Ensure "Support email" is selected in Firebase Project Settings!\n'
            '2. Ensure Google provider is ENABLED in Firebase Auth tab.\n'
            '3. SHA-1 ($errorMessage) must match Firebase console.\n'
            '4. Try uninstalling the app and running flutter clean.';
        print('🚨 CRITICAL: Check Support Email in Firebase Project Settings!');
      } else if (errorMessage.contains('sign_in_failed')) {
        errorMessage = 'Google Sign-In failed. Please try again or use email/password.';
      }
      
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> signOutGoogle() async {
      await _googleSignIn.signOut();
  }
  
  // Регистрация
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String preferredLanguage = 'ru',
  }) async {
    // ... (rest remains same)
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': password,
          'preferred_language': preferredLanguage,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        await saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data.toString()};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Вход
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        await saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Выход
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $token',
          },
        );
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await clearToken();
    }
  }
  
  // Получение профиля
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Profile error: $e');
      return null;
    }
  }
  
  // Проверка лимитов
  Future<Map<String, dynamic>?> checkLimits() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/check-limits/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Check limits error: $e');
      return null;
    }
  }
  
  // Получить заголовки с токеном
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }
}
