import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/due_model.dart';
import '../state/app_settings_provider.dart';
import '../state/dues_provider.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

// ── Screen ─────────────────────────────────────────────────────────────────────

class DueAnalyticsScreen extends StatefulWidget {
  const DueAnalyticsScreen({super.key});

  @override
  State<DueAnalyticsScreen> createState() => _DueAnalyticsScreenState();
}

class _DueAnalyticsScreenState extends State<DueAnalyticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final p = context.watch<DuesProvider>();
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);
    final money = context.watch<AppSettingsProvider>().money;

    final monthDues = p.dues
        .where((d) =>
            !d.date.isBefore(_month) && d.date.isBefore(monthEnd))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final activeDues = monthDues.where((d) => !d.isSettled).toList();
    final settledDues = monthDues.where((d) => d.isSettled).toList();

    double sumAmount(Iterable<DueModel> dues) =>
        dues.fold(0.0, (acc, d) => acc + d.amount);

    final totalLent = sumAmount(activeDues.where((d) => d.type == 'lent'));
    final totalBorrowed = sumAmount(activeDues.where((d) => d.type == 'borrowed'));
    final netAmount = totalLent - totalBorrowed;

    final settledLent = sumAmount(settledDues.where((d) => d.type == 'lent'));
    final settledBorrowed = sumAmount(settledDues.where((d) => d.type == 'borrowed'));

    // Group by person for analytics
    final Map<String, List<DueModel>> personGroups = {};
    for (final due in monthDues) {
      personGroups.putIfAbsent(due.personName, () => []).add(due);
    }

    final overdueCount = activeDues.where((d) =>
        d.dueDate != null && d.dueDate!.isBefore(DateTime.now())
    ).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: const Text(
          'Due Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _textSecondary),
            onPressed: () => _exportDues(context, monthDues),
            tooltip: 'Export Dues',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: _textSecondary,
          indicatorColor: _primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'People'),
          ],
        ),
      ),
      body: p.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _MonthPicker(
                    label: DateFormat('MMMM yyyy').format(_month),
                    onPrev: _prev,
                    onNext: _isCurrent ? null : _next,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OverviewTab(
                        monthDues: monthDues,
                        activeDues: activeDues,
                        settledDues: settledDues,
                        totalLent: totalLent,
                        totalBorrowed: totalBorrowed,
                        netAmount: netAmount,
                        settledLent: settledLent,
                        settledBorrowed: settledBorrowed,
                        overdueCount: overdueCount,
                        money: money,
                      ),
                      _PeopleTab(
                        personGroups: personGroups,
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

// ── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<DueModel> monthDues;
  final List<DueModel> activeDues;
  final List<DueModel> settledDues;
  final double totalLent;
  final double totalBorrowed;
  final double netAmount;
  final double settledLent;
  final double settledBorrowed;
  final int overdueCount;
  final NumberFormat money;

  const _OverviewTab({
    required this.monthDues,
    required this.activeDues,
    required this.settledDues,
    required this.totalLent,
    required this.totalBorrowed,
    required this.netAmount,
    required this.settledLent,
    required this.settledBorrowed,
    required this.overdueCount,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SummaryCard(
            totalLent: money.format(totalLent),
            totalBorrowed: money.format(totalBorrowed),
            netAmount: money.format(netAmount.abs()),
            isPositive: netAmount >= 0,
            activeCount: activeDues.length,
            settledCount: settledDues.length,
            overdueCount: overdueCount,
          ),
          const SizedBox(height: 24),
          if (monthDues.isEmpty)
            _EmptyState(month: DateFormat('MMMM yyyy').format(DateTime.now()))
          else ...[
            const _SectionLabel('RECENT TRANSACTIONS'),
            const SizedBox(height: 12),
            ...monthDues.take(10).map(
              (due) => _DueRow(
                due: due,
                amountText: money.format(due.amount),
                dateText: DateFormat('d MMM').format(due.date),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── People Tab ───────────────────────────────────────────────────────────────

class _PeopleTab extends StatelessWidget {
  final Map<String, List<DueModel>> personGroups;
  final NumberFormat money;

  const _PeopleTab({
    required this.personGroups,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final sortedPeople = personGroups.entries.toList()
      ..sort((a, b) {
        final netA = a.value.fold(0.0, (s, d) => 
          d.type == 'lent' ? s + d.amount : s - d.amount);
        final netB = b.value.fold(0.0, (s, d) => 
          d.type == 'lent' ? s + d.amount : s - d.amount);
        return netB.abs().compareTo(netA.abs());
      });

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionLabel('PEOPLE SUMMARY'),
          const SizedBox(height: 12),
          ...sortedPeople.map(
            (entry) => _PersonCard(
              name: entry.key,
              dues: entry.value,
              money: money,
            ),
          ),
        ],
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

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String totalLent;
  final String totalBorrowed;
  final String netAmount;
  final bool isPositive;
  final int activeCount;
  final int settledCount;
  final int overdueCount;

  const _SummaryCard({
    required this.totalLent,
    required this.totalBorrowed,
    required this.netAmount,
    required this.isPositive,
    required this.activeCount,
    required this.settledCount,
    required this.overdueCount,
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
          const Text(
            'Monthly Summary',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            netAmount,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive ? 'You are owed' : 'You owe',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Lent',
                  value: totalLent,
                  sub: '$activeCount active',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Borrowed',
                  value: totalBorrowed,
                  sub: '$settledCount settled',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (overdueCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, 
                      color: _red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$overdueCount overdue ${overdueCount == 1 ? 'due' : 'dues'}',
                    style: const TextStyle(
                      color: _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
        color: Colors.white.withOpacity(0.18),
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

// ── Due Row ──────────────────────────────────────────────────────────────────

class _DueRow extends StatelessWidget {
  final DueModel due;
  final String amountText;
  final String dateText;

  const _DueRow({
    required this.due,
    required this.amountText,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final isLent = due.type == 'lent';
    final color = due.isSettled ? _textTertiary : (isLent ? _green : _red);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: due.isSettled ? const Color(0xFFFAFAFA) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLent
                  ? Icons.call_received_rounded
                  : Icons.call_made_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  due.description ?? (isLent ? 'Lent' : 'Borrowed'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: due.isSettled
                        ? _textTertiary
                        : _textPrimary,
                    decoration: due.isSettled
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: _textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${due.personName} · $dateText',
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: due.isSettled ? _textTertiary : color,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  due.isSettled
                      ? 'Settled'
                      : (isLent ? 'Lent' : 'Borrowed'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Person Card ───────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final String name;
  final List<DueModel> dues;
  final NumberFormat money;

  const _PersonCard({
    required this.name,
    required this.dues,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final netAmount = dues.fold(0.0, (s, d) {
      return d.type == 'lent' ? s + d.amount : s - d.amount;
    });
    
    final isPositive = netAmount >= 0;
    final color = isPositive ? _green : _red;
    final activeCount = dues.where((d) => !d.isSettled).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.substring(0, math.min(2, name.length)).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
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
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount active ${activeCount == 1 ? 'due' : 'dues'}',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(netAmount.abs()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPositive ? 'Owe Me' : 'I Owe',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
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
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              size: 36,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No dues found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No dues are recorded in $month',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Export Functionality ─────────────────────────────────────────────────────

Future<void> _exportDues(BuildContext context, List<DueModel> dues) async {
  try {
    final csvData = [
      ['Date', 'Person', 'Type', 'Amount', 'Description', 'Due Date', 'Status'],
      ...dues.map((due) => [
        DateFormat('yyyy-MM-dd').format(due.date),
        due.personName,
        due.type == 'lent' ? 'Lent' : 'Borrowed',
        due.amount.toStringAsFixed(2),
        due.description ?? '',
        due.dueDate != null ? DateFormat('yyyy-MM-dd').format(due.dueDate!) : '',
        due.isSettled ? 'Settled' : 'Active',
      ]),
    ];

    final csv = csvData
        .map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))
        .join('\n');

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'dues_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    if (!context.mounted) return;
    
    await Share.shareXFiles([XFile(file.path)], text: 'Dues Export - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}');
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _green,
        content: Text('Dues exported successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _red,
        content: Text('Export failed: $e'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
