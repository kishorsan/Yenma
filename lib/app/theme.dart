import 'package:flutter/material.dart';

import '../domain/money.dart';

const mint = Color(0xFF58DCB1);
const coral = Color(0xFFFF887C);
const blue = Color(0xFF8AB4FF);
Color kindColor(TransactionKind kind, Brightness brightness) => switch (kind) {
  TransactionKind.expense =>
    brightness == Brightness.dark ? coral : const Color(0xFFB54035),
  TransactionKind.income =>
    brightness == Brightness.dark ? mint : const Color(0xFF147452),
  TransactionKind.transfer =>
    brightness == Brightness.dark ? blue : const Color(0xFF305AA1),
};

ThemeData yenmaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF258464),
        brightness: brightness,
      ).copyWith(
        surface: dark ? const Color(0xFF111C20) : const Color(0xFFF7F9F7),
        primary: dark ? mint : const Color(0xFF146B50),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
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
      color: dark ? const Color(0xFF1C292D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
  _ => Icons.more_horiz,
};
