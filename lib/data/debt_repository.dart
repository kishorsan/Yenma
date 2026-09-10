import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/debt.dart';
import '../domain/money.dart';

Future<void> createDebtSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE debts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id INTEGER REFERENCES transactions(id) ON DELETE RESTRICT,
    person TEXT NOT NULL CHECK(length(trim(person)) > 0),
    title TEXT NOT NULL CHECK(length(trim(title)) > 0),
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0 AND amount_paise <= 999999999999),
    direction TEXT NOT NULL CHECK(direction IN ('owedToMe','iOwe')),
    date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
    has_receipt INTEGER NOT NULL DEFAULT 0 CHECK(has_receipt IN (0,1)))''');
  // Small rows avoid Android CursorWindow limits for large screenshots.
  await db.execute('''CREATE TABLE debt_receipt_chunks (
    debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL, bytes BLOB NOT NULL CHECK(length(bytes) <= 262144),
    PRIMARY KEY(debt_id, chunk_index))''');
  await db.execute('CREATE INDEX debts_transaction ON debts(transaction_id)');
  await db.execute('''CREATE TABLE repayments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '')''');
  await db.execute('CREATE INDEX repayments_debt ON repayments(debt_id)');
}

Future<void> createPeopleSchema(DatabaseExecutor db) async {
  await db.execute(
    '''CREATE TABLE debt_people (
    name_key TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) > 0))''',
  );
  final existing = await db.query(
    'debts',
    columns: ['person'],
    orderBy: 'id ASC',
  );
  final batch = db.batch();
  for (final row in existing) {
    final name = normalizePersonName(row['person'] as String);
    if (name.isNotEmpty) {
      batch.insert('debt_people', {
        'name_key': personNameKey(name),
        'name': name,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
  await batch.commit(noResult: true);
}

mixin SqliteDebtOperations implements DebtRepository {
  Database get debtDatabase;
  @override
  Future<List<String>> people() async => (await debtDatabase.query(
    'debt_people',
    orderBy: 'name_key ASC',
  )).map((row) => row['name'] as String).toList();
  Future<int> writeTransaction(
    DatabaseExecutor db,
    MoneyTransaction transaction,
  );

  @override
  Future<List<DebtRecord>> debts() async =>
      (await debtDatabase.rawQuery('''
    SELECT d.id, d.transaction_id, d.person, d.title, d.amount_paise, d.direction,
      d.date, d.note, d.has_receipt,
      COALESCE(SUM(r.amount_paise), 0) AS repaid_paise
    FROM debts d LEFT JOIN repayments r ON r.debt_id = d.id
    GROUP BY d.id ORDER BY d.date DESC, d.id DESC'''))
          .map(DebtRecord.fromRow)
          .toList();

  @override
  Future<MoneyTransaction?> transactionById(int id) async {
    final rows = await debtDatabase.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : MoneyTransaction.fromRow(rows.single);
  }

  @override
  Future<void> saveDebt(DebtDraft draft) async {
    await debtDatabase.transaction((db) => _writeDebt(db, draft));
  }

  @override
  Future<void> saveSharedExpense(
    MoneyTransaction transaction,
    DebtDraft draft,
  ) async {
    if (draft.id != null || transaction.kind != TransactionKind.expense) {
      throw const DebtValidationException(
        'Only an expense can have a new friend’s share.',
      );
    }
    await debtDatabase.transaction((db) async {
      final id = await writeTransaction(db, transaction);
      await _writeDebt(db, draft.linkedTo(id));
    });
  }

  Future<void> _writeDebt(DatabaseExecutor db, DebtDraft draft) async {
    if (draft.person.trim().isEmpty ||
        draft.person.trim().length > 80 ||
        draft.title.trim().isEmpty ||
        draft.title.trim().length > 120 ||
        draft.amountPaise <= 0 ||
        draft.amountPaise > 999999999999 ||
        draft.note.length > 2000 ||
        draft.date.year < 1900 ||
        draft.date.year > 2100) {
      throw const DebtValidationException(
        'Enter a name, description and valid positive amount.',
      );
    }
    if (draft.receipt != null &&
        (draft.receipt!.isEmpty || draft.receipt!.length > maxReceiptBytes)) {
      throw const DebtValidationException(
        'Choose an image smaller than 10 MB.',
      );
    }
    if (draft.id != null) {
      final existing = await db.query(
        'debts',
        columns: ['transaction_id', 'direction'],
        where: 'id = ?',
        whereArgs: [draft.id],
      );
      if (existing.isEmpty) {
        throw const DebtValidationException('This debt no longer exists.');
      }
      if (existing.single['transaction_id'] != draft.transactionId ||
          existing.single['direction'] != draft.direction.name) {
        throw const DebtValidationException(
          'The linked payment and direction cannot be changed.',
        );
      }
      final paid = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_paise),0) AS total FROM repayments WHERE debt_id = ?',
        [draft.id],
      );
      if (draft.amountPaise < (paid.single['total'] as int)) {
        throw const DebtValidationException(
          'The share cannot be less than the repayments already recorded.',
        );
      }
      final earlier = await db.query(
        'repayments',
        columns: ['id'],
        where: 'debt_id = ? AND date < ?',
        whereArgs: [draft.id, dateKey(draft.date)],
        limit: 1,
      );
      if (earlier.isNotEmpty) {
        throw const DebtValidationException(
          'The debt date must be on or before its first repayment.',
        );
      }
    }
    if (draft.transactionId != null) {
      final transactions = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [draft.transactionId],
      );
      if (transactions.isEmpty ||
          transactions.single['kind'] != 'expense' ||
          draft.direction != DebtDirection.owedToMe) {
        throw const DebtValidationException(
          'Only an expense you paid can have amounts owed to you.',
        );
      }
      final other = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_paise),0) AS total FROM debts WHERE transaction_id = ? AND id != ?',
        [draft.transactionId, draft.id ?? -1],
      );
      final available =
          (transactions.single['amount_paise'] as int) -
          (other.single['total'] as int);
      if (draft.amountPaise > available) {
        throw DebtValidationException(
          'All shares together cannot exceed the payment. Available: ${formatMoney(available)}.',
        );
      }
    }
    final name = normalizePersonName(draft.person);
    await db.insert('debt_people', {
      'name_key': personNameKey(name),
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final row = <String, Object?>{
      'transaction_id': draft.transactionId,
      'person': name,
      'title': draft.title.trim(),
      'amount_paise': draft.amountPaise,
      'direction': draft.direction.name,
      'date': dateKey(draft.date),
      'note': draft.note.trim(),
      if (draft.receipt != null || draft.removeReceipt)
        'has_receipt': draft.removeReceipt ? 0 : 1,
    };
    final int id;
    if (draft.id == null) {
      id = await db.insert('debts', row);
    } else {
      id = draft.id!;
      await db.update('debts', row, where: 'id = ?', whereArgs: [draft.id]);
    }
    if (draft.receipt != null || draft.removeReceipt) {
      await db.delete(
        'debt_receipt_chunks',
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      if (!draft.removeReceipt && draft.receipt != null) {
        final bytes = draft.receipt!;
        final batch = db.batch();
        for (var offset = 0; offset < bytes.length; offset += 262144) {
          final end = offset + 262144 < bytes.length
              ? offset + 262144
              : bytes.length;
          batch.insert('debt_receipt_chunks', {
            'debt_id': id,
            'chunk_index': offset ~/ 262144,
            'bytes': Uint8List.sublistView(bytes, offset, end),
          });
        }
        await batch.commit(noResult: true);
      }
    }
  }

  @override
  Future<void> deleteDebt(int id) async {
    await debtDatabase.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Uint8List?> debtReceipt(int id) async {
    final rows = await debtDatabase.query(
      'debt_receipt_chunks',
      columns: ['bytes'],
      where: 'debt_id = ?',
      whereArgs: [id],
      orderBy: 'chunk_index ASC',
    );
    if (rows.isEmpty) return null;
    final builder = BytesBuilder(copy: false);
    for (final row in rows) {
      builder.add(row['bytes'] as Uint8List);
    }
    return builder.takeBytes();
  }

  @override
  Future<List<Repayment>> repayments(int debtId) async =>
      (await debtDatabase.query(
        'repayments',
        where: 'debt_id = ?',
        whereArgs: [debtId],
        orderBy: 'date DESC, id DESC',
      )).map(Repayment.fromRow).toList();

  @override
  Future<void> addRepayment(
    int debtId,
    int amountPaise,
    DateTime date,
    String note,
  ) async {
    await debtDatabase.transaction((db) async {
      final debts = await db.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      if (debts.isEmpty) {
        throw const DebtValidationException('This debt no longer exists.');
      }
      final paid = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_paise),0) AS total FROM repayments WHERE debt_id = ?',
        [debtId],
      );
      final remaining =
          (debts.single['amount_paise'] as int) - (paid.single['total'] as int);
      if (amountPaise <= 0 || amountPaise > remaining) {
        throw DebtValidationException(
          'Enter a repayment between ₹0.01 and ${formatMoney(remaining)}.',
        );
      }
      if (date.year < 1900 ||
          date.year > 2100 ||
          dateKey(date).compareTo(debts.single['date'] as String) < 0 ||
          dateKey(date).compareTo(dateKey(DateTime.now())) > 0 ||
          note.length > 2000) {
        throw const DebtValidationException(
          'Repayment date must be between the debt date and today.',
        );
      }
      await db.insert('repayments', {
        'debt_id': debtId,
        'amount_paise': amountPaise,
        'date': dateKey(date),
        'note': note.trim(),
      });
    });
  }

  @override
  Future<void> deleteRepayment(int id) async {
    await debtDatabase.delete('repayments', where: 'id = ?', whereArgs: [id]);
  }
}
