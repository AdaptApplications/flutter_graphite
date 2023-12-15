import 'package:arrow_path/arrow_path.dart';
import 'package:flutter/material.dart';
import 'package:touchable/touchable.dart';

import 'core/typings.dart';
import 'graphite_typings.dart';

Paint _defaultPaintBuilder(Edge edge) {
  return Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 2;
}

class LinesPainter extends CustomPainter {
  final List<Edge> edges;
  final BuildContext context;
  final EdgePaintBuilder? paintBuilder;
  final EdgePathBuilder? pathBuilder;
  final double tipLength;
  final double tipAngle;

  final GestureBackgroundTapCallback? onCanvasTap;
  final GestureEdgeTapDownCallback? onEdgeTapDown;
  final PaintingStyle? edgePaintStyleForTouch;

  final GestureEdgeTapUpCallback? onEdgeTapUp;
  final GestureEdgeLongPressStartCallback? onEdgeLongPressStart;

  final GestureEdgeLongPressEndCallback? onEdgeLongPressEnd;
  final GestureEdgeLongPressMoveUpdateCallback? onEdgeLongPressMoveUpdate;

  final GestureEdgeForcePressStartCallback? onEdgeForcePressStart;
  final GestureEdgeForcePressEndCallback? onEdgeForcePressEnd;

  final GestureEdgeForcePressPeakCallback? onEdgeForcePressPeak;
  final GestureEdgeForcePressUpdateCallback? onEdgeForcePressUpdate;

  final GestureEdgeTapDownCallback? onEdgeSecondaryTapDown;

  final GestureEdgeTapUpCallback? onEdgeSecondaryTapUp;

  List<List<double>> _offsetPoints(Edge edge) {
    List<List<double>> points = List.empty(growable: true);

    var reversedPoints = edge.points.reversed.toList();

    if (edge.curve == EdgeCurveType.sameNode && edge.points.length == 2) {
      // handle straigt edges
      for (var element in reversedPoints) {
        var offsetPoint = List<double>.from(element);
        offsetPoint[1] = offsetPoint[1] - 20;
        points.add(offsetPoint);
      }
    } else if (edge.curve == EdgeCurveType.sameNode && edge.points.length == 4) {
      for (var element in reversedPoints) {
        var offsetPoint = List<double>.from(element);
        points.add(offsetPoint);
      }
      points[1][1] = points[1][1] - 40;
      points[2][1] = points[2][1] - 40;
    } else {
      points.addAll(reversedPoints);
    }
    return points;
  }

  Path _defaultEdgePathBuilder(NodeInput from, NodeInput to, List<List<double>> points, Edge edge) {
    var path = Path();
    path.moveTo(points[0][0], points[0][1]);
    for (var point in points) {
      path.lineTo(point[0], point[1]);
    }
    if (edge.arrowType == EdgeArrowType.none) {
      return path;
    }
    return ArrowPath.make(path: path, isDoubleSided: edge.arrowType == EdgeArrowType.both, tipLength: tipLength, tipAngle: tipAngle);
  }

  const LinesPainter(
    this.context,
    this.edges, {
    required this.tipLength,
    required this.tipAngle,
    this.onCanvasTap,
    this.onEdgeTapDown,
    this.edgePaintStyleForTouch,
    this.onEdgeTapUp,
    this.onEdgeLongPressStart,
    this.onEdgeLongPressEnd,
    this.onEdgeLongPressMoveUpdate,
    this.onEdgeForcePressStart,
    this.onEdgeForcePressEnd,
    this.onEdgeForcePressPeak,
    this.onEdgeForcePressUpdate,
    this.onEdgeSecondaryTapDown,
    this.onEdgeSecondaryTapUp,
    this.paintBuilder,
    this.pathBuilder,
  });

  @override
  void paint(Canvas c, Size size) {
    var canvas = TouchyCanvas(context, c);
    var background = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)), background, onTapDown: onCanvasTap);
    List<Edge> nodeEdges = edges;

    for (var e in nodeEdges) {
      Path path = Path();

      switch (e.curve) {
        default:
          path = _defaultEdgePathBuilder(e.from.toInput(), e.to.toInput(), _offsetPoints(e), e);
      }

      final paint = _defaultPaintBuilder(e);
      c.drawPath(
        path,
        paint,
      );

      // add transparent wider lines on top to track gestures
      _handleTransparentLineForTaps(e, canvas, _offsetPoints(e), paint.strokeWidth * 5);
    }
  }

  _handleTransparentLineForTaps(Edge e, TouchyCanvas canvas, List<List<double>> points, double strokeWidth) {
    for (int i = 1; i < points.length; i++) {
      var p = Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(points[i - 1][0], points[i - 1][1]),
        Offset(points[i][0], points[i][1]),
        p,
        paintStyleForTouch: PaintingStyle.fill,
        onTapDown: onEdgeTapDown != null ? (details) => onEdgeTapDown!(details, e) : null,
        onTapUp: onEdgeTapUp != null ? (details) => onEdgeTapUp!(details, e) : null,
        onLongPressStart: onEdgeLongPressStart != null ? (details) => onEdgeLongPressStart!(details, e) : null,
        onLongPressEnd: onEdgeLongPressEnd != null ? (details) => onEdgeLongPressEnd!(details, e) : null,
        onLongPressMoveUpdate: onEdgeLongPressMoveUpdate != null ? (details) => onEdgeLongPressMoveUpdate!(details, e) : null,
        onForcePressStart: onEdgeForcePressStart != null ? (details) => onEdgeForcePressStart!(details, e) : null,
        onForcePressEnd: onEdgeForcePressEnd != null ? (details) => onEdgeForcePressEnd!(details, e) : null,
        onForcePressPeak: onEdgeForcePressPeak != null ? (details) => onEdgeForcePressPeak!(details, e) : null,
        onForcePressUpdate: onEdgeForcePressUpdate != null ? (details) => onEdgeForcePressUpdate!(details, e) : null,
        onSecondaryTapDown: onEdgeSecondaryTapDown != null ? (details) => onEdgeSecondaryTapDown!(details, e) : null,
        onSecondaryTapUp: onEdgeSecondaryTapUp != null ? (details) => onEdgeSecondaryTapUp!(details, e) : null,
      );
    }
  }

  @override
  bool shouldRepaint(LinesPainter oldDelegate) {
    return true;
  }
}
