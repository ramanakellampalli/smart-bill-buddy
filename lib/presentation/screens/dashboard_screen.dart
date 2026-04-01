import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
import '../state/budgets_provider.dart';
import '../state/dues_provider.dart';
import '../state/expenses_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/category_logo.dart';
import '../../data/models/bill_model.dart';
import '../../data/models/budget_model.dart';
import '../../core/theme/app_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

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


String _catLabel(String value) {
  const labels = {
    'utilities': 'Utilities',
    'rent': 'Rent',
    'emi': 'EMI',
    'credit_card': 'Credit Card',
    'subscriptions': 'Subscriptions',
    'education': 'Education',
    'other': 'Other',
  };
  return labels[value] ??
      (value.isEmpty ? value : value[0].toUpperCase() + value.substring(1));
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Advance [from] by one billing cycle, clamping to the last valid day of the
/// target month (mirrors the same helper in bills_repository.dart).
DateTime _nextDueDateCalendar(DateTime from, String frequency) {
  int y = from.year, m = from.month, d = from.day;
  switch (frequency) {
    case 'quarterly':
      m += 3;
    case 'yearly':
      y += 1;
    default:
      m += 1;
  }
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.clamp(1, lastDay));
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToBills;
  final VoidCallback onNavigateToDues;
  final VoidCallback onNavigateToExpenses;
  final VoidCallback onNavigateToBudgets;
  const DashboardScreen({
    super.key,
    required this.onNavigateToBills,
    required this.onNavigateToDues,
    required this.onNavigateToExpenses,
    required this.onNavigateToBudgets,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showWelcome = true;
  Timer? _timer;
  late final PageController _summaryPageCtrl;
  int _summaryPage = 0;

  @override
  void initState() {
    super.initState();
    _summaryPageCtrl = PageController();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _summaryPageCtrl.dispose();
    super.dispose();
  }

  void _openNotifications(
    BuildContext context, {
    required List<BillModel> overdue,
    required List<BillModel> dueToday,
    required NumberFormat money,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationsSheet(
        overdue: overdue,
        dueToday: dueToday,
        money: money,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BillsProvider>();
    final dp = context.watch<DuesProvider>();
    final ep = context.watch<ExpensesProvider>();
    final budgetP = context.watch<BudgetsProvider>();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final monthBills = p.bills.where(
        (b) => !b.dueDate.isBefore(monthStart) && b.dueDate.isBefore(monthEnd));

    double sumAmount(Iterable<BillModel> bills) =>
        bills.fold(0.0, (acc, b) => acc + (b.amount ?? 0.0));

    final totalThisMonth = sumAmount(monthBills);
    final paidThisMonth = sumAmount(monthBills.where((b) => b.isPaid));
    final remainingThisMonth =
        (totalThisMonth - paidThisMonth).clamp(0, double.infinity);
    final progress = totalThisMonth <= 0
        ? 0.0
        : (paidThisMonth / totalThisMonth).clamp(0.0, 1.0);

    final overdue = p.bills
        .where((b) => !b.isPaid && b.dueDate.isBefore(today))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final dueToday = p.bills
        .where((b) => !b.isPaid && _isSameDay(b.dueDate, today))
        .toList();

    final hasAlerts = overdue.isNotEmpty || dueToday.isNotEmpty;

    // ── Dues snapshot data ─────────────────────────────────────────────────
    final activeDues = dp.dues.where((d) => !d.isSettled).toList();
    final toReceive = activeDues
        .where((d) => d.type == 'lent')
        .fold(0.0, (s, d) => s + d.remaining);
    final iOwe = activeDues
        .where((d) => d.type == 'borrowed')
        .fold(0.0, (s, d) => s + d.remaining);
    final duesPeople = activeDues
        .map((d) => d.personName)
        .toSet()
        .take(3)
        .toList();
    final duesPeopleTotal = activeDues.map((d) => d.personName).toSet().length;

    // ── Expenses snapshot data ──────────────────────────────────────────────
    final thisMonthExpenses = ep.forMonth(now);
    final totalExpenses = ep.totalForMonth(now);
    final expenseCount = thisMonthExpenses.length;

    // ── Budgets snapshot data ───────────────────────────────────────────────
    final Map<String, double> catSpend = {};
    for (final b in monthBills) {
      catSpend[b.category] = (catSpend[b.category] ?? 0) + (b.amount ?? 0);
    }
    final totalBudgeted =
        budgetP.budgets.fold(0.0, (acc, b) => acc + b.limit);
    final totalBudgetSpent = budgetP.budgets
        .fold(0.0, (acc, b) => acc + (catSpend[b.category] ?? 0));
    final overCount = budgetP.budgets
        .where((b) => (catSpend[b.category] ?? 0) > b.limit)
        .length;
    final shownBudgets = ([...budgetP.budgets]
          ..sort((a, b) {
            final fa =
                a.limit <= 0 ? 0.0 : (catSpend[a.category] ?? 0) / a.limit;
            final fb =
                b.limit <= 0 ? 0.0 : (catSpend[b.category] ?? 0) / b.limit;
            return fb.compareTo(fa);
          }))
        .take(2)
        .toList();

    final money = context.watch<AppSettingsProvider>().money;
    final df = DateFormat('EEE, dd MMM');
    final dayLabel = DateFormat('EEEE').format(now);
    final dateLabel = DateFormat('d MMM').format(now);
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Bill Buddy',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/settings'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.heroCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => _openNotifications(
                  ctx,
                  overdue: overdue,
                  dueToday: dueToday,
                  money: money,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.heroCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 18),
                    ),
                    if (hasAlerts)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SelectionArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            monthLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 200,
            child: PageView(
              controller: _summaryPageCtrl,
              onPageChanged: (i) => setState(() => _summaryPage = i),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _SummaryCard(
                    total: money.format(totalThisMonth),
                    paid: money.format(paidThisMonth),
                    remaining: money.format(remainingThisMonth),
                    progress: progress,
                    onViewBills: widget.onNavigateToBills,
                  ),
                ),
                _BillCalendarCard(bills: p.bills),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageDot(active: _summaryPage == 0),
              const SizedBox(width: 6),
              _PageDot(active: _summaryPage == 1),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/add-bill'),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add Bill',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heroCard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Dues snapshot ─────────────────────────────────────────────────
          _DuesSnapshotCard(
            toReceive: toReceive,
            iOwe: iOwe,
            people: duesPeople,
            totalPeople: duesPeopleTotal,
            money: money,
            onTap: widget.onNavigateToDues,
          ),

          const SizedBox(height: 20),

          // ── Expenses snapshot ──────────────────────────────────────────────
          _ExpensesSnapshotCard(
            total: totalExpenses,
            count: expenseCount,
            money: money,
            onTap: widget.onNavigateToExpenses,
          ),

          const SizedBox(height: 20),

          // ── Budgets snapshot ───────────────────────────────────────────────
          _BudgetsSnapshotCard(
            totalBudgeted: totalBudgeted,
            totalSpent: totalBudgetSpent,
            overCount: overCount,
            budgets: shownBudgets,
            catSpend: catSpend,
            money: money,
            hasBudgets: budgetP.budgets.isNotEmpty,
            onTap: widget.onNavigateToBudgets,
          ),

          const SizedBox(height: 20),

          // ── Overdue section ───────────────────────────────────────────────
          if (overdue.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overdue',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _red),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${overdue.length} ${overdue.length == 1 ? 'bill' : 'bills'}',
                    style: const TextStyle(fontSize: 11, color: _red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...overdue.map((b) => _BillCard(
                  bill: b,
                  dateText: df.format(b.dueDate),
                  amountText:
                      b.amount == null ? '' : money.format(b.amount),
                  isToday: false,
                  isOverdue: true,
                  onTap: () => Navigator.pushNamed(context, '/add-bill',
                      arguments: b),
                  onMarkPaid: () {
                    if (b.amount != null) {
                      showAppToast(context, 'Added to Expenses',
                          icon: Icons.receipt_long_rounded);
                    }
                    context.read<BillsProvider>().setPaid(b.id, true);
                  },
                )),
          ],
        ],
      )),
    );
  }
}

// ── Dues Snapshot Card ────────────────────────────────────────────────────────

class _DuesSnapshotCard extends StatelessWidget {
  final double toReceive;
  final double iOwe;
  final List<String> people;
  final int totalPeople;
  final NumberFormat money;
  final VoidCallback onTap;

  const _DuesSnapshotCard({
    required this.toReceive,
    required this.iOwe,
    required this.people,
    required this.totalPeople,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasActivity = toReceive > 0 || iOwe > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dues',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary),
                ),
                Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: _primary),
                  ],
                ),
              ],
            ),

            if (!hasActivity) ...[
              const SizedBox(height: 10),
              const Text(
                'No active dues',
                style: TextStyle(fontSize: 13, color: _textTertiary),
              ),
            ] else ...[
              const SizedBox(height: 12),

              // ── Two stat chips ───────────────────────────────────────
              Row(
                children: [
                  if (toReceive > 0)
                    Expanded(
                      child: _DuesChip(
                        label: 'To Receive',
                        amount: money.format(toReceive),
                        color: _green,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  if (toReceive > 0 && iOwe > 0) const SizedBox(width: 10),
                  if (iOwe > 0)
                    Expanded(
                      child: _DuesChip(
                        label: 'You Owe',
                        amount: money.format(iOwe),
                        color: _red,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                ],
              ),

              // ── People names ─────────────────────────────────────────
              if (people.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined,
                        size: 13, color: _textTertiary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _peopleLabel(people, totalPeople),
                        style: const TextStyle(
                            fontSize: 12, color: _textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _peopleLabel(List<String> names, int total) {
    final shown = names.map((n) => n.split(' ').first).join(' · ');
    final extra = total - names.length;
    return extra > 0 ? '$shown · +$extra more' : shown;
  }
}

class _DuesChip extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _DuesChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(amount,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budgets Snapshot Card ─────────────────────────────────────────────────────

class _BudgetsSnapshotCard extends StatelessWidget {
  final double totalBudgeted;
  final double totalSpent;
  final int overCount;
  final List<BudgetModel> budgets;
  final Map<String, double> catSpend;
  final NumberFormat money;
  final bool hasBudgets;
  final VoidCallback onTap;

  const _BudgetsSnapshotCard({
    required this.totalBudgeted,
    required this.totalSpent,
    required this.overCount,
    required this.budgets,
    required this.catSpend,
    required this.money,
    required this.hasBudgets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalBudgeted <= 0
        ? 0.0
        : (totalSpent / totalBudgeted).clamp(0.0, 1.0);
    final isOver = overCount > 0;
    final isWarn = !isOver && progress >= 0.75;
    final statusColor = isOver ? _red : isWarn ? _primary : _green;
    final statusLabel = isOver
        ? '$overCount ${overCount == 1 ? 'category' : 'categories'} over budget'
        : isWarn
            ? 'Approaching limit'
            : 'On track';
    final statusIcon = isOver
        ? Icons.warning_amber_rounded
        : isWarn
            ? Icons.trending_up_rounded
            : Icons.check_circle_outline_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isOver ? _red.withValues(alpha: 0.3) : _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Budgets',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary),
                ),
                Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: _primary),
                  ],
                ),
              ],
            ),

            if (!hasBudgets) ...[
              const SizedBox(height: 10),
              const Text(
                'No budgets set',
                style: TextStyle(fontSize: 13, color: _textTertiary),
              ),
            ] else ...[
              const SizedBox(height: 12),

              // ── Overall progress bar ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Status row ────────────────────────────────────────────
              Row(
                children: [
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${money.format(totalSpent)} of ${money.format(totalBudgeted)}',
                    style: const TextStyle(
                        fontSize: 11, color: _textTertiary),
                  ),
                ],
              ),

              // ── Top category rows ─────────────────────────────────────
              if (budgets.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 10),
                ...budgets.map((b) => _BudgetCategoryRow(
                      budget: b,
                      spent: catSpend[b.category] ?? 0,
                      money: money,
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetCategoryRow extends StatelessWidget {
  final BudgetModel budget;
  final double spent;
  final NumberFormat money;

  const _BudgetCategoryRow({
    required this.budget,
    required this.spent,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        budget.limit <= 0 ? 0.0 : (spent / budget.limit).clamp(0.0, 1.0);
    final isOver = spent > budget.limit;
    final isWarn = !isOver && fraction >= 0.75;
    final barColor = isOver ? _red : isWarn ? _primary : _green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CategoryLogo(category: budget.category, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _catLabel(budget.category),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '${money.format(spent)} / ${money.format(budget.limit)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOver ? _red : _textSecondary,
                        fontWeight:
                            isOver ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEDE6DC),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
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

// ── Notifications Sheet ───────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final List<BillModel> overdue;
  final List<BillModel> dueToday;
  final NumberFormat money;

  const _NotificationsSheet({
    required this.overdue,
    required this.dueToday,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    // Combine: overdue first, then due-today
    final items = [
      ...overdue.map((b) => (b, 'Overdue', _red)),
      ...dueToday.map((b) => (b, 'Due Today', _primary)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.notifications_off_outlined,
                      color: _textTertiary, size: 32),
                  SizedBox(height: 12),
                  Text('No new notifications',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary)),
                  SizedBox(height: 4),
                  Text("You're all caught up",
                      style: TextStyle(fontSize: 12, color: _textTertiary)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: _border, height: 1),
                itemBuilder: (ctx, i) {
                  final (bill, label, color) = items[i];
                  return _NotifItem(
                    bill: bill,
                    label: label,
                    color: color,
                    amountText: bill.amount != null
                        ? money.format(bill.amount)
                        : '',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(ctx, '/add-bill', arguments: bill);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Notification Item ─────────────────────────────────────────────────────────

class _NotifItem extends StatelessWidget {
  final BillModel bill;
  final String label;
  final Color color;
  final String amountText;
  final VoidCallback onTap;

  const _NotifItem({
    required this.bill,
    required this.label,
    required this.color,
    required this.amountText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_long_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy').format(bill.dueDate),
                    style: const TextStyle(
                        fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amountText.isNotEmpty)
                  Text(
                    amountText,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary),
                  ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String total;
  final String paid;
  final String remaining;
  final double progress;
  final VoidCallback onViewBills;

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.remaining,
    required this.progress,
    required this.onViewBills,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.heroCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MONTHLY TOTAL',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${(progress * 100).toStringAsFixed(0)}% PAID',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(total,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Paid', value: paid)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Remaining', value: remaining)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onViewBills,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('View Bills',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: Colors.white38),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white38,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}


// ── Page Dot ──────────────────────────────────────────────────────────────────

class _PageDot extends StatelessWidget {
  final bool active;
  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? _primary : _border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ── Bill Calendar Card ────────────────────────────────────────────────────────

class _BillCalendarCard extends StatefulWidget {
  final List<BillModel> bills;
  const _BillCalendarCard({required this.bills});

  @override
  State<_BillCalendarCard> createState() => _BillCalendarCardState();
}

class _BillCalendarCardState extends State<_BillCalendarCard> {
  late DateTime _month;
  late final DateTime _minMonth;
  late final DateTime _maxMonth;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _minMonth = DateTime(n.year, n.month);
    _maxMonth = DateTime(n.year, n.month + 5);
    _month = _minMonth;
  }

  /// Returns a map of day → [(bill, isPaidForThisCycle)].
  /// For the current stored cycle the actual isPaid is used; for projected
  /// future cycles the entry is always marked unpaid (new cycle hasn't started).
  Map<int, List<(BillModel, bool)>> get _byDay {
    final map = <int, List<(BillModel, bool)>>{};
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd   = DateTime(_month.year, _month.month + 1, 1);

    for (final b in widget.bills) {
      DateTime d = b.dueDate;

      // If the stored due date is already past this month, skip.
      if (!d.isBefore(monthEnd)) continue;

      // Advance through cycles until we reach the target month.
      while (d.isBefore(monthStart)) {
        d = _nextDueDateCalendar(d, b.frequency);
      }

      // Include only if the projected date lands in the target month.
      if (d.year == _month.year && d.month == _month.month) {
        final isActualCycle = d.year  == b.dueDate.year  &&
                              d.month == b.dueDate.month &&
                              d.day   == b.dueDate.day;
        (map[d.day] ??= []).add((b, isActualCycle && b.isPaid));
      }
    }
    return map;
  }

  void _showDaySheet(BuildContext context, DateTime date,
      List<(BillModel, bool)> entries) {
    final money = context.read<AppSettingsProvider>().money;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayBillsSheet(date: date, entries: entries, money: money),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // weekday: Mon=1..Sun=7 → offset to Sun=0
    final startOffset = (_month.weekday % 7);
    final byDay = _byDay;

    // Build flat cell list: nulls for leading empty cells, then 1..daysInMonth
    final cells = <int?>[
      ...List.filled(startOffset, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) cells.add(null);

    // Split into rows of 7
    final rows = <List<int?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.heroCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Row(
                children: [
                  _navBtn(Icons.chevron_left_rounded,
                    _month.isAfter(_minMonth)
                        ? () => setState(() => _month = DateTime(_month.year, _month.month - 1))
                        : null),
                  const SizedBox(width: 2),
                  _navBtn(Icons.chevron_right_rounded,
                    _month.isBefore(_maxMonth)
                        ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                        : null),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          // ── Day-of-week headers ───────────────────────────────────────────
          Row(
            children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 3),
          // ── Calendar rows ─────────────────────────────────────────────────
          ...rows.map((row) => Expanded(
            child: Row(
              children: row.map((day) {
                if (day == null) return const Expanded(child: SizedBox());
                final date = DateTime(_month.year, _month.month, day);
                final isToday = date == today;
                final isPast = date.isBefore(today);
                final dayEntries = byDay[day] ?? [];
                final hasUnpaid = dayEntries.any((e) => !e.$2);
                final hasPaid   = dayEntries.any((e) =>  e.$2);

                return Expanded(
                  child: GestureDetector(
                    onTap: dayEntries.isEmpty ? null
                        : () => _showDaySheet(context, date, dayEntries),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: isToday
                              ? const BoxDecoration(
                                  color: _primary, shape: BoxShape.circle)
                              : null,
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isToday
                                  ? Colors.white
                                  : isPast
                                      ? Colors.white30
                                      : Colors.white70,
                            ),
                          ),
                        ),
                        if (hasUnpaid || hasPaid)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasUnpaid) _dot(_primary),
                                if (hasUnpaid && hasPaid)
                                  const SizedBox(width: 2),
                                if (hasPaid) _dot(_green),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          )),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Icon(icon, size: 16,
          color: onTap != null ? Colors.white54 : Colors.white24),
    ),
  );

  Widget _dot(Color color) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Day Bills Sheet ───────────────────────────────────────────────────────────

class _DayBillsSheet extends StatelessWidget {
  final DateTime date;
  final List<(BillModel, bool)> entries;
  final NumberFormat money;

  const _DayBillsSheet({
    required this.date,
    required this.entries,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('EEEE, d MMMM').format(date),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map((entry) {
            final (b, isPaid) = entry;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CategoryLogo(category: b.category, size: 36, billName: b.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        if (b.amount != null)
                          Text(money.format(b.amount),
                              style: const TextStyle(
                                  fontSize: 12, color: _textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? _green.withValues(alpha: 0.1)
                          : _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Unpaid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPaid ? _green : _primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final String dateText;
  final String amountText;
  final bool isToday;
  final bool isOverdue;
  final VoidCallback onMarkPaid;
  final VoidCallback onTap;

  const _BillCard({
    required this.bill,
    required this.dateText,
    required this.amountText,
    required this.isToday,
    this.isOverdue = false,
    required this.onMarkPaid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isToday || isOverdue) ? _red.withValues(alpha: 0.3) : _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CategoryLogo(category: bill.category, size: 38, billName: bill.name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(bill.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isOverdue || isToday)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isOverdue ? 'Overdue' : 'Due Today',
                            style: const TextStyle(
                                fontSize: 10,
                                color: _red,
                                fontWeight: FontWeight.w600)),
                      ),
                    Expanded(
                      child: Text('${_capitalize(bill.category)} · $dateText',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: _textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (amountText.isNotEmpty)
                Text(amountText,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onMarkPaid,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Mark Paid',
                      style: TextStyle(
                          fontSize: 11,
                          color: _green,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Expenses Snapshot Card ────────────────────────────────────────────────────

class _ExpensesSnapshotCard extends StatelessWidget {
  final double total;
  final int count;
  final NumberFormat money;
  final VoidCallback onTap;

  const _ExpensesSnapshotCard({
    required this.total,
    required this.count,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wallet_rounded, color: _textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expenses',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'No expenses this month'
                        : '$count ${count == 1 ? 'expense' : 'expenses'} this month',
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count == 0 ? '—' : money.format(total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: count == 0 ? _textTertiary : _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: _textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
