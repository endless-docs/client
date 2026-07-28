import 'package:flutter/material.dart';

/// Endless Docs v1.1 brand primitives and semantic colors.
abstract final class EndlessBrand {
  static const Color ink = Color(0xff102428);
  static const Color mint = Color(0xff34d3a4);
  static const Color deepMint = Color(0xff087763);
  static const Color paper = Color(0xfff4f3ee);
  static const Color mist = Color(0xffdce9e5);
  static const Color slate = Color(0xff5c7072);
  static const Color white = Color(0xffffffff);

  static const Color lightSurfaceMuted = Color(0xffe8f0ed);
  static const Color lightBorder = Color(0xffcad8d4);
  static const Color lightSelection = Color(0xffd5efe7);
  static const Color lightInfo = Color(0xff286dd6);
  static const Color lightSuccess = Color(0xff168260);
  static const Color lightWarning = Color(0xffa66714);
  static const Color lightDanger = Color(0xffb64242);

  static const Color darkBackground = Color(0xff09181b);
  static const Color darkSurfaceMuted = Color(0xff183438);
  static const Color darkTextMuted = Color(0xffa9bab8);
  static const Color darkBorder = Color(0xff2b494c);
  static const Color darkSelection = Color(0xff164039);
  static const Color darkInfo = Color(0xff79aeff);
  static const Color darkSuccess = Color(0xff5ad9a5);
  static const Color darkWarning = Color(0xfff2b866);
  static const Color darkDanger = Color(0xffff9098);

  static const double controlRadius = 10;
  static const double marketingRadius = 16;
}

abstract final class EndlessTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color background = dark
        ? EndlessBrand.darkBackground
        : EndlessBrand.paper;
    final Color surface = dark ? EndlessBrand.ink : EndlessBrand.white;
    final Color surfaceMuted = dark
        ? EndlessBrand.darkSurfaceMuted
        : EndlessBrand.lightSurfaceMuted;
    final Color text = dark ? EndlessBrand.paper : EndlessBrand.ink;
    final Color textMuted = dark
        ? EndlessBrand.darkTextMuted
        : EndlessBrand.slate;
    final Color border = dark
        ? EndlessBrand.darkBorder
        : EndlessBrand.lightBorder;
    final Color accent = dark ? EndlessBrand.mint : EndlessBrand.deepMint;
    final Color onAccent = dark ? EndlessBrand.ink : EndlessBrand.white;
    final Color selection = dark
        ? EndlessBrand.darkSelection
        : EndlessBrand.lightSelection;
    final Color danger = dark
        ? EndlessBrand.darkDanger
        : EndlessBrand.lightDanger;

    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
          error: danger,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: selection,
          onPrimaryContainer: text,
          secondary: dark
              ? EndlessBrand.darkSuccess
              : EndlessBrand.lightSuccess,
          onSecondary: dark ? EndlessBrand.ink : EndlessBrand.white,
          secondaryContainer: surfaceMuted,
          onSecondaryContainer: text,
          tertiary: dark ? EndlessBrand.darkInfo : EndlessBrand.lightInfo,
          onTertiary: EndlessBrand.white,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: textMuted,
          surfaceContainerLowest: surface,
          surfaceContainerLow: surfaceMuted,
          surfaceContainer: surfaceMuted,
          surfaceContainerHigh: selection,
          surfaceContainerHighest: selection,
          outline: border,
          outlineVariant: border,
          inverseSurface: text,
          onInverseSurface: background,
          inversePrimary: dark ? EndlessBrand.deepMint : EndlessBrand.mint,
          shadow: EndlessBrand.ink,
          scrim: EndlessBrand.ink,
          error: danger,
          onError: EndlessBrand.white,
        );

    final ThemeData base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: border,
      fontFamily: 'Manrope',
    );
    final TextTheme brandedTextTheme = base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: 'Manrope',
      fontFamilyFallback: const <String>['Inter', 'Arial'],
    );
    final TextTheme textTheme = brandedTextTheme.copyWith(
      displaySmall: brandedTextTheme.displaySmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 38,
        height: 1.15,
        letterSpacing: -1.1,
      ),
      headlineMedium: brandedTextTheme.headlineMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 30,
        height: 1.2,
        letterSpacing: -0.6,
      ),
      headlineSmall: brandedTextTheme.headlineSmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: brandedTextTheme.titleLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.3,
      ),
      titleMedium: brandedTextTheme.titleMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.4,
      ),
      titleSmall: brandedTextTheme.titleSmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.4,
      ),
      bodyLarge: brandedTextTheme.bodyLarge?.copyWith(
        color: text,
        fontSize: 16,
        height: 1.55,
      ),
      bodyMedium: brandedTextTheme.bodyMedium?.copyWith(
        color: text,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: brandedTextTheme.bodySmall?.copyWith(
        color: textMuted,
        fontSize: 12,
        height: 1.45,
      ),
      labelLarge: brandedTextTheme.labelLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0,
      ),
      labelMedium: brandedTextTheme.labelMedium?.copyWith(
        color: textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.2,
      ),
    );

    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(EndlessBrand.controlRadius),
      borderSide: BorderSide(color: border),
    );
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(EndlessBrand.controlRadius),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: EndlessBrand.ink,
        foregroundColor: EndlessBrand.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 76,
        titleSpacing: 24,
        shape: Border(bottom: BorderSide(color: border)),
        iconTheme: const IconThemeData(color: EndlessBrand.paper),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: danger, width: 2),
        ),
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: border),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textMuted,
          hoverColor: selection,
          highlightColor: selection,
          shape: controlShape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: selection,
        side: BorderSide(color: border),
        shape: controlShape,
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        iconTheme: IconThemeData(color: accent, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: text,
        selectedColor: accent,
        selectedTileColor: selection,
        shape: controlShape,
        minTileHeight: 44,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EndlessBrand.marketingRadius),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EndlessBrand.marketingRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EndlessBrand.controlRadius),
          side: BorderSide(color: border),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                states.contains(WidgetState.selected) ? selection : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                states.contains(WidgetState.selected) ? accent : textMuted,
          ),
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: border)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(controlShape),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: selection,
        selectionHandleColor: accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceMuted,
        circularTrackColor: surfaceMuted,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: text,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: background),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: background),
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
    );
  }
}
