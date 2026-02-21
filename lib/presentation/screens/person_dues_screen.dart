import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

// ── Avatar helpers (mirrored from dues_screen) ────────────────────────────────

const _avatarPalette = [
  Color(0xFF6C8EBF),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

Color _avatarColor(String name) =>
    _avatarPalette[name.hashCode.abs() % _avatarPalette.length];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, min(2, name.length)).toUpperCase();
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class PersonDuesScreen extends StatelessWidget {
  final String personName;
  final VoidCallback onAddTap;

  const PersonDuesScreen({
    super.key,
    required this.personName,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DuesProvider>();
    final money = context.watch<AppSettingsProvider>().money;

    final personDues = p.dues
        .where((d) => d.personName == personName)
        .toList()
      ..sort((a, b) {
        // Unsettled first, then by date desc
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.date.compareTo(a.date);
      });

    final active = personDues.where((d) => !d.isSettled).toList();
    final settled = personDues.where((d) => d.isSettled).toList();

    final netAmount = active.fold(0.0, (s, d) {
      return d.type == 'lent' ? s + d.amount : s - d.amount;
    });

    final avatarColor = _avatarColor(personName);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(personName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: avatarColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                personName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _primary, size: 22),
            tooltip: 'Add transaction',
            onPressed: onAddTap,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Net header ──────────────────────────────────────────────────────
          _NetHeader(
            personName: personName,
            net: netAmount,
            money: money,
            activeCount: active.length,
          ),

          // ── Transaction list ────────────────────────────────────────────────
          Expanded(
            child: personDues.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: personDues.length,
                    itemBuilder: (context, i) {
                      final due = personDues[i];

                      // Section divider between active and settled
                      final showDivider = i == active.length &&
                          active.isNotEmpty &&
                          settled.isNotEmpty;

                      return Column(
                        children: [
                          if (showDivider)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Container(
                                          height: 1, color: _border)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text(
                                      'Settled',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _textTertiary,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.8),
                                    ),
                                  ),
                                  Expanded(
                                      child: Container(
                                          height: 1, color: _border)),
                                ],
                              ),
                            ),
                          Dismissible(
                            key: Key(due.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: _red, size: 22),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete transaction?'),
                                  content: const Text(
                                      'This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete',
                                          style:
                                              TextStyle(color: _red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) =>
                                context.read<DuesProvider>().delete(due.id),
                            child: _TransactionCard(
                              due: due,
                              money: money,
                              onSettle: due.isSettled
                                  ? null
                                  : () => context
                                      .read<DuesProvider>()
                                      .settle(due.id),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      // ── Add transaction FAB-style button ────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: _card,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onAddTap,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add transaction with $personName',
              overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ── Net Header ─────────────────────────────────────────────────────────────────

class _NetHeader extends StatelessWidget {
  final String personName;
  final double net;
  final NumberFormat money;
  final int activeCount;

  const _NetHeader({
    required this.personName,
    required this.net,
    required this.money,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = net > 0;
    final isZero = net == 0;
    final color = isZero ? _textSecondary : (isPositive ? _green : _red);
    final label = isZero
        ? 'All settled up'
        : (isPositive
            ? '${personName.split(' ').first} owes you'
            : 'You owe ${personName.split(' ').first}');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isZero
                ? Icons.check_circle_outline_rounded
                : (isPositive
                    ? Icons.call_received_rounded
                    : Icons.call_made_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500),
                ),
                if (!isZero) ...[
                  const SizedBox(height: 1),
                  Text(
                    money.format(net.abs()),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$activeCount active',
            style: const TextStyle(fontSize: 12, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Card ───────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final DueModel due;
  final NumberFormat money;
  final VoidCallback? onSettle;

  const _TransactionCard({
    required this.due,
    required this.money,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final isLent = due.type == 'lent';
    final color = due.isSettled ? _textTertiary : (isLent ? _green : _red);
    final df = DateFormat('d MMM yyyy');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final isOverdue = !due.isSettled &&
        due.dueDate != null &&
        due.dueDate!.isBefore(today);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: due.isSettled ? const Color(0xFFFAFAFA) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? _red.withOpacity(0.3) : _border,
        ),
        boxShadow: due.isSettled
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Direction icon
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
                const SizedBox(width: 10),
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
                        df.format(due.date),
                        style: const TextStyle(
                            fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money.format(due.amount),
                      style: TextStyle(
                        fontSize: 16,
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

            // Due date / overdue row
            if (due.dueDate != null && !due.isSettled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.event_outlined,
                    size: 13,
                    color: isOverdue ? _red : _textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOverdue
                        ? 'Overdue · ${df.format(due.dueDate!)}'
                        : 'Due by ${df.format(due.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? _red : _textSecondary,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],

            // Mark settled button
            if (onSettle != null) ...[
              const SizedBox(height: 10),
              const Divider(color: _border, height: 1),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onSettle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15, color: _green.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text(
                      'Mark as Settled',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: _textTertiary),
          SizedBox(height: 14),
          Text(
            'No transactions yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textPrimary),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the button below to add one',
            style: TextStyle(fontSize: 13, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
