import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/bill_model.dart';
import '../state/bills_provider.dart';
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
const _red = Color(0xFFDC2626);


String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Screen ─────────────────────────────────────────────────────────────────────

enum _Filter { all, unpaid, paid }

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BillsProvider>();
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final df = DateFormat('d MMM yyyy');

    final filtered = p.bills.where((b) {
      if (_filter == _Filter.unpaid) return !b.isPaid;
      if (_filter == _Filter.paid) return b.isPaid;
      return true;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final allCount = p.bills.length;
    final unpaidCount = p.bills.where((b) => !b.isPaid).length;
    final paidCount = p.bills.where((b) => b.isPaid).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Bills',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _primary, size: 24),
            tooltip: 'Add Bill',
            onPressed: () => Navigator.pushNamed(context, '/add-bill'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SelectionArea(child: Column(
        children: [
          // ── Filter tabs ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _FilterPill(
                    label: 'All',
                    count: allCount,
                    selected: _filter == _Filter.all,
                    onTap: () => setState(() => _filter = _Filter.all)),
                const SizedBox(width: 8),
                _FilterPill(
                    label: 'Unpaid',
                    count: unpaidCount,
                    selected: _filter == _Filter.unpaid,
                    color: _red,
                    onTap: () => setState(() => _filter = _Filter.unpaid)),
                const SizedBox(width: 8),
                _FilterPill(
                    label: 'Paid',
                    count: paidCount,
                    selected: _filter == _Filter.paid,
                    color: _green,
                    onTap: () => setState(() => _filter = _Filter.paid)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Error banner ─────────────────────────────────────────────────
          if (p.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.error!,
                          style:
                              const TextStyle(color: _red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(filter: _filter)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      return _BillCard(
                        key: ValueKey(b.id),
                        bill: b,
                        dateText: df.format(b.dueDate),
                        amountText: b.amount == null
                            ? ''
                            : money.format(b.amount),
                        onMarkPaid: () => context
                            .read<BillsProvider>()
                            .setPaid(b.id, !b.isPaid),
                        onDelete: () =>
                            context.read<BillsProvider>().remove(b.id),
                      );
                    },
                  ),
          ),
        ],
      )),
    );
  }
}

// ── Filter Pill ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = _primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : _textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.15)
                    : const Color(0xFFEDE6DC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : _textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final String dateText;
  final String amountText;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _BillCard({
    super.key,
    required this.bill,
    required this.dateText,
    required this.amountText,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue =
        !bill.isPaid && bill.dueDate.isBefore(DateTime(now.year, now.month, now.day));

    return Dismissible(
      key: ValueKey(bill.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline_rounded, color: _red, size: 22),
            SizedBox(height: 3),
            Text('Delete',
                style: TextStyle(
                    fontSize: 11,
                    color: _red,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bill.isPaid ? const Color(0xFFFAFAFA) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? _red.withOpacity(0.3)
                : _border,
          ),
          boxShadow: bill.isPaid
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Category logo
            CategoryLogo(category: bill.category, size: 48, dimmed: bill.isPaid),
            const SizedBox(width: 14),

            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: bill.isPaid ? _textTertiary : _textPrimary,
                      decoration: bill.isPaid
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: _textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isOverdue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Overdue',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _red,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '${_capitalize(bill.category)} · ${_capitalize(bill.frequency)} · $dateText',
                          style: const TextStyle(
                              fontSize: 12, color: _textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount + toggle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amountText.isNotEmpty)
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: bill.isPaid ? _textTertiary : _textPrimary,
                    ),
                  ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onMarkPaid,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bill.isPaid
                          ? _green.withOpacity(0.08)
                          : const Color(0xFFFDF5ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: bill.isPaid
                            ? _green.withOpacity(0.3)
                            : _border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bill.isPaid
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 12,
                          color: bill.isPaid ? _green : _textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bill.isPaid ? 'Paid' : 'Mark Paid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: bill.isPaid ? _green : _textSecondary,
                          ),
                        ),
                      ],
                    ),
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      _Filter.paid => (
          Icons.check_circle_outline_rounded,
          'No paid bills',
          'Bills you mark as paid will appear here'
        ),
      _Filter.unpaid => (
          Icons.check_circle_outline_rounded,
          'All caught up!',
          'No unpaid bills right now'
        ),
      _Filter.all => (
          Icons.receipt_long_rounded,
          'No bills yet',
          'Tap + to add your first bill'
        ),
    };

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
              child: Icon(icon, size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
            if (filter == _Filter.all) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/add-bill'),
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
                      Text('Add Bill',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
