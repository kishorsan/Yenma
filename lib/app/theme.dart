import 'package:flutter/material.dart';

import '../domain/money.dart';

@immutable
class YenmaColors extends ThemeExtension<YenmaColors> {
  const YenmaColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.success,
    required this.warning,
    required this.heroSurface,
    required this.onHeroSurface,
    required this.onHeroSurfaceMuted,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color success;
  final Color warning;
  final Color heroSurface;
  final Color onHeroSurface;
  final Color onHeroSurfaceMuted;

  static const light = YenmaColors(
    income: Color(0xFF256B4F),
    expense: Color(0xFF9A3E38),
    transfer: Color(0xFF405F8E),
    success: Color(0xFF256B4F),
    warning: Color(0xFF835500),
    heroSurface: Color(0xFF303236),
    onHeroSurface: Color(0xFFF7F7F7),
    onHeroSurfaceMuted: Color(0xFFCECFD2),
  );

  static const dark = YenmaColors(
    income: Color(0xFF78D8AD),
    expense: Color(0xFFFFAAA2),
    transfer: Color(0xFFAFC6F0),
    success: Color(0xFF78D8AD),
    warning: Color(0xFFFFC56A),
    heroSurface: Color(0xFFE1E2E5),
    onHeroSurface: Color(0xFF202124),
    onHeroSurfaceMuted: Color(0xFF55575C),
  );

  @override
  YenmaColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? success,
    Color? warning,
    Color? heroSurface,
    Color? onHeroSurface,
    Color? onHeroSurfaceMuted,
  }) => YenmaColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    heroSurface: heroSurface ?? this.heroSurface,
    onHeroSurface: onHeroSurface ?? this.onHeroSurface,
    onHeroSurfaceMuted: onHeroSurfaceMuted ?? this.onHeroSurfaceMuted,
  );

  @override
  YenmaColors lerp(covariant YenmaColors? other, double t) {
    if (other == null) return this;
    return YenmaColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heroSurface: Color.lerp(heroSurface, other.heroSurface, t)!,
      onHeroSurface: Color.lerp(onHeroSurface, other.onHeroSurface, t)!,
      onHeroSurfaceMuted: Color.lerp(
        onHeroSurfaceMuted,
        other.onHeroSurfaceMuted,
        t,
      )!,
    );
  }
}

extension YenmaThemeContext on BuildContext {
  YenmaColors get yenmaColors =>
      Theme.of(this).extension<YenmaColors>() ?? YenmaColors.light;
}

Color kindColor(TransactionKind kind, BuildContext context) => switch (kind) {
  TransactionKind.expense => context.yenmaColors.expense,
  TransactionKind.income => context.yenmaColors.income,
  TransactionKind.transfer => context.yenmaColors.transfer,
};

ThemeData yenmaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF66686D),
        brightness: brightness,
      ).copyWith(
        surface: dark ? const Color(0xFF17181A) : const Color(0xFFF2F2F3),
        surfaceContainer: dark
            ? const Color(0xFF222326)
            : const Color(0xFFE7E7E9),
        surfaceContainerHigh: dark
            ? const Color(0xFF2C2D31)
            : const Color(0xFFDCDDE0),
        primary: dark ? const Color(0xFFE1E2E5) : const Color(0xFF303236),
        onPrimary: dark ? const Color(0xFF202124) : const Color(0xFFF7F7F7),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      dark ? YenmaColors.dark : YenmaColors.light,
    ],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      toolbarHeight: 48,
      titleTextStyle: base.textTheme.titleLarge!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primary,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
    ),
  );
}

IconData categoryIcon(String key) => switch (key) {
  'restaurant' => Icons.restaurant_rounded,
  'shopping_cart' => Icons.shopping_cart_outlined,
  'directions_car' => Icons.directions_car_outlined,
  'shopping_bag' => Icons.shopping_bag_outlined,
  'local_hospital' => Icons.favorite_outline,
  'movie' => Icons.movie_outlined,
  'receipt' => Icons.receipt_long_outlined,
  'subscriptions' => Icons.subscriptions_outlined,
  'school' => Icons.school_outlined,
  'account_balance' => Icons.account_balance_outlined,
  'trending_up' => Icons.trending_up,
  'swap_horiz' => Icons.swap_horiz_rounded,
  'home' => Icons.home_outlined,
  'call_received' => Icons.call_received_rounded,
  'account_balance_wallet' => Icons.account_balance_wallet_outlined,
  'savings' => Icons.savings_outlined,
  _ => Icons.more_horiz,
};
