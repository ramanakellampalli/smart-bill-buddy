import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/expense_model.dart';
import '../../services/receipt_scanner_service.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import 'category_logo.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _green = Color(0xFF16A34A);

// ── Preview sheet ──────────────────────────────────────────────────────────────

class ScannedExpensePreview extends StatelessWidget {
  final ScannedExpense scanned;

  const ScannedExpensePreview({super.key, required this.scanned});

  Future<void> _save(BuildContext context) async {
    final provider = context.read<ExpensesProvider>();
    await provider.add(ExpenseModel.create(
      amount: scanned.amount,
      category: scanned.category,
      description: scanned.description,
      date: scanned.date,
    ));
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added from receipt'),
          backgroundColor: _green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = context.watch<AppSettingsProvider>().money;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          const SizedBox(height: 20),
          _Header(),
          const SizedBox(height: 20),
          _PreviewCard(scanned: scanned, money: money),
          const SizedBox(height: 8),
          const Text(
            'Review and confirm — you can edit this expense afterwards.',
            style: TextStyle(fontSize: 12, color: _textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _ActionRow(onSave: () => _save(context), onSkip: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

// ── Sub-components ─────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.receipt_long_rounded, size: 18, color: _primary),
        SizedBox(width: 8),
        Text(
          'Receipt Scanned',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ScannedExpense scanned;
  final dynamic money;

  const _PreviewCard({required this.scanned, required this.money});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(scanned.date, DateTime.now());
    final dateLabel = isToday ? 'Today' : DateFormat('d MMM yyyy').format(scanned.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            money.fmt(scanned.amount),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CategoryLogo(category: scanned.category.value, size: 15),
              const SizedBox(width: 6),
              Text(
                scanned.category.label,
                style: const TextStyle(fontSize: 14, color: _textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_rounded, size: 13, color: _textTertiary),
              const SizedBox(width: 4),
              Text(dateLabel, style: const TextStyle(fontSize: 13, color: _textTertiary)),
            ],
          ),
          if (scanned.description != null) ...[
            const SizedBox(height: 6),
            Text(
              scanned.description!,
              style: const TextStyle(fontSize: 13, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onSkip;

  const _ActionRow({required this.onSave, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontSize: 15, color: _textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Save Expense',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
