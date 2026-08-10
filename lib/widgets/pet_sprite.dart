import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_animation.dart';

class PetSprite extends StatelessWidget {
  const PetSprite({super.key, required this.animation, required this.frame});

  final PetAnimation animation;
  final int frame;

  static final Map<String, Future<ui.Image>> _cache = {};

  Future<ui.Image> _load(String sheet) {
    return _cache.putIfAbsent(sheet, () async {
      final bytes = await rootBundle.load('Assets/Animations/$sheet');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _load(animation.sheet),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.expand();
        return CustomPaint(
          painter: _SpritePainter(
            image: snapshot.data!,
            sourceTop: animation.sourceTop,
            sourceLeft: animation.sourceLefts[frame],
            sourceHeight: animation.sourceHeight,
            frame: frame,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({
    required this.image,
    required this.sourceTop,
    required this.sourceLeft,
    required this.sourceHeight,
    required this.frame,
  });

  final ui.Image image;
  final double sourceTop;
  final double sourceLeft;
  final double sourceHeight;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 256.0;
    final source = Rect.fromLTWH(
      sourceLeft,
      sourceTop,
      frameSize,
      sourceHeight,
    );
    final destinationHeight = size.width * sourceHeight / frameSize;
    final destination = Rect.fromLTWH(
      0,
      (size.height - destinationHeight) / 2,
      size.width,
      destinationHeight,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.sourceTop != sourceTop ||
      oldDelegate.sourceLeft != sourceLeft ||
      oldDelegate.sourceHeight != sourceHeight ||
      oldDelegate.frame != frame;
}
