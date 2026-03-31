import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/bill_model.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
import '../widgets/app_toast.dart';
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

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Screen ─────────────────────────────────────────────────────────────────────

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  bool _unpaidExpanded = true;
  bool _paidExpanded = false;

  void _handleDelete(BuildContext context, BillModel bill) {
    context.read<BillsProvider>().remove(bill.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final entry = messenger.showSnackBar(
      SnackBar(
        content: Text('${bill.name} deleted'),
        duration: const Duration(seconds: 4),
        backgroundColor: _textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Undo',
          textColor: _primary,
          onPressed: () => context.read<BillsProvider>().add(bill),
        ),
      ),
    );
    // Backup dismiss — guarantees the snackbar goes away even if Flutter's
    // internal duration timer is disrupted by a widget tree rebuild.
    Future.delayed(const Duration(seconds: 4), entry.close);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BillsProvider>();
    final money = context.watch<AppSettingsProvider>().money;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    final monthBills = p.bills
        .where((b) =>
            !b.dueDate.isBefore(monthStart) && b.dueDate.isBefore(monthEnd))
        .toList();

    final unpaid = monthBills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final paid = monthBills.where((b) => b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final totalUnpaid = unpaid.fold(0.0, (s, b) => s + (b.amount ?? 0.0));
    final totalPaid = paid.fold(0.0, (s, b) => s + (b.amount ?? 0.0));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            const Text(
              'Bills',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
            ),
            Text(
              monthLabel,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary),
            ),
          ],
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
      body: p.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Error banner ─────────────────────────────────────────
                  if (p.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: _red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: _red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(p.error!,
                                  style: const TextStyle(
                                      color: _red, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Empty state ──────────────────────────────────────────
                  if (monthBills.isEmpty)
                    const _EmptyState()
                  else ...[
                    // ── Month summary chip ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${monthBills.length} ${monthBills.length == 1 ? 'bill' : 'bills'} this month',
                        style: const TextStyle(
                            fontSize: 13, color: _textSecondary),
                      ),
                    ),

                    // ── Unpaid section ────────────────────────────────────
                    _Section(
                      label: 'Unpaid',
                      count: unpaid.length,
                      total: totalUnpaid,
                      money: money,
                      color: _red,
                      icon: Icons.radio_button_unchecked_rounded,
                      expanded: _unpaidExpanded,
                      onToggle: () =>
                          setState(() => _unpaidExpanded = !_unpaidExpanded),
                      emptyText: 'All bills paid this month!',
                      bills: unpaid,
                      onMarkPaid: (b) {
                        if (!b.isPaid && b.amount != null) {
                          showAppToast(context, 'Added to Expenses',
                              icon: Icons.receipt_long_rounded);
                        }
                        context.read<BillsProvider>().setPaid(b.id, !b.isPaid);
                      },
                      onDelete: (b) => _handleDelete(context, b),
                    ),

                    const SizedBox(height: 12),

                    // ── Paid section ──────────────────────────────────────
                    _Section(
                      label: 'Paid',
                      count: paid.length,
                      total: totalPaid,
                      money: money,
                      color: _green,
                      icon: Icons.check_circle_rounded,
                      expanded: _paidExpanded,
                      onToggle: () =>
                          setState(() => _paidExpanded = !_paidExpanded),
                      emptyText: 'No bills paid yet this month',
                      bills: paid,
                      onMarkPaid: (b) =>
                          context.read<BillsProvider>().setPaid(b.id, !b.isPaid),
                      onDelete: (b) => _handleDelete(context, b),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Section card ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final int count;
  final double total;
  final NumberFormat money;
  final Color color;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final String emptyText;
  final List<BillModel> bills;
  final void Function(BillModel) onMarkPaid;
  final void Function(BillModel) onDelete;

  const _Section({
    required this.label,
    required this.count,
    required this.total,
    required this.money,
    required this.color,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.emptyText,
    required this.bills,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: color),
                        ),
                        Text(
                          '$count ${count == 1 ? 'bill' : 'bills'}',
                          style: const TextStyle(
                              fontSize: 12, color: _textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    total > 0 ? money.format(total) : '—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded bill rows ────────────────────────────────────────────
          if (expanded) ...[
            Divider(height: 1, color: _border),
            if (bills.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(emptyText,
                    style: const TextStyle(
                        fontSize: 13, color: _textTertiary)),
              )
            else
              ...bills.asMap().entries.map((entry) {
                final i = entry.key;
                final b = entry.value;
                return _BillRow(
                  key: ValueKey(b.id),
                  bill: b,
                  money: money,
                  isLast: i == bills.length - 1,
                  onMarkPaid: () => onMarkPaid(b),
                  onDelete: () => onDelete(b),
                );
              }),
          ],
        ],
      ),
    );
  }
}

// ── Bill row ───────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final BillModel bill;
  final NumberFormat money;
  final bool isLast;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _BillRow({
    super.key,
    required this.bill,
    required this.money,
    required this.isLast,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final now = DateTime.now();
    final isOverdue = !bill.isPaid &&
        bill.dueDate
            .isBefore(DateTime(now.year, now.month, now.day));

    return Dismissible(
      key: ValueKey('row-${bill.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.10),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: _red, size: 20),
            SizedBox(height: 2),
            Text('Delete',
                style: TextStyle(
                    fontSize: 10,
                    color: _red,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/add-bill', arguments: bill),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: !isLast
                ? const Border(bottom: BorderSide(color: _border))
                : null,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : null,
          ),
          child: Row(
            children: [
              // Category logo
              CategoryLogo(
                  category: bill.category,
                  size: 32,
                  dimmed: bill.isPaid,
                  billName: bill.name),
              const SizedBox(width: 10),

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: bill.isPaid ? _textTertiary : _textPrimary,
                        decoration: bill.isPaid
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: _textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isOverdue) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Overdue',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _red,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            '${_capitalize(bill.category)} · ${df.format(bill.dueDate)}',
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
              const SizedBox(width: 8),

              // Amount + mark paid
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bill.amount != null)
                    Text(
                      money.format(bill.amount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: bill.isPaid ? _textTertiary : _textPrimary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onMarkPaid,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: bill.isPaid
                            ? _green.withValues(alpha: 0.08)
                            : const Color(0xFFFDF5ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: bill.isPaid
                              ? _green.withValues(alpha: 0.3)
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
                            size: 11,
                            color:
                                bill.isPaid ? _green : _textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            bill.isPaid ? 'Paid' : 'Mark Paid',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: bill.isPaid
                                  ? _green
                                  : _textSecondary,
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
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            const Text('No bills this month',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            const Text('Tap + to add your first bill',
                style: TextStyle(fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
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
        ),
      ),
    );
  }
}
