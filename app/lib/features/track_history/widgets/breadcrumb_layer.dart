import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class Breadcrumb {
  final LatLng point;
  final double bearing; // Radians for rotation
  final int indexInRoute; // To sync with animation

  Breadcrumb({required this.point, required this.bearing, required this.indexInRoute});
}

class BreadcrumbLayer extends StatefulWidget {
  final List<LatLng> routePoints;
  final Animation<double> animation;

  const BreadcrumbLayer({
    super.key,
    required this.routePoints,
    required this.animation,
  });

  @override
  State<BreadcrumbLayer> createState() => _BreadcrumbLayerState();
}

class _BreadcrumbLayerState extends State<BreadcrumbLayer> {
  List<Breadcrumb> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _calculateBreadcrumbs();
  }

  @override
  void didUpdateWidget(BreadcrumbLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routePoints != widget.routePoints) {
      _calculateBreadcrumbs();
    }
  }

  void _calculateBreadcrumbs() {
    if (widget.routePoints.length < 10) {
      _breadcrumbs = [];
      return;
    }

    final distance = const Distance();
    double totalDistance = 0.0;
    
    for (int i = 0; i < widget.routePoints.length - 1; i++) {
      totalDistance += distance.as(LengthUnit.Meter, widget.routePoints[i], widget.routePoints[i + 1]);
    }

    // Target ~30-40 markers. Clamp the interval to sensible defaults.
    double interval = (totalDistance / 35.0).clamp(200.0, 5000.0);

    List<Breadcrumb> crumbs = [];
    double accumulatedSinceLast = 0.0;

    for (int i = 0; i < widget.routePoints.length - 1; i++) {
      final p1 = widget.routePoints[i];
      final p2 = widget.routePoints[i + 1];
      
      double segmentDist = distance.as(LengthUnit.Meter, p1, p2);
      accumulatedSinceLast += segmentDist;

      if (accumulatedSinceLast >= interval) {
        // Calculate bearing from p1 to p2 in degrees, then to radians
        double bearingDegrees = distance.bearing(p1, p2);
        
        crumbs.add(Breadcrumb(
          point: p2,
          bearing: bearingDegrees * pi / 180.0,
          indexInRoute: i + 1,
        ));
        
        accumulatedSinceLast = 0.0;
      }
    }

    // Ensure we don't drop a marker exactly on top of the end pin
    if (crumbs.isNotEmpty && (widget.routePoints.length - crumbs.last.indexInRoute) < 5) {
      crumbs.removeLast();
    }

    setState(() {
      _breadcrumbs = crumbs;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_breadcrumbs.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final currentPointCount = (widget.routePoints.length * widget.animation.value).ceil();
        
        final visibleCrumbs = _breadcrumbs.where((b) => b.indexInRoute <= currentPointCount).toList();

        return MarkerLayer(
          markers: visibleCrumbs.map((crumb) {
            return Marker(
              point: crumb.point,
              width: 16.0,
              height: 16.0,
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: crumb.bearing,
                child: const ChevronPainterWidget(),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ChevronPainterWidget extends StatelessWidget {
  const ChevronPainterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _ChevronPainter(),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.7);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.lineTo(size.width * 0.85, size.height * 0.7);

    // Draw shadow first, then the white stroke
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
