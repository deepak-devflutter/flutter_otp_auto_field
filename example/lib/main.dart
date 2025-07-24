import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otp_auto_field/flutter_otp_auto_field.dart';
import 'package:flutter_otp_auto_field/otp_service.dart';

void main() {
  runApp(const MyApp());
}

/// Main application widget showcasing different usages of the Flutter OTP plugin.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final otpController = TextEditingController();
  final secondOtpController = TextEditingController();
  late final StreamSubscription<String> _otpSub;

  String appSignature = '';

  @override
  void initState() {
    super.initState();

    /// 📌 Example 1: Get Android App Signature for SMS Retriever
    OtpService().getAndroidAppSignature().then((signature) {
      setState(() => appSignature = signature ?? '');
    });

    /// 📌 Example 2: Start listening for OTP using OtpService
    /// Use this if you want to manually handle autofill outside the widget.
    OtpService().init();

    _otpSub = OtpService().otpStream.listen((otp) {
      debugPrint('Received OTP (via stream): $otp');
      // Optionally fill it into a controller:
      // otpController.text = otp;
    });
  }

  @override
  void dispose() {
    _otpSub.cancel();
    otpController.dispose();
    secondOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter OTP Field Example',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter OTP Field Plugin Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                "📲 Android App Signature (for SMS Retriever):",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SelectableText(
                appSignature,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 32),

              /// 📌 Example 3: FlutterOtpAutoField default widget with autofill & styling
              const Text("Default Auto-fill OTP Field "),
              FlutterOtpAutoField(),
              const SizedBox(height: 48),

              /// 📌 Example 4: FlutterOtpAutoField widget with autofill & styling
              const Text("Auto-fill OTP Field (Length: 5)"),
              const SizedBox(height: 8),
              FlutterOtpAutoField(
                length: 5,
                controller: otpController,
                boxHeight: 60,
                boxWidth: 60,
                autoFocus: true,
                obscureText: false,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.green.shade100,
                      width: 4,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                textStyle: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                onCompleted: (value) {
                  debugPrint("OTP Completed: $value");
                },
              ),

              const SizedBox(height: 48),

              /// 📌 Example 5: Another OTP field with different style
              const Text("Second OTP Field (Length: 6)"),
              const SizedBox(height: 8),
              FlutterOtpAutoField(
                length: 6,
                controller: secondOtpController,
                boxHeight: 55,
                boxWidth: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.blueGrey, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                onCompleted: (value) {
                  debugPrint("Second OTP Completed: $value");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
