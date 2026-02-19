import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showWelcome = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationsSheet(),
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

    final upcoming = p.bills
        .where((b) =>
            !b.isPaid &&
            !b.dueDate.isBefore(today.subtract(const Duration(seconds: 1))) &&
            !b.dueDate.isAfter(next7))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
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
              icon: const Icon(Icons.notifications_outlined,
                  color: _textSecondary, size: 22),
              tooltip: 'Notifications',
              onPressed: () => _openNotifications(ctx),
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

          _SummaryCard(
            total: money.format(totalThisMonth),
            paid: money.format(paidThisMonth),
            remaining: money.format(remainingThisMonth),
            progress: progress,
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
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Text('Notifications',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
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
          ),
          const SizedBox(height: 8),
        ],
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
            color: Color(0xFF1C1917).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Total',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(total,
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Paid', value: paid)),
              const SizedBox(width: 10),
              Expanded(child: _StatChip(label: 'Remaining', value: remaining)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paid so far',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
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
        color: Colors.white.withOpacity(0.18),
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

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final String dateText;
  final String amountText;
  final bool isToday;
  final VoidCallback onMarkPaid;
  final VoidCallback onTap;

  const _BillCard({
    required this.bill,
    required this.dateText,
    required this.amountText,
    required this.isToday,
    required this.onMarkPaid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isToday ? _red.withOpacity(0.3) : _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CategoryLogo(category: bill.category, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Due Today',
                            style: TextStyle(
                                fontSize: 10,
                                color: _red,
                                fontWeight: FontWeight.w600)),
                      ),
                    Text('${_capitalize(bill.category)} · $dateText',
                        style: const TextStyle(
                            fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amountText.isNotEmpty)
                Text(amountText,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onMarkPaid,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
