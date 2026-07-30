import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/platform_utils.dart';
import 'components/common_page_top_bar.dart';
import 'contact_page.dart';

class DiscoveriesPage extends StatefulWidget {
  const DiscoveriesPage({super.key});

  @override
  State<DiscoveriesPage> createState() => _DiscoveriesPageState();
}

class _DiscoveriesPageState extends State<DiscoveriesPage>
    with TickerProviderStateMixin {
  late final AnimationController _driftController;
  late final AnimationController _pulseController;
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _driftController.dispose();
    _pulseController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  void _openContact() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContactPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentMaxWidth = PlatformUtils.getContentMaxWidth();
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: Stack(
        children: [
          const _AmbientBackdrop(),
          AnimatedBuilder(
            animation: Listenable.merge([_driftController, _pulseController]),
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _AmbientBubblesPainter(
                  progress: _driftController.value,
                  pulse: _pulseController.value,
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: contentMaxWidth ?? double.infinity,
                ),
                child: Column(
                  children: [
                    CommonPageTopBar(
                      title: '发现宝藏',
                      rightIcon: Icons.mark_chat_unread_outlined,
                      onRightPressed: _openContact,
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: Listenable.merge(
                            [_driftController, _pulseController, _enterController]),
                        builder: (context, _) {
                          final enter = Curves.easeOutCubic
                              .transform(_enterController.value);
                          final drift = _driftController.value * math.pi * 2;
                          final pulse = _pulseController.value;

                          return Stack(
                            children: [
                              Positioned(
                                left: 28,
                                top: 28 + math.sin(drift) * 10,
                                child: Opacity(
                                  opacity: 0.35 + pulse * 0.15,
                                  child: _SoftOrb(
                                    size: 88 + pulse * 8,
                                    colors: const [
                                      Color(0x66FF9BB3),
                                      Color(0x33FFE4EC),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 18,
                                top: 120 + math.cos(drift * 0.8) * 12,
                                child: Opacity(
                                  opacity: 0.28 + (1 - pulse) * 0.12,
                                  child: _SoftOrb(
                                    size: 64,
                                    colors: const [
                                      Color(0x55F43F7A),
                                      Color(0x22FFFFFF),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 40,
                                bottom: 70 + math.sin(drift + 1.2) * 14,
                                child: Opacity(
                                  opacity: 0.22,
                                  child: _SoftOrb(
                                    size: 52,
                                    colors: const [
                                      Color(0x44FDA4AF),
                                      Color(0x22FFFFFF),
                                    ],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment(
                                  -0.55 + math.sin(drift) * 0.035,
                                  -0.18 + math.cos(drift * 0.9) * 0.04,
                                ),
                                child: Transform.scale(
                                  scale: 0.82 + enter * 0.18,
                                  child: Opacity(
                                    opacity: enter,
                                    child: _TreasureBubble(
                                      title: 'Codex 代充',
                                      subtitle: '官方直充 质保时长',
                                      icon: Icons.auto_awesome_rounded,
                                      size: 168 + pulse * 6,
                                      gradient: const [
                                        Color(0xFFFF6B8A),
                                        Color(0xFFE11D48),
                                        Color(0xFFBE123C),
                                      ],
                                      glow: const Color(0x66E11D48),
                                      onTap: _openContact,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment(
                                  0.58 + math.cos(drift + 0.6) * 0.03,
                                  0.38 + math.sin(drift * 1.1) * 0.045,
                                ),
                                child: Transform.scale(
                                  scale: 0.78 + enter * 0.22,
                                  child: Opacity(
                                    opacity: enter,
                                    child: _TreasureBubble(
                                      title: '机票代订',
                                      subtitle: '最少 9.3 折',
                                      icon: Icons.flight_takeoff_rounded,
                                      size: 146 + (1 - pulse) * 7,
                                      gradient: const [
                                        Color(0xFFFF8FA8),
                                        Color(0xFFF43F7A),
                                        Color(0xFFDB2777),
                                      ],
                                      glow: const Color(0x55F43F7A),
                                      onTap: _openContact,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF1F2),
            Color(0xFFFFE4EC),
            Color(0xFFFFF7F9),
          ],
          stops: [0, 0.35, 0.75, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _TreasureBubble extends StatefulWidget {
  const _TreasureBubble({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.size,
    required this.gradient,
    required this.glow,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double size;
  final List<Color> gradient;
  final Color glow;
  final VoidCallback onTap;

  @override
  State<_TreasureBubble> createState() => _TreasureBubbleState();
}

class _TreasureBubbleState extends State<_TreasureBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glow,
                      blurRadius: 34,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(-6, -8),
                    ),
                  ],
                ),
              ),
              Container(
                width: size * 0.92,
                height: size * 0.92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradient,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: size * 0.12,
                      left: size * 0.16,
                      child: Container(
                        width: size * 0.34,
                        height: size * 0.18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: size * 0.12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientBubblesPainter extends CustomPainter {
  _AmbientBubblesPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final specs = <_DotSpec>[
      _DotSpec(0.18, 0.22, 7, 0.12),
      _DotSpec(0.78, 0.18, 5, 0.10),
      _DotSpec(0.86, 0.55, 8, 0.11),
      _DotSpec(0.12, 0.62, 6, 0.09),
      _DotSpec(0.48, 0.78, 4, 0.08),
      _DotSpec(0.62, 0.30, 5, 0.10),
      _DotSpec(0.30, 0.88, 6, 0.09),
    ];

    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final phase = progress * math.pi * 2 + i * 0.7;
      final dx = math.sin(phase) * 10;
      final dy = math.cos(phase * 0.85) * 12;
      final r = s.radius + pulse * 1.5;
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFF8FA8),
          const Color(0xFFE11D48),
          i / specs.length,
        )!
            .withValues(alpha: s.opacity + pulse * 0.04);
      canvas.drawCircle(
        Offset(size.width * s.x + dx, size.height * s.y + dy),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}

class _DotSpec {
  const _DotSpec(this.x, this.y, this.radius, this.opacity);
  final double x;
  final double y;
  final double radius;
  final double opacity;
}
