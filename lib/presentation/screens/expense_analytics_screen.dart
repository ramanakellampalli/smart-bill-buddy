import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/expense_model.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import '../widgets/category_logo.dart';
import 'expenses_screen.dart' show MonthPicker;

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _green = Color(0xFF16A34A);

// ── Screen ─────────────────────────────────────────────────────────────────────

class ExpenseAnalyticsScreen extends StatefulWidget {
  const ExpenseAnalyticsScreen({super.key});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _prev() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _next() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
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
    final ep = context.watch<ExpensesProvider>();
    final money = context.watch<AppSettingsProvider>().money;
    final monthExpenses = ep.forMonth(_month);
    final total = monthExpenses.fold(0.0, (acc, e) => acc + e.amount);

    // Group by category
    final Map<ExpenseCategory, double> catTotals = {};
    for (final e in monthExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Compare with previous month
    final prevMonth = DateTime(_month.year, _month.month - 1);
    final prevTotal = ep.totalForMonth(prevMonth);
    final diff = total - prevTotal;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: const Text(
          'Expense Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
      ),
      body: ep.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: MonthPicker(
                    label: DateFormat('MMMM yyyy').format(_month),
                    onPrev: _prev,
                    onNext: _isCurrent ? null : _next,
                  ),
                ),
                Expanded(
                  child: monthExpenses.isEmpty
                      ? _EmptyAnalytics(month: DateFormat('MMMM yyyy').format(_month))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _AnalyticsSummaryCard(
                              total: total,
                              count: monthExpenses.length,
                              prevTotal: prevTotal,
                              diff: diff,
                              money: money,
                            ),
                            const SizedBox(height: 24),
                            _SpendingBarChart(
                              catTotals: sortedCats,
                              total: total,
                              money: money,
                            ),
                            const SizedBox(height: 24),
                            _CategoryBreakdownList(
                              catTotals: sortedCats,
                              total: total,
                              money: money,
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Analytics Summary Card ─────────────────────────────────────────────────────

class _AnalyticsSummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final double prevTotal;
  final double diff;
  final NumberFormat money;

  const _AnalyticsSummaryCard({
    required this.total,
    required this.count,
    required this.prevTotal,
    required this.diff,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = prevTotal > 0;
    final isHigher = diff > 0;
    final pct = hasPrev ? ((diff / prevTotal) * 100).abs().toStringAsFixed(0) : null;

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
            color: const Color(0xFF1C1917).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Spent',
            style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            money.format(total),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'expense' : 'expenses'} recorded',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          if (hasPrev) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isHigher ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isHigher ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isHigher
                        ? '$pct% more than last month'
                        : '$pct% less than last month',
                    style: TextStyle(
                      fontSize: 12,
                      color: isHigher ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Spending Bar Chart ─────────────────────────────────────────────────────────

class _SpendingBarChart extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> catTotals;
  final double total;
  final NumberFormat money;

  const _SpendingBarChart({
    required this.catTotals,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (catTotals.isEmpty) return const SizedBox();
    final maxVal = catTotals.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SPENDING BY CATEGORY'),
        const SizedBox(height: 12),
        ...catTotals.map((entry) {
          final fraction = maxVal <= 0 ? 0.0 : (entry.value / maxVal).clamp(0.0, 1.0);
          final pct = total <= 0 ? 0.0 : (entry.value / total * 100);
          return _CategoryBar(
            category: entry.key,
            amount: money.format(entry.value),
            fraction: fraction,
            pct: pct,
          );
        }),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final ExpenseCategory category;
  final String amount;
  final double fraction;
  final double pct;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.fraction,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLogo(category: category.value, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary),
                ),
              ),
              Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11, color: _textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFFEDE6DC),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Breakdown List ────────────────────────────────────────────────────

class _CategoryBreakdownList extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> catTotals;
  final double total;
  final NumberFormat money;

  const _CategoryBreakdownList({
    required this.catTotals,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('BREAKDOWN'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: catTotals.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              final pct = total <= 0 ? 0.0 : (entry.value / total * 100);
              final isLast = index == catTotals.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CategoryLogo(category: entry.key.value, size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key.label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary),
                          ),
                        ),
                        Text(
                          money.format(entry.value),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(height: 1, thickness: 1, color: _border, indent: 62),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────────

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

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyAnalytics extends StatelessWidget {
  final String month;
  const _EmptyAnalytics({required this.month});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No data yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'No expenses recorded in $month.',
              style: const TextStyle(fontSize: 13, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
