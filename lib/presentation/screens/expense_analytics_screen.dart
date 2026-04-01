import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/expense_model.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import 'expenses_screen.dart' show MonthPicker;

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

const _categoryColors = <ExpenseCategory, Color>{
  ExpenseCategory.food: Color(0xFFF59E0B),
  ExpenseCategory.transport: Color(0xFF3B82F6),
  ExpenseCategory.housing: Color(0xFF10B981),
  ExpenseCategory.shopping: Color(0xFFEC4899),
  ExpenseCategory.health: Color(0xFFEF4444),
  ExpenseCategory.entertainment: Color(0xFF8B5CF6),
  ExpenseCategory.finance: Color(0xFF6366F1),
  ExpenseCategory.other: Color(0xFF78716C),
};

Color _colorFor(ExpenseCategory cat) => _categoryColors[cat] ?? const Color(0xFF78716C);

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

    final Map<ExpenseCategory, double> catTotals = {};
    for (final e in monthExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
                          children: [
                            _QuickStatsRow(
                              total: total,
                              expenses: monthExpenses,
                              month: _month,
                              money: money,
                            ),
                            const SizedBox(height: 16),
                            _BreakdownCard(
                              total: total,
                              sortedCats: sortedCats,
                              money: money,
                            ),
                            const SizedBox(height: 16),
                            _TopExpensesCard(
                              expenses: monthExpenses,
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

// ── Quick Stats Row ────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final double total;
  final List<ExpenseModel> expenses;
  final DateTime month;
  final NumberFormat money;

  const _QuickStatsRow({
    required this.total,
    required this.expenses,
    required this.month,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final dailyAvg = total / daysInMonth;
    final count = expenses.length;
    final biggest = expenses.isEmpty
        ? 0.0
        : expenses.map((e) => e.amount).reduce(max);

    return Row(
      children: [
        _StatTile(
          icon: Icons.today_rounded,
          label: 'Daily Avg',
          value: money.format(dailyAvg),
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.receipt_rounded,
          label: 'Transactions',
          value: '$count',
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.arrow_upward_rounded,
          label: 'Biggest',
          value: money.format(biggest),
          iconColor: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: iconColor ?? _primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Breakdown Card ─────────────────────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final double total;
  final List<MapEntry<ExpenseCategory, double>> sortedCats;
  final NumberFormat money;

  const _BreakdownCard({
    required this.total,
    required this.sortedCats,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Expense Breakdown by Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _DonutPainter(segments: sortedCats, total: total),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money.format(total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _LegendGrid(sortedCats: sortedCats, total: total, money: money),
        ],
      ),
    );
  }
}

// ── Donut Painter ─────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<MapEntry<ExpenseCategory, double>> segments;
  final double total;

  const _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = min(cx, cy) - 4;
    final innerR = outerR * 0.58;

    double startAngle = -pi / 2;
    const gap = 0.025;

    for (final entry in segments) {
      final sweep = (entry.value / total) * (2 * pi) - gap;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = _colorFor(entry.key)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR
        ..strokeCap = StrokeCap.butt;

      final arcRect = Rect.fromCircle(
        center: Offset(cx, cy),
        radius: innerR + (outerR - innerR) / 2,
      );
      canvas.drawArc(arcRect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.total != total;
}

// ── Legend Grid ───────────────────────────────────────────────────────────────

class _LegendGrid extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> sortedCats;
  final double total;
  final NumberFormat money;

  const _LegendGrid({
    required this.sortedCats,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<MapEntry<ExpenseCategory, double>>>[];
    for (var i = 0; i < sortedCats.length; i += 2) {
      rows.add(sortedCats.sublist(i, min(i + 2, sortedCats.length)));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: row.map((entry) {
              final pct = total <= 0 ? 0.0 : entry.value / total;
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _colorFor(entry.key),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}% · ${money.format(entry.value)}',
                            style: const TextStyle(fontSize: 11, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ── Top Expenses Card ─────────────────────────────────────────────────────────

class _TopExpensesCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final NumberFormat money;

  const _TopExpensesCard({required this.expenses, required this.money});

  @override
  Widget build(BuildContext context) {
    final top = (expenses.toList()..sort((a, b) => b.amount.compareTo(a.amount)))
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Top Expenses',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final label = (e.description != null && e.description!.isNotEmpty)
                ? e.description!
                : e.category.label;
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _colorFor(e.category).withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _colorFor(e.category),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.category.label} · ${DateFormat('d MMM').format(e.date)}',
                            style: const TextStyle(fontSize: 11, color: _textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money.format(e.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                if (idx < top.length - 1)
                  Divider(height: 20, thickness: 1, color: _border),
              ],
            );
          }),
        ],
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
                color: _surface2,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 36, color: _textSecondary),
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
