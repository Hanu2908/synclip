import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One device drawn on the [DeviceRing].
class RingNode {
  const new({
    required this.name,
    required this.icon,
    required this.color,
    this.online = true,
  });

  final String name;
  final IconData icon;
  final Color color;
  final bool online;
}

/// The signature visual: this device in the centre, the room's other devices
/// on a ring around it (PLAN.md §7.5). Static for now; motion lands in M7.
class DeviceRing extends StatelessWidget {
  const new({
    required this.self,
    this.others = const [],
    this.size = 240,
    super.key,
  });

  final RingNode self;
  final List<RingNode> others;
  final double size;

  /// Screen-reader summary, e.g.
  /// "3 devices online: MacBook, Windows PC, this phone. Lab PC offline."
  static String describe(RingNode self, List<RingNode> others) {
    final online = [
      ...others.where((n) => n.online).map((n) => n.name),
      self.name,
    ];
    final offline = others.where((n) => !n.online).map((n) => n.name);
    final noun = online.length == 1 ? 'device' : 'devices';
    final summary = '${online.length} $noun online: ${online.join(', ')}.';
    return offline.isEmpty
        ? summary
        : '$summary ${offline.join(', ')} offline.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final centre = size / 2;
    final radius = size * 0.39;
    final selfSize = size * 0.27;
    final nodeSize = size * 0.18;

    Offset positionOf(int i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / others.length;
      return Offset(
        centre + radius * math.cos(angle),
        centre + radius * math.sin(angle),
      );
    }

    return Semantics(
      label: describe(self, others),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                radius: radius,
                ringColor: scheme.outlineVariant,
                spokes: [
                  for (final (i, node) in others.indexed)
                    (positionOf(i), node.online ? node.color : null),
                ],
              ),
            ),
            for (final (i, node) in others.indexed)
              _positioned(
                positionOf(i),
                nodeSize,
                _Node(node: node, size: nodeSize),
              ),
            _positioned(
              Offset(centre, centre),
              selfSize,
              Container(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 6),
                ),
                child: Icon(
                  self.icon,
                  color: scheme.onPrimaryContainer,
                  size: selfSize * 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _positioned(Offset centre, double size, Widget child) =>
      Positioned(
        left: centre.dx - size / 2,
        top: centre.dy - size / 2,
        width: size,
        height: size,
        child: child,
      );
}

class _Node extends StatelessWidget {
  const new({required this.node, required this.size});

  final RingNode node;
  final double size;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: node.online ? node.color : surface,
        shape: BoxShape.circle,
        border: node.online ? null : Border.all(color: node.color, width: 2),
      ),
      child: Icon(
        node.icon,
        size: size * 0.45,
        color: node.online ? Colors.white : node.color,
      ),
    );
  }
}

/// Dashed ring plus one spoke per device: solid in the device colour when
/// online, dashed in the outline colour when offline (`colour == null`).
class _RingPainter extends CustomPainter {
  new({required this.radius, required this.ringColor, required this.spokes});

  final double radius;
  final Color ringColor;
  final List<(Offset, Color?)> spokes;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _dashed(
      canvas,
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
      stroke..color = ringColor,
    );
    for (final (end, colour) in spokes) {
      final spoke = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(end.dx, end.dy);
      if (colour == null) {
        _dashed(canvas, spoke, stroke..color = ringColor);
      } else {
        canvas.drawPath(spoke, stroke..color = colour);
      }
    }
  }

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  // `spokes` is rebuilt every build, so a field comparison is always true.
  bool shouldRepaint(_RingPainter oldDelegate) => true;
}
