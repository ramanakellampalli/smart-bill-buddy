import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/bill_model.dart';
import '../state/app_settings_provider.dart';
import '../state/bills_provider.dart';
// ── Palette ────────────────────────────────────────────────────────────────────

const _bg            = AppColors.bg;
const _card          = AppColors.surface;
const _surface2      = AppColors.surface2;
const _border        = AppColors.border;
const _primary       = AppColors.primary;
const _textPrimary   = AppColors.textPrimary;
const _textSecondary = AppColors.textSecondary;
const _textTertiary  = AppColors.textTertiary;
const _red           = AppColors.red;

IconData _currencyIcon(String code) => switch (code) {
  'USD' || 'AUD' => Icons.attach_money_rounded,
  'EUR'          => Icons.euro_rounded,
  'GBP'          => Icons.currency_pound_rounded,
  'JPY'          => Icons.currency_yen_rounded,
  _              => Icons.currency_rupee_rounded,
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class AddBillScreen extends StatefulWidget {
  final BillModel? bill; // null = add mode, non-null = edit mode
  const AddBillScreen({super.key, this.bill});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  String _frequency = 'monthly';
  String _category = 'utilities';

  bool _remind5 = true;
  bool _remind2 = true;
  bool _remindDue = true;

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    if (b != null) {
      _nameCtrl.text = b.name;
      _amountCtrl.text = b.amount?.toString() ?? '';
      _dueDate = b.dueDate;
      _frequency = b.frequency;
      _category = b.category;
      _remind5 = b.remind5Days;
      _remind2 = b.remind2Days;
      _remindDue = b.remindDueDay;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 1),
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
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final t = _amountCtrl.text.trim();
    final amount = t.isEmpty ? null : double.tryParse(t);

    final bill = BillModel(
      id: _isEditing ? widget.bill!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      amount: amount,
      dueDate: _dueDate,
      frequency: _frequency,
      category: _category,
      isPaid: _isEditing ? widget.bill!.isPaid : false,
      remind5Days: _remind5,
      remind2Days: _remind2,
      remindDueDay: _remindDue,
      createdAt: _isEditing ? widget.bill!.createdAt : null,
    );

    final provider = context.read<BillsProvider>();
    if (_isEditing) {
      await provider.update(bill);
    } else {
      await provider.add(bill);
    }

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
    final saving = context.watch<BillsProvider>().saving;
    final currencyCode = context.watch<AppSettingsProvider>().currency.code;
    final df = DateFormat('EEE, d MMM yyyy');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Bill' : 'Add Bill',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Bill Details ────────────────────────────────────────────
              _SectionCard(
                children: [
                  const _FieldLabel('Bill name'),
                  const SizedBox(height: 8),
                  _StyledField(
                    controller: _nameCtrl,
                    hint: 'Electricity, Rent, Netflix...',
                    icon: Icons.receipt_long_rounded,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Enter a bill name';
                      if (t.length < 2) return 'Name is too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Amount (optional)'),
                  const SizedBox(height: 8),
                  _StyledField(
                    controller: _amountCtrl,
                    hint: '0',
                    icon: _currencyIcon(currencyCode),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      if (double.tryParse(t) == null) {
                        return 'Enter a valid number';
                      }
                      if (double.parse(t) < 0) {
                        return 'Amount cannot be negative';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Due Date ────────────────────────────────────────────────
              const _SectionLabel('Due Date'),
              const SizedBox(height: 8),
              _SectionCard(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha:0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today_rounded,
                                color: _primary, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Due on',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _textSecondary)),
                                const SizedBox(height: 2),
                                Text(df.format(_dueDate),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: _textTertiary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Category ────────────────────────────────────────────────
              const _SectionLabel('Category'),
              const SizedBox(height: 10),
              _CategoryGrid(
                selected: _category,
                onSelect: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 14),

              // ── Frequency ───────────────────────────────────────────────
              const _SectionLabel('Frequency'),
              const SizedBox(height: 10),
              _FrequencySelector(
                selected: _frequency,
                onSelect: (f) => setState(() => _frequency = f),
              ),
              const SizedBox(height: 14),

              // ── Reminders ───────────────────────────────────────────────
              const _SectionLabel('Reminders'),
              const SizedBox(height: 8),
              _SectionCard(
                padding: EdgeInsets.zero,
                children: [
                  _ReminderTile(
                    label: '5 days before',
                    value: _remind5,
                    onChanged: (v) => setState(() => _remind5 = v),
                    showDivider: true,
                  ),
                  _ReminderTile(
                    label: '2 days before',
                    value: _remind2,
                    onChanged: (v) => setState(() => _remind2 = v),
                    showDivider: true,
                  ),
                  _ReminderTile(
                    label: 'On due day',
                    value: _remindDue,
                    onChanged: (v) => setState(() => _remindDue = v),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Save ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.heroCard,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          _isEditing ? 'Update Bill' : 'Save Bill',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textTertiary,
          letterSpacing: 1.0,
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  const _SectionCard({required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _textSecondary),
      );
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textTertiary, size: 18),
        filled: true,
        fillColor: _surface2,
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
      ),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────

const _categories = [
  _CatOption('utilities', 'Utilities', Icons.bolt_rounded,
      Color(0xFFF59E0B)),
  _CatOption('rent', 'Rent', Icons.home_rounded, Color(0xFF6C8EBF)),
  _CatOption('emi', 'EMI', Icons.account_balance_rounded,
      Color(0xFF8B5CF6)),
  _CatOption('credit_card', 'Credit Card', Icons.credit_card_rounded,
      Color(0xFFEF4444)),
  _CatOption('subscriptions', 'Subscriptions',
      Icons.play_circle_fill_rounded, Color(0xFF10B981)),
  _CatOption('education', 'Education', Icons.school_rounded,
      Color(0xFF3B82F6)),
  _CatOption('other', 'Other', Icons.receipt_long_rounded,
      Color(0xFF78716C)),
];

class _CatOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _CatOption(this.value, this.label, this.icon, this.color);
}

class _CategoryGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSel = cat.value == selected;
        return GestureDetector(
          onTap: () => onSelect(cat.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? cat.color.withValues(alpha:0.12) : _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? cat.color : _border,
                width: isSel ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon,
                    size: 16,
                    color: isSel ? cat.color : _textTertiary),
                const SizedBox(width: 7),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSel ? FontWeight.w600 : FontWeight.w400,
                    color: isSel ? cat.color : _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Frequency Selector ────────────────────────────────────────────────────────

const _frequencies = [
  _FreqOption('monthly', 'Monthly'),
  _FreqOption('quarterly', 'Quarterly'),
  _FreqOption('yearly', 'Yearly'),
];

class _FreqOption {
  final String value;
  final String label;
  const _FreqOption(this.value, this.label);
}

class _FrequencySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _FrequencySelector(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _frequencies.map((freq) {
          final isSel = freq.value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(freq.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSel ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  freq.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSel ? FontWeight.w600 : FontWeight.w400,
                    color: isSel ? Colors.white : _textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Reminder Tile ─────────────────────────────────────────────────────────────

class _ReminderTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _ReminderTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.notifications_rounded
                    : Icons.notifications_off_outlined,
                size: 18,
                color: value ? _primary : _textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value ? _textPrimary : _textSecondary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: _primary,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
              color: _border, height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
