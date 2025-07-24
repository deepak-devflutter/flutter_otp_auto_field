import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_service.dart';

/// A PIN/OTP input widget with auto-fill support using Android SMS Retriever.
///
/// Example:
/// ```dart
/// FlutterOtpAutoField(
///   length: 6,
///   onCompleted: (value) => print('OTP: $value'),
/// )
/// ```
class FlutterOtpAutoField extends StatefulWidget {
  final int length;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool obscureText;
  final String obscuringCharacter;
  final double boxWidth;
  final double boxHeight;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const FlutterOtpAutoField({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.autoFocus = false,
    this.obscureText = false,
    this.obscuringCharacter = '*',
    this.boxWidth = 50,
    this.boxHeight = 55,
    this.decoration,
    this.textStyle,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<FlutterOtpAutoField> createState() => _FlutterOtpAutoFieldState();
}

class _FlutterOtpAutoFieldState extends State<FlutterOtpAutoField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  late final bool _ownsFocusNode;
  StreamSubscription<String>? _otpSub;

  @override
  void initState() {
    super.initState();

    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();

    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();

    _controller.addListener(_handleTextChange);

    _initOtpListening();
  }

  Future<void> _initOtpListening() async {
    await OtpService().init();
    _otpSub = OtpService().otpStream.listen((otp) {
      if (otp.length == widget.length) {
        _controller.text = otp;
        _focusNode.unfocus(); // optional: auto-close keyboard
      }
    });
  }

  void _handleTextChange() {
    final text = _controller.text;
    widget.onChanged?.call(text);

    if (text.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(text);
    }
    setState(() {}); // only triggers box highlight rebuild
  }

  void _requestFocus() {
    if (_controller.text.length >= widget.length) {
      _focusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 50), () {
        _focusNode.requestFocus();
      });
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _otpSub?.cancel();

    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputText = _controller.text;

    return GestureDetector(
      onTap: _requestFocus,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden text field for input
          Offstage(
            offstage: true,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autoFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableSuggestions: false,
              autocorrect: false,
              enableInteractiveSelection: false,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.length),
                FilteringTextInputFormatter.digitsOnly,
              ],
              onEditingComplete: _focusNode.unfocus,
            ),
          ),

          // Display boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final isActive = inputText.length == index ||
                  (inputText.length == widget.length && index == widget.length - 1);
              final char = index < inputText.length ? inputText[index] : '';
              final display = widget.obscureText && char.isNotEmpty
                  ? widget.obscuringCharacter
                  : char;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.boxWidth,
                height: widget.boxHeight,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: widget.decoration ??
                    BoxDecoration(
                      color: isActive ? Colors.blue.withValues(alpha: 0.05) : Colors.transparent,
                      border: Border.all(
                        color: isActive ? Colors.blue : Colors.grey.shade400,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                child: Text(
                  display,
                  style: widget.textStyle ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
