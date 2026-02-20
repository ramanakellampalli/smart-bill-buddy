import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Supported currencies ───────────────────────────────────────────────────────

class CurrencyOption {
  final String symbol;
  final String locale;
  final String label; // e.g. "Indian Rupee (₹)"
  final String code;  // e.g. "INR"

  const CurrencyOption({
    required this.symbol,
    required this.locale,
    required this.label,
    required this.code,
  });
}

const List<CurrencyOption> kCurrencies = [
  CurrencyOption(symbol: '₹', locale: 'en_IN', label: 'Indian Rupee',    code: 'INR'),
  CurrencyOption(symbol: '\$', locale: 'en_US', label: 'US Dollar',       code: 'USD'),
  CurrencyOption(symbol: '€', locale: 'eu',    label: 'Euro',             code: 'EUR'),
  CurrencyOption(symbol: '£', locale: 'en_GB', label: 'British Pound',    code: 'GBP'),
  CurrencyOption(symbol: '¥', locale: 'ja_JP', label: 'Japanese Yen',     code: 'JPY'),
  CurrencyOption(symbol: 'A\$', locale: 'en_AU', label: 'Australian Dollar', code: 'AUD'),
];

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kCurrencyIndex = 'currency_index';

// ── Provider ──────────────────────────────────────────────────────────────────

class AppSettingsProvider extends ChangeNotifier {
  int _currencyIndex = 0;

  int get currencyIndex => _currencyIndex;

  CurrencyOption get currency => kCurrencies[_currencyIndex];

  NumberFormat get money => NumberFormat.currency(
        locale: currency.locale,
        symbol: currency.symbol,
        decimalDigits: currency.code == 'JPY' ? 0 : 0,
      );

  AppSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyIndex = (prefs.getInt(_kCurrencyIndex) ?? 0)
        .clamp(0, kCurrencies.length - 1);
    notifyListeners();
  }

  Future<void> setCurrency(int index) async {
    if (index < 0 || index >= kCurrencies.length) return;
    _currencyIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCurrencyIndex, index);
  }
}
