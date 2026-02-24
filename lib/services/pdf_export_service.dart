import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/due_model.dart';

// ignore_for_file: deprecated_member_use

class PdfExportService {
  // ── Brand colours ────────────────────────────────────────────────────────────

  static final _primary      = PdfColor.fromHex('#F97316');
  static final _green        = PdfColor.fromHex('#16A34A');
  static final _red          = PdfColor.fromHex('#DC2626');
  static final _textPrimary  = PdfColor.fromHex('#1C1917');
  static final _textSecondary= PdfColor.fromHex('#78716C');
  static final _textTertiary = PdfColor.fromHex('#A8A29E');
  static final _border       = PdfColor.fromHex('#EDE6DC');
  static final _rowAlt       = PdfColor.fromHex('#FAF8F5');
  static const _white70      = PdfColor(1, 1, 1, 0.7);

  // ── Payment method label ─────────────────────────────────────────────────────

  static String _methodLabel(String? m) {
    switch (m) {
      case 'cash':          return 'Cash';
      case 'upi':           return 'UPI';
      case 'bank_transfer': return 'Bank Transfer';
      case 'other':         return 'Other';
      default:              return '';
    }
  }

  // ── Public entry point ───────────────────────────────────────────────────────

  static Future<void> exportPersonDues({
    required String personName,
    required List<DueModel> dues,
    required NumberFormat money,
  }) async {
    // Noto Sans supports the ₹ symbol (default PDF fonts do not)
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();

    final df  = DateFormat('d MMM yyyy');
    final now = DateTime.now();

    // ── Flatten dues + payments into time-sorted rows ─────────────────────────

    final rows = <_Row>[];

    for (final due in dues) {
      rows.add(_Row(
        dateTime:    due.date,
        date:        df.format(due.date),
        type:        due.type == 'lent' ? 'Lent' : 'Borrowed',
        description: due.description ??
            (due.type == 'lent' ? 'Lent' : 'Borrowed'),
        amount:      money.format(due.amount),
        isPayment:   false,
        isSettled:   due.isSettled,
        isLent:      due.type == 'lent',
      ));

      final sortedPayments = [...due.payments]
        ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

      for (final p in sortedPayments) {
        final parts = <String>[
          if (p.method != null && p.method!.isNotEmpty) _methodLabel(p.method),
          if (p.note   != null && p.note!.isNotEmpty)   p.note!,
        ];
        rows.add(_Row(
          dateTime:    p.paidAt,
          date:        df.format(p.paidAt),
          type:        'Payment',
          description: parts.isEmpty ? 'Payment' : parts.join(' · '),
          amount:      '-${money.format(p.amount)}',
          isPayment:   true,
          isSettled:   false,
          isLent:      false,
        ));
      }
    }

    rows.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // ── Summary values ────────────────────────────────────────────────────────

    final totalLent     = dues.where((d) => d.type == 'lent')
        .fold(0.0, (s, d) => s + d.amount);
    final totalBorrowed = dues.where((d) => d.type == 'borrowed')
        .fold(0.0, (s, d) => s + d.amount);
    final totalPaid     = dues.fold(0.0, (s, d) => s + d.paidAmount);

    final activeDues = dues.where((d) => !d.isSettled).toList();
    final netAmount  = activeDues.fold(0.0, (s, d) =>
        d.type == 'lent' ? s + d.remaining : s - d.remaining);

    final isPositive = netAmount > 0;
    final isZero     = netAmount == 0;
    final firstName  = personName.split(' ').first;
    final netLabel   = isZero
        ? 'All settled up'
        : (isPositive
            ? '$firstName owes you'
            : 'You owe $firstName');

    // ── Column widths ─────────────────────────────────────────────────────────

    const colWidths = {
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(1.5),
      2: pw.FlexColumnWidth(3.5),
      3: pw.FlexColumnWidth(1.8),
    };

    // ── Build PDF ─────────────────────────────────────────────────────────────

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: _textTertiary),
          ),
        ),
        build: (ctx) => [
          // ── Header card ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: pw.BoxDecoration(
              color: _primary,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill Buddy',
                        style: pw.TextStyle(
                            font: bold, fontSize: 20, color: PdfColors.white)),
                    pw.SizedBox(height: 3),
                    pw.Text('Transaction Report',
                        style: pw.TextStyle(
                            font: regular, fontSize: 11, color: _white70)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(personName,
                        style: pw.TextStyle(
                            font: bold, fontSize: 14, color: PdfColors.white)),
                    pw.SizedBox(height: 3),
                    pw.Text('Generated ${df.format(now)}',
                        style: pw.TextStyle(
                            font: regular, fontSize: 10, color: _white70)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Table header row ───────────────────────────────────────────────
          pw.Table(
            columnWidths: colWidths,
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _primary),
                children: [
                  _headerCell('Date',        bold),
                  _headerCell('Type',        bold, align: pw.Alignment.center),
                  _headerCell('Description', bold),
                  _headerCell('Amount',      bold, align: pw.Alignment.centerRight),
                ],
              ),
              // Data rows
              ...rows.asMap().entries.map((e) {
                final i   = e.key;
                final row = e.value;
                final bg  = row.isSettled
                    ? _rowAlt
                    : (i.isOdd ? _rowAlt : PdfColors.white);

                final typeColor = row.isPayment
                    ? _textSecondary
                    : (row.isLent ? _green : _red);
                final amtColor = row.isPayment
                    ? _textSecondary
                    : (row.isLent ? _green : _red);
                final defaultColor =
                    row.isSettled ? _textTertiary : _textPrimary;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    // Date
                    _dataCell(row.date,        regular, defaultColor),
                    // Type
                    _dataCell(row.type,        bold,    typeColor,
                        align: pw.Alignment.center),
                    // Description
                    _dataCell(row.description, regular, defaultColor),
                    // Amount
                    _dataCell(row.amount,      bold,    amtColor,
                        align: pw.Alignment.centerRight),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Summary card ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.5),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary',
                    style: pw.TextStyle(font: bold, fontSize: 12)),
                pw.SizedBox(height: 12),

                _summaryRow('Total Lent',
                    money.format(totalLent), bold, regular),
                _summaryRow('Total Borrowed',
                    money.format(totalBorrowed), bold, regular),
                if (totalPaid > 0)
                  _summaryRow('Total Payments',
                      money.format(totalPaid), bold, regular),

                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  height: 0.5,
                  color: _border,
                ),

                _summaryRow(
                  netLabel,
                  isZero ? '' : money.format(netAmount.abs()),
                  bold,
                  regular,
                  valueColor: isZero
                      ? _textSecondary
                      : (isPositive ? _green : _red),
                  highlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${personName.replaceAll(' ', '_')}_transactions.pdf',
    );
  }

  // ── Table cell builders ───────────────────────────────────────────────────────

  static pw.Widget _headerCell(
    String text,
    pw.Font bold, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text,
    pw.Font font,
    PdfColor color, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9, color: color),
      ),
    );
  }

  // ── Summary row builder ────────────────────────────────────────────────────

  static pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular, {
    PdfColor? valueColor,
    bool highlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: highlight
                  ? pw.TextStyle(font: bold,    fontSize: 11)
                  : pw.TextStyle(font: regular, fontSize: 10,
                      color: _textSecondary)),
          pw.Text(value,
              style: pw.TextStyle(
                font: bold,
                fontSize: highlight ? 13 : 10,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

// ── Row data model ────────────────────────────────────────────────────────────

class _Row {
  final DateTime dateTime;
  final String date;
  final String type;
  final String description;
  final String amount;
  final bool isPayment;
  final bool isSettled;
  final bool isLent;

  _Row({
    required this.dateTime,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.isPayment,
    required this.isSettled,
    required this.isLent,
  });
}
