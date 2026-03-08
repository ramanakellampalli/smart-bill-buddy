import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/expense_model.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import 'expenses_screen.dart' show MonthPicker;

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);

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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _BreakdownCard(
                              total: total,
                              sortedCats: sortedCats,
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
            color: Colors.black.withOpacity(0.04),
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
          // Donut chart
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: sortedCats,
                  total: total,
                ),
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
          // 2-column legend grid
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

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    double startAngle = -pi / 2;
    const gap = 0.025; // radians gap between segments

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
    // Pair items into rows of 2
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
              final pctStr = '${(pct * 100).toStringAsFixed(1)}%';
              final amtStr = money.format(entry.value);
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
                            '$pctStr · $amtStr',
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
