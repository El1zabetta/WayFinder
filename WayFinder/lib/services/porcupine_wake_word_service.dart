import 'package:flutter/services.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import '../secrets.dart'; // Import secrets

class PorcupineWakeWordService {
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  Function(String command)? onWakeWordDetected;
  
  // Access key from Picovoice Console
  String get _accessKey => Secrets.picovoiceAccessKey;
  
  // Custom wake word file path
  static const String _keywordPath = 'assets/words/way_finder.ppn';

  Future<bool> initialize() async {
    try {
      print('🎤 Initializing Porcupine Wake Word with custom keyword...');
      
      // Check if access key is set
      if (_accessKey.isEmpty || _accessKey.contains('YOUR_PICOVOICE')) {
        print('⚠️ ERROR: Picovoice Access Key not set in secrets.dart!');
        return false;
      }
      
      // Create Porcupine manager with custom keyword file
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [_keywordPath], // Custom WayFinder wake word
        _wakeWordCallback,
        errorCallback: _errorCallback,
      );
      
      print('✅ Porcupine initialized with custom WayFinder wake word!');
      print('✅ Say "WayFinder" to activate the assistant');
      return true;
    } on PorcupineActivationException catch (e) {
      print('❌ Porcupine Activation Error: $e');
      print('💡 This usually means:');
      print('   1. Access key is invalid or expired');
      print('   2. Get a FREE key at: https://console.picovoice.ai/');
      return false;
    } on PorcupineInvalidArgumentException catch (e) {
      print('❌ Porcupine Invalid Argument: $e');
      print('💡 This usually means:');
      print('   1. The .ppn file path is incorrect');
      print('   2. The .ppn file is corrupted');
      print('   3. Access key doesn\'t match the .ppn file');
      return false;
    } on PorcupineException catch (e) {
      print('❌ Porcupine Error: $e');
      return false;
    } catch (e) {
      print('❌ Porcupine initialization error: $e');
      return false;
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    print('🚀 WAYFINDER WAKE WORD DETECTED!');
    print('🎯 User said: "WayFinder"');
    
    // Trigger callback with default command for vision analysis
    onWakeWordDetected?.call('что передо мной?');
  }

  void _errorCallback(PorcupineException error) {
    print('❌ Porcupine runtime error: $error');
  }

  Future<void> startListening() async {
    if (_porcupineManager == null) {
      print('⚠️ Porcupine not initialized. Cannot start listening.');
      return;
    }
    
    if (_isListening) return;
    
    try {
      await _porcupineManager!.start();
      _isListening = true;
      print('🎤 Porcupine is now listening for "WayFinder"...');
      print('💡 The wake word detection runs continuously in the background');
    } catch (e) {
      print('❌ Failed to start Porcupine: $e');
    }
  }

  Future<void> stopListening() async {
    if (_porcupineManager == null || !_isListening) return;
    
    try {
      await _porcupineManager!.stop();
      _isListening = false;
      print('🛑 Porcupine stopped listening');
    } catch (e) {
      print('❌ Failed to stop Porcupine: $e');
    }
  }

  Future<void> dispose() async {
    await stopListening();
    _porcupineManager?.delete();
    _porcupineManager = null;
  }

  bool get isListening => _isListening;
}
