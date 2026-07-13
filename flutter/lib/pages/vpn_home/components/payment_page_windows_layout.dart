import 'package:flutter/material.dart';

class PaymentPageWindowsLayout extends StatelessWidget {
  const PaymentPageWindowsLayout({
    super.key,
    required this.leftContent,
    required this.onActionPressed,
    required this.actionLabel,
    required this.onlinePayment,
    this.previewTitle,
    this.previewImageUrl,
  });

  final Widget leftContent;
  final VoidCallback? onActionPressed;
  final String actionLabel;
  final bool onlinePayment;
  final String? previewTitle;
  final String? previewImageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: leftContent,
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.86),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF881337).withOpacity(0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    previewTitle ??
                        '\u5f53\u524d\u6536\u6b3e\u4e8c\u7ef4\u7801',
                    style: const TextStyle(
                      color: Color(0xFF881337),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    onlinePayment
                        ? '\u70b9\u51fb\u4e0b\u65b9\u6309\u94ae\u6253\u5f00\u5728\u7ebf\u6536\u94f6\u53f0\uff0c\u652f\u4ed8\u6210\u529f\u540e\u7cfb\u7edf\u4f1a\u81ea\u52a8\u5f00\u901a\u5957\u9910\u3002'
                        : '\u8bf7\u4f7f\u7528\u5de6\u4fa7\u5df2\u9009\u652f\u4ed8\u65b9\u5f0f\u8fdb\u884c\u626b\u7801\u6216\u8f6c\u8d26\uff0c\u5b8c\u6210\u652f\u4ed8\u540e\u518d\u8054\u7cfb\u4eba\u5de5\u786e\u8ba4\u3002',
                    style: TextStyle(
                      color: const Color(0xFF9F1239).withOpacity(0.72),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7F9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE11D48).withOpacity(0.12),
                        ),
                      ),
                      child: Center(
                        child: previewImageUrl != null &&
                                previewImageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  previewImageUrl!,
                                  width: 360,
                                  height: 360,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _buildEmptyState(
                                    '\u4e8c\u7ef4\u7801\u52a0\u8f7d\u5931\u8d25',
                                  ),
                                ),
                              )
                            : _buildEmptyState(
                                '\u5f53\u524d\u652f\u4ed8\u65b9\u5f0f\u6682\u65e0\u4e8c\u7ef4\u7801',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: onActionPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 72,
          color: const Color(0xFFE11D48).withOpacity(0.35),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          style: TextStyle(
            color: const Color(0xFF9F1239).withOpacity(0.72),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
