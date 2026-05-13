import 'package:emulator_device_manager/ui/home_page.dart';
import 'package:emulator_device_manager/ui/settings_page.dart';
import 'package:emulator_device_manager/ui/widgets/app_shortcuts.dart';
import 'package:flutter/material.dart';

/// macOS uses SF Pro by default. Setting this as the primary font family
/// (with graceful fallbacks for non-Apple hosts) is the biggest single win
/// to make the app feel native instead of Roboto-on-Android.
const String _systemFontFamily = '.AppleSystemUIFont';
const List<String> _systemFontFallback = <String>[
  'SF Pro Text',
  'SF Pro Display',
  '-apple-system',
  'BlinkMacSystemFont',
  'Segoe UI',
  'Helvetica Neue',
  'Roboto',
];

class EmulatorDeviceManagerApp extends StatelessWidget {
  const EmulatorDeviceManagerApp({super.key, required this.themeMode});
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AVD Pilot',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routes: <String, WidgetBuilder>{
        '/': (_) => const HomePage(),
        '/settings': (_) => const SettingsPage(),
      },
      builder: (context, child) =>
          AppShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const Color brandSeed = Color(0xFF1FAE5E);
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: brandSeed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        ).copyWith(
          primary: brightness == Brightness.light
              ? const Color(0xFF1FAE5E)
              : const Color(0xFF6BE0A0),
          tertiary: brightness == Brightness.light
              ? const Color(0xFF0094B0)
              : const Color(0xFF7BD8E8),
        );

    final TextTheme textTheme = _buildMacTextTheme(scheme);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // macOS doesn't have ripple/ink splashes; suppress them globally so
      // FilledButton/IconButton/etc. fall back to overlay-based hover/press
      // states which feel native.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      fontFamily: _systemFontFamily,
      fontFamilyFallback: _systemFontFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.macOS: _NoTransitionsBuilder(),
          TargetPlatform.linux: _NoTransitionsBuilder(),
          TargetPlatform.windows: _NoTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.6,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.6,
        space: 0.6,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
            width: 0.6,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
            width: 0.6,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.5 : 0.12,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: brightness == Brightness.dark
              ? const Color(0xFFE8E8E8)
              : const Color(0xFF1C1C1E),
          fontSize: 11,
          letterSpacing: -0.05,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(
            scheme.surfaceContainerHigh,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
          ),
          elevation: const WidgetStatePropertyAll<double>(2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.6,
          ),
        ),
        textStyle: textTheme.bodySmall,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      extensions: const <ThemeExtension<dynamic>>[_BrandTokens()],
    );
  }
}

/// macOS-tuned text theme: SF Pro tracks tighter than Roboto. Apply a small
/// negative letter-spacing on display/title roles that mirrors Apple's own
/// dynamic typography stack, and keep body roles close to system default.
TextTheme _buildMacTextTheme(ColorScheme scheme) {
  final Color body = scheme.onSurface;
  final Color subtle = scheme.onSurfaceVariant;
  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: body,
    ),
    displayMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: body,
    ),
    displaySmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: body,
    ),
    headlineLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: body,
    ),
    headlineMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: body,
    ),
    headlineSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      color: body,
    ),
    titleLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      color: body,
    ),
    titleMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.08,
      color: body,
    ),
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.05,
      color: body,
    ),
    bodyLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.05,
      color: body,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.05,
      color: body,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.02,
      color: subtle,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.05,
      color: body,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.02,
      color: body,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.0,
      color: subtle,
    ),
  );
}

/// Drop-in replacement for the platform default page transition. macOS apps
/// don't slide/fade between routes the way Android does — switching panes
/// should feel instant.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _BrandTokens extends ThemeExtension<_BrandTokens> {
  const _BrandTokens({this.contentPadding = const EdgeInsets.all(14)});
  final EdgeInsets contentPadding;

  @override
  _BrandTokens copyWith({EdgeInsets? contentPadding}) {
    return _BrandTokens(contentPadding: contentPadding ?? this.contentPadding);
  }

  @override
  ThemeExtension<_BrandTokens> lerp(
    covariant ThemeExtension<_BrandTokens>? other,
    double t,
  ) {
    if (other is! _BrandTokens) {
      return this;
    }
    return _BrandTokens(
      contentPadding:
          EdgeInsets.lerp(contentPadding, other.contentPadding, t) ??
          contentPadding,
    );
  }
}
