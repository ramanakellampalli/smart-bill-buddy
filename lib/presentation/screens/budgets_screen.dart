import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/budget_model.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
import '../state/budgets_provider.dart';
import '../widgets/category_logo.dart';
import '../../core/theme/app_colors.dart';

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

// ── Category metadata ─────────────────────────────────────────────────────────

class _Cat {
  final String value;
  final String label;
  const _Cat(this.value, this.label);
}

const _allCats = [
  _Cat('utilities', 'Utilities'),
  _Cat('rent', 'Rent'),
  _Cat('emi', 'EMI'),
  _Cat('credit_card', 'Credit Card'),
  _Cat('subscriptions', 'Subscriptions'),
  _Cat('education', 'Education'),
  _Cat('other', 'Other'),
];

String _catLabel(String value) {
  for (final c in _allCats) {
    if (c.value == value) return c.label;
  }
  return value[0].toUpperCase() + value.substring(1);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  void _openSheet(BuildContext context, {BudgetModel? existing}) {
    final bp = context.read<BudgetsProvider>();
    final takenCats = bp.budgets.map((b) => b.category).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: bp,
        child: _BudgetSheet(existing: existing, takenCats: takenCats),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BudgetsProvider>();
    final bills = context.watch<BillsProvider>().bills;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final money = context.watch<AppSettingsProvider>().money;
    final monthLabel = DateFormat('MMMM yyyy').format(now).toUpperCase();

    // Per-category spend from bills this month (all bills, paid or not)
    final Map<String, double> catSpend = {};
    for (final b in bills) {
      if (!b.dueDate.isBefore(monthStart) && b.dueDate.isBefore(monthEnd)) {
        catSpend[b.category] =
            (catSpend[b.category] ?? 0) + (b.amount ?? 0);
      }
    }

    final totalBudgeted =
        bp.budgets.fold(0.0, (acc, b) => acc + b.limit);
    final totalSpent = bp.budgets.fold(
        0.0, (acc, b) => acc + (catSpend[b.category] ?? 0));

    // Sort budgets: over-budget first, then by category name
    final sorted = [...bp.budgets]..sort((a, b) {
        final aOver =
            (catSpend[a.category] ?? 0) > a.limit ? 1 : 0;
        final bOver =
            (catSpend[b.category] ?? 0) > b.limit ? 1 : 0;
        if (aOver != bOver) return bOver - aOver;
        return _catLabel(a.category).compareTo(_catLabel(b.category));
      });

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Budgets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _textPrimary, size: 24),
            tooltip: 'Add Budget',
            onPressed: bp.isLoading || bp.budgets.length >= _allCats.length
                ? null
                : () => _openSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SelectionArea(
        child: bp.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _primary,
                ),
              )
            : bp.budgets.isEmpty
            ? _EmptyState(onAdd: () => _openSheet(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    budgeted: money.format(totalBudgeted),
                    spent: money.format(totalSpent),
                    remaining: money.format(
                        (totalBudgeted - totalSpent).clamp(0, double.infinity)),
                    progress: totalBudgeted <= 0
                        ? 0.0
                        : (totalSpent / totalBudgeted).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 24),
                  if (bp.error != null)
                    _ErrorBanner(message: bp.error!),
                  const _SectionLabel('BUDGET LIMITS'),
                  const SizedBox(height: 12),
                  ...sorted.map(
                    (budget) => _BudgetCard(
                      budget: budget,
                      spent: catSpend[budget.category] ?? 0,
                      money: money,
                      onTap: () =>
                          _openSheet(context, existing: budget),
                    ),
                  ),
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

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: _red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String budgeted;
  final String spent;
  final String remaining;
  final double progress;

  const _SummaryCard({
    required this.budgeted,
    required this.spent,
    required this.remaining,
    required this.progress,
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
            'Total Budget',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            budgeted,
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
              Expanded(child: _StatChip(label: 'Spent', value: spent)),
              const SizedBox(width: 10),
              Expanded(child: _StatChip(label: 'Remaining', value: remaining)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Spent so far',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
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
  const _StatChip({required this.label, required this.value});

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
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Budget Card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final double spent;
  final NumberFormat money;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = budget.limit <= 0 ? 0.0 : (spent / budget.limit).clamp(0.0, 2.0);
    final isOver = spent > budget.limit;
    final isWarn = !isOver && fraction >= 0.75;

    final barColor = isOver
        ? _red
        : isWarn
            ? _primary
            : _green;

    final remaining = budget.limit - spent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOver ? _red.withValues(alpha:0.3) : _border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryLogo(category: budget.category, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _catLabel(budget.category),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Limit: ${money.format(budget.limit)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money.format(spent),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isOver ? _red : _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isOver)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha:0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Over budget',
                          style: TextStyle(
                            fontSize: 10,
                            color: _red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${money.format(remaining)} left',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(fraction.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(
                    fontSize: 11,
                    color: barColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: _textTertiary, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFEDE6DC),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

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
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 36,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No budgets yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set monthly limits per category to track your spending',
              style: TextStyle(fontSize: 13, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
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
                      'Set Budget',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

// ── Add / Edit Budget Sheet ───────────────────────────────────────────────────

class _BudgetSheet extends StatefulWidget {
  final BudgetModel? existing;
  final Set<String> takenCats;

  const _BudgetSheet({this.existing, required this.takenCats});

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late String _category;
  final _amtCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existing != null;

  List<_Cat> get _available {
    if (_isEditing) return _allCats;
    return _allCats
        .where((c) => !widget.takenCats.contains(c.value))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _category = widget.existing!.category;
      _amtCtrl.text = widget.existing!.limit.toStringAsFixed(0);
    } else {
      _category = _available.isNotEmpty ? _available.first.value : '';
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final limit = double.parse(_amtCtrl.text.trim());
    final bp = context.read<BudgetsProvider>();

    if (_isEditing) {
      await bp.set(widget.existing!.copyWith(
        category: _category,
        limit: limit,
      ));
    } else {
      await bp.set(BudgetModel.create(
        category: _category,
        limit: limit,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await context
        .read<BudgetsProvider>()
        .remove(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<BudgetsProvider>().saving;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Budget' : 'Set Budget',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                if (_isEditing)
                  GestureDetector(
                    onTap: saving ? null : _delete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: _red.withValues(alpha:0.2)),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 12,
                          color: _red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Category selector
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            if (_isEditing)
              // Editing: show current category locked
              Row(
                children: [
                  CategoryLogo(category: _category, size: 36),
                  const SizedBox(width: 10),
                  Text(
                    _catLabel(_category),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE6DC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'locked',
                      style: TextStyle(
                          fontSize: 10, color: _textTertiary),
                    ),
                  ),
                ],
              )
            else
              // Adding: wrap of available categories
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _available.map((cat) {
                  final sel = cat.value == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? _primary.withValues(alpha:0.10)
                            : _card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? _primary : _border,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryLogo(
                              category: cat.value, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: sel ? _primary : _textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // Amount field
            Text(
              'Monthly Limit (${context.watch<AppSettingsProvider>().currency.symbol})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '${context.watch<AppSettingsProvider>().currency.symbol} ',
                prefixStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                ),
                hintText: '0',
                hintStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: _textTertiary,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F0EA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a limit amount';
                }
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroCard,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Budget' : 'Save Budget',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
