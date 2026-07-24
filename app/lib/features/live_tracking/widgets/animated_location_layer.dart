import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class LocationState {
  final LatLng point;
  final double heading;
  final double accuracy;

  LocationState({
    required this.point,
    required this.heading,
    required this.accuracy,
  });
}

class LocationStateTween extends Tween<LocationState> {
  LocationStateTween({super.begin, super.end});

  @override
  LocationState lerp(double t) {
    if (begin == null && end == null) {
      return LocationState(point: const LatLng(0, 0), heading: 0, accuracy: 0);
    }
    if (begin == null) return end!;
    if (end == null) return begin!;

    final lat = lerpDouble(begin!.point.latitude, end!.point.latitude, t)!;
    final lng = lerpDouble(begin!.point.longitude, end!.point.longitude, t)!;

    // Shortest path heading calculation
    double startHeading = begin!.heading;
    double endHeading = end!.heading;
    double diff = (endHeading - startHeading) % 360;
    if (diff > 180) diff -= 360;
    final h = startHeading + diff * t;

    final acc = lerpDouble(begin!.accuracy, end!.accuracy, t)!;

    return LocationState(
      point: LatLng(lat, lng),
      heading: h,
      accuracy: acc,
    );
  }
}

class AnimatedLocationLayer extends StatefulWidget {
  final LocationState state;

  const AnimatedLocationLayer({super.key, required this.state});

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}

class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> {
  late LocationState _oldState;

  @override
  void initState() {
    super.initState();
    _oldState = widget.state;
  }

  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.point.latitude != widget.state.point.latitude ||
        oldWidget.state.point.longitude != widget.state.point.longitude ||
        oldWidget.state.heading != widget.state.heading ||
        oldWidget.state.accuracy != widget.state.accuracy) {
      _oldState = oldWidget.state;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<LocationState>(
      tween: LocationStateTween(begin: _oldState, end: widget.state),
      duration: const Duration(milliseconds: 300),
      curve: Curves.linearToEaseOut,
      builder: (context, animatedState, child) {
        return Stack(
          children: [
            CircleLayer(
              circles: [
                CircleMarker(
                  point: animatedState.point,
                  radius: animatedState.accuracy,
                  useRadiusInMeter: true,
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  borderColor: Colors.blueAccent.withValues(alpha: 0.2),
                  borderStrokeWidth: 0.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: animatedState.point,
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: animatedState.heading * math.pi / 180,
                    child: const NavigationMarkerWidget(),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class NavigationMarkerWidget extends StatelessWidget {
  const NavigationMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Heading Pointer (small triangle on top of the dot)
        Positioned(
          top: 0,
          child: CustomPaint(
            size: const Size(14, 18),
            painter: _PointerPainter(),
          ),
        ),
        // Main Blue Dot
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blueAccent.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0); // Top point
    path.lineTo(size.width, size.height); // Bottom right
    path.lineTo(size.width / 2, size.height * 0.8); // Inner bottom indent
    path.lineTo(0, size.height); // Bottom left
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blueAccent.shade700
        ..style = PaintingStyle.fill,
    );
    
    // Add white stroke around the pointer to match the dot's border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
