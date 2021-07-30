import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

typedef AnimationPropertySequence<T> = List<AnimationProperty<T>>;
typedef PathCommands = List<PathCommand>;
typedef VectorElements = List<VectorElement>;

class AnimatedVector extends StatelessWidget {
  final AnimatedVectorData vector;
  final Animation<double> progress;
  final Size? size;
  final Color? color;
  final bool applyColor;

  const AnimatedVector({
    required this.vector,
    required this.progress,
    this.color,
    this.applyColor = false,
    this.size,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        Widget child = CustomPaint(
          painter: _AnimatedVectorPainter(
            vector: vector,
            progress: progress.value,
            colorOverride: applyColor
                ? color ?? Theme.of(context).iconTheme.color ?? Colors.black
                : null,
          ),
          child: SizedBox.fromSize(
            size: size ?? vector.viewportSize,
          ),
        );

        return child;
      },
    );
  }
}

class _AnimatedVectorPainter extends CustomPainter {
  final AnimatedVectorData vector;
  final double progress;
  final Color? colorOverride;

  const _AnimatedVectorPainter({
    required this.vector,
    required this.progress,
    this.colorOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / vector.viewportSize.width,
      size.height / vector.viewportSize.height,
    );

    if (colorOverride != null) {
      canvas.saveLayer(
        null,
        Paint()
          ..colorFilter = ColorFilter.mode(
            colorOverride!,
            BlendMode.srcIn,
          ),
      );
    }
    vector.root.paint(canvas, vector.viewportSize, progress, vector.duration);
    if (colorOverride != null) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnimatedVectorPainter old) {
    return vector != old.vector || progress != old.progress;
  }
}

class AnimatedVectorData {
  final VectorElement root;
  final Duration duration;
  final Size viewportSize;

  const AnimatedVectorData({
    required this.root,
    required this.duration,
    required this.viewportSize,
  });

  @override
  int get hashCode => hashValues(
        root.hashCode,
        duration.hashCode,
        viewportSize.hashCode,
      );

  @override
  bool operator ==(Object other) {
    if (other is AnimatedVectorData) {
      return root == other.root &&
          duration == other.duration &&
          viewportSize == other.viewportSize;
    }

    return false;
  }
}

abstract class VectorElement {
  const VectorElement();

  VectorElement evaluate(
    double t, {
    Duration baseDuration = const Duration(milliseconds: 300),
  });

  void paint(Canvas canvas, Size size, double progress, Duration duration);

  T? evaluateProperties<T>(
    AnimationPropertySequence<T?>? properties,
    T? defaultValue,
    Duration baseDuration,
    double t,
  ) {
    if (properties == null || properties.isEmpty) return defaultValue;

    final _AnimationTimeline<T?> timeline =
        _AnimationTimeline(properties, baseDuration, defaultValue);

    return timeline.evaluate(t) ?? defaultValue;
  }
}

class RootVectorElement extends VectorElement {
  final double alpha;
  final RootVectorAnimationProperties properties;
  final VectorElements elements;

  const RootVectorElement({
    this.alpha = 1.0,
    this.properties = const RootVectorAnimationProperties(),
    this.elements = const [],
  });

  @override
  RootVectorElement evaluate(
    double t, {
    Duration baseDuration = const Duration(milliseconds: 300),
  }) {
    final double alpha =
        evaluateProperties(properties.alpha, this.alpha, baseDuration, t)!;

    return RootVectorElement(
      alpha: alpha,
      elements: elements,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final RootVectorElement evaluated = evaluate(
      progress,
      baseDuration: duration,
    );

    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..colorFilter = ColorFilter.mode(
          Colors.white.withOpacity(evaluated.alpha),
          BlendMode.modulate,
        ),
    );
    for (final VectorElement element in evaluated.elements) {
      element.paint(canvas, size, progress, duration);
    }
    canvas.restore();
  }

  @override
  int get hashCode => hashValues(
        alpha.hashCode,
        elements.hashCode,
        properties.hashCode,
      );

  @override
  bool operator ==(Object other) {
    if (other is RootVectorElement) {
      return alpha == other.alpha &&
          listEquals(elements, other.elements) &&
          properties == other.properties;
    }

    return false;
  }
}

class GroupElement extends VectorElement {
  final double translateX;
  final double translateY;
  final double scaleX;
  final double scaleY;
  final double pivotX;
  final double pivotY;
  final double rotation;
  final GroupAnimationProperties properties;
  final VectorElements elements;

  const GroupElement({
    this.translateX = 0.0,
    this.translateY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.pivotX = 0.0,
    this.pivotY = 0.0,
    this.rotation = 0.0,
    this.properties = const GroupAnimationProperties(),
    this.elements = const [],
  });

  @override
  GroupElement evaluate(
    double t, {
    Duration baseDuration = const Duration(milliseconds: 300),
  }) {
    final double translateX = evaluateProperties(
        properties.translateX, this.translateX, baseDuration, t)!;
    final double translateY = evaluateProperties(
        properties.translateY, this.translateY, baseDuration, t)!;
    final double scaleX =
        evaluateProperties(properties.scaleX, this.scaleX, baseDuration, t)!;
    final double scaleY =
        evaluateProperties(properties.scaleY, this.scaleY, baseDuration, t)!;
    final double pivotX =
        evaluateProperties(properties.pivotX, this.pivotX, baseDuration, t)!;
    final double pivotY =
        evaluateProperties(properties.pivotY, this.pivotY, baseDuration, t)!;
    final double rotation = evaluateProperties(
        properties.rotation, this.rotation, baseDuration, t)!;

    return GroupElement(
      translateX: translateX,
      translateY: translateY,
      scaleX: scaleX,
      scaleY: scaleY,
      pivotX: pivotX,
      pivotY: pivotY,
      rotation: rotation,
      elements: elements,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final GroupElement evaluated = evaluate(
      progress,
      baseDuration: duration,
    );

    Matrix4 transformMatrix = Matrix4.identity();
    transformMatrix = transformMatrix.clone()
      ..translate(evaluated.pivotX, evaluated.pivotY)
      ..multiply(Matrix4.rotationZ(evaluated.rotation * math.pi / 180))
      ..translate(-evaluated.pivotX, -evaluated.pivotY);
    transformMatrix.translate(evaluated.translateX, evaluated.translateY);
    transformMatrix.scale(evaluated.scaleX, evaluated.scaleY);

    canvas.save();
    canvas.transform(transformMatrix.storage);
    for (final VectorElement element in evaluated.elements) {
      element.paint(canvas, size, progress, duration);
    }
    canvas.restore();
  }

  @override
  int get hashCode => hashValues(
        translateX.hashCode,
        translateY.hashCode,
        scaleX.hashCode,
        scaleY.hashCode,
        pivotX.hashCode,
        pivotY.hashCode,
        rotation.hashCode,
        elements.hashCode,
        properties.hashCode,
      );

  @override
  bool operator ==(Object other) {
    if (other is GroupElement) {
      return translateX == other.translateX &&
          translateY == other.translateY &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY &&
          pivotX == other.pivotX &&
          pivotY == other.pivotY &&
          rotation == other.rotation &&
          listEquals(elements, other.elements) &&
          properties == other.properties;
    }

    return false;
  }
}

class PathElement extends VectorElement {
  final PathData pathData;
  final Color? fillColor;
  final double fillAlpha;
  final Color? strokeColor;
  final double strokeAlpha;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final double strokeMiterLimit;
  final double trimStart;
  final double trimEnd;
  final double trimOffset;
  final PathAnimationProperties properties;

  PathElement({
    required this.pathData,
    this.fillColor,
    this.fillAlpha = 1.0,
    this.strokeColor,
    this.strokeAlpha = 1.0,
    this.strokeWidth = 1.0,
    this.strokeCap = StrokeCap.butt,
    this.strokeJoin = StrokeJoin.bevel,
    this.strokeMiterLimit = 4.0,
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
    this.trimOffset = 0.0,
    PathAnimationProperties? properties,
  })  : properties = properties ?? PathAnimationProperties(),
        assert(trimStart >= 0 && trimStart <= 1),
        assert(trimEnd >= 0 && trimEnd <= 1),
        assert(trimOffset >= 0 && trimOffset <= 1);

  @override
  PathElement evaluate(
    double t, {
    Duration baseDuration = const Duration(milliseconds: 300),
  }) {
    final PathData pathData = evaluateProperties(
        properties.pathData, this.pathData, baseDuration, t)!;
    final Color? fillColor = evaluateProperties(
        properties.fillColor, this.fillColor, baseDuration, t);
    final double fillAlpha = evaluateProperties(
        properties.fillAlpha, this.fillAlpha, baseDuration, t)!;
    final Color? strokeColor = evaluateProperties(
        properties.strokeColor, this.strokeColor, baseDuration, t);
    final double strokeAlpha = evaluateProperties(
        properties.strokeAlpha, this.strokeAlpha, baseDuration, t)!;
    final double strokeWidth = evaluateProperties(
        properties.strokeWidth, this.strokeWidth, baseDuration, t)!;
    final double trimStart = evaluateProperties(
        properties.trimStart, this.trimStart, baseDuration, t)!;
    final double trimEnd =
        evaluateProperties(properties.trimEnd, this.trimEnd, baseDuration, t)!;
    final double trimOffset = evaluateProperties(
        properties.trimOffset, this.trimOffset, baseDuration, t)!;

    return PathElement(
      pathData: pathData,
      fillColor: fillColor,
      fillAlpha: fillAlpha,
      strokeColor: strokeColor,
      strokeAlpha: strokeAlpha,
      strokeWidth: strokeWidth,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      strokeMiterLimit: strokeMiterLimit,
      trimStart: trimStart,
      trimEnd: trimEnd,
      trimOffset: trimOffset,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final PathElement evaluated = evaluate(
      progress,
      baseDuration: duration,
    );

    final Color fillColor = evaluated.fillColor ?? Colors.transparent;
    final Color strokeColor = evaluated.strokeColor ?? Colors.transparent;

    if (evaluated.strokeWidth > 0 && evaluated.strokeColor != null) {
      canvas.drawPath(
        evaluated.pathData.toPath(
          trimStart: evaluated.trimStart,
          trimEnd: evaluated.trimEnd,
          trimOffset: evaluated.trimOffset,
        ),
        Paint()
          ..color = strokeColor
              .withOpacity(strokeColor.opacity * evaluated.strokeAlpha)
          ..strokeWidth = evaluated.strokeWidth
          ..strokeCap = evaluated.strokeCap
          ..strokeJoin = evaluated.strokeJoin
          ..strokeMiterLimit = evaluated.strokeMiterLimit
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawPath(
      evaluated.pathData.toPath(),
      Paint()
        ..color =
            fillColor.withOpacity(fillColor.opacity * evaluated.fillAlpha),
    );
  }

  @override
  int get hashCode => hashValues(
        pathData.hashCode,
        fillColor.hashCode,
        fillAlpha.hashCode,
        strokeColor.hashCode,
        strokeAlpha.hashCode,
        strokeWidth.hashCode,
        strokeCap.hashCode,
        strokeJoin.hashCode,
        strokeMiterLimit.hashCode,
        trimStart.hashCode,
        trimEnd.hashCode,
        trimOffset.hashCode,
        properties.hashCode,
      );

  @override
  bool operator ==(Object other) {
    if (other is PathElement) {
      return pathData == other.pathData &&
          fillColor == other.fillColor &&
          fillAlpha == other.fillAlpha &&
          strokeColor == other.strokeColor &&
          strokeAlpha == other.strokeAlpha &&
          strokeWidth == other.strokeWidth &&
          strokeCap == other.strokeCap &&
          strokeJoin == other.strokeJoin &&
          strokeMiterLimit == other.strokeMiterLimit &&
          trimStart == other.trimStart &&
          trimEnd == other.trimEnd &&
          trimOffset == other.trimOffset &&
          properties == other.properties;
    }

    return false;
  }
}

class ClipPathElement extends VectorElement {
  final PathData pathData;
  final ClipPathAnimationProperties properties;

  const ClipPathElement({
    required this.pathData,
    this.properties = const ClipPathAnimationProperties(),
  });

  @override
  ClipPathElement evaluate(
    double t, {
    Duration baseDuration = const Duration(milliseconds: 300),
  }) {
    final PathData pathData = evaluateProperties(
        properties.pathData, this.pathData, baseDuration, t)!;

    return ClipPathElement(pathData: pathData);
  }

  @override
  void paint(Canvas canvas, Size size, double progress, Duration duration) {
    final ClipPathElement evaluated = evaluate(
      progress,
      baseDuration: duration,
    );

    canvas.clipPath(evaluated.pathData.toPath());
  }

  @override
  int get hashCode => hashValues(pathData.hashCode, properties.hashCode);

  @override
  bool operator ==(Object other) {
    if (other is ClipPathElement) {
      return pathData == other.pathData && properties == other.properties;
    }

    return false;
  }
}

class PathDataTween extends Tween<PathData> {
  PathDataTween({PathData? begin, PathData? end})
      : super(begin: begin, end: end);

  @override
  PathData lerp(double t) {
    return PathData.lerp(begin!, end!, t);
  }

  @override
  int get hashCode => hashValues(begin.hashCode, end.hashCode);

  @override
  bool operator ==(Object other) {
    if (other is PathDataTween) {
      return begin == other.begin && end == other.end;
    }

    return false;
  }
}

class PathData {
  final PathCommands operations;

  const PathData(this.operations);

  factory PathData.parse(String svg) {
    if (svg == '') {
      return const PathData([]);
    }

    if (!svg.toUpperCase().startsWith("M")) {
      svg = "M 0 0 $svg";
    }

    final SvgPathStringSource parser = SvgPathStringSource(svg);
    final _PathCommandPathProxy path = _PathCommandPathProxy();
    final SvgPathNormalizer normalizer = SvgPathNormalizer();
    for (PathSegmentData seg in parser.parseSegments()) {
      normalizer.emitSegment(seg, path);
    }
    return PathData(path.operations);
  }

  static PathData? tryParse(String svg) {
    try {
      return PathData.parse(svg);
    } on StateError {
      return null;
    }
  }

  static PathData lerp(PathData a, PathData b, double t) {
    assert(a.checkForCompatibility(b));
    final PathCommands interpolatedOperations = [];

    for (int i = 0; i < a.operations.length; i++) {
      interpolatedOperations.add(PathCommand.lerp(
        a.operations[i],
        b.operations[i],
        t,
      ));
    }

    return PathData(interpolatedOperations);
  }

  bool checkForCompatibility(PathData other) {
    if (operations.length != other.operations.length) return false;

    for (int i = 0;
        i < math.min(operations.length, other.operations.length);
        i++) {
      final PathCommand aItem = operations[i];
      final PathCommand bItem = operations[i];
      if (aItem.type != bItem.type) return false;
      if (aItem.points.length != bItem.points.length) return false;
    }
    return true;
  }

  Path toPath({
    double trimStart = 0.0,
    double trimEnd = 1.0,
    double trimOffset = 0.0,
  }) {
    if (trimStart == trimEnd) return Path();

    final Path base = Path();

    for (final PathCommand operation in operations) {
      switch (operation.type) {
        case PathCommandType.moveTo:
          final double x = operation.points[0];
          final double y = operation.points[1];
          base.moveTo(x, y);
          break;
        case PathCommandType.lineTo:
          final double x = operation.points[0];
          final double y = operation.points[1];
          base.lineTo(x, y);
          break;
        case PathCommandType.curveTo:
          final double x1 = operation.points[0];
          final double y1 = operation.points[1];
          final double x2 = operation.points[2];
          final double y2 = operation.points[3];
          final double x = operation.points[4];
          final double y = operation.points[5];
          base.cubicTo(x1, y1, x2, y2, x, y);
          break;
        case PathCommandType.close:
          base.close();
          break;
      }
    }

    if (trimStart == 0.0 && trimEnd == 1.0) return base;

    final Path trimPath = Path();
    for (final PathMetric metric in base.computeMetrics()) {
      final double offset = metric.length * trimOffset;
      double start = metric.length * trimStart + offset;
      double end = metric.length * trimEnd + offset;
      start = start.wrap(0, metric.length);
      end = end.wrap(0, metric.length);

      final Path path;

      if (end <= start) {
        final Path lower = metric.extractPath(0.0, end);
        final Path higher = metric.extractPath(start, metric.length);
        path = Path()
          ..addPath(lower, Offset.zero)
          ..addPath(higher, Offset.zero);
      } else {
        path = metric.extractPath(start, end);
      }

      trimPath.addPath(path, Offset.zero);
    }

    return trimPath;
  }

  @override
  int get hashCode => operations.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is PathData) {
      return listEquals(operations, other.operations);
    }

    return false;
  }

  @override
  String toString() {
    return operations.join(" ");
  }
}

class PathCommand {
  final PathCommandType type;
  final List<double> points;

  PathCommand._raw(
    this.type,
    this.points,
  );

  PathCommand.moveTo(
    double x,
    double y,
  )   : type = PathCommandType.moveTo,
        points = [x, y];

  PathCommand.lineTo(
    double x,
    double y,
  )   : type = PathCommandType.lineTo,
        points = [x, y];

  PathCommand.curveTo(
    double x,
    double y,
    double x1,
    double y1,
    double x2,
    double y2,
  )   : type = PathCommandType.curveTo,
        points = [x1, y1, x2, y2, x, y];

  const PathCommand.close()
      : type = PathCommandType.close,
        points = const [];

  static PathCommand lerp(PathCommand start, PathCommand end, double progress) {
    assert(progress >= 0 && progress <= 1);
    assert(start.type == end.type);
    assert(start.points.length == end.points.length);

    final List<double> interpolatedPoints = [];

    for (int i = 0; i < math.min(start.points.length, end.points.length); i++) {
      interpolatedPoints.add(
        lerpDouble(
          start.points[i],
          end.points[i],
          progress,
        )!,
      );
    }

    return PathCommand._raw(start.type, interpolatedPoints);
  }

  @override
  int get hashCode => hashValues(type.hashCode, points.hashCode);

  @override
  bool operator ==(Object other) {
    if (other is PathCommand) {
      return type == other.type && listEquals(points, other.points);
    }

    return false;
  }

  @override
  String toString() {
    switch (type) {
      case PathCommandType.moveTo:
        return "M ${points[0].eventuallyAsInt} ${points[1].eventuallyAsInt}";
      case PathCommandType.lineTo:
        return "L ${points[0].eventuallyAsInt} ${points[1].eventuallyAsInt}";
      case PathCommandType.curveTo:
        return "C ${points[0].eventuallyAsInt} ${points[1].eventuallyAsInt} ${points[2].eventuallyAsInt} ${points[3].eventuallyAsInt} ${points[4].eventuallyAsInt} ${points[5].eventuallyAsInt}";
      case PathCommandType.close:
        return "Z";
    }
  }
}

class AnimationProperties<T extends VectorElement> {
  const AnimationProperties();

  static bool checkForIntervalsValidity(AnimationPropertySequence? properties) {
    if (properties == null) return true;

    Duration lastValidEndDuration = Duration.zero;

    for (final AnimationProperty property in properties) {
      if (property.interval.start >= lastValidEndDuration) {
        lastValidEndDuration = property.interval.end;
        continue;
      }
      return false;
    }

    return true;
  }

  static T _getNearestDefaultForTween<T>(
    AnimationPropertySequence<T> properties,
    int startIndex,
    T defaultValue, {
    bool goDown = false,
  }) {
    final List<Tween<T>> tweens = properties.map((p) => p.tween).toList();
    T? value;

    for (int i = startIndex;
        goDown ? i > 0 : i < properties.length;
        goDown ? i-- : i++) {
      if (value != null) break;
      value ??= goDown
          ? tweens.getOrNull(i - 1)?.end
          : tweens.getOrNull(i + 1)?.begin;
    }

    return value ?? defaultValue;
  }
}

class RootVectorAnimationProperties
    extends AnimationProperties<RootVectorElement> {
  final AnimationPropertySequence<double>? alpha;

  const RootVectorAnimationProperties({this.alpha});

  @override
  int get hashCode => alpha.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is RootVectorAnimationProperties) {
      return listEquals(alpha, other.alpha);
    }

    return false;
  }
}

class GroupAnimationProperties extends AnimationProperties<GroupElement> {
  final AnimationPropertySequence<double>? translateX;
  final AnimationPropertySequence<double>? translateY;
  final AnimationPropertySequence<double>? scaleX;
  final AnimationPropertySequence<double>? scaleY;
  final AnimationPropertySequence<double>? pivotX;
  final AnimationPropertySequence<double>? pivotY;
  final AnimationPropertySequence<double>? rotation;

  const GroupAnimationProperties({
    this.translateX,
    this.translateY,
    this.scaleX,
    this.scaleY,
    this.pivotX,
    this.pivotY,
    this.rotation,
  });

  @override
  int get hashCode => hashValues(
        translateX,
        translateY,
        scaleX,
        scaleY,
        pivotX,
        pivotY,
        rotation,
      );

  @override
  bool operator ==(Object other) {
    if (other is GroupAnimationProperties) {
      return listEquals(translateX, other.translateX) &&
          listEquals(translateY, other.translateY) &&
          listEquals(scaleX, other.scaleX) &&
          listEquals(scaleY, other.scaleY) &&
          listEquals(pivotX, other.pivotX) &&
          listEquals(pivotY, other.pivotY) &&
          listEquals(rotation, other.rotation);
    }

    return false;
  }
}

class PathAnimationProperties extends AnimationProperties<PathElement> {
  final AnimationPropertySequence<PathData>? pathData;
  final AnimationPropertySequence<Color?>? fillColor;
  final AnimationPropertySequence<double>? fillAlpha;
  final AnimationPropertySequence<Color?>? strokeColor;
  final AnimationPropertySequence<double>? strokeAlpha;
  final AnimationPropertySequence<double>? strokeWidth;
  final AnimationPropertySequence<double>? trimStart;
  final AnimationPropertySequence<double>? trimEnd;
  final AnimationPropertySequence<double>? trimOffset;

  PathAnimationProperties({
    this.pathData,
    this.fillColor,
    this.fillAlpha,
    this.strokeColor,
    this.strokeAlpha,
    this.strokeWidth,
    this.trimStart,
    this.trimEnd,
    this.trimOffset,
  })  : assert(AnimationProperties.checkForIntervalsValidity(pathData)),
        assert(AnimationProperties.checkForIntervalsValidity(fillColor)),
        assert(AnimationProperties.checkForIntervalsValidity(fillAlpha)),
        assert(AnimationProperties.checkForIntervalsValidity(strokeColor)),
        assert(AnimationProperties.checkForIntervalsValidity(strokeAlpha)),
        assert(AnimationProperties.checkForIntervalsValidity(strokeWidth)),
        assert(AnimationProperties.checkForIntervalsValidity(trimStart)),
        assert(AnimationProperties.checkForIntervalsValidity(trimEnd)),
        assert(AnimationProperties.checkForIntervalsValidity(trimOffset));

  @override
  int get hashCode => hashValues(
        pathData,
        fillColor,
        fillAlpha,
        strokeColor,
        strokeAlpha,
        strokeWidth,
        trimStart,
        trimEnd,
        trimOffset,
      );

  @override
  bool operator ==(Object other) {
    if (other is PathAnimationProperties) {
      return listEquals(pathData, other.pathData) &&
          listEquals(fillColor, other.fillColor) &&
          listEquals(fillAlpha, other.fillAlpha) &&
          listEquals(strokeColor, other.strokeColor) &&
          listEquals(strokeAlpha, other.strokeAlpha) &&
          listEquals(strokeWidth, other.strokeWidth) &&
          listEquals(trimStart, other.trimStart) &&
          listEquals(trimEnd, other.trimEnd) &&
          listEquals(trimOffset, other.trimOffset);
    }

    return false;
  }
}

class ClipPathAnimationProperties extends AnimationProperties<ClipPathElement> {
  final AnimationPropertySequence<PathData>? pathData;

  const ClipPathAnimationProperties({this.pathData});

  @override
  int get hashCode => pathData.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is ClipPathAnimationProperties) {
      return listEquals(pathData, other.pathData);
    }

    return false;
  }
}

class AnimationProperty<T> {
  final Tween<T> tween;
  final AnimationInterval interval;
  final Curve curve;

  const AnimationProperty({
    required this.tween,
    required this.interval,
    this.curve = Curves.linear,
  });

  T evaluate(T? defaultValue, Duration baseDuration, double t) {
    final Curve c = calculateIntervalCurve(baseDuration);

    final double curvedT = c.transform(t);
    tween.begin = tween.begin ?? defaultValue;
    tween.end = tween.end ?? defaultValue;
    return tween.transform(curvedT);
  }

  Interval calculateIntervalCurve(Duration baseDuration) {
    final int start =
        interval.start.inMilliseconds.clamp(0, baseDuration.inMilliseconds);
    final int end =
        interval.end.inMilliseconds.clamp(0, baseDuration.inMilliseconds);

    return Interval(
      start / baseDuration.inMilliseconds,
      end / baseDuration.inMilliseconds,
      curve: curve,
    );
  }

  @override
  int get hashCode => hashValues(
        tween.hashCode,
        interval.hashCode,
        curve.hashCode,
      );

  @override
  bool operator ==(Object other) {
    if (other is AnimationProperty) {
      return tween == other.tween &&
          interval == other.interval &&
          curve == other.curve;
    }

    return false;
  }
}

class AnimationInterval {
  final Duration start;
  final Duration end;

  const AnimationInterval({
    this.start = Duration.zero,
    required this.end,
  });

  AnimationInterval.withDuration({
    Duration startOffset = Duration.zero,
    required Duration duration,
  })  : start = startOffset,
        end = Duration(
          microseconds: startOffset.inMicroseconds + duration.inMicroseconds,
        );

  bool isBetween(double value, Duration baseDuration) {
    final List<double> resolved = resolve(baseDuration);
    final double start = resolved.first;
    final double end = resolved.last;

    return value >= start && value <= end;
  }

  List<double> resolve(Duration baseDuration) {
    return [
      start.inMilliseconds.clamp(0, baseDuration.inMilliseconds) /
          baseDuration.inMilliseconds,
      end.inMilliseconds.clamp(0, baseDuration.inMilliseconds) /
          baseDuration.inMilliseconds,
    ];
  }

  @override
  int get hashCode => hashValues(start.hashCode, end.hashCode);

  @override
  bool operator ==(Object other) {
    if (other is AnimationInterval) {
      return start == other.start && end == other.end;
    }

    return false;
  }
}

class _AnimationTimeline<T> {
  final AnimationPropertySequence<T?> timeline;
  final Duration baseDuration;
  final T? defaultValue;

  const _AnimationTimeline(
    this.timeline,
    this.baseDuration,
    this.defaultValue,
  );

  T? evaluate(double t) {
    AnimationProperty<T?>? matchingProperty = timeline.firstWhereOrNull(
      (element) => element.interval.isBetween(t, baseDuration),
    );
    T? beginDefaultValue;
    T? endDefaultValue;

    if (matchingProperty == null) {
      for (int i = timeline.length - 1; i >= 0; i--) {
        final AnimationProperty<T?> property = timeline[i];

        final List<double> resolved = property.interval.resolve(baseDuration);
        final double end = resolved.last;
        double interval = t - end;
        if (!interval.isNegative) {
          return property.tween.end ??
              AnimationProperties._getNearestDefaultForTween(
                  timeline, i, defaultValue,
                  goDown: true) ??
              defaultValue;
        }
      }

      return defaultValue;
    } else {
      final int indexOf = timeline.indexOf(matchingProperty);
      if (indexOf != 0) {
        beginDefaultValue = AnimationProperties._getNearestDefaultForTween(
          timeline,
          indexOf,
          defaultValue,
          goDown: true,
        );
        endDefaultValue = AnimationProperties._getNearestDefaultForTween(
          timeline,
          indexOf,
          defaultValue,
        );
      }
    }

    beginDefaultValue ??= defaultValue;
    endDefaultValue ??= defaultValue;

    final List<double> resolved =
        matchingProperty.interval.resolve(baseDuration);
    final double begin = resolved.first;
    final double end = resolved.last;
    t = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    final tween = matchingProperty.tween;
    tween.begin ??= beginDefaultValue;
    tween.end ??= endDefaultValue;

    return tween.transform(matchingProperty.curve.transform(t))!;
  }
}

enum PathCommandType {
  moveTo,
  lineTo,
  curveTo,
  close,
}

class _PathCommandPathProxy implements PathProxy {
  final PathCommands operations = [];

  @override
  void close() {
    operations.add(const PathCommand.close());
  }

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    operations.add(PathCommand.curveTo(x3, y3, x1, y1, x2, y2));
  }

  @override
  void lineTo(double x, double y) {
    operations.add(PathCommand.lineTo(x, y));
  }

  @override
  void moveTo(double x, double y) {
    operations.add(PathCommand.moveTo(x, y));
  }
}

extension _ListNullGet<T> on List<T> {
  T? getOrNull(int index) {
    if (index < 0 || index > length - 1) {
      return null;
    }
    return this[index];
  }
}

extension DoubleHelper on double {
  double wrap(double min, double max) {
    if (this > max || this < min) {
      return min + (this - min) % (max - min);
    } else {
      return this;
    }
  }

  bool get isInt => (this % 1) == 0;

  num get eventuallyAsInt {
    if (isInt) return round();
    return this;
  }
}
