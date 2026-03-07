import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/expense_model.dart';
import '../state/app_settings_provider.dart';
import '../state/expenses_provider.dart';
import 'category_logo.dart';

// ── Palette ────────────────────────────────────────────────────────────────────

const _bg = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _red = Color(0xFFDC2626);

// ── Sheet ──────────────────────────────────────────────────────────────────────

class AddExpenseSheet extends StatefulWidget {
  final ExpenseModel? existing;

  const AddExpenseSheet({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late ExpenseCategory _category;
  late DateTime _date;
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final e = widget.existing!;
      _category = e.category;
      _date = e.date;
      _amtCtrl.text = e.amount.toStringAsFixed(0);
      _descCtrl.text = e.description ?? '';
    } else {
      _category = ExpenseCategory.food;
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amtCtrl.text.trim());
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final provider = context.read<ExpensesProvider>();

    if (widget.isEditing) {
      await provider.update(widget.existing!.copyWith(
        amount: amount,
        category: _category,
        description: desc,
        date: _date,
      ));
    } else {
      await provider.add(ExpenseModel.create(
        amount: amount,
        category: _category,
        description: desc,
        date: _date,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await context.read<ExpensesProvider>().delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<ExpensesProvider>().saving;
    final symbol = context.watch<AppSettingsProvider>().currency.symbol;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 20),
            _SheetTitleRow(
              isEditing: widget.isEditing,
              onDelete: saving ? null : (widget.isEditing ? _delete : null),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _AmountField(controller: _amtCtrl, symbol: symbol)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _DescriptionField(controller: _descCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            _CategoryPicker(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            _DateRow(date: _date, onTap: _pickDate),
            const SizedBox(height: 24),
            _SaveButton(
              isEditing: widget.isEditing,
              saving: saving,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-components ─────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitleRow extends StatelessWidget {
  final bool isEditing;
  final VoidCallback? onDelete;

  const _SheetTitleRow({required this.isEditing, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isEditing ? 'Edit Expense' : 'Add Expense',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        if (isEditing && onDelete != null)
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red.withOpacity(0.2)),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontSize: 12,
                  color: _red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String symbol;

  const _AmountField({required this.controller, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        prefixText: '$symbol ',
        prefixStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
        ),
        hintText: '0',
        hintStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: _textTertiary,
        ),
        filled: true,
        fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter an amount';
        final n = double.tryParse(v.trim());
        if (n == null || n <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            itemCount: ExpenseCategory.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = ExpenseCategory.values[i];
              final isSel = cat == selected;
              return GestureDetector(
                onTap: () => onChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSel ? _primary.withOpacity(0.12) : const Color(0xFFF5F0EA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryLogo(category: cat.value, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: isSel ? _primary : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 15, color: _textPrimary),
      decoration: InputDecoration(
        hintText: 'Description (optional)',
        hintStyle: const TextStyle(color: _textTertiary),
        filled: true,
        fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: _textSecondary),
            const SizedBox(width: 10),
            Text(
              isToday ? 'Today' : DateFormat('d MMM yyyy').format(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isEditing;
  final bool saving;
  final VoidCallback onSave;

  const _SaveButton({
    required this.isEditing,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: saving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                isEditing ? 'Update Expense' : 'Save Expense',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
