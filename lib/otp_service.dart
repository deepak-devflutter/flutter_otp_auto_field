import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A singleton OTP listener service using Android's SMS Retriever API.
///
/// Call [init] once during app startup or on-demand. Access the stream via [otpStream].
class OtpService {
  OtpService._internal();
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;

  static const MethodChannel _channel = MethodChannel('flutter_otp_auto_field');

  final StreamController<String> _otpStreamController =
  StreamController<String>.broadcast();

  bool _isInitialized = false;

  /// Call this once to initialize the plugin and start listening to OTPs.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Handle native messages
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onOtpReceived") {
        final otp = call.arguments as String?;
        if (otp != null && !_otpStreamController.isClosed) {
          _otpStreamController.add(otp);
        }
      }
    });

    // Start SMS listener on Android side
    try {
      await _channel.invokeMethod('startListening');
    } catch (e, stackTrace) {
      debugPrint("Error starting SMS retriever: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Access the OTP stream for listening to incoming codes.
  ///
  /// Example:
  /// ```dart
  /// OtpService().otpStream.listen((otp) => print("OTP: $otp"));
  /// ```
  Stream<String> get otpStream => _otpStreamController.stream;

  /// Optionally fetch the Android app signature for the SMS Retriever hash.
  Future<String?> getAndroidAppSignature() async {
    try {
      return await _channel.invokeMethod<String>('getAppSignature');
    } catch (e, stackTrace) {
      debugPrint("Error getting app signature: $e");
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Call this during app shutdown or widget dispose if needed.
  void dispose() {
    if (!_otpStreamController.isClosed) {
      _otpStreamController.close();
    }
  }
}
