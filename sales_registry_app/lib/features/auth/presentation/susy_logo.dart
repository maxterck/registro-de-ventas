import 'package:flutter/material.dart';
import 'dart:math' as math;

class SusyMarketLogo extends StatefulWidget {
  final double size;
  const SusyMarketLogo({super.key, this.size = 100});

  @override
  State<SusyMarketLogo> createState() => _SusyMarketLogoState();
}

class _SusyMarketLogoState extends State<SusyMarketLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animación suave de flotación
    _controller = AnimationController(
       duration: const Duration(seconds: 4), 
       vsync: this
    )..repeat(reverse: true);
  }

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
        final floatOffset = math.sin(_controller.value * math.pi) * 8.0;

        return Transform.translate(
           offset: Offset(0, floatOffset),
           child: SizedBox(
             width: widget.size,
             height: widget.size,
             child: CustomPaint(
               painter: _HouseLogoPainter(),
             ),
           ),
        );
      },
    );
  }
}

class _HouseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pintar base de la casa (Cubo 2D isométrico)
    final basePaint = Paint()
      ..color = Colors.indigo.shade600
      ..style = PaintingStyle.fill;
      
    final baseShadowPaint = Paint()
      ..color = Colors.indigo.shade800
      ..style = PaintingStyle.fill;

    // Frente de la casa
    final frontRect = Rect.fromLTWH(w * 0.15, h * 0.45, w * 0.7, h * 0.5);
    // Sombra proyectada por el bloque base
    final shadowBaseRect = Rect.fromLTWH(w * 0.2, h * 0.5, w * 0.7, h * 0.55);
    canvas.drawRRect(RRect.fromRectAndRadius(shadowBaseRect, const Radius.circular(12)), baseShadowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(frontRect, const Radius.circular(12)), basePaint);

    // Puerta
    final doorPaint = Paint()..color = Colors.orangeAccent.shade200;
    final doorRect = Rect.fromLTWH(w * 0.4, h * 0.65, w * 0.2, h * 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(doorRect, const Radius.circular(6)), doorPaint);

    // Techo (Pirámide/Triángulo)
    final roofPaint = Paint()
       ..color = Colors.indigo.shade400
       ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.1) // Cúspide
      ..lineTo(w * 0.05, h * 0.5) // Esquina izq
      ..lineTo(w * 0.95, h * 0.5) // Esquina der
      ..close();

    // Sombra del techo
    canvas.drawShadow(path, Colors.black45, 8.0, false);
    
    // Dibujo del techo
    canvas.drawPath(path, roofPaint);
    
    // Un toque moderno: un destello naranja en el techo
    final highlightPaint = Paint()
       ..color = Colors.orangeAccent.withOpacity(0.8)
       ..style = PaintingStyle.stroke
       ..strokeWidth = 4
       ..strokeCap = StrokeCap.round;
       
    canvas.drawLine(Offset(w * 0.5, h * 0.15), Offset(w * 0.15, h * 0.45), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
