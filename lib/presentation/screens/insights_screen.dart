import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/bill_model.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
import '../widgets/category_logo.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg            = AppColors.bg;
const _card          = AppColors.surface;
const _surface2      = AppColors.surface2;
const _border        = AppColors.border;
const _primary       = AppColors.primary;
const _textPrimary   = AppColors.textPrimary;
const _textSecondary = AppColors.textSecondary;
const _textTertiary  = AppColors.textTertiary;
const _green         = AppColors.green;
const _red           = AppColors.red;

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Screen ─────────────────────────────────────────────────────────────────────

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _prev() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1, 1));

  void _next() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1, 1);
    if (!next.isAfter(DateTime(now.year, now.month, 1))) {
      setState(() => _month = next);
    }
  }

  bool get _isCurrent {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BillsProvider>();
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);
    final money = context.watch<AppSettingsProvider>().money;

    final monthBills = p.bills
        .where((b) =>
            !b.dueDate.isBefore(_month) && b.dueDate.isBefore(monthEnd))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    double sumOf(Iterable<BillModel> bills) =>
        bills.fold(0.0, (acc, b) => acc + (b.amount ?? 0.0));

    final total = sumOf(monthBills);
    final paid = sumOf(monthBills.where((b) => b.isPaid));
    final unpaid = (total - paid).clamp(0.0, double.infinity);
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final paidCount = monthBills.where((b) => b.isPaid).length;
    final unpaidCount = monthBills.where((b) => !b.isPaid).length;

    final Map<String, double> catTotals = {};
    final Map<String, int> catCounts = {};
    for (final b in monthBills) {
      catTotals[b.category] = (catTotals[b.category] ?? 0) + (b.amount ?? 0);
      catCounts[b.category] = (catCounts[b.category] ?? 0) + 1;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmt = sortedCats.isEmpty
        ? 1.0
        : sortedCats.first.value.clamp(1.0, double.infinity);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: const Text(
          'Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ),
      body: p.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _primary))
          : SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _MonthPicker(
              label: DateFormat('MMMM yyyy').format(_month),
              onPrev: _prev,
              onNext: _isCurrent ? null : _next,
            ),
            const SizedBox(height: 16),
            _SummaryCard(
              total: money.format(total),
              paid: money.format(paid),
              unpaid: money.format(unpaid),
              progress: progress,
              paidCount: paidCount,
              unpaidCount: unpaidCount,
            ),
            const SizedBox(height: 24),
            if (monthBills.isEmpty)
              _EmptyState(month: DateFormat('MMMM yyyy').format(_month))
            else ...[
              const _SectionLabel('SPEND BY CATEGORY'),
              const SizedBox(height: 12),
              ...sortedCats.map(
                (e) => _CategoryBar(
                  category: e.key,
                  amount: money.format(e.value),
                  count: catCounts[e.key]!,
                  fraction: e.value / maxAmt,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('BILLS THIS MONTH'),
              const SizedBox(height: 12),
              ...monthBills.map(
                (b) => _BillRow(
                  bill: b,
                  amountText: b.amount == null ? '' : money.format(b.amount),
                  dateText: DateFormat('d MMM').format(b.dueDate),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Month Picker ──────────────────────────────────────────────────────────────

class _MonthPicker extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthPicker({
    required this.label,
    required this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Arrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(width: 16),
        _Arrow(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Arrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF0EDE9) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? _textTertiary : _textSecondary,
        ),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String total;
  final String paid;
  final String unpaid;
  final double progress;
  final int paidCount;
  final int unpaidCount;

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.progress,
    required this.paidCount,
    required this.unpaidCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF292524), Color(0xFF57534E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha:0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Total',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Paid',
                  value: paid,
                  sub: '$paidCount ${paidCount == 1 ? 'bill' : 'bills'}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Pending',
                  value: unpaid,
                  sub: '$unpaidCount ${unpaidCount == 1 ? 'bill' : 'bills'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paid so far',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _StatChip({
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }
}

// ── Category Bar ──────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final String category;
  final String amount;
  final int count;
  final double fraction;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.count,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CategoryLogo(category: category, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _cap(category),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'bill' : 'bills'}',
                  style: const TextStyle(fontSize: 11, color: _textTertiary),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFEDE6DC),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bill Row ──────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final BillModel bill;
  final String amountText;
  final String dateText;

  const _BillRow({
    required this.bill,
    required this.amountText,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bill.isPaid ? const Color(0xFFFAFAFA) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CategoryLogo(category: bill.category, size: 38, dimmed: bill.isPaid, billName: bill.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: bill.isPaid ? _textTertiary : _textPrimary,
                    decoration:
                        bill.isPaid ? TextDecoration.lineThrough : null,
                    decorationColor: _textTertiary,
                  ),
                ),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          if (amountText.isNotEmpty)
            Text(
              amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: bill.isPaid ? _textTertiary : _textPrimary,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bill.isPaid
                  ? _green.withValues(alpha:0.08)
                  : _red.withValues(alpha:0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bill.isPaid ? 'Paid' : 'Unpaid',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: bill.isPaid ? _green : _red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String month;
  const _EmptyState({required this.month});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No bills found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No bills are due in $month',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
