import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/due_model.dart';
import '../state/app_settings_provider.dart';
import '../state/dues_provider.dart';
import 'person_dues_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

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

// ── Avatar helpers ─────────────────────────────────────────────────────────────

// Each pair: [gradientStart, gradientEnd] — matches profile screen style
const _avatarGradients = [
  [Color(0xFF6C8EBF), Color(0xFF3A5A8C)],
  [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  [Color(0xFF10B981), Color(0xFF047857)],
  [Color(0xFFEF4444), Color(0xFFB91C1C)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  [Color(0xFFEC4899), Color(0xFFBE185D)],
  [Color(0xFF14B8A6), Color(0xFF0F766E)],
];

List<Color> _avatarGradient(String name) =>
    _avatarGradients[name.hashCode.abs() % _avatarGradients.length];

Color _avatarColor(String name) => _avatarGradient(name)[0];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, min(2, name.length)).toUpperCase();
}

// ── Filter ─────────────────────────────────────────────────────────────────────

enum _Filter { all, oweMe, iOwe }

// ── Screen ─────────────────────────────────────────────────────────────────────

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  _Filter _filter = _Filter.all;
  bool _showSettled = false;
  late final PageController _analyticsPageCtrl;
  int _analyticsPage = 0;

  @override
  void initState() {
    super.initState();
    _analyticsPageCtrl = PageController();
  }

  @override
  void dispose() {
    _analyticsPageCtrl.dispose();
    super.dispose();
  }

  void _openAddSheet(BuildContext context, {String? personName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDueSheet(initialPersonName: personName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DuesProvider>();
    final money = context.watch<AppSettingsProvider>().money;

    // ── Compute totals ─────────────────────────────────────────────────────────
    final active = p.dues.where((d) => !d.isSettled).toList();
    final settled = p.dues.where((d) => d.isSettled).toList();

    final toReceive =
        active.where((d) => d.type == 'lent').fold(0.0, (s, d) => s + d.remaining);
    final iOwe = active
        .where((d) => d.type == 'borrowed')
        .fold(0.0, (s, d) => s + d.remaining);
    final net = toReceive - iOwe;

    // ── Filter active dues ─────────────────────────────────────────────────────
    final filtered = active.where((d) {
      if (_filter == _Filter.oweMe) return d.type == 'lent';
      if (_filter == _Filter.iOwe) return d.type == 'borrowed';
      return true;
    }).toList();

    // ── Group by person name ───────────────────────────────────────────────────
    final Map<String, List<DueModel>> grouped = {};
    for (final d in filtered) {
      grouped.putIfAbsent(d.personName, () => []).add(d);
    }
    final people = grouped.keys.toList()..sort();

    // ── Group settled by person ────────────────────────────────────────────────
    final Map<String, List<DueModel>> settledGrouped = {};
    for (final d in settled) {
      settledGrouped.putIfAbsent(d.personName, () => []).add(d);
    }
    final settledPeople = settledGrouped.keys.toList()..sort();

    // ── Counts for pills ───────────────────────────────────────────────────────
    final allCount = active.length;
    final oweMeCount = active.where((d) => d.type == 'lent').length;
    final iOweCount = active.where((d) => d.type == 'borrowed').length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Dues',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _primary, size: 24),
            tooltip: 'Add Due',
            onPressed: () => _openAddSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: p.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _primary))
          : Column(
              children: [
                // ── Carousel (outside SelectionArea to avoid layout assertion) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 172,
                        child: PageView(
                          controller: _analyticsPageCtrl,
                          onPageChanged: (i) =>
                              setState(() => _analyticsPage = i),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _SummaryCard(
                                net: net,
                                toReceive: toReceive,
                                iOwe: iOwe,
                                toReceiveCount: active
                                    .where((d) => d.type == 'lent')
                                    .length,
                                iOweCount: active
                                    .where((d) => d.type == 'borrowed')
                                    .length,
                                money: money,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _DuesAnalyticsCard(
                                totalDues: active.length,
                                totalAmount: toReceive + iOwe,
                                overdueCount: active
                                    .where((d) =>
                                        d.dueDate != null &&
                                        d.dueDate!.isBefore(DateTime.now()))
                                    .length,
                                money: money,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _PeopleAnalyticsCard(
                                peopleCount: grouped.keys.length,
                                avgPerPerson: grouped.keys.isNotEmpty
                                    ? (toReceive + iOwe) / grouped.keys.length
                                    : 0.0,
                                highestDebtor: _getHighestDebtor(grouped),
                                highestCreditor: _getHighestCreditor(grouped),
                                money: money,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PageDot(active: _analyticsPage == 0),
                          const SizedBox(width: 6),
                          _PageDot(active: _analyticsPage == 1),
                          const SizedBox(width: 6),
                          _PageDot(active: _analyticsPage == 2),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── Scrollable list ───────────────────────────────────────────
                Expanded(
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        // ── Filter pills ───────────────────────────────────────
                        Row(
                          children: [
                            _FilterPill(
                              label: 'All',
                              count: allCount,
                              selected: _filter == _Filter.all,
                              onTap: () =>
                                  setState(() => _filter = _Filter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'Owe Me',
                              count: oweMeCount,
                              selected: _filter == _Filter.oweMe,
                              color: _green,
                              onTap: () =>
                                  setState(() => _filter = _Filter.oweMe),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'I Owe',
                              count: iOweCount,
                              selected: _filter == _Filter.iOwe,
                              color: _red,
                              onTap: () =>
                                  setState(() => _filter = _Filter.iOwe),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Active person cards ───────────────────────────────
                        if (people.isEmpty)
                          _EmptyState(filter: _filter)
                        else
                          ...people.map((name) {
                            final txns = grouped[name]!;
                            final netForPerson = txns.fold(0.0, (s, d) {
                              return d.type == 'lent'
                                  ? s + d.remaining
                                  : s - d.remaining;
                            });
                            return _PersonCard(
                              name: name,
                              transactions: txns,
                              net: netForPerson,
                              money: money,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PersonDuesScreen(
                                    personName: name,
                                    onAddTap: () => _openAddSheet(context,
                                        personName: name),
                                  ),
                                ),
                              ),
                            );
                          }),

                        // ── Settled history ───────────────────────────────────
                        if (settled.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SettledHeader(
                            count: settled.length,
                            isOpen: _showSettled,
                            onToggle: () =>
                                setState(() => _showSettled = !_showSettled),
                          ),
                          if (_showSettled) ...[
                            const SizedBox(height: 10),
                            ...settledPeople.map((name) {
                              final txns = settledGrouped[name]!;
                              final netForPerson = txns.fold(0.0, (s, d) {
                                return d.type == 'lent'
                                    ? s + d.amount
                                    : s - d.amount;
                              });
                              return _PersonCard(
                                name: name,
                                transactions: txns,
                                net: netForPerson,
                                money: money,
                                isSettled: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDuesScreen(
                                      personName: name,
                                      onAddTap: () => _openAddSheet(context,
                                          personName: name),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────────
// Visual: proportional split-bar showing lent vs borrowed ratio

class _SummaryCard extends StatelessWidget {
  final double net;
  final double toReceive;
  final double iOwe;
  final int toReceiveCount;
  final int iOweCount;
  final NumberFormat money;

  const _SummaryCard({
    required this.net,
    required this.toReceive,
    required this.iOwe,
    required this.toReceiveCount,
    required this.iOweCount,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final netColor =
        isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5);
    final total = toReceive + iOwe;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.55),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient glow circle behind the number
            Positioned(
              top: -45,
              right: -45,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: netColor.withOpacity(0.07),
                ),
              ),
            ),
            // Positioned.fill gives the Column tight constraints so Spacer works
            Positioned.fill(
              child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: _primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NET BALANCE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: netColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: netColor.withOpacity(0.35), width: 1),
                        ),
                        child: Text(
                          isPositive ? '▲ ahead' : '▼ behind',
                          style: TextStyle(
                            fontSize: 10,
                            color: netColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Hero amount ──────────────────────────────────────────
                  Text(
                    money.format(net.abs()),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: netColor,
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    isPositive ? 'overall in your favor' : 'you owe net',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),

                  const Spacer(),

                  // ── Proportional split bar ───────────────────────────────
                  if (total > 0) ...[
                    LayoutBuilder(
                      builder: (_, c) => SizedBox(
                        height: 7,
                        width: c.maxWidth,
                        child: CustomPaint(
                          painter: _SplitBarPainter(
                              lent: toReceive, borrowed: iOwe),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Labels below bar ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BarLabel(
                        color: const Color(0xFF4ADE80),
                        amount: money.format(toReceive),
                        count: toReceiveCount,
                        label: 'To Receive',
                      ),
                      _BarLabel(
                        color: const Color(0xFFFCA5A5),
                        amount: money.format(iOwe),
                        count: iOweCount,
                        label: 'I Owe',
                        alignRight: true,
                      ),
                    ],
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

class _BarLabel extends StatelessWidget {
  final Color color;
  final String amount;
  final int count;
  final String label;
  final bool alignRight;

  const _BarLabel({
    required this.color,
    required this.amount,
    required this.count,
    required this.label,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
    final amtText = Text(
      amount,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: color),
    );
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: alignRight
              ? [amtText, const SizedBox(width: 5), dot]
              : [dot, const SizedBox(width: 5), amtText],
        ),
        const SizedBox(height: 2),
        Text(
          '$count ${count == 1 ? 'txn' : 'txns'} · $label',
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}

// ── Filter Pill ────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.10) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? accent : _textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withOpacity(0.15)
                    : const Color(0xFFF0EDE9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : _textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Person Card ────────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final String name;
  final List<DueModel> transactions;
  final double net;
  final NumberFormat money;
  final bool isSettled;
  final VoidCallback onTap;

  const _PersonCard({
    required this.name,
    required this.transactions,
    required this.net,
    required this.money,
    this.isSettled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositiveNet = net >= 0;
    final accentColor =
        isSettled ? _textTertiary : (isPositiveNet ? _green : _red);
    final avatarColor = isSettled ? _textTertiary : _avatarColor(name);
    final gradient = _avatarGradient(name);

    // Last transaction description
    final lastDesc = transactions.isNotEmpty
        ? (transactions.first.description ?? '')
        : '';

    // Count of lent vs borrowed
    final lentCount = transactions.where((d) => d.type == 'lent').length;
    final borrowedCount =
        transactions.where((d) => d.type == 'borrowed').length;

    String subText;
    if (lentCount > 0 && borrowedCount > 0) {
      subText = '$lentCount lent · $borrowedCount borrowed';
    } else if (lentCount > 0) {
      subText =
          '$lentCount ${lentCount == 1 ? 'transaction' : 'transactions'}';
    } else {
      subText =
          '$borrowedCount ${borrowedCount == 1 ? 'transaction' : 'transactions'}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: isSettled
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(width: 4, color: accentColor),
                // Card content
                Expanded(
                  child: Container(
                    color: isSettled ? const Color(0xFFFAFAFA) : _card,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: isSettled
                      ? null
                      : LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isSettled ? _textTertiary.withOpacity(0.15) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSettled ? _textTertiary : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSettled ? _textTertiary : _textPrimary,
                        decoration: isSettled
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: _textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText +
                          (lastDesc.isNotEmpty ? ' · $lastDesc' : ''),
                      style: const TextStyle(
                          fontSize: 11, color: _textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Net amount + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    money.format(net.abs()),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSettled ? _textTertiary : accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSettled
                          ? 'Settled'
                          : (isPositiveNet ? 'Owe Me' : 'I Owe'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: _textTertiary),
            ],
          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settled Header ─────────────────────────────────────────────────────────────

class _SettledHeader extends StatelessWidget {
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;

  const _SettledHeader({
    required this.count,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Container(
                  height: 1, color: _border),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: _textTertiary),
                  const SizedBox(width: 5),
                  Text(
                    'Settled ($count)',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: _textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 1, color: _border),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (filter) {
      _Filter.oweMe => (
          Icons.call_received_rounded,
          'No one owes you',
          'Add a due when someone borrows from you'
        ),
      _Filter.iOwe => (
          Icons.call_made_rounded,
          'You owe nothing',
          'Add a due when you borrow from someone'
        ),
      _ => (
          Icons.people_alt_outlined,
          'No active dues',
          'Track money you lend or borrow'
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(fontSize: 13, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Add Due Sheet ──────────────────────────────────────────────────────────────

class _AddDueSheet extends StatefulWidget {
  final String? initialPersonName;
  const _AddDueSheet({this.initialPersonName});

  @override
  State<_AddDueSheet> createState() => _AddDueSheetState();
}

class _AddDueSheetState extends State<_AddDueSheet> {
  final _formKey = GlobalKey<FormState>();
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'lent'; // 'lent' | 'borrowed'
  DateTime _date = DateTime.now();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialPersonName != null) {
      _personCtrl.text = widget.initialPersonName!;
    }
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool isDueDate = false}) async {
    final now = DateTime.now();
    final initial = isDueDate ? (_dueDate ?? now) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isDueDate) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final due = DueModel(
      id: const Uuid().v4(),
      personName: _personCtrl.text.trim(),
      amount: amount,
      type: _type,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      date: _date,
      dueDate: _dueDate,
    );
    final provider = context.read<DuesProvider>();
    await provider.add(due);
    if (!mounted) return;
    if (provider.error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<DuesProvider>().saving;
    final df = DateFormat('d MMM yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 18),

            // Title
            const Text(
              'Add Due',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
            ),
            const SizedBox(height: 20),

            // Type toggle ── They owe me / I owe them
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _TypeToggleBtn(
                    label: 'They owe me',
                    icon: Icons.call_received_rounded,
                    selected: _type == 'lent',
                    color: _green,
                    onTap: () => setState(() => _type = 'lent'),
                  ),
                  _TypeToggleBtn(
                    label: 'I owe them',
                    icon: Icons.call_made_rounded,
                    selected: _type == 'borrowed',
                    color: _red,
                    onTap: () => setState(() => _type = 'borrowed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Person name
            TextFormField(
              controller: _personCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              decoration: _inputDecoration(
                  hint: 'Person name (e.g. Rahul)',
                  icon: Icons.person_outline_rounded),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Enter a name';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              decoration: _inputDecoration(
                  hint: 'Amount', icon: Icons.currency_rupee_rounded),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter an amount';
                final n = double.tryParse(t);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              decoration: _inputDecoration(
                  hint: 'Description (optional)',
                  icon: Icons.notes_rounded),
            ),
            const SizedBox(height: 12),

            // Date row
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Date',
                    value: df.format(_date),
                    onTap: () => _pickDate(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: _dueDate != null
                        ? 'Due: ${df.format(_dueDate!)}'
                        : 'Due date (opt.)',
                    value: '',
                    isEmpty: _dueDate == null,
                    onTap: () => _pickDate(isDueDate: true),
                    onClear: _dueDate != null
                        ? () => setState(() => _dueDate = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'lent' ? _green : _red,
                  disabledBackgroundColor:
                      (_type == 'lent' ? _green : _red).withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        _type == 'lent'
                            ? 'They Owe Me'
                            : 'I Owe Them',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textTertiary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textTertiary, size: 18),
      filled: true,
      fillColor: const Color(0xFFFDF5ED),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5)),
      errorStyle: const TextStyle(color: _red, fontSize: 12),
    );
  }
}

class _TypeToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: color.withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? color : _textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmpty;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
    required this.label,
    required this.value,
    this.isEmpty = false,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 15,
                color: isEmpty ? _textTertiary : _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmpty ? label : (value.isEmpty ? label : value),
                style: TextStyle(
                  fontSize: 13,
                  color: isEmpty ? _textTertiary : _textPrimary,
                  fontWeight:
                      isEmpty ? FontWeight.w400 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: _textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Methods ─────────────────────────────────────────────────────────────

String? _getHighestDebtor(Map<String, List<DueModel>> grouped) {
  String? highestDebtor;
  double highestAmount = 0.0;
  
  for (final entry in grouped.entries) {
    final netAmount = entry.value.fold(0.0, (s, d) {
      return d.type == 'borrowed' ? s + d.amount : s - d.amount;
    });
    
    if (netAmount > highestAmount) {
      highestAmount = netAmount;
      highestDebtor = entry.key;
    }
  }
  
  return highestDebtor;
}

String? _getHighestCreditor(Map<String, List<DueModel>> grouped) {
  String? highestCreditor;
  double highestAmount = 0.0;
  
  for (final entry in grouped.entries) {
    final netAmount = entry.value.fold(0.0, (s, d) {
      return d.type == 'lent' ? s + d.amount : s - d.amount;
    });
    
    if (netAmount > highestAmount) {
      highestAmount = netAmount;
      highestCreditor = entry.key;
    }
  }
  
  return highestCreditor;
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

// ── People Analytics Card ───────────────────────────────────────────────────────
// Visual: two highlighted person tiles (highest creditor / highest debtor)
// Palette: warm amber/rust

class _PeopleAnalyticsCard extends StatelessWidget {
  final int peopleCount;
  final double avgPerPerson;
  final String? highestDebtor;
  final String? highestCreditor;
  final NumberFormat money;

  const _PeopleAnalyticsCard({
    required this.peopleCount,
    required this.avgPerPerson,
    this.highestDebtor,
    this.highestCreditor,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF7C2D12), Color(0xFFC2410C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C2D12).withOpacity(0.55),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative ambient circle
            Positioned(
              bottom: -35,
              left: -35,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.people_rounded,
                            color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CONNECTIONS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$peopleCount ${peopleCount == 1 ? 'person' : 'people'}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Two person highlight tiles ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _PersonHighlight(
                          name: highestCreditor ?? '',
                          label: 'Owes you most',
                          color: const Color(0xFF4ADE80),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PersonHighlight(
                          name: highestDebtor ?? '',
                          label: 'You owe most',
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Avg row ───────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.trending_flat_rounded,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Avg per person: ${money.format(avgPerPerson)}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white54),
                      ),
                    ],
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

// ── Dues Analytics Card ─────────────────────────────────────────────────────────
// Visual: two bold hero counts (on-time vs overdue) + proportion bar + amount footer
// Palette: deep indigo

class _DuesAnalyticsCard extends StatelessWidget {
  final int totalDues;
  final double totalAmount;
  final int overdueCount;
  final NumberFormat money;

  const _DuesAnalyticsCard({
    required this.totalDues,
    required this.totalAmount,
    required this.overdueCount,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final onTime = totalDues - overdueCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF312E81).withOpacity(0.55),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle
            Positioned(
              bottom: -30,
              right: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.bar_chart_rounded,
                              color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ACTIVITY',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalDues ${totalDues == 1 ? 'due' : 'dues'} active',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Two hero counts ──────────────────────────────────────
                    Row(
                      children: [
                        // On-time count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$onTime',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4ADE80),
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),
                              const Text(
                                'on time',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 44,
                          color: Colors.white12,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        // Overdue count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$overdueCount',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: overdueCount > 0
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white24,
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                'overdue',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: overdueCount > 0
                                      ? const Color(0xFFFCA5A5)
                                          .withOpacity(0.7)
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── Proportion bar ───────────────────────────────────────
                    LayoutBuilder(
                      builder: (_, c) => SizedBox(
                        height: 6,
                        width: c.maxWidth,
                        child: CustomPaint(
                          painter: _SplitBarPainter(
                            lent: onTime.toDouble(),
                            borrowed: overdueCount.toDouble(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Total amount footer ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total outstanding',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                        Text(
                          money.format(totalAmount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

// ── Supporting widgets ──────────────────────────────────────────────────────────

/// Highlighted person tile used inside the People card.
class _PersonHighlight extends StatelessWidget {
  final String name;
  final String label;
  final Color color;

  const _PersonHighlight({
    required this.name,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = name.isEmpty;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: isEmpty
                  ? null
                  : LinearGradient(
                      colors: [color.withOpacity(0.75), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isEmpty ? Colors.white12 : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isEmpty ? '?' : _initials(name),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isEmpty ? 'None' : name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withOpacity(0.85)),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── CustomPainters ──────────────────────────────────────────────────────────────

/// Draws a proportional two-segment bar: green (lent) | red (borrowed).
class _SplitBarPainter extends CustomPainter {
  final double lent;
  final double borrowed;

  const _SplitBarPainter({required this.lent, required this.borrowed});

  @override
  void paint(Canvas canvas, Size size) {
    final total = lent + borrowed;
    if (total == 0) return;

    const gap = 3.0;
    const r = Radius.circular(5);
    final lentW = (lent / total) * (size.width - gap);
    final borrowedW = size.width - lentW - gap;

    if (lentW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, lentW, size.height), r),
        Paint()..color = const Color(0xFF4ADE80),
      );
    }
    if (borrowedW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(lentW + gap, 0, borrowedW, size.height), r),
        Paint()..color = const Color(0xFFFCA5A5),
      );
    }
  }

  @override
  bool shouldRepaint(_SplitBarPainter old) =>
      old.lent != lent || old.borrowed != borrowed;
}

