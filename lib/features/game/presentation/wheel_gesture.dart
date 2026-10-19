import 'dart:math' as math;
import 'dart:ui';

/// Shared local coordinates for hit testing, tiles and the connection painter.
class WheelGeometry {
  WheelGeometry(double size, List<String> order)
    : size = size,
      tileRadius = size >= 290 ? 30 : 26 {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - tileRadius - 10;
    centers = Map.unmodifiable({
      for (var i = 0; i < order.length; i++)
        order[i]:
            center +
            Offset(
              radius * math.cos(-math.pi / 2 + 2 * math.pi * i / order.length),
              radius * math.sin(-math.pi / 2 + 2 * math.pi * i / order.length),
            ),
    });
  }
  final double size;
  final double tileRadius;
  late final Map<String, Offset> centers;

  String? hit(Offset point) {
    String? nearest;
    var distance = double.infinity;
    for (final entry in centers.entries) {
      final d = (entry.value - point).distance;
      if (d <= tileRadius && d < distance) {
        nearest = entry.key;
        distance = d;
      }
    }
    return nearest;
  }

  /// Segment/circle entry parameters, including tiles crossed between events.
  List<String> entries(Offset from, Offset to) {
    final delta = to - from;
    final a = delta.distanceSquared;
    if (a < 0.000001) return const [];
    final hits = <({String id, double t})>[];
    for (final entry in centers.entries) {
      final relative = from - entry.value;
      final c = relative.distanceSquared - tileRadius * tileRadius;
      // No new entry while remaining inside the same circle.
      if (c <= 0) continue;
      final b = 2 * (relative.dx * delta.dx + relative.dy * delta.dy);
      final discriminant = b * b - 4 * a * c;
      if (discriminant < 0) continue;
      final t = (-b - math.sqrt(discriminant)) / (2 * a);
      if (t >= 0 && t <= 1) hits.add((id: entry.key, t: t));
    }
    hits.sort((a, b) => a.t.compareTo(b.t));
    return hits.map((hit) => hit.id).toList();
  }

  bool sameAs(WheelGeometry other) =>
      size == other.size &&
      centers.length == other.centers.length &&
      centers.entries.every((entry) => other.centers[entry.key] == entry.value);
}

class WheelGesture {
  int? pointer;
  Offset? position;
  final List<String> _selected = [];
  List<String> get selected => List.unmodifiable(_selected);
  bool get dragging => pointer != null;

  bool down(int id, Offset point, WheelGeometry geometry) {
    if (dragging) return false;
    final tile = geometry.hit(point);
    if (tile == null) return false;
    pointer = id;
    position = point;
    _selected.add(tile);
    return true;
  }

  bool move(int id, Offset point, WheelGeometry geometry) {
    if (pointer != id) return false;
    for (final tile in geometry.entries(position!, point)) {
      if (_selected.length > 1 && _selected[_selected.length - 2] == tile) {
        _selected.removeLast();
      } else if (!_selected.contains(tile)) {
        _selected.add(tile);
      }
    }
    position = point;
    return true;
  }

  List<String>? up(int id) {
    if (pointer != id) return null;
    final result = selected;
    cancel();
    return result;
  }

  bool cancel() {
    final wasDragging = dragging;
    pointer = null;
    position = null;
    _selected.clear();
    return wasDragging;
  }
}
