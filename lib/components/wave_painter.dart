// lib/components/wave_painter.dart
// 🌊 波浪動畫繪製器

import 'package:flutter/material.dart';
import 'dart:math' as math;

class WavePainter extends CustomPainter {
  final double animationValue;
  final double waveHeight;
  final Color color;

  WavePainter({
    required this.animationValue,
    required this.waveHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 計算波浪的 Y 位置 (從底部往上)
    final waveY = size.height * (1 - waveHeight);

    // 繪製波浪路徑
    path.moveTo(0, waveY);

    // 繪製兩層正弦波疊加,產生更自然的波浪效果
    for (double i = 0; i <= size.width; i += 2) {
      final normalizedX = i / size.width;
      
      // 第一層波浪 (主波)
      final wave1 = math.sin(
        (normalizedX * 2 * math.pi * 2) + // 2個完整波浪
        (animationValue * 2 * math.pi)     // 動畫偏移
      ) * 8;  // 波浪振幅
      
      // 第二層波浪 (次波,頻率稍快)
      final wave2 = math.sin(
        (normalizedX * 2 * math.pi * 3) +  // 3個完整波浪
        (animationValue * 2 * math.pi * 1.5) // 動畫偏移(稍快)
      ) * 4;  // 較小振幅
      
      // 合併兩層波浪
      final y = waveY + wave1 + wave2;
      path.lineTo(i, y);
    }

    // 完成路徑 (填滿底部)
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.waveHeight != waveHeight ||
           oldDelegate.color != color;
  }
}

/// 🌊 多層波浪效果 (更豐富的動畫)
class MultiWavePainter extends CustomPainter {
  final double animationValue;
  final double waveHeight;

  MultiWavePainter({
    required this.animationValue,
    required this.waveHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 繪製三層波浪,由深到淺
    _drawWave(
      canvas, 
      size, 
      Colors.white.withValues(alpha: 0.1), 
      waveHeight - 0.02,
      animationValue,
      amplitude: 12,
      frequency: 1.5,
    );
    
    _drawWave(
      canvas, 
      size, 
      Colors.white.withValues(alpha: 0.15), 
      waveHeight - 0.01,
      animationValue * 0.8,
      amplitude: 8,
      frequency: 2,
    );
    
    _drawWave(
      canvas, 
      size, 
      Colors.white.withValues(alpha: 0.2), 
      waveHeight,
      animationValue * 1.2,
      amplitude: 6,
      frequency: 2.5,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color color,
    double height,
    double animation,
    {
      required double amplitude,
      required double frequency,
    }
  ) {
    final path = Path();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final waveY = size.height * (1 - height.clamp(0.0, 1.0));

    path.moveTo(0, waveY);

    for (double i = 0; i <= size.width; i += 2) {
      final normalizedX = i / size.width;
      final wave = math.sin(
        (normalizedX * 2 * math.pi * frequency) +
        (animation * 2 * math.pi)
      ) * amplitude;
      
      path.lineTo(i, waveY + wave);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MultiWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.waveHeight != waveHeight;
  }
}