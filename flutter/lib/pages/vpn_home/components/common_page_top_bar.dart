import 'package:flutter/material.dart';

class CommonPageTopBar extends StatelessWidget {
  const CommonPageTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.rightIcon = Icons.chat_bubble_rounded,
    this.onRightPressed,
    this.showRightButton = true,
  });

  final String title;
  final VoidCallback? onBack;
  final IconData rightIcon;
  final VoidCallback? onRightPressed;
  /// 是否显示右侧图标按钮，默认 true
  final bool showRightButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF9F1239),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF881337),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showRightButton)
            IconButton(
              onPressed: onRightPressed,
              icon: Icon(rightIcon),
              color: const Color(0xFF9F1239),
            )
          else
            // 占位保持标题居中
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
