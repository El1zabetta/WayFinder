/// WayFinder 3.0 — Auth Provider
/// Manages Firebase Authentication and Google Sign-In state.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> getIdToken() async {
    if (_user == null) return null;
    try {
      final token = await _user!.getIdToken();
      return token;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'ID_TOKEN_EXPIRED') {
        _log.i('Firebase ID token expired, refreshing...');
        try {
          await _user!.reload();
          final newToken = await _user!.getIdToken();
          return newToken;
        } catch (refreshError) {
          _log.e('Failed to refresh token: $refreshError');
          await signOut();
          return null;
        }
      }
      _log.e('FirebaseAuthException: ${e.message}');
      return null;
    } catch (e) {
      _log.e('Error getting ID token: $e');
      return null;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _log.e('Google Sign-In Error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      _user = null;
    } catch (e) {
      _log.e('Sign-Out Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
