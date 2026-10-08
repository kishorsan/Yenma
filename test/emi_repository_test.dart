import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/data/money_repository.dart';

void main() {
  sqfliteFfiInit();

  test(
    'SQLite persists EMI direction, GST, fee, and remaining balance',
    () async {
      final directory = await Directory.systemTemp.createTemp('yenma_emi_');
      final repository = SqliteMoneyRepository(
        factory: databaseFactoryFfi,
        path: p.join(directory.path, 'money.db'),
      );
      addTearDown(() async {
        await repository.close();
        await directory.delete(recursive: true);
      });
      await repository.initialize();
      await repository.saveGstBasisPoints(1800);

      final id = await repository.saveEmi(
        EmiRecord(
          name: 'Pass-through phone',
          principalPaise: 100000,
          processingFeePaise: 9900,
          billingDay: 7,
          startDate: DateTime(2026, 10, 7),
          ownership: EmiOwnership.throughMe,
        ),
      );
      await repository.saveEmiInstallment(
        emiId: id,
        principalPaise: 25000,
        interestPaise: 1000,
        date: DateTime(2026, 10, 7),
        isPaid: true,
      );

      final emi = (await repository.emis()).single;
      final installment = (await repository.emiInstallments(id)).single;
      expect(emi.ownership, EmiOwnership.throughMe);
      expect(emi.processingFeePaise, 9900);
      expect(emi.remainingPaise, 75000);
      expect(installment.gstPaise, 180);
    },
  );
}
