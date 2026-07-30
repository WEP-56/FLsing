import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 从等距圆柱投影（equirectangular）世界地图采样大陆点云。
///
/// 与 Web 版 `src/components/Globe.tsx` 的采样逻辑完全一致：
///   1. 图片缩到 220×110
///   2. 逐像素读亮度，> 110 判定为陆地
///   3. 像素坐标 → 经纬度 → 单位球面笛卡尔坐标
///
/// 返回扁平数组 [x0,y0,z0, x1,y1,z1, ...]，约 1500–4000 个点。
class GlobePoints {
  const GlobePoints._();

  static const _sampleWidth = 220;
  static const _sampleHeight = 110;
  static const _luminanceThreshold = 110.0;

  /// 主入口。解码在主 isolate（dart:ui 限制），像素扫描在后台 isolate。
  static Future<Float32List> load(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: _sampleWidth,
        targetHeight: _sampleHeight,
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();

      if (bytes == null) return fallbackSphere();

      // 扫描 24k 像素，丢到后台 isolate 避免掉帧
      final pts = await compute(_scanPixels, bytes.buffer.asUint8List());
      return pts.length > 2400 ? pts : fallbackSphere();
    } catch (_) {
      return fallbackSphere();
    }
  }

  /// 纯计算，运行在后台 isolate。
  static Float32List _scanPixels(Uint8List rgba) {
    final pts = <double>[];
    const w = _sampleWidth;
    const h = _sampleHeight;

    for (var y = 0; y < h; y++) {
      final lat = (y / h - 0.5) * math.pi;
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);

      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final lum = 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
        if (lum <= _luminanceThreshold) continue;

        final lon = (x / w) * math.pi * 2;
        pts
          ..add(cosLat * math.cos(lon))
          ..add(sinLat)
          ..add(cosLat * math.sin(lon));
      }
    }
    return Float32List.fromList(pts);
  }

  /// 兜底：斐波那契球面均匀分布点，地图缺失时仍有可用视觉。
  static Float32List fallbackSphere([int count = 1500]) {
    final pts = Float32List(count * 3);
    final ga = math.pi * (3 - math.sqrt(5)); // 黄金角
    for (var i = 0; i < count; i++) {
      final y = 1 - (i / (count - 1)) * 2;
      final r = math.sqrt(1 - y * y);
      final th = ga * i;
      pts[i * 3] = math.cos(th) * r;
      pts[i * 3 + 1] = y;
      pts[i * 3 + 2] = math.sin(th) * r;
    }
    return pts;
  }
}
