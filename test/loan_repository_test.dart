import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/data/money_repository.dart';

void main() {
  sqfliteFfiInit();

  test(
    'SQLite keeps loans separate from EMIs and updates paid principal',
    () async {
      final directory = await Directory.systemTemp.createTemp('yenma_loan_');
      final repository = SqliteMoneyRepository(
        factory: databaseFactoryFfi,
        path: p.join(directory.path, 'money.db'),
      );
      addTearDown(() async {
        await repository.close();
        await directory.delete(recursive: true);
      });
      await repository.initialize();

      final loanId = await repository.saveLoan(
        LoanRecord(
          name: 'Vehicle loan',
          totalAmountPaise: 500000,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2027, 10, 1),
          type: LoanType.emiAmortizing,
        ),
      );
      await repository.saveEmi(
        EmiRecord(
          name: 'Phone EMI',
          principalPaise: 100000,
          billingDay: 8,
          startDate: DateTime(2026, 10, 1),
        ),
      );
      await repository.saveLoanPayment(
        LoanTrackingRecord(
          loanId: loanId,
          principalPaise: 125000,
          interestPaise: 10000,
          gstPaise: 500,
          date: DateTime(2026, 10, 8),
          isPaid: true,
        ),
      );

      final loan = (await repository.loans()).single;
      final payment = (await repository.loanPayments(loanId)).single;
      expect(loan.name, 'Vehicle loan');
      expect(loan.remainingPaise, 375000);
      expect(payment.interestPaise, 10000);
      expect(payment.gstPaise, 500);
      expect(await repository.emis(), hasLength(1));
    },
  );
}
