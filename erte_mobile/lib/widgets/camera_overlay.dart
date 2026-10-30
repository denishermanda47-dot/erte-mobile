import 'package:flutter/material.dart';

import '../models/document_type.dart';

/// Overlay panduan di atas preview kamera:
/// bingkai (rasio KTP/KK), corner brackets berdenyut, area luar gelap
/// (rgba(0,0,0,0.55)), garis tengah tipis, dan teks instruksi.
///
/// Bingkai HANYA panduan visual: foto yang diambil tidak dipotong.
class CameraOverlay extends StatefulWidget {
  const CameraOverlay({
    super.key,
    required this.documentType,
    this.framePadding = EdgeInsets.zero,
  });

  final DocumentType documentType;

  /// Area aman (di luar header & panel bawah) tempat bingkai diletakkan.
  final EdgeInsets framePadding;

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = widget.framePadding;
        final region = Rect.fromLTRB(
          pad.left,
          pad.top,
          c.maxWidth - pad.right,
          c.maxHeight - pad.bottom,
        );

        // Lebar ±85% area; tinggi mengikuti rasio tetap.
        var w = region.width * 0.85;
        var h = w / widget.documentType.aspect;
        final maxH = region.height - 56; // sisakan ruang untuk teks instruksi
        if (h > maxH && maxH > 0) {
          h = maxH;
          w = h * widget.documentType.aspect;
        }
        final frame = Rect.fromCenter(
          center: Offset(region.center.dx, region.center.dy - 16),
          width: w,
          height: h,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _OverlayPainter(frame: frame, pulse: _pulse),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: frame.bottom + 14,
              child: IgnorePointer(
                child: Text(
                  widget.documentType.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.frame, required this.pulse})
    : super(repaint: pulse);

  final Rect frame;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(frame, const Radius.circular(12));

    // Area luar bingkai: hitam semi-transparan 0.55.
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(mask, Paint()..color = const Color(0x8C000000));

    // Garis tengah horizontal tipis.
    canvas.drawLine(
      Offset(frame.left + 16, frame.center.dy),
      Offset(frame.right - 16, frame.center.dy),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = 1,
    );

    // Corner brackets (30px, tebal 4px) dengan pulse halus.
    final opacity = 0.65 + 0.35 * pulse.value;
    final p = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const len = 30.0;
    final l = frame.left, t = frame.top, r = frame.right, b = frame.bottom;

    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t)
        ..lineTo(l + len, t),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r - len, t)
        ..lineTo(r, t)
        ..lineTo(r, t + len),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(l, b - len)
        ..lineTo(l, b)
        ..lineTo(l + len, b),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r - len, b)
        ..lineTo(r, b)
        ..lineTo(r, b - len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.frame != frame;
}
