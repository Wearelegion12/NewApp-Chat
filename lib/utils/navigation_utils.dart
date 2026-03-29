import 'package:flutter/material.dart';

class SmoothPageRoute<T> extends MaterialPageRoute<T> {
  SmoothPageRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(builder: builder, settings: settings);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
}

extension SmoothNavigation on BuildContext {
  Future<T?> pushSmooth<T extends Object?>(Widget page) {
    return Navigator.push<T>(
      this,
      SmoothPageRoute(builder: (_) => page),
    );
  }

  Future<T?> pushReplacementSmooth<T extends Object?, TO extends Object?>(
    Widget page, {
    TO? result,
  }) {
    return Navigator.pushReplacement<T, TO>(
      this,
      SmoothPageRoute(builder: (_) => page),
      result: result,
    );
  }

  Future<T?> pushNamedSmooth<T extends Object?>(String routeName,
      {Object? arguments}) {
    return Navigator.pushNamed<T>(
      this,
      routeName,
      arguments: arguments,
    );
  }
}
