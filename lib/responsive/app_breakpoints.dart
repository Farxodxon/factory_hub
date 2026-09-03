import 'package:flutter/widgets.dart';

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static int gridColumns(BuildContext context) {
    final w = width(context);
    if (w >= tablet) return 4;
    if (w >= mobile) return 3;
    return 2;
  }

  static int tableColumns(BuildContext context) {
    final w = width(context);
    if (w >= tablet) return 8;
    if (w >= mobile) return 5;
    return 3;
  }
}
