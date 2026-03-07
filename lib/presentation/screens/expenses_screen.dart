import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/expense_model.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/category_logo.dart';

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

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void _openSheet({ExpenseModel? existing}) {
    final provider = context.read<ExpensesProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddExpenseSheet(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpensesProvider>();
    final money = context.watch<AppSettingsProvider>().money;
    final monthExpenses = p.forMonth(_month);
    final total = monthExpenses.fold(0.0, (acc, e) => acc + e.amount);

    // Group by category
    final Map<ExpenseCategory, List<ExpenseModel>> grouped = {};
    for (final e in monthExpenses) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }
    // Sort categories by total spend descending
    final sortedCategories = grouped.entries.toList()
      ..sort((a, b) {
        final sumA = a.value.fold(0.0, (s, e) => s + e.amount);
        final sumB = b.value.fold(0.0, (s, e) => s + e.amount);
        return sumB.compareTo(sumA);
      });

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Expenses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: _primary, size: 24),
            tooltip: 'Add Expense',
            onPressed: () => _openSheet(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary))
          : monthExpenses.isEmpty
                      ? ExpenseEmptyState(onAdd: () => _openSheet())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            ExpenseSummaryCard(total: total, count: monthExpenses.length, money: money),
                            const SizedBox(height: 20),
                            const _SectionLabel('BY CATEGORY'),
                            const SizedBox(height: 12),
                            ...sortedCategories.map(
                              (entry) => ExpenseCategoryRow(
                                category: entry.key,
                                expenses: entry.value,
                                money: money,
                                onExpenseTap: (e) => _openSheet(existing: e),
                              ),
                            ),
                          ],
                        ),
    );
  }
}

// ── Month Picker ───────────────────────────────────────────────────────────────

class MonthPicker extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const MonthPicker({
    super.key,
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
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

// ── Summary Card ───────────────────────────────────────────────────────────────

class ExpenseSummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final NumberFormat money;

  const ExpenseSummaryCard({
    super.key,
    required this.total,
    required this.count,
    required this.money,
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
            color: const Color(0xFF1C1917).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Spent',
                style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 0.3),
              ),
              Text(
                DateFormat('MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w400),
              ),
            ],
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
            '$count ${count == 1 ? 'expense' : 'expenses'} this month',
            style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Category Row (expandable) ──────────────────────────────────────────────────

class ExpenseCategoryRow extends StatefulWidget {
  final ExpenseCategory category;
  final List<ExpenseModel> expenses;
  final NumberFormat money;
  final ValueChanged<ExpenseModel> onExpenseTap;

  const ExpenseCategoryRow({
    super.key,
    required this.category,
    required this.expenses,
    required this.money,
    required this.onExpenseTap,
  });

  @override
  State<ExpenseCategoryRow> createState() => _ExpenseCategoryRowState();
}

class _ExpenseCategoryRowState extends State<ExpenseCategoryRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expenses.fold(0.0, (s, e) => s + e.amount);
    final sorted = [...widget.expenses]..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row — tappable
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CategoryLogo(category: widget.category.value, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${widget.expenses.length} ${widget.expenses.length == 1 ? 'expense' : 'expenses'}',
                              style: const TextStyle(fontSize: 11, color: _textSecondary),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 14,
                              color: _textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.money.format(total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable list
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                Divider(height: 1, thickness: 1, color: _border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: sorted.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final e = entry.value;
                        final isLast = idx == sorted.length - 1;
                        return ExpenseItemRow(
                          expense: e,
                          money: widget.money,
                          isLast: isLast,
                          onTap: () => widget.onExpenseTap(e),
                        );
                      }).toList(),
                    ),
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

// ── Expense Item Row ───────────────────────────────────────────────────────────

class ExpenseItemRow extends StatelessWidget {
  final ExpenseModel expense;
  final NumberFormat money;
  final VoidCallback onTap;
  final bool isLast;

  const ExpenseItemRow({
    super.key,
    required this.expense,
    required this.money,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(expense.date, DateTime.now());
    final dateLabel = isToday ? 'Today' : DateFormat('d MMM').format(expense.date);
    final hasDesc = expense.description != null && expense.description!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot + connector
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 2),
                        color: const Color(0xFFEDE6DC),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Row(
                  children: [
                    Text(
                      money.format(expense.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    if (hasDesc) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          expense.description!,
                          style: const TextStyle(fontSize: 12, color: _textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 11, color: _textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class ExpenseEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const ExpenseEmptyState({super.key, required this.onAdd});

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
              child: const Icon(Icons.receipt_long_rounded, size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track your daily spending by adding expenses here.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Add Expense',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
