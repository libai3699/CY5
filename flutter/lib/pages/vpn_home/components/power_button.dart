import 'dart:math' as math;

import 'package:flutter/material.dart';

class PowerButton extends StatefulWidget {
  const PowerButton({
    super.key,
    required this.connected,
    required this.busy,
    required this.compact,
    required this.onPressed,
  });

  final bool connected;
  final bool busy;
  final bool compact;
  final VoidCallback onPressed;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.connected || widget.busy
            ? 1 + math.sin(_controller.value * math.pi * 2) * 0.035
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.compact ? 170 : 210,
        height: widget.compact ? 170 : 210,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF5C8A),
                Color(0xFFE11D48),
                Color(0xFFBE123C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withOpacity(widget.connected ? 0.42 : 0.24),
                blurRadius: widget.connected ? 34 : 22,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.busy ? null : widget.onPressed,
              child: Icon(
                widget.connected ? Icons.power_settings_new_rounded : Icons.bolt_rounded,
                color: Colors.white,
                size: widget.compact ? 70 : 86,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
