import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String baseUrl = 'https://tristian-weightier-loblolly.ngrok-free.dev'; 
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '134229584480-334prfbri8hbkbu0qanram8j3nvcgr9q.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  // Custom Client to ignore bad certificates (common in ngrok/dev)
  static final http.Client _client = IOClient(
    HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true
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
    await prefs.remove('user_data'); // Clear user data too
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
      
      // Sign out first to always show account picker dialog
      await _googleSignIn.signOut();
      
      // 1. Trigger Google Sign In flow (native) - this will show account picker
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

      // 3. Send ID Token to Backend (optional - auth works even if backend unavailable)
      print('📡 Sending token to backend: $baseUrl/api/auth/google/');
      
      try {
        final response = await _client.post(
          Uri.parse('$baseUrl/api/auth/google/'),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({
            'access_token': idToken,
          }),
        ).timeout(const Duration(seconds: 5));

        print('📥 Backend response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Backend authentication successful');
          await saveToken(data['token']);
          await saveUserLocally(data['user']); // Save user info
          print('✅ Token saved locally');
          return {'success': true, 'user': data['user']};
        }
      } catch (e) {
        print('⚠️ Backend unavailable, using local auth: $e');
      }
      
      // Backend failed or timeout - still allow login with Google auth
      // Backend failed or timeout - still allow login with Google auth
      await saveToken(idToken); // Save Google token as fallback
      final localUser = {'email': googleUser.email, 'username': googleUser.displayName ?? 'Google User'};
      await saveUserLocally(localUser);
      print('✅ Using Google auth (backend unavailable)');
      return {'success': true, 'user': localUser};

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
    // ... (rest remains same)
    try {
      final response = await _client.post(
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
        await saveUserLocally(data['user']);
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
      final response = await _client.post(
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
        await saveUserLocally(data['user']);
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
        await _client.post(
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
  
  // Получение профиля - Returns LOCAL data primarily
  Future<Map<String, dynamic>?> getProfile() async {
    return getUserLocally();
  }
  
  // Save user data locally
  Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(user));
  }
  
  // Get local user data
  Future<Map<String, dynamic>?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString('user_data');
    if (userStr != null) {
      return json.decode(userStr);
    }
    return null;
  }
  
  // Проверка лимитов - DISABLED to prevent HandshakeException
  Future<Map<String, dynamic>?> checkLimits() async {
    // Temporarily disabled
    return null;
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
