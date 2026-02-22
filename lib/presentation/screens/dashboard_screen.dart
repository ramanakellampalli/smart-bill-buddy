import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
import '../widgets/category_logo.dart';
import '../../data/models/bill_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _surface2 = Color(0xFFFDF5ED);
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);


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
  const DashboardScreen({super.key});

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
      backgroundColor: _card,
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final next7 = now.add(const Duration(days: 7));

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

    final upcoming = p.bills
        .where((b) =>
            !b.isPaid &&
            !b.dueDate.isBefore(today.subtract(const Duration(seconds: 1))) &&
            !b.dueDate.isAfter(next7))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
        centerTitle: true,
        leadingWidth: 48,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: _textSecondary, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _showWelcome ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: _showWelcome
                    ? const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          height: 1.2,
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),
            Text(
              '$dayLabel, $dateLabel',
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: _textSecondary, size: 22),
                  if (hasAlerts)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Notifications',
              onPressed: () => _openNotifications(
                ctx,
                overdue: overdue,
                dueToday: dueToday,
                money: money,
              ),
            ),
          ),
          const SizedBox(width: 4),
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
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

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
                    color: _red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${overdue.length} ${overdue.length == 1 ? 'bill' : 'bills'}',
                    style:
                        const TextStyle(fontSize: 11, color: _red),
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
                  onMarkPaid: () =>
                      context.read<BillsProvider>().setPaid(b.id, true),
                )),
            const SizedBox(height: 24),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Bills',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Next 7 days',
                    style: TextStyle(fontSize: 11, color: _textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (p.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.error!,
                        style: const TextStyle(color: _red, fontSize: 13)),
                  ),
                ],
              ),
            ),

          if (upcoming.isEmpty)
            const _EmptyState()
          else
            ...upcoming.map((b) => _BillCard(
                  bill: b,
                  dateText: df.format(b.dueDate),
                  amountText: b.amount == null ? '' : money.format(b.amount),
                  isToday: _isSameDay(b.dueDate, now),
                  onTap: () => Navigator.pushNamed(context, '/add-bill',
                      arguments: b),
                  onMarkPaid: () =>
                      context.read<BillsProvider>().setPaid(b.id, true),
                )),
        ],
      )),
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
                    color: _red.withOpacity(0.10),
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
                color: color.withOpacity(0.10),
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
                    color: color.withOpacity(0.10),
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

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF292524), Color(0xFF57534E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C1917).withOpacity(0.22),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Monthly Total',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
              Text('${(progress * 100).toStringAsFixed(0)}% paid',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(total,
              style: const TextStyle(
                  fontSize: 28,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: _green, size: 34),
          SizedBox(height: 14),
          Text('All clear!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          SizedBox(height: 6),
          Text('No bills due in the next 7 days 🎉',
              style: TextStyle(fontSize: 13, color: _textSecondary),
              textAlign: TextAlign.center),
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
      backgroundColor: _card,
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
                          ? _green.withOpacity(0.1)
                          : _primary.withOpacity(0.1),
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
            color: (isToday || isOverdue) ? _red.withOpacity(0.3) : _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                          color: _red.withOpacity(0.10),
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
                    color: _green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.3)),
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
