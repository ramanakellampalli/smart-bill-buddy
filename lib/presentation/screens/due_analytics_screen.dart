import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/due_model.dart';
import '../state/app_settings_provider.dart';
import '../state/dues_provider.dart';

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
const _amber         = AppColors.amber;

// ── Aging thresholds (days) ────────────────────────────────────────────────────

const _freshDays = 30;
const _pendingDays = 90;
const _oldDays = 365;

// ── Screen ─────────────────────────────────────────────────────────────────────

class DueAnalyticsScreen extends StatefulWidget {
  const DueAnalyticsScreen({super.key});

  @override
  State<DueAnalyticsScreen> createState() => _DueAnalyticsScreenState();
}

class _DueAnalyticsScreenState extends State<DueAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DuesProvider>();
    final money = context.watch<AppSettingsProvider>().money;
    final now = DateTime.now();

    final allDues = p.dues;
    final activeDues = allDues.where((d) => !d.isSettled).toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // oldest first

    double sumActive(Iterable<DueModel> dues) =>
        dues.fold(0.0, (acc, d) => acc + d.remaining);

    final totalLent = sumActive(activeDues.where((d) => d.type == 'lent'));
    final totalBorrowed = sumActive(activeDues.where((d) => d.type == 'borrowed'));
    final netAmount = totalLent - totalBorrowed;

    // Aging buckets — based on days since the due was created
    List<DueModel> ageBucket(int minDays, int? maxDays) => activeDues.where((d) {
          final age = now.difference(d.date).inDays;
          return age >= minDays && (maxDays == null || age < maxDays);
        }).toList();

    final freshDues = ageBucket(0, _freshDays);
    final pendingDues = ageBucket(_freshDays, _pendingDays);
    final oldDues = ageBucket(_pendingDays, _oldDays);
    final veryOldDues = ageBucket(_oldDays, null);

    // Overdue — dueDate is set and has passed
    final overdueDues = activeDues
        .where((d) => d.dueDate != null && d.dueDate!.isBefore(now))
        .toList();

    // People — all-time active balance per person
    final Map<String, List<DueModel>> personGroups = {};
    for (final due in activeDues) {
      personGroups.putIfAbsent(due.personName, () => []).add(due);
    }

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
            onPressed: () => _exportDues(context, activeDues),
            tooltip: 'Export Active Dues',
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
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  activeDues: activeDues,
                  totalLent: totalLent,
                  totalBorrowed: totalBorrowed,
                  netAmount: netAmount,
                  freshDues: freshDues,
                  pendingDues: pendingDues,
                  oldDues: oldDues,
                  veryOldDues: veryOldDues,
                  overdueDues: overdueDues,
                  money: money,
                ),
                _PeopleTab(
                  personGroups: personGroups,
                  money: money,
                ),
              ],
            ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<DueModel> activeDues;
  final double totalLent;
  final double totalBorrowed;
  final double netAmount;
  final List<DueModel> freshDues;
  final List<DueModel> pendingDues;
  final List<DueModel> oldDues;
  final List<DueModel> veryOldDues;
  final List<DueModel> overdueDues;
  final NumberFormat money;

  const _OverviewTab({
    required this.activeDues,
    required this.totalLent,
    required this.totalBorrowed,
    required this.netAmount,
    required this.freshDues,
    required this.pendingDues,
    required this.oldDues,
    required this.veryOldDues,
    required this.overdueDues,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (activeDues.isEmpty) {
      return const _EmptyState();
    }

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _BalanceSummaryCard(
            totalLent: money.format(totalLent),
            totalBorrowed: money.format(totalBorrowed),
            netAmount: money.format(netAmount.abs()),
            isPositive: netAmount >= 0,
            activeCount: activeDues.length,
            overdueCount: overdueDues.length,
          ),
          const SizedBox(height: 24),
          const _SectionLabel('AGING BREAKDOWN'),
          const SizedBox(height: 12),
          _AgingBreakdown(
            freshDues: freshDues,
            pendingDues: pendingDues,
            oldDues: oldDues,
            veryOldDues: veryOldDues,
            money: money,
          ),
          if (overdueDues.isNotEmpty) ...[
            const SizedBox(height: 20),
            _OverdueBanner(count: overdueDues.length),
            const SizedBox(height: 12),
            const _SectionLabel('OVERDUE DUES'),
            const SizedBox(height: 12),
            ...overdueDues.map((due) => _DueRow(
                  due: due,
                  money: money,
                  showAge: true,
                )),
          ],
          const SizedBox(height: 20),
          const _SectionLabel('ALL ACTIVE DUES — OLDEST FIRST'),
          const SizedBox(height: 12),
          ...activeDues.map((due) => _DueRow(
                due: due,
                money: money,
                showAge: true,
              )),
        ],
      ),
    );
  }
}

// ── Balance Summary Card ───────────────────────────────────────────────────────

class _BalanceSummaryCard extends StatelessWidget {
  final String totalLent;
  final String totalBorrowed;
  final String netAmount;
  final bool isPositive;
  final int activeCount;
  final int overdueCount;

  const _BalanceSummaryCard({
    required this.totalLent,
    required this.totalBorrowed,
    required this.netAmount,
    required this.isPositive,
    required this.activeCount,
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
            'Balance Overview',
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
            isPositive ? 'Total you are owed' : 'Total you owe',
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
                child: _StatChip(label: 'Lent Out', value: totalLent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(label: 'Borrowed', value: totalBorrowed),
              ),
            ],
          ),
          if (overdueCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$overdueCount ${overdueCount == 1 ? 'due has' : 'dues have'} passed due date',
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
        ],
      ),
    );
  }

}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
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
        ],
      ),
    );
  }
}

// ── Aging Breakdown ────────────────────────────────────────────────────────────

class _AgingBreakdown extends StatelessWidget {
  final List<DueModel> freshDues;
  final List<DueModel> pendingDues;
  final List<DueModel> oldDues;
  final List<DueModel> veryOldDues;
  final NumberFormat money;

  const _AgingBreakdown({
    required this.freshDues,
    required this.pendingDues,
    required this.oldDues,
    required this.veryOldDues,
    required this.money,
  });

  double _sum(List<DueModel> dues) =>
      dues.fold(0.0, (acc, d) => acc + d.remaining);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AgingBucket(
            label: 'Fresh',
            sublabel: '< 30 days',
            count: freshDues.length,
            amount: money.format(_sum(freshDues)),
            color: _green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AgingBucket(
            label: 'Pending',
            sublabel: '30–90 days',
            count: pendingDues.length,
            amount: money.format(_sum(pendingDues)),
            color: _primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AgingBucket(
            label: 'Old',
            sublabel: '3–12 months',
            count: oldDues.length,
            amount: money.format(_sum(oldDues)),
            color: _amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AgingBucket(
            label: 'Very Old',
            sublabel: '1+ year',
            count: veryOldDues.length,
            amount: money.format(_sum(veryOldDues)),
            color: _red,
          ),
        ),
      ],
    );
  }
}

class _AgingBucket extends StatelessWidget {
  final String label;
  final String sublabel;
  final int count;
  final String amount;
  final Color color;

  const _AgingBucket({
    required this.label,
    required this.sublabel,
    required this.count,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count > 0 ? color.withOpacity(0.35) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 0 ? '—' : amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: count > 0 ? _textPrimary : _textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count == 0 ? 'none' : '$count ${count == 1 ? 'due' : 'dues'}',
            style: TextStyle(
              fontSize: 10,
              color: count > 0 ? _textSecondary : _textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 9, color: _textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Overdue Banner ─────────────────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  final int count;
  const _OverdueBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'due has' : 'dues have'} passed their due date and are still unsettled.',
              style: const TextStyle(
                fontSize: 13,
                color: _red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── People Tab ────────────────────────────────────────────────────────────────

class _PeopleTab extends StatelessWidget {
  final Map<String, List<DueModel>> personGroups;
  final NumberFormat money;

  const _PeopleTab({
    required this.personGroups,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (personGroups.isEmpty) {
      return const _EmptyState();
    }

    final sortedPeople = personGroups.entries.toList()
      ..sort((a, b) {
        final netA = a.value.fold(
            0.0, (s, d) => d.type == 'lent' ? s + d.remaining : s - d.remaining);
        final netB = b.value.fold(
            0.0, (s, d) => d.type == 'lent' ? s + d.remaining : s - d.remaining);
        return netB.abs().compareTo(netA.abs());
      });

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionLabel('ACTIVE BALANCES BY PERSON'),
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

// ── Due Row ───────────────────────────────────────────────────────────────────

class _DueRow extends StatelessWidget {
  final DueModel due;
  final NumberFormat money;
  final bool showAge;

  const _DueRow({
    required this.due,
    required this.money,
    this.showAge = false,
  });

  String _ageLabel(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days < 1) return 'today';
    if (days < 30) return '${days}d ago';
    if (days < 365) return '${(days / 30).round()}mo ago';
    return '${(days / 365).floor()}yr ${((days % 365) / 30).round()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final isLent = due.type == 'lent';
    final color = isLent ? _green : _red;
    final isOverdue =
        due.dueDate != null && due.dueDate!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? _red.withOpacity(0.4) : _border,
        ),
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
              isLent ? Icons.call_received_rounded : Icons.call_made_rounded,
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
                  due.personName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (showAge) ...[
                      Text(
                        _ageLabel(due.date),
                        style: const TextStyle(
                            fontSize: 11, color: _textSecondary),
                      ),
                      if (due.description != null &&
                          due.description!.isNotEmpty)
                        const Text(' · ',
                            style: TextStyle(
                                fontSize: 11, color: _textTertiary)),
                    ],
                    if (due.description != null && due.description!.isNotEmpty)
                      Expanded(
                        child: Text(
                          due.description!,
                          style: const TextStyle(
                              fontSize: 11, color: _textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(due.remaining),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOverdue) ...[
                    const Icon(Icons.schedule_rounded,
                        size: 10, color: _red),
                    const SizedBox(width: 3),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isLent ? 'Lent' : 'Borrowed',
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
        ],
      ),
    );
  }
}

// ── Person Card ────────────────────────────────────────────────────────────────

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
      return d.type == 'lent' ? s + d.remaining : s - d.remaining;
    });

    final isPositive = netAmount >= 0;
    final color = isPositive ? _green : _red;
    final overdueCount = dues.where((d) {
      return d.dueDate != null && d.dueDate!.isBefore(DateTime.now());
    }).length;

    // Oldest active due for context
    final oldest = dues.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
    final oldestAge = DateTime.now().difference(oldest.date).inDays;
    final ageLabel = oldestAge < 30
        ? '${oldestAge}d'
        : oldestAge < 365
            ? '${(oldestAge / 30).round()}mo'
            : '${(oldestAge / 365).floor()}yr+';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdueCount > 0 ? _red.withOpacity(0.3) : _border,
        ),
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
            width: 42,
            height: 42,
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${dues.length} ${dues.length == 1 ? 'due' : 'dues'} · oldest $ageLabel ago',
                      style: const TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                    if (overdueCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$overdueCount overdue',
                          style: const TextStyle(
                            fontSize: 10,
                            color: _red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
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
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPositive ? 'Owes Me' : 'I Owe',
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

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
              'No active dues',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All settled up! Add dues from the Dues screen to track lending and borrowing.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Export ────────────────────────────────────────────────────────────────────

Future<void> _exportDues(BuildContext context, List<DueModel> dues) async {
  try {
    final csvData = [
      ['Person', 'Type', 'Amount', 'Remaining', 'Description', 'Date', 'Due Date', 'Age (days)'],
      ...dues.map((due) {
        final age = DateTime.now().difference(due.date).inDays;
        return [
          due.personName,
          due.type == 'lent' ? 'Lent' : 'Borrowed',
          due.amount.toStringAsFixed(2),
          due.remaining.toStringAsFixed(2),
          due.description ?? '',
          DateFormat('yyyy-MM-dd').format(due.date),
          due.dueDate != null ? DateFormat('yyyy-MM-dd').format(due.dueDate!) : '',
          age.toString(),
        ];
      }),
    ];

    final csv = csvData
        .map((row) =>
            row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))
        .join('\n');

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'dues_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    if (!context.mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Active Dues Export — ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
    );

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
