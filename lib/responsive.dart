// lib/responsive.dart
import 'package:flutter/material.dart';

/// Extension on BuildContext to provide easy access to responsive values
extension Responsive on BuildContext {
  /// Get the screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Get the screen width
  double get screenWidth => screenSize.width;

  /// Get the screen height
  double get screenHeight => screenSize.height;

  /// Get the device pixel ratio
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);

  /// Check if the device is a small phone (< 360px width)
  bool get isSmallPhone => screenWidth < 360;

  /// Check if the device is a phone (width < 600px)
  bool get isPhone => screenWidth < 600;

  /// Check if the device is a tablet (width >= 600px)
  bool get isTablet => screenWidth >= 600;

  /// Check if the device is a large tablet (width >= 800px)
  bool get isLargeTablet => screenWidth >= 800;

  /// Get responsive horizontal padding (smaller on phones, larger on tablets)
  double get horizontalPadding {
    if (isSmallPhone) return 12.0;
    if (isPhone) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  /// Get responsive vertical padding
  double get verticalPadding {
    if (isSmallPhone) return 8.0;
    if (isPhone) return 12.0;
    if (isTablet) return 16.0;
    return 24.0;
  }

  /// Get responsive title font size
  double get titleFontSize {
    if (isSmallPhone) return 24.0;
    if (isPhone) return 28.0;
    if (isTablet) return 32.0;
    return 36.0;
  }

  /// Get responsive subtitle font size
  double get subtitleFontSize {
    if (isSmallPhone) return 14.0;
    if (isPhone) return 16.0;
    if (isTablet) return 18.0;
    return 20.0;
  }

  /// Get responsive body font size
  double get bodyFontSize {
    if (isSmallPhone) return 14.0;
    if (isPhone) return 16.0;
    if (isTablet) return 18.0;
    return 20.0;
  }

  /// Get responsive small font size
  double get smallFontSize {
    if (isSmallPhone) return 11.0;
    if (isPhone) return 13.0;
    if (isTablet) return 15.0;
    return 16.0;
  }

  /// Get responsive header padding (top)
  double get headerPaddingTop => isSmallPhone ? 16.0 : 20.0;

  /// Get responsive header padding (bottom)
  double get headerPaddingBottom => isSmallPhone ? 20.0 : 28.0;

  /// Get responsive border radius for cards
  double get cardBorderRadius => isSmallPhone ? 14.0 : 18.0;

  /// Get responsive border radius for small elements
  double get smallBorderRadius => isSmallPhone ? 10.0 : 12.0;

  /// Get responsive ball size for lotto numbers
  double lottoBallSize({double baseSize = 32.0}) {
    if (isSmallPhone) return baseSize * 0.8;
    if (isPhone) return baseSize;
    if (isTablet) return baseSize * 1.2;
    return baseSize * 1.4;
  }

  /// Get responsive icon size
  double iconSize({double baseSize = 24.0}) {
    if (isSmallPhone) return baseSize * 0.85;
    if (isPhone) return baseSize;
    if (isTablet) return baseSize * 1.15;
    return baseSize * 1.3;
  }

  /// Get responsive spacing between elements
  double spacing({double baseSize = 12.0}) {
    if (isSmallPhone) return baseSize * 0.75;
    if (isPhone) return baseSize;
    if (isTablet) return baseSize * 1.25;
    return baseSize * 1.5;
  }

  /// Get the bottom safe area padding for navigation
  double get bottomSafeArea => MediaQuery.paddingOf(this).bottom;

  /// Get the top safe area padding
  double get topSafeArea => MediaQuery.paddingOf(this).top;

  /// Check if the device is in landscape mode
  bool get isLandscape => screenWidth > screenHeight;

  /// Check if the device has narrow width (for special cases)
  bool get isNarrow => screenWidth < 320;
}

/// A simple responsive widget that rebuilds based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
      builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

/// A widget that shows different children based on screen width breakpoints
class ResponsiveLayout extends StatelessWidget {
  final Widget? smallPhone;
  final Widget? phone;
  final Widget? tablet;
  final Widget? largeTablet;
  final Widget? defaultWidget;

  const ResponsiveLayout({
    super.key,
    this.smallPhone,
    this.phone,
    this.tablet,
    this.largeTablet,
    this.defaultWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isLargeTablet && largeTablet != null) {
      return largeTablet!;
    }
    if (context.isTablet && tablet != null) {
      return tablet!;
    }
    if (context.isSmallPhone && smallPhone != null) {
      return smallPhone!;
    }
    if (phone != null) {
      return phone!;
    }
    return defaultWidget ?? const SizedBox.shrink();
  }
}

/// Constants for responsive values that can be used anywhere
class ResponsiveConstants {
  // Navigation bar
  static const double navBarMinHeight = 60.0;
  static const double navBarMaxHeight = 80.0;

  // Card elevations
  static const double cardElevation = 0.0;
  static const double cardElevationHover = 4.0;

  // Minimum touch target (for accessibility)
  static const double minTouchTarget = 44.0;

  // Content max width for tablets
  static const double tabletContentMaxWidth = 600.0;
}
