import 'dart:io';

import 'package:image/image.dart' as img;

class WeedVisionEstimate {
  final double coveragePct;
  final String label;
  final int sampledPixels;

  const WeedVisionEstimate({
    required this.coveragePct,
    required this.label,
    required this.sampledPixels,
  });
}

class WeedVision {
  static Future<WeedVisionEstimate> estimateGreenCover(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const WeedVisionEstimate(coveragePct: 0, label: '판독 실패', sampledPixels: 0);
    }

    final small = img.copyResize(decoded, width: decoded.width > 360 ? 360 : decoded.width);
    int total = 0;
    int green = 0;

    for (var y = 0; y < small.height; y += 2) {
      for (var x = 0; x < small.width; x += 2) {
        final p = small.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        total++;

        final greenDominant = g > 55 && g > r * 1.08 && g > b * 1.06;
        final vegetationLike = (g - r) > 10 && (g - b) > 6;
        if (greenDominant && vegetationLike) green++;
      }
    }

    final pct = total == 0 ? 0.0 : green * 100 / total;
    final label = pct < 15 ? '낮음' : pct < 40 ? '중간' : '높음';
    return WeedVisionEstimate(
      coveragePct: double.parse(pct.toStringAsFixed(1)),
      label: label,
      sampledPixels: total,
    );
  }
}
