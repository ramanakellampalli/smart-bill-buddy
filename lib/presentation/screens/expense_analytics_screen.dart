import 'dart:math';
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

    // Prev month comparison
    final prevMonth = DateTime(_month.year, _month.month - 1);
    final prevTotal = ep.totalForMonth(prevMonth);
    final diff = total - prevTotal;

    // Last 6 months for mini trend chart
    final monthBars = List.generate(6, (i) {
      final m = DateTime(_month.year, _month.month - (5 - i));
      return (label: DateFormat('MMM').format(m), amount: ep.totalForMonth(m));
    });

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
                            _SummaryCard(
                              total: total,
                              count: monthExpenses.length,
                              prevTotal: prevTotal,
                              diff: diff,
                              money: money,
                              monthBars: monthBars,
                              currentMonth: _month,
                            ),
                            const SizedBox(height: 24),
                            _CategoryList(
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

// ── Summary Card with Trend Chart ──────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final double prevTotal;
  final double diff;
  final NumberFormat money;
  final List<({String label, double amount})> monthBars;
  final DateTime currentMonth;

  const _SummaryCard({
    required this.total,
    required this.count,
    required this.prevTotal,
    required this.diff,
    required this.money,
    required this.monthBars,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = prevTotal > 0;
    final isHigher = diff > 0;
    final pct = hasPrev ? ((diff / prevTotal) * 100).abs().toStringAsFixed(0) : null;
    final maxBar = monthBars.isEmpty ? 0.0 : monthBars.map((b) => b.amount).reduce(max);
    final currentLabel = DateFormat('MMM').format(currentMonth);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
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
          // Amount + trend badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL SPENT',
                      style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      money.format(total),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count ${count == 1 ? 'expense' : 'expenses'} this month',
                      style: const TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              if (hasPrev)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isHigher ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isHigher ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                        size: 20,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${isHigher ? '+' : '-'}$pct%',
                        style: TextStyle(
                          fontSize: 13,
                          color: isHigher ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'vs last mo',
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // 6-month mini bar chart
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthBars.map((bar) {
                final frac = maxBar <= 0 ? 0.05 : (bar.amount / maxBar).clamp(0.05, 1.0);
                final isCurrent = bar.label == currentLabel;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 44 * frac,
                          decoration: BoxDecoration(
                            color: isCurrent ? _primary : Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          bar.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: isCurrent ? Colors.white70 : Colors.white38,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category List ──────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> catTotals;
  final double total;
  final NumberFormat money;

  const _CategoryList({
    required this.catTotals,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (catTotals.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('BY CATEGORY'),
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
              final pct = total <= 0 ? 0.0 : entry.value / total;
              final isLast = index == catTotals.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CategoryLogo(category: entry.key.value, size: 32),
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
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 11, color: _textTertiary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: const Color(0xFFEDE6DC),
                            valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(height: 1, thickness: 1, color: _border, indent: 60),
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
