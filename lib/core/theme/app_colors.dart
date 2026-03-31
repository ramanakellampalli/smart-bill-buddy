import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const bg      = Color(0xFFF5F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF0F0E8);

  // ── Borders ─────────────────────────────────────────────────────────────────
  static const border  = Color(0xFFE8E8E0);

  // ── Primary accent — electric lime ──────────────────────────────────────────
  static const primary      = Color(0xFFC8FF00);
  static const primaryDark  = Color(0xFF9ECC00);

  // ── Hero card ───────────────────────────────────────────────────────────────
  static const heroCard = Color(0xFF111111);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF111111);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary  = Color(0xFFAAAAAA);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const green = Color(0xFF15803D);
  static const red   = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);

  // ── Nav ──────────────────────────────────────────────────────────────────────
  static const navBg       = Color(0xFF111111);
  static const navActive   = Color(0xFFC8FF00);
  static const navInactive = Color(0xFF555555);
}
