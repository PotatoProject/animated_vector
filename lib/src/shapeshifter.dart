import 'dart:convert';
import 'dart:ui';

import 'package:animated_vector/animated_vector.dart';
import 'package:animated_vector/src/animation.dart';
import 'package:animated_vector/src/data.dart';
import 'package:flutter/animation.dart';

class ShapeshifterConverter {
  const ShapeshifterConverter._();

  static AnimatedVectorData toAVD(String rawJson) {
    final Map<String, dynamic> json =
        jsonDecode(rawJson) as Map<String, dynamic>;

    final Map<String, dynamic> layers = json.get("layers");
    final Map<String, dynamic> vectorLayer = layers.get("vectorLayer");
    final Map<String, dynamic> animation =
        json.get<Map<String, dynamic>>("timeline").get("animation");
    final List<JsonAnimationProperty> blocks = animation
        .get<List<dynamic>>("blocks")
        .map((e) => JsonAnimationProperty.fromJson(e))
        .toList();
    final List<dynamic> children = vectorLayer.get("children");

    final AnimatedVectorData data = AnimatedVectorData(
      viewportSize: Size(
        vectorLayer.get("width").toDouble(),
        vectorLayer.get("height").toDouble(),
      ),
      duration: Duration(milliseconds: animation.get("duration")),
      root: RootVectorElement(
        alpha: vectorLayer["alpha"]?.toDouble() ?? 1.0,
        properties: RootVectorAnimationProperties(
          alpha: _parseJsonAnimationProperties<double>(
            blocks,
            vectorLayer.get<String>("id"),
            "alpha",
          ),
        ),
        elements: _elementsFromJson(
          children.cast<Map<String, dynamic>>(),
          blocks,
        ),
      ),
    );

    return data;
  }

  static VectorElements _elementsFromJson(
    List<Map<String, dynamic>> json,
    List<JsonAnimationProperty> animations,
  ) {
    final VectorElements elements = [];

    for (final Map<String, dynamic> child in json) {
      final String id = child.get<String>("id");
      final String type = child.get<String>("type");

      switch (type) {
        case "path":
          final PathElement element = PathElement(
            pathData: PathData.parse(child.get<String>("pathData")),
            fillColor: _colorFromHex(child["fillColor"]),
            fillAlpha: child["fillAlpha"]?.toDouble() ?? 1.0,
            strokeColor: _colorFromHex(child["strokeColor"]),
            strokeAlpha: child["strokeAlpha"]?.toDouble() ?? 1.0,
            strokeWidth: child["strokeWidth"]?.toDouble() ?? 1.0,
            strokeCap: _strokeCapFromString(child["strokeLinecap"]),
            strokeJoin: _strokeJoinFromString(child["strokeLinejoin"]),
            strokeMiterLimit: child["strokeMiterLimit"]?.toDouble() ?? 4.0,
            trimStart: child["trimPathStart"]?.toDouble() ?? 0.0,
            trimEnd: child["trimPathEnd"]?.toDouble() ?? 1.0,
            trimOffset: child["trimPathOffset"]?.toDouble() ?? 0.0,
            properties: PathAnimationProperties(
              pathData: _parseJsonAnimationProperties<PathData>(
                animations,
                id,
                "pathData",
              ),
              fillColor: _parseJsonAnimationProperties<Color?>(
                animations,
                id,
                "fillColor",
              ),
              fillAlpha: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "fillAlpha",
              ),
              strokeColor: _parseJsonAnimationProperties<Color?>(
                animations,
                id,
                "strokeColor",
              ),
              strokeAlpha: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "strokeAlpha",
              ),
              strokeWidth: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "strokeWidth",
              ),
              trimStart: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "trimPathStart",
              ),
              trimEnd: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "trimPathEnd",
              ),
              trimOffset: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "trimPathOffset",
              ),
            ),
          );
          elements.add(element);
          break;
        case "mask":
          final ClipPathElement element = ClipPathElement(
            pathData: PathData.parse(child.get<String>("pathData")),
            properties: ClipPathAnimationProperties(
              pathData: _parseJsonAnimationProperties<PathData>(
                animations,
                id,
                "pathData",
              ),
            ),
          );
          elements.add(element);
          break;
        case "group":
          final GroupElement element = GroupElement(
            translateX: child["translateX"]?.toDouble() ?? 0.0,
            translateY: child["translateY"] ?? 0.0,
            scaleX: child["scaleX"]?.toDouble() ?? 1.0,
            scaleY: child["scaleY"]?.toDouble() ?? 1.0,
            pivotX: child["pivotX"]?.toDouble() ?? 0.0,
            pivotY: child["pivotY"]?.toDouble() ?? 0.0,
            rotation: child["rotation"]?.toDouble() ?? 0.0,
            elements: _elementsFromJson(
              child.get<List<dynamic>>("children").cast<Map<String, dynamic>>(),
              animations,
            ),
            properties: GroupAnimationProperties(
              translateX: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "translateX",
              ),
              translateY: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "translateY",
              ),
              scaleX: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "scaleX",
              ),
              scaleY: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "scaleY",
              ),
              pivotX: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "pivotX",
              ),
              pivotY: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "pivotY",
              ),
              rotation: _parseJsonAnimationProperties<double>(
                animations,
                id,
                "rotation",
              ),
            ),
          );
          elements.add(element);
          break;
      }
    }

    return elements;
  }

  static AnimationPropertySequence<T> _parseJsonAnimationProperties<T>(
    List<JsonAnimationProperty> properties,
    String layerId,
    String propertyName,
  ) {
    return properties
        .where((a) => a.layerId == layerId && a.propertyName == propertyName)
        .map(
          (a) => AnimationProperty<T>(
            tween: a.tween as Tween<T>,
            interval: AnimationInterval(
              start: Duration(milliseconds: a.startTime),
              end: Duration(milliseconds: a.endTime),
            ),
            curve: a.interpolator,
          ),
        )
        .toList();
  }

  static StrokeCap _strokeCapFromString(String? source) {
    switch (source) {
      case "square":
        return StrokeCap.square;
      case "round":
        return StrokeCap.round;
      case "butt":
      default:
        return StrokeCap.butt;
    }
  }

  static StrokeJoin _strokeJoinFromString(String? source) {
    switch (source) {
      case "bevel":
        return StrokeJoin.bevel;
      case "round":
        return StrokeJoin.round;
      case "miter":
      default:
        return StrokeJoin.miter;
    }
  }
}

class JsonAnimationProperty<T> {
  final String layerId;
  final String propertyName;
  final Tween<T?> tween;
  final int startTime;
  final int endTime;
  final Curve interpolator;

  const JsonAnimationProperty({
    required this.layerId,
    required this.propertyName,
    required this.tween,
    required this.startTime,
    required this.endTime,
    required this.interpolator,
  });

  static JsonAnimationProperty fromJson<T>(Map<String, dynamic> json) {
    final String layerId = json.get<String>("layerId");
    final String propertyName = json.get<String>("propertyName");
    final int startTime = json.get<int>("startTime");
    final int endTime = json.get<int>("endTime");
    final Curve interpolator =
        _interpolatorFromString(json.get<String>("interpolator"));
    final String type = json.get<String>("type");

    switch (type) {
      case "path":
        final PathData from = PathData.parse(json.get<String>("fromValue"));
        final PathData to = PathData.parse(json.get<String>("toValue"));
        return JsonAnimationProperty<PathData>(
          layerId: layerId,
          propertyName: propertyName,
          startTime: startTime,
          endTime: endTime,
          interpolator: interpolator,
          tween: PathDataTween(begin: from, end: to),
        );
      case "color":
        final Color from = _colorFromHex(json.get<String>("fromValue"))!;
        final Color to = _colorFromHex(json.get<String>("toValue"))!;
        return JsonAnimationProperty<Color>(
          layerId: layerId,
          propertyName: propertyName,
          startTime: startTime,
          endTime: endTime,
          interpolator: interpolator,
          tween: ColorTween(begin: from, end: to),
        );
      case "number":
        final double from = json.get<num>("fromValue").toDouble();
        final double to = json.get<num>("toValue").toDouble();
        return JsonAnimationProperty<double>(
          layerId: layerId,
          propertyName: propertyName,
          startTime: startTime,
          endTime: endTime,
          interpolator: interpolator,
          tween: Tween<double>(begin: from, end: to),
        );
      default:
        throw UnsupportedAnimationProperty(type);
    }
  }

  static Curve _interpolatorFromString(String interpolator) {
    switch (interpolator) {
      case "FAST_OUT_SLOW_IN":
        return ShapeshifterCurves.fastOutSlowIn;
      case "FAST_OUT_LINEAR_IN":
        return ShapeshifterCurves.fastOutLinearIn;
      case "LINEAR_OUT_SLOW_IN":
        return ShapeshifterCurves.linearOutSlowIn;
      case "ACCELERATE_DECELERATE":
        return ShapeshifterCurves.accelerateDecelerate;
      case "ACCELERATE":
        return ShapeshifterCurves.accelerate;
      case "DECELERATE":
        return ShapeshifterCurves.decelerate;
      case "ANTICIPATE":
        return ShapeshifterCurves.anticipate;
      case "OVERSHOOT":
        return ShapeshifterCurves.overshoot;
      case "BOUNCE":
        return ShapeshifterCurves.bounce;
      case "ANTICIPATE_OVERSHOOT":
        return ShapeshifterCurves.anticipateOvershoot;
      case "LINEAR":
      default:
        return ShapeshifterCurves.linear;
    }
  }
}

class ShapeshifterCurves {
  const ShapeshifterCurves._();

  static const Curve linear = Curves.linear;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve fastOutLinearIn = Cubic(0.4, 0, 1, 1);
  static const Curve linearOutSlowIn = Cubic(0, 0, 0.2, 1);
  static const Curve accelerateDecelerate = Cubic(0.455, 0.03, 0.515, 0.955);
  static const Curve accelerate = Cubic(0.55, 0.085, 0.68, 0.53);
  static const Curve decelerate = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve anticipate = _AnticipateCurve();
  static const Curve overshoot = _OvershootCurve();
  static const Curve bounce = _BounceCurve();
  static const Curve anticipateOvershoot = _AnticipateOvershootCurve();
}

class _AnticipateCurve extends Curve {
  const _AnticipateCurve();

  @override
  double transformInternal(double t) {
    return t * t * ((2 + 1) * t - 2);
  }
}

class _OvershootCurve extends Curve {
  const _OvershootCurve();

  @override
  double transformInternal(double t) {
    return (t - 1) * (t - 1) * ((2 + 1) * (t - 1) + 2) + 1;
  }
}

class _BounceCurve extends Curve {
  const _BounceCurve();

  @override
  double transformInternal(double t) {
    double bounceFn(double t) => t * t * 8;

    t *= 1.1226;
    if (t < 0.3535) {
      return bounceFn(t);
    } else if (t < 0.7408) {
      return bounceFn(t - 0.54719) + 0.7;
    } else if (t < 0.9644) {
      return bounceFn(t - 0.8526) + 0.9;
    } else {
      return bounceFn(t - 1.0435) + 0.95;
    }
  }
}

class _AnticipateOvershootCurve extends Curve {
  const _AnticipateOvershootCurve();

  @override
  double transformInternal(double t) {
    double a(double t, double s) {
      return t * t * ((s + 1) * t - s);
    }

    double o(double t, double s) {
      return t * t * ((s + 1) * t + s);
    }

    if (t < 0.5) {
      return 0.5 * a(t * 2, 2 * 1.5);
    } else {
      return 0.5 * (o(t * 2 - 2, 2 * 1.5) + 2);
    }
  }
}

Color? _colorFromHex(String? hex) {
  if (hex == null) return null;

  String cleanHex = hex.replaceAll("#", "");
  if (cleanHex.length == 6) {
    // ex. #4a5ccc -> #FF4a5ccc0
    cleanHex = ["FF", cleanHex].join();
  } else if (cleanHex.length == 3) {
    // ex. #ccd -> #FFccdccd
    cleanHex = ["FF", cleanHex, cleanHex].join();
  } else if (cleanHex.length == 2) {
    // ex. #2a -> #FF2a2a2a
    cleanHex = ["FF", cleanHex, cleanHex, cleanHex].join();
  }
  final int? colorValue = int.tryParse(cleanHex, radix: 16);

  if (colorValue == null) return null;
  return Color(colorValue);
}

class UnsupportedAnimationProperty implements Exception {
  final String property;

  const UnsupportedAnimationProperty(this.property);

  @override
  String toString() {
    return "The property '$property' is not handled from the lib or not valid";
  }
}

class MissingPropertyException implements Exception {
  final String property;

  const MissingPropertyException(this.property);

  @override
  String toString() {
    return "MissingPropertyException: The provided json doesn't have required property '$property'";
  }
}

extension SafeMapGet<K> on Map<K, dynamic> {
  T get<T>(K key) {
    if (!containsKey(key)) {
      throw MissingPropertyException(key.toString());
    }

    return this[key]! as T;
  }
}