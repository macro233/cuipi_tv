import 'dart:math';
import 'package:flutter/material.dart';

/// 🎨 包豪斯风格半圆大弧度表盘组件 (复刻大表盘刻度与中央液晶数字)
class BauhausArcDialWidget extends StatelessWidget {
  final double value; // 0.0 ~ 1.0
  final bool isVolume;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMode;
  final String titleText;
  final String readoutText;
  final double height;

  const BauhausArcDialWidget({
    Key? key,
    required this.value,
    required this.isVolume,
    required this.onChanged,
    required this.onToggleMode,
    required this.titleText,
    required this.readoutText,
    this.height = 160,
  }) : super(key: key);

  void _handleTouch(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    double angle = atan2(dy, dx);
    const startAngle = pi * 0.82;
    const sweepAngle = pi * 1.36;

    if (angle < 0) {
      angle += 2 * pi;
    }
    double diff = angle - startAngle;
    if (diff < 0) {
      diff += 2 * pi;
    }

    if (diff <= sweepAngle) {
      final progress = (diff / sweepAngle).clamp(0.0, 1.0);
      onChanged(progress);
    } else {
      final distToStart = (angle - startAngle).abs();
      final endAngle = (startAngle + sweepAngle) % (2 * pi);
      final distToEnd = (angle - endAngle).abs();
      if (distToStart < distToEnd) {
        onChanged(0.0);
      } else {
        onChanged(1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 弧形轨道与放射刻度
                CustomPaint(
                  size: size,
                  painter: BauhausArcDialPainter(
                    value: value,
                    isVolume: isVolume,
                  ),
                ),
                // 中央数字显示与切换按钮
                Positioned(
                  top: height * 0.22,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x55162E29),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x337CE1D4)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVolume ? Icons.volume_up_rounded : Icons.av_timer_rounded,
                                size: 14,
                                color: isVolume ? const Color(0xFFFFC83B) : const Color(0xFF7CE1D4),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                titleText,
                                style: TextStyle(
                                  color: isVolume ? const Color(0xFFFFC83B) : const Color(0xFF7CE1D4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.sync_alt_rounded, size: 12, color: Colors.white54),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            readoutText,
                            style: const TextStyle(
                              color: Color(0xFFFFFDF7),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 🎨 包豪斯弧度画笔：精确绘制圆弧、放射刻度与滑动圆钮
class BauhausArcDialPainter extends CustomPainter {
  final double value; // 0.0 ~ 1.0
  final bool isVolume;
  final Color baseColor;
  final Color activeColor;
  final Color tickColor;

  BauhausArcDialPainter({
    required this.value,
    required this.isVolume,
    this.baseColor = const Color(0x28FFFFFF),
    this.activeColor = const Color(0xFF7CE1D4),
    this.tickColor = const Color(0x66FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = (size.width * 0.38).clamp(65.0, 130.0);

    const startAngle = pi * 0.82;
    const sweepAngle = pi * 1.36;

    // 1. 绘制放射刻度线
    const tickCount = 21;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = startAngle + sweepAngle * t;
      final isMajor = i % 4 == 0;
      final tickLen = isMajor ? 9.0 : 5.0;
      final tickR1 = radius + 9.0;
      final tickR2 = tickR1 + tickLen;

      final p1 = Offset(center.dx + tickR1 * cos(angle), center.dy + tickR1 * sin(angle));
      final p2 = Offset(center.dx + tickR2 * cos(angle), center.dy + tickR2 * sin(angle));

      final isActive = t <= value;
      tickPaint.color = isActive
          ? (isMajor ? const Color(0xFFFFC83B) : activeColor)
          : (isMajor ? const Color(0xAAFFFFFF) : tickColor);
      tickPaint.strokeWidth = isMajor ? 2.0 : 1.2;

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 2. 绘制弧形底轨
    final bgArcPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgArcPaint,
    );

    // 3. 绘制发光高亮激活弧轨
    final activeSweep = sweepAngle * value.clamp(0.0, 1.0);
    if (activeSweep > 0.001) {
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        glowPaint,
      );

      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // 4. 绘制滑动旋钮
    final knobAngle = startAngle + sweepAngle * value.clamp(0.0, 1.0);
    final knobCenter = Offset(
      center.dx + radius * cos(knobAngle),
      center.dy + radius * sin(knobAngle),
    );

    // 旋钮阴影与深色外环
    final knobShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(knobCenter + const Offset(0, 2), 11, knobShadowPaint);

    final knobOuterPaint = Paint()
      ..color = const Color(0xFF1B3630)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 11, knobOuterPaint);

    final knobRimPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(knobCenter, 11, knobRimPaint);

    // 旋钮中心高光小圆点 (音量模式为金黄，进度模式为象牙白)
    final knobDotPaint = Paint()
      ..color = isVolume ? const Color(0xFFFFC83B) : const Color(0xFFFFFDF7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 4, knobDotPaint);
  }

  @override
  bool shouldRepaint(covariant BauhausArcDialPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isVolume != isVolume ||
        oldDelegate.activeColor != activeColor;
  }
}
