import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';

import '../../data/models/due_model.dart';
import '../../services/pdf_export_service.dart';
import '../state/app_settings_provider.dart';
import '../state/dues_provider.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg            = AppColors.bg;
const _card          = AppColors.surface;
const _border        = AppColors.border;
const _textPrimary   = AppColors.textPrimary;
const _textSecondary = AppColors.textSecondary;
const _textTertiary  = AppColors.textTertiary;
const _green         = AppColors.green;
const _red           = AppColors.red;

// ── Avatar helpers ─────────────────────────────────────────────────────────────

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

// ── Payment method helpers ─────────────────────────────────────────────────────

const _paymentMethods = ['cash', 'upi', 'bank_transfer', 'other'];

String _methodLabel(String? m) {
  switch (m) {
    case 'cash':          return 'Cash';
    case 'upi':           return 'UPI';
    case 'bank_transfer': return 'Bank Transfer';
    case 'other':         return 'Other';
    default:              return '';
  }
}

IconData _methodIcon(String? m) {
  switch (m) {
    case 'cash':          return Icons.payments_outlined;
    case 'upi':           return Icons.phone_android_outlined;
    case 'bank_transfer': return Icons.account_balance_outlined;
    default:              return Icons.swap_horiz_rounded;
  }
}

// ── Internal payment data ──────────────────────────────────────────────────────

class _PaymentData {
  final double amount;
  final String? method;
  final String? note;
  final DateTime date;
  _PaymentData({
    required this.amount,
    this.method,
    this.note,
    required this.date,
  });
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

  // ── Export PDF ────────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
    BuildContext context,
    List<DueModel> personDues,
    NumberFormat money,
  ) async {
    try {
      await PdfExportService.exportPersonDues(
        personName: personName,
        dues: personDues,
        money: money,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate PDF: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // ── Record payment (cascades oldest-first, user doesn't see the split) ────────

  Future<void> _showRecordPayment(
    BuildContext context,
    List<DueModel> activeDues,
    NumberFormat money,
  ) async {
    final totalRemaining =
        activeDues.fold(0.0, (s, d) => s + d.remaining);

    final data = await showModalBottomSheet<_PaymentData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonPaymentSheet(
        totalRemaining: totalRemaining,
        money: money,
      ),
    );
    if (data == null || !context.mounted) return;

    final provider = context.read<DuesProvider>();

    // Apply payment to dues oldest-first (user just sees total update)
    double leftToApply = data.amount;
    final sorted = [...activeDues]..sort((a, b) => a.date.compareTo(b.date));

    for (final due in sorted) {
      if (leftToApply < 0.01) break;
      final toApply = min(leftToApply, due.remaining);
      final entry = PaymentEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}_${due.id.substring(0, min(4, due.id.length))}',
        amount: toApply,
        method: data.method,
        note: data.note,
        paidAt: data.date,
      );
      await provider.addPayment(due.id, entry);
      leftToApply -= toApply;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of ${money.format(data.amount)} recorded'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1917),
      ),
    );
  }

  // ── Settle all active dues ─────────────────────────────────────────────────

  Future<void> _settleAll(
    BuildContext context,
    List<DueModel> activeDues,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settle all?'),
        content: Text(
          'Mark all ${activeDues.length} active transaction${activeDues.length == 1 ? '' : 's'} with $personName as settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Settle All',
              style: TextStyle(color: _green),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<DuesProvider>();
    for (final due in activeDues) {
      await provider.settle(due.id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All settled up ✓'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DuesProvider>();
    final money = context.watch<AppSettingsProvider>().money;

    final personDues = p.dues
        .where((d) => d.personName == personName)
        .toList()
      ..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.date.compareTo(a.date);
      });

    final active = personDues.where((d) => !d.isSettled).toList();
    final settled = personDues.where((d) => d.isSettled).toList();

    // Net uses remaining (not original amount) for accuracy
    final netAmount = active.fold(0.0, (s, d) {
      return d.type == 'lent' ? s + d.remaining : s - d.remaining;
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
                color: avatarColor.withValues(alpha:0.18),
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
          if (personDues.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: _textSecondary, size: 20),
              tooltip: 'Export as PDF',
              onPressed: () => _exportPdf(context, personDues, money),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _textPrimary, size: 22),
            tooltip: 'Add transaction',
            onPressed: onAddTap,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _NetHeader(
            personName: personName,
            net: netAmount,
            money: money,
            activeCount: active.length,
            onRecordPayment: active.isEmpty
                ? null
                : () => _showRecordPayment(context, active, money),
            onSettleAll: active.isEmpty
                ? null
                : () => _settleAll(context, active),
          ),
          Expanded(
            child: personDues.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: personDues.length,
                    itemBuilder: (context, i) {
                      final due = personDues[i];
                      final showDivider = i == active.length &&
                          active.isNotEmpty &&
                          settled.isNotEmpty;

                      return Column(
                        children: [
                          if (showDivider)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                color: _red.withValues(alpha:0.12),
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
                                          style: TextStyle(color: _red)),
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
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: _card,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
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
            backgroundColor: AppColors.heroCard,
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
  final VoidCallback? onRecordPayment;
  final VoidCallback? onSettleAll;

  const _NetHeader({
    required this.personName,
    required this.net,
    required this.money,
    required this.activeCount,
    this.onRecordPayment,
    this.onSettleAll,
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
    final hasActions = onRecordPayment != null || onSettleAll != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Amount row ──────────────────────────────────────────────────────
          Row(
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

          // ── Action buttons (only when there are active dues) ────────────────
          if (hasActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeaderButton(
                    label: 'Record Payment',
                    icon: Icons.payments_outlined,
                    color: _textPrimary,
                    onTap: onRecordPayment!,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderButton(
                    label: 'Settle All',
                    icon: Icons.check_circle_outline_rounded,
                    color: _green,
                    onTap: onSettleAll!,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Header Action Button ───────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha:0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction Card (read-only) ───────────────────────────────────────────────

class _TransactionCard extends StatefulWidget {
  final DueModel due;
  final NumberFormat money;

  const _TransactionCard({
    required this.due,
    required this.money,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _historyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final due = widget.due;
    final money = widget.money;
    final isLent = due.type == 'lent';
    final color = due.isSettled ? _textTertiary : (isLent ? _green : _red);
    final df = DateFormat('d MMM yyyy');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final isOverdue = !due.isSettled &&
        due.dueDate != null &&
        due.dueDate!.isBefore(today);

    final hasPayments = due.payments.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: due.isSettled ? const Color(0xFFFAFAFA) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? _red.withValues(alpha:0.3) : _border,
        ),
        boxShadow: due.isSettled
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.03),
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
            // ── Main row ───────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.10),
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
                          color: due.isSettled ? _textTertiary : _textPrimary,
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
                // Amount column
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
                        color: color.withValues(alpha:0.10),
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

            // ── Due date / overdue ─────────────────────────────────────────────
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
                      fontWeight:
                          isOverdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],

            // ── Payment progress bar (shown when partially paid) ───────────────
            if (hasPayments && !due.isSettled) ...[
              const SizedBox(height: 10),
              _PaymentProgressBar(
                paid: due.paidAmount,
                total: due.amount,
                money: money,
                color: color,
              ),
            ],

            // ── Payment history toggle ─────────────────────────────────────────
            if (hasPayments) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _historyExpanded = !_historyExpanded),
                child: Row(
                  children: [
                    Text(
                      due.isSettled
                          ? 'Paid in ${due.payments.length} payment${due.payments.length == 1 ? '' : 's'}'
                          : '${due.payments.length} payment${due.payments.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _historyExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: _textSecondary,
                    ),
                  ],
                ),
              ),

              // ── Payment history timeline (expandable) ──────────────────────
              if (_historyExpanded) ...[
                const SizedBox(height: 10),
                _PaymentTimeline(
                  payments: due.payments,
                  money: money,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Payment Progress Bar ───────────────────────────────────────────────────────

class _PaymentProgressBar extends StatelessWidget {
  final double paid;
  final double total;
  final NumberFormat money;
  final Color color;

  const _PaymentProgressBar({
    required this.paid,
    required this.total,
    required this.money,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final remaining = (total - paid).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (_, c) => Stack(
              children: [
                Container(
                  height: 5,
                  width: c.maxWidth,
                  color: color.withValues(alpha:0.12),
                ),
                Container(
                  height: 5,
                  width: c.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${money.format(paid)} paid',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              '${money.format(remaining)} left',
              style: const TextStyle(fontSize: 11, color: _textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Payment History Timeline ───────────────────────────────────────────────────

class _PaymentTimeline extends StatelessWidget {
  final List<PaymentEntry> payments;
  final NumberFormat money;

  const _PaymentTimeline({
    required this.payments,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final sorted = [...payments]
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isLast = i == sorted.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: _textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.only(top: 2),
                            color: _border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    money.format(p.amount),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  if (p.method != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _border,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_methodIcon(p.method),
                                              size: 10,
                                              color: _textSecondary),
                                          const SizedBox(width: 3),
                                          Text(
                                            _methodLabel(p.method),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: _textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (p.note != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  p.note!,
                                  style: const TextStyle(
                                      fontSize: 11, color: _textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          df.format(p.paidAt),
                          style: const TextStyle(
                              fontSize: 11, color: _textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Person Payment Sheet ───────────────────────────────────────────────────────

class _PersonPaymentSheet extends StatefulWidget {
  final double totalRemaining;
  final NumberFormat money;

  const _PersonPaymentSheet({
    required this.totalRemaining,
    required this.money,
  });

  @override
  State<_PersonPaymentSheet> createState() => _PersonPaymentSheetState();
}

class _PersonPaymentSheetState extends State<_PersonPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _method;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    final rem = widget.totalRemaining;
    _amountCtrl.text =
        rem == rem.truncate() ? rem.toInt().toString() : rem.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amount > widget.totalRemaining + 0.01) {
      setState(() => _error = 'Amount exceeds total outstanding');
      return;
    }
    Navigator.pop(
      context,
      _PaymentData(
        amount: amount,
        method: _method,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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

              const Text(
                'Record Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.money.format(widget.totalRemaining)} outstanding',
                style: const TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),

              // Amount
              const Text(
                'Amount',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle:
                        TextStyle(color: _textTertiary, fontSize: 16),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!,
                    style: const TextStyle(fontSize: 12, color: _red)),
              ],
              const SizedBox(height: 20),

              // Method
              const Text(
                'Payment Method',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: _paymentMethods.map((m) {
                  final selected = _method == m;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _method = selected ? null : m),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: m == _paymentMethods.last ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? _textPrimary.withValues(alpha:0.08)
                              : _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? _textPrimary.withValues(alpha:0.4)
                                : _border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _methodIcon(m),
                              size: 16,
                              color: selected ? _textPrimary : _textSecondary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _methodLabel(m),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: selected ? _textPrimary : _textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Note
              const Text(
                'Note (optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style:
                      const TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                    hintText: 'e.g. First installment',
                    hintStyle:
                        TextStyle(color: _textTertiary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date
              const Text(
                'Date',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: _textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        df.format(_date),
                        style: const TextStyle(
                            fontSize: 14, color: _textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.heroCard,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Save Payment',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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
