import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

export 'package:material_3_expressive/material_3_expressive.dart';
export '../../views/shared/sliding_marquee_text.dart';

/// Strict Google Material 3 Expressive Theme & Catppuccin Mocha + Champagne Gold Palette
/// for Boss Arman MotoHub (Santa Cruz, Laguna).
class AppPalette {
  AppPalette._();

  // Catppuccin Mocha + Custom Champagne Gold Accents
  static const Color crust = Color(0xFF11111B); // Scaffold Base
  static const Color mantle = Color(0xFF181825); // Card / Surface
  static const Color surface0 = Color(0xFF313244); // Surface Borders / Dividers
  static const Color surface1 = Color(0xFF241E18); // Highlight / Input Surface
  static const Color surface2 = Color(0xFF45475A); // Elevated Surface / Secondary Border
  static const Color champagneGold = Color(0xFFF9E2AF); // Primary Accent
  static const Color warmGold = Color(0xFFE5C287); // Secondary Accent
  static const Color success = Color(0xFFA6E3A1); // Success / Paid / In-Stock
  static const Color warning = Color(0xFFFAB387); // Warning / Low-Stock / In-Transit
  static const Color danger = Color(0xFFF38BA8); // Danger / Shortage / Critical
  static const Color info = Color(0xFF89B4FA); // Catppuccin Blue / Info
  static const Color textHigh = Color(0xFFFFFFFF); // Text High-Emphasis
  static const Color textBody = Color(0xFFCDD6F4); // Text Body / Primary
  static const Color textMuted = Color(0xFFA6ADC8); // Text Muted / Subtext
  static const Color inactive = Color(0xFF6C7086); // Inactive Icons / Text

  // Signature Champagne Gold to Warm Peach/Gold Gradient
  static const LinearGradient goldActionGradient = LinearGradient(
    colors: [
      Color(0xFFF9E2AF),
      Color(0xFFE5C287),
      Color(0xFFFAB387),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient subtleCardGradient = LinearGradient(
    colors: [
      Color(0xFF1E1E2E),
      Color(0xFF181825),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  /// Primary bundled Google Sans font family registered in `pubspec.yaml`
  static const String fontFamily = 'GoogleSans';

  /// Material 3 Expressive (`M3EThemeData`) synchronized with Catppuccin Mocha,
  /// Champagne Gold, and Google Sans typography.
  static M3EThemeData get expressiveTheme {
    final baseTypography = M3ETypography.material3().apply(
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Google Sans', 'sans-serif'],
    );
    return M3EThemeData(
      colorScheme: M3EColorScheme.fromSeed(
        AppPalette.champagneGold,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppPalette.champagneGold,
        onPrimary: AppPalette.crust,
        primaryContainer: AppPalette.surface1,
        onPrimaryContainer: AppPalette.champagneGold,
        secondary: AppPalette.warmGold,
        onSecondary: AppPalette.crust,
        secondaryContainer: AppPalette.surface1,
        onSecondaryContainer: AppPalette.champagneGold,
        tertiary: AppPalette.warning,
        onTertiary: AppPalette.crust,
        error: AppPalette.danger,
        onError: AppPalette.crust,
        surface: AppPalette.mantle,
        onSurface: AppPalette.textHigh,
        onSurfaceVariant: AppPalette.textBody,
        surfaceContainerLowest: AppPalette.crust,
        surfaceContainerLow: AppPalette.mantle,
        surfaceContainer: AppPalette.mantle,
        surfaceContainerHigh: AppPalette.mantle,
        surfaceContainerHighest: AppPalette.surface0,
        outline: AppPalette.surface0,
        outlineVariant: AppPalette.surface0,
        success: AppPalette.success,
        warning: AppPalette.warning,
        danger: AppPalette.danger,
      ),
      typography: M3ETypography(
        baseline: M3ETypeScale(
          displayLarge: baseTypography.baseline.displayLarge,
          displayMedium: baseTypography.baseline.displayMedium,
          displaySmall: baseTypography.baseline.displaySmall,
          headlineLarge: baseTypography.baseline.headlineLarge,
          headlineMedium: baseTypography.baseline.headlineMedium,
          headlineSmall: baseTypography.baseline.headlineSmall,
          titleLarge: baseTypography.baseline.titleLarge,
          titleMedium: baseTypography.baseline.titleMedium,
          titleSmall: baseTypography.baseline.titleSmall,
          bodyLarge: baseTypography.baseline.bodyLarge,
          bodyMedium: baseTypography.baseline.bodyMedium,
          bodySmall: baseTypography.baseline.bodySmall,
          labelLarge: baseTypography.baseline.labelLarge,
          labelMedium: baseTypography.baseline.labelMedium.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.0,
          ),
          labelSmall: baseTypography.baseline.labelSmall,
        ),
        emphasized: baseTypography.emphasized,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      surface: AppPalette.mantle,
      surfaceContainerLowest: AppPalette.crust,
      surfaceContainerLow: AppPalette.mantle,
      surfaceContainer: AppPalette.mantle,
      surfaceContainerHigh: AppPalette.surface1,
      surfaceContainerHighest: AppPalette.surface0,
      primary: AppPalette.champagneGold,
      onPrimary: AppPalette.crust,
      primaryContainer: AppPalette.surface1,
      onPrimaryContainer: AppPalette.champagneGold,
      secondary: AppPalette.warmGold,
      onSecondary: AppPalette.crust,
      secondaryContainer: AppPalette.surface0,
      onSecondaryContainer: AppPalette.textBody,
      tertiary: AppPalette.warning,
      onTertiary: AppPalette.crust,
      error: AppPalette.danger,
      onError: AppPalette.crust,
      onSurface: AppPalette.textBody,
      onSurfaceVariant: AppPalette.textMuted,
      outline: AppPalette.surface0,
      outlineVariant: AppPalette.surface0,
    );

    final baseTextTheme = ThemeData.dark().textTheme.apply(
          fontFamily: fontFamily,
          fontFamilyFallback: const ['Google Sans', 'sans-serif'],
          bodyColor: AppPalette.textBody,
          displayColor: AppPalette.textHigh,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SlidePageTransitionsBuilder(),
          TargetPlatform.iOS: SlidePageTransitionsBuilder(),
          TargetPlatform.windows: SlidePageTransitionsBuilder(),
          TargetPlatform.macOS: SlidePageTransitionsBuilder(),
          TargetPlatform.linux: SlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: AppPalette.crust,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Google Sans', 'sans-serif'],
      textTheme: baseTextTheme,
      primaryTextTheme: baseTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.crust,
        foregroundColor: AppPalette.textHigh,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.mantle,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.surface0, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.surface1;
            }
            return AppPalette.mantle;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.champagneGold;
            }
            return AppPalette.textMuted;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: AppPalette.champagneGold, width: 1.2);
            }
            return const BorderSide(color: AppPalette.surface0, width: 1);
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.mantle,
        indicatorColor: AppPalette.surface1,
        surfaceTintColor: Colors.transparent,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.champagneGold, size: 24);
          }
          return const IconThemeData(color: AppPalette.inactive, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              color: AppPalette.champagneGold,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            color: AppPalette.inactive,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.champagneGold,
          foregroundColor: AppPalette.crust,
          disabledBackgroundColor: AppPalette.surface0,
          disabledForegroundColor: AppPalette.inactive,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.champagneGold,
          side: const BorderSide(color: AppPalette.surface0, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.mantle,
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.inactive,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textMuted,
          fontSize: 13.5,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.champagneGold,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.surface0, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.surface0, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.champagneGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.mantle,
        selectedColor: AppPalette.surface1,
        disabledColor: AppPalette.crust,
        side: const BorderSide(color: AppPalette.surface0, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textBody,
          fontSize: 12.5,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.champagneGold,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.surface0,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.mantle,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textHigh,
          fontSize: 13.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppPalette.surface0),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.mantle,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.textBody,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppPalette.surface0, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.mantle,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppPalette.mantle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Global slide page transition — applied to every MaterialPageRoute.
// Incoming page slides in from the right edge with M3 emphasized decelerate.
// Outgoing page parallaxes 30% to the left and fades.
// ---------------------------------------------------------------------------
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primaryCurve = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.05, 0.7, 0.1, 1.0),
      reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
    );

    final secondaryCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Cubic(0.05, 0.7, 0.1, 1.0),
      reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).animate(secondaryCurve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(primaryCurve),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Custom Gradient CTA Button matching the user's Figma Login/Splash design
/// Hardened with `Flexible` + `TextOverflow.ellipsis` so long labels never overflow on 360dp screens.
class GoldGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isTrailingIcon;
  final double height;
  final bool isLoading;

  const GoldGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isTrailingIcon = false,
    this.height = 54,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppPalette.goldActionGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppPalette.champagneGold.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppPalette.crust,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null && !isTrailingIcon) ...[
                            Icon(icon, color: AppPalette.crust, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppPalette.crust,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          if (icon != null && isTrailingIcon) ...[
                            const SizedBox(width: 8),
                            Icon(icon, color: AppPalette.crust, size: 19),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Production-Grade Material 3 Empty State Widget (Objective 3).
/// Ensures every initially-empty database list displays an icon, descriptive text,
/// and an optional primary `FilledButton` CTA instead of a blank screen.
class MotoHubEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MotoHubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return M3ECard(
      variant: M3ECardVariant.filled,
      color: AppPalette.mantle,
      borderRadius: BorderRadius.circular(24),
      border: const BorderSide(color: AppPalette.surface0, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.surface1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.champagneGold.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              icon,
              color: AppPalette.champagneGold,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textHigh,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            M3EButton.filled(
              onPressed: onAction,
              size: M3EButtonSize.md,
              icon: const Icon(Icons.add_rounded, size: 18),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
