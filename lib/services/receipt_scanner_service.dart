import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/expense_model.dart';

// ── Result model ───────────────────────────────────────────────────────────────

class ScannedExpense {
  final double amount;
  final ExpenseCategory category;
  final String? description;
  final DateTime date;

  const ScannedExpense({
    required this.amount,
    required this.category,
    this.description,
    required this.date,
  });
}

// ── Service ────────────────────────────────────────────────────────────────────

class ReceiptScannerService {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScannedExpense?> scanFromCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return _process(photo.path);
  }

  Future<ScannedExpense?> scanFromGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return _process(photo.path);
  }

  Future<ScannedExpense?> _process(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await _recognizer.processImage(inputImage);
      final text = recognized.text;
      try {
        File(path).deleteSync();
      } catch (_) {}

      if (text.isEmpty) return null;

      final amount = _extractAmount(text);
      if (amount == null) return null;

      return ScannedExpense(
        amount: amount,
        category: _extractCategory(text),
        description: _extractDescription(text),
        date: _extractDate(text) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  double? _extractAmount(String text) {
    // Priority 1: amount near a total/payable label
    final labeled = RegExp(
      r'(?:grand\s*total|total\s*amount|net\s*payable|amount\s*payable|net\s*amt?|bill\s*amount|to\s*pay|total)[:\s]*(?:rs\.?|₹|inr)?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    double? best;
    for (final m in labeled.allMatches(text)) {
      final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (val != null && val > 0 && (best == null || val > best)) best = val;
    }
    if (best != null) return best;

    // Priority 2: currency-prefixed number
    final currencyPrefixed = RegExp(
      r'(?:rs\.?|₹|inr)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    for (final m in currencyPrefixed.allMatches(text)) {
      final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (val != null && val > 0 && (best == null || val > best)) best = val;
    }
    if (best != null) return best;

    // Fallback: largest standalone number (> 1)
    final nums = RegExp(r'\b([\d,]+\.?\d*)\b');
    double? largest;
    for (final m in nums.allMatches(text)) {
      final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (val != null && val > 1 && (largest == null || val > largest)) {
        largest = val;
      }
    }
    return largest;
  }

  ExpenseCategory _extractCategory(String text) {
    final lower = text.toLowerCase();

    const food = [
      'swiggy', 'zomato', 'restaurant', 'cafe', 'hotel', 'diner', 'pizza',
      'burger', 'biryani', 'dhaba', 'bakery', 'blinkit', 'bigbasket', 'zepto',
      'groceries', 'supermarket', 'fruits', 'vegetables', 'eatery', 'kitchen',
    ];
    const transport = [
      'uber', 'ola', 'rapido', 'metro', 'bus', 'auto', 'cab', 'taxi',
      'petrol', 'diesel', 'fuel', 'hpcl', 'bpcl', 'iocl', 'parking', 'toll',
      'irctc', 'railway', 'flight', 'indigo', 'air india', 'airindia',
    ];
    const health = [
      'pharmacy', 'medical', 'hospital', 'clinic', 'apollo', 'medplus',
      'netmeds', '1mg', 'doctor', 'diagnostic', 'pathology', 'medicine',
    ];
    const entertainment = [
      'netflix', 'amazon prime', 'hotstar', 'spotify', 'youtube', 'movie',
      'cinema', 'pvr', 'inox', 'bookmyshow', 'game', 'subscription',
    ];
    const shopping = [
      'amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa',
      'clothing', 'fashion', 'apparel', 'shoes',
    ];
    const housing = [
      'rent', 'electricity', 'water bill', 'gas', 'maintenance', 'society',
    ];
    const finance = [
      'bank', 'atm', 'emi', 'loan', 'insurance', 'credit card',
    ];

    if (food.any((k) => lower.contains(k))) return ExpenseCategory.food;
    if (transport.any((k) => lower.contains(k))) return ExpenseCategory.transport;
    if (health.any((k) => lower.contains(k))) return ExpenseCategory.health;
    if (entertainment.any((k) => lower.contains(k))) return ExpenseCategory.entertainment;
    if (shopping.any((k) => lower.contains(k))) return ExpenseCategory.shopping;
    if (housing.any((k) => lower.contains(k))) return ExpenseCategory.housing;
    if (finance.any((k) => lower.contains(k))) return ExpenseCategory.finance;
    return ExpenseCategory.other;
  }

  String? _extractDescription(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final line in lines.take(5)) {
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(line)) {
        final clean = line.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-&]'), '').trim();
        if (clean.length >= 3) {
          return clean.length > 40 ? clean.substring(0, 40) : clean;
        }
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dmy = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})');
    final m1 = dmy.firstMatch(text);
    if (m1 != null) {
      try {
        final d = int.parse(m1.group(1)!);
        final mo = int.parse(m1.group(2)!);
        var y = int.parse(m1.group(3)!);
        if (y < 100) y += 2000;
        if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12) return DateTime(y, mo, d);
      } catch (_) {}
    }

    // DD Month YYYY (e.g. 12 Jan 2025)
    final dMonthY = RegExp(
      r'(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{2,4})',
      caseSensitive: false,
    );
    final m2 = dMonthY.firstMatch(text);
    if (m2 != null) {
      try {
        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final d = int.parse(m2.group(1)!);
        final mo = months[m2.group(2)!.toLowerCase().substring(0, 3)]!;
        var y = int.parse(m2.group(3)!);
        if (y < 100) y += 2000;
        return DateTime(y, mo, d);
      } catch (_) {}
    }

    return null;
  }

  void dispose() => _recognizer.close();
}
