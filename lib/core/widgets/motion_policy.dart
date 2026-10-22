import 'package:flutter/widgets.dart';

class MotionPolicy extends InheritedWidget {
  const MotionPolicy({
    super.key,
    required this.systemReduced,
    required super.child,
  });
  final bool systemReduced;
  static bool systemOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MotionPolicy>()
          ?.systemReduced ??
      MediaQuery.disableAnimationsOf(context);
  @override
  bool updateShouldNotify(MotionPolicy oldWidget) =>
      systemReduced != oldWidget.systemReduced;
}
