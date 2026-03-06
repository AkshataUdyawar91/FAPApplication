/// Breakpoint definitions for responsive layouts
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// Device type enum
enum DeviceType { mobile, tablet, desktop }

/// Get current device type from width
DeviceType getDeviceType(double width) {
  if (width < Breakpoints.mobile) return DeviceType.mobile;
  if (width < Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.desktop;
}

/// Responsive value helper - returns different values per breakpoint
T responsiveValue<T>(double width, {required T mobile, T? tablet, required T desktop}) {
  final type = getDeviceType(width);
  switch (type) {
    case DeviceType.mobile:
      return mobile;
    case DeviceType.tablet:
      return tablet ?? desktop;
    case DeviceType.desktop:
      return desktop;
  }
}
