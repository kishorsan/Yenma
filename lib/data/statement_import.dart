import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

import '../domain/import_foundation.dart';
import '../domain/money.dart';
import '../domain/statement_import.dart';

class DecodedStatement {
  const DecodedStatement({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Decodes CSV/XLSX bytes. Field meaning is applied separately by a profile.
class StatementWorkbookDecoder {
  const StatementWorkbookDecoder();

  DecodedStatement decode(Uint8List bytes, StatementImportProfile profile) {
    final rows = switch (profile.format) {
      StatementFileFormat.csv => _csvRows(bytes),
      StatementFileFormat.xlsx => _xlsxRows(bytes, profile.sheetName),
    };
    if (profile.headerRow < 0 || profile.headerRow >= rows.length) {
      throw const FormatException('Statement header row was not found.');
    }
    final headers = rows[profile.headerRow]
        .map((value) => _cellText(value).trim())
        .toList();
    if (headers.every((header) => header.isEmpty)) {
      throw const FormatException('Statement header row is empty.');
    }
    return DecodedStatement(
      headers: headers,
      rows: rows.skip(profile.headerRow + 1).toList(),
    );
  }

  List<List<Object?>> _csvRows(Uint8List bytes) => csv
      .decode(utf8.decode(bytes, allowMalformed: false))
      .map((row) => List<Object?>.from(row))
      .toList();

  List<List<Object?>> _xlsxRows(Uint8List bytes, String? requestedSheet) {
    return _OoxmlStatementReader(bytes).rows(requestedSheet);
  }
}

/// Small read-only OOXML reader for statement cell values. It ignores macros,
/// drawings, and formulas except for their cached values.
class _OoxmlStatementReader {
  _OoxmlStatementReader(Uint8List bytes)
    : _archive = ZipDecoder().decodeBytes(bytes);

  final Archive _archive;

  List<List<Object?>> rows(String? requestedSheet) {
    final workbook = _xml('xl/workbook.xml');
    final relationships = _xml('xl/_rels/workbook.xml.rels');
    final targets = <String, String>{
      for (final relation in _elements(relationships, 'Relationship'))
        _attribute(relation, 'Id')!: _attribute(relation, 'Target')!,
    };
    final sheets = _elements(workbook, 'sheet').toList();
    if (sheets.isEmpty) {
      throw const FormatException('The workbook has no worksheets.');
    }
    final requested = requestedSheet?.trim();
    final sheet = requested == null || requested.isEmpty
        ? sheets.first
        : sheets
              .where((item) => _attribute(item, 'name') == requested)
              .firstOrNull;
    if (sheet == null) {
      throw FormatException('Worksheet "$requested" was not found.');
    }
    final target = targets[_attribute(sheet, 'id')];
    if (target == null) {
      throw const FormatException('Worksheet relationship is missing.');
    }
    final sheetPath = target.startsWith('/')
        ? target.substring(1)
        : target.startsWith('xl/')
        ? target
        : 'xl/$target';
    final sharedStrings = _sharedStrings();
    final dateStyles = _dateStyleIndexes();
    final document = _xml(sheetPath.replaceAll('\\', '/'));
    final result = <List<Object?>>[];
    for (final row in _elements(document, 'row')) {
      final rowIndex =
          (int.tryParse(_attribute(row, 'r') ?? '') ?? result.length + 1) - 1;
      while (result.length <= rowIndex) {
        result.add(<Object?>[]);
      }
      final values = <Object?>[];
      for (final cell in row.childElements.where(
        (item) => item.name.local == 'c',
      )) {
        final column = _columnIndex(_attribute(cell, 'r') ?? '');
        while (values.length <= column) {
          values.add(null);
        }
        values[column] = _cellValue(cell, sharedStrings, dateStyles);
      }
      result[rowIndex] = values;
    }
    return result;
  }

  Object? _cellValue(
    XmlElement cell,
    List<String> sharedStrings,
    Set<int> dateStyles,
  ) {
    final type = _attribute(cell, 't');
    if (type == 'inlineStr') {
      return _elements(cell, 't').map((item) => item.innerText).join();
    }
    final raw = cell.childElements
        .where((item) => item.name.local == 'v')
        .firstOrNull
        ?.innerText;
    if (raw == null || raw.isEmpty) return null;
    if (type == 's') {
      final index = int.tryParse(raw);
      return index == null || index < 0 || index >= sharedStrings.length
          ? raw
          : sharedStrings[index];
    }
    if (type == 'str' || type == 'e') return raw;
    if (type == 'b') return raw == '1';
    if (type == 'd') return DateTime.tryParse(raw) ?? raw;
    final number = num.tryParse(raw);
    if (number == null) return raw;
    final style = int.tryParse(_attribute(cell, 's') ?? '');
    if (style != null && dateStyles.contains(style)) {
      final milliseconds = (number * Duration.millisecondsPerDay).round();
      return DateTime(1899, 12, 30).add(Duration(milliseconds: milliseconds));
    }
    return number == number.roundToDouble()
        ? number.toInt()
        : number.toDouble();
  }

  List<String> _sharedStrings() {
    final file = _archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];
    return _elements(_parse(file), 'si')
        .map(
          (item) => _elements(item, 't').map((text) => text.innerText).join(),
        )
        .toList();
  }

  Set<int> _dateStyleIndexes() {
    final file = _archive.findFile('xl/styles.xml');
    if (file == null) return const {};
    final document = _parse(file);
    final customFormats = <int, String>{};
    for (final format in _elements(document, 'numFmt')) {
      final id = int.tryParse(_attribute(format, 'numFmtId') ?? '');
      final code = _attribute(format, 'formatCode');
      if (id != null && code != null) customFormats[id] = code;
    }
    final cellXfs = _elements(document, 'cellXfs').firstOrNull;
    if (cellXfs == null) return const {};
    final result = <int>{};
    final styles = cellXfs.childElements
        .where((item) => item.name.local == 'xf')
        .toList();
    for (var index = 0; index < styles.length; index++) {
      final numFmtId =
          int.tryParse(_attribute(styles[index], 'numFmtId') ?? '0') ?? 0;
      final format = customFormats[numFmtId];
      if (_builtInDateFormats.contains(numFmtId) ||
          (format != null && _looksLikeDateFormat(format))) {
        result.add(index);
      }
    }
    return result;
  }

  XmlDocument _xml(String path) {
    final file = _archive.findFile(path);
    if (file == null) throw FormatException('Missing XLSX part: $path.');
    return _parse(file);
  }

  XmlDocument _parse(ArchiveFile file) =>
      XmlDocument.parse(utf8.decode(List<int>.from(file.content as List)));
}

/// Converts decoded statement rows into Phase 1 import inbox records.
class StatementImportAdapter {
  const StatementImportAdapter();

  StatementParseResult parse(
    DecodedStatement statement,
    StatementImportProfile profile, {
    DateTime? receivedAt,
  }) {
    final indexes = <StatementField, int>{};
    final normalizedHeaders = statement.headers.map(_headerKey).toList();
    for (final entry in profile.columns.entries) {
      final index = normalizedHeaders.indexOf(_headerKey(entry.value));
      if (index >= 0) indexes[entry.key] = index;
    }
    for (final field in const [
      StatementField.sourceRecordId,
      StatementField.transactionDate,
      StatementField.description,
    ]) {
      if (!indexes.containsKey(field) && !profile.defaults.containsKey(field)) {
        throw FormatException('Required mapping is missing: ${field.name}.');
      }
    }
    final hasAmount =
        indexes.containsKey(StatementField.amount) ||
        profile.defaults.containsKey(StatementField.amount);
    final hasDebitCredit =
        indexes.containsKey(StatementField.debitAmount) ||
        indexes.containsKey(StatementField.creditAmount);
    if (!hasAmount && !hasDebitCredit) {
      throw const FormatException(
        'Map amount, or map debit and credit amount columns.',
      );
    }

    final records = <ImportRecord>[];
    final issues = <StatementRowIssue>[];
    final observedAt = receivedAt ?? DateTime.now();
    for (var index = 0; index < statement.rows.length; index++) {
      final row = statement.rows[index];
      if (row.every((value) => _cellText(value).trim().isEmpty)) continue;
      final rowNumber = profile.headerRow + index + 2;
      final values = <StatementField, String>{};
      for (final field in StatementField.values) {
        final column = indexes[field];
        final value = column == null || column >= row.length
            ? null
            : row[column];
        final text = _cellText(value).trim();
        if (text.isNotEmpty) values[field] = text;
      }
      values.addAll({
        for (final entry in profile.defaults.entries)
          if ((values[entry.key] ?? '').isEmpty) entry.key: entry.value.trim(),
      });
      final rawPayload = jsonEncode({
        for (var column = 0; column < statement.headers.length; column++)
          statement.headers[column]: column < row.length
              ? _cellText(row[column])
              : '',
      });
      final sourceRecordId = values[StatementField.sourceRecordId] ?? '';
      final sourceItemId = sourceRecordId.isEmpty
          ? 'row-$rowNumber'
          : sourceRecordId;
      try {
        final transaction = _transaction(values, row, indexes, profile);
        records.add(
          ImportRecord(
            source: 'statement:${profile.sourceKey}',
            sourceItemId: sourceItemId,
            rawPayload: rawPayload,
            receivedAt: observedAt,
            transaction: transaction,
          ),
        );
      } on FormatException catch (error) {
        final message = error.message.toString();
        final code = _issueCode(message);
        issues.add(
          StatementRowIssue(rowNumber: rowNumber, code: code, message: message),
        );
        records.add(
          ImportRecord(
            source: 'statement:${profile.sourceKey}',
            sourceItemId: sourceItemId,
            rawPayload: rawPayload,
            receivedAt: observedAt,
            rejectionReason: code,
          ),
        );
      }
    }
    return StatementParseResult(records: records, issues: issues);
  }

  MoneyTransaction _transaction(
    Map<StatementField, String> values,
    List<Object?> row,
    Map<StatementField, int> indexes,
    StatementImportProfile profile,
  ) {
    final sourceRecordId = values[StatementField.sourceRecordId] ?? '';
    if (sourceRecordId.isEmpty) {
      throw const FormatException('source_record_id is required.');
    }
    final description = values[StatementField.description] ?? '';
    if (description.isEmpty) {
      throw const FormatException('description is required.');
    }
    final dateValue = _rawValue(
      StatementField.transactionDate,
      row,
      indexes,
      values,
    );
    final date = _parseDate(dateValue);
    if (date == null) {
      throw const FormatException('transaction_date is invalid.');
    }
    final debit = _parseAmount(
      _rawValue(StatementField.debitAmount, row, indexes, values),
    );
    final credit = _parseAmount(
      _rawValue(StatementField.creditAmount, row, indexes, values),
    );
    final amount = _parseAmount(
      _rawValue(StatementField.amount, row, indexes, values),
    );
    if (debit != null && credit != null) {
      throw const FormatException(
        'Only one debit or credit amount is allowed.',
      );
    }
    final resolvedAmount = amount ?? debit ?? credit;
    if (resolvedAmount == null || resolvedAmount <= 0) {
      throw const FormatException('amount_inr must be a positive number.');
    }
    final typeText = values[StatementField.transactionType];
    final kind = typeText == null || typeText.isEmpty
        ? debit != null
              ? TransactionKind.expense
              : credit != null
              ? TransactionKind.income
              : null
        : _parseKind(typeText);
    if (kind == null) {
      throw const FormatException('transaction_type is invalid.');
    }
    final institution = values[StatementField.institution] ?? '';
    if (institution.isEmpty) {
      throw const FormatException('institution is required.');
    }
    final instrument = _parseInstrument(
      values[StatementField.instrumentType] ?? '',
    );
    if (instrument == null) {
      throw const FormatException('instrument_type is invalid.');
    }
    final currency = (values[StatementField.currency] ?? 'INR').toUpperCase();
    if (currency != 'INR') {
      throw const FormatException('Only INR statements are supported.');
    }
    final categoryId = _categoryId(values[StatementField.category], kind);
    final reference = values[StatementField.reference] ?? '';
    final note = values[StatementField.note] ?? '';
    final combinedNote = [
      if (reference.isNotEmpty) 'Reference: $reference',
      if (note.isNotEmpty) note,
    ].join('\n');
    return MoneyTransaction(
      title: description,
      amountPaise: resolvedAmount,
      kind: kind,
      categoryId: categoryId,
      date: date,
      note: combinedNote,
      source: 'STATEMENT',
      bankName: institution,
      instrumentType: instrument,
      instrumentLast4: _last4(values[StatementField.instrumentLast4]),
      importRole: switch ((instrument, kind)) {
        (FinancialInstrumentType.creditCard, TransactionKind.expense) =>
          ImportedTransactionRole.cardPurchase,
        (FinancialInstrumentType.creditCard, TransactionKind.transfer) =>
          ImportedTransactionRole.cardPayment,
        (FinancialInstrumentType.bankAccount, TransactionKind.income) =>
          ImportedTransactionRole.accountCredit,
        _ => ImportedTransactionRole.accountDebit,
      },
      externalId: 'statement:${profile.sourceKey}:$sourceRecordId',
    );
  }
}

Object? _rawValue(
  StatementField field,
  List<Object?> row,
  Map<StatementField, int> indexes,
  Map<StatementField, String> values,
) {
  final index = indexes[field];
  return index == null || index >= row.length ? values[field] : row[index];
}

const _builtInDateFormats = <int>{
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  45,
  46,
  47,
};

Iterable<XmlElement> _elements(XmlNode node, String localName) => node
    .descendants
    .whereType<XmlElement>()
    .where((element) => element.name.local == localName);

String? _attribute(XmlElement element, String localName) => element.attributes
    .where((attribute) => attribute.name.local == localName)
    .firstOrNull
    ?.value;

int _columnIndex(String reference) {
  final letters = RegExp(r'^[A-Za-z]+').firstMatch(reference)?.group(0) ?? 'A';
  var result = 0;
  for (final unit in letters.toUpperCase().codeUnits) {
    result = result * 26 + unit - 64;
  }
  return result - 1;
}

bool _looksLikeDateFormat(String format) {
  final clean = format
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\\.'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .toLowerCase();
  return clean.contains('y') && clean.contains('d');
}

String _cellText(Object? value) => switch (value) {
  null => '',
  DateTime date => date.toIso8601String(),
  _ => value.toString(),
};

String _headerKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
  final text = _cellText(value).trim();
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;
  final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$')
      .firstMatch(text);
  if (match == null) return null;
  var year = int.parse(match[3]!);
  if (year < 100) year += 2000;
  final result = DateTime(year, int.parse(match[2]!), int.parse(match[1]!));
  return result.year == year &&
          result.month == int.parse(match[2]!) &&
          result.day == int.parse(match[1]!)
      ? result
      : null;
}

int? _parseAmount(Object? value) {
  if (value == null) return null;
  if (value is num) return (value.abs() * 100).round();
  final clean = _cellText(value)
      .replaceAll(',', '')
      .replaceAll('₹', '')
      .replaceAll(RegExp(r'\b(?:INR|Rs\.?)\b', caseSensitive: false), '')
      .trim();
  if (clean.isEmpty) return null;
  final parsed = double.tryParse(clean);
  return parsed == null ? null : (parsed.abs() * 100).round();
}

TransactionKind? _parseKind(String value) => switch (_headerKey(value)) {
  'expense' || 'debit' || 'dr' => TransactionKind.expense,
  'income' || 'credit' || 'cr' => TransactionKind.income,
  'transfer' => TransactionKind.transfer,
  _ => null,
};

FinancialInstrumentType? _parseInstrument(String value) => switch (_headerKey(
  value,
)) {
  'bank_account' || 'account' || 'bank' => FinancialInstrumentType.bankAccount,
  'credit_card' || 'card' => FinancialInstrumentType.creditCard,
  _ => null,
};

String? _last4(String? value) {
  final match = RegExp(r'(\d{4})$').firstMatch(value?.trim() ?? '');
  return match?.group(1);
}

int _categoryId(String? value, TransactionKind kind) {
  if (kind == TransactionKind.transfer) return 12;
  final key = _headerKey(value ?? '');
  final category = defaultCategories
      .where(
        (item) => _headerKey(item.name) == key && item.kinds.contains(kind),
      )
      .firstOrNull;
  return category?.id ?? 13;
}

String _issueCode(String message) {
  if (message.startsWith('source_record_id')) return 'missing_source_record_id';
  if (message.startsWith('transaction_date')) return 'invalid_date';
  if (message.startsWith('description')) return 'missing_description';
  if (message.startsWith('amount') || message.startsWith('Only one debit')) {
    return 'invalid_amount';
  }
  if (message.startsWith('transaction_type')) return 'invalid_type';
  if (message.startsWith('institution')) return 'missing_institution';
  if (message.startsWith('instrument_type')) return 'invalid_instrument';
  if (message.startsWith('Only INR')) return 'unsupported_currency';
  return 'invalid_row';
}
