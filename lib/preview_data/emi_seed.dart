import '../data/money_repository.dart';
import '../models/commitments/emi.dart';
import 'preview_dates.dart';

/// Creates owned and pass-through EMIs with paid and pending installments.
Future<void> seedEmiPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final laptopId = await repository.saveEmi(
    EmiRecord(
      name: 'Laptop EMI',
      principalPaise: 9000000,
      processingFeePaise: 99900,
      billingDay: 5,
      startDate: addPreviewMonths(anchor, -4),
      endDate: addPreviewMonths(anchor, 7),
      note: '12-month no-cost EMI',
    ),
  );
  for (var monthsAgo = 2; monthsAgo >= 0; monthsAgo--) {
    await repository.saveEmiInstallment(
      emiId: laptopId,
      principalPaise: 750000,
      interestPaise: 0,
      date: previewMonthDay(anchor, -monthsAgo, 5),
      isPaid: monthsAgo > 0 || anchor.day >= 5,
    );
  }

  final phoneId = await repository.saveEmi(
    EmiRecord(
      name: 'Phone EMI for Rahul',
      principalPaise: 4800000,
      processingFeePaise: 49900,
      billingDay: 20,
      startDate: addPreviewMonths(anchor, -2),
      endDate: addPreviewMonths(anchor, 9),
      note: 'Pass-through purchase; Rahul transfers the instalment',
      ownership: EmiOwnership.throughMe,
    ),
  );
  await repository.saveEmiInstallment(
    emiId: phoneId,
    principalPaise: 400000,
    interestPaise: 18000,
    date: previewMonthDay(anchor, -1, 20),
    isPaid: true,
  );
  await repository.saveEmiInstallment(
    emiId: phoneId,
    principalPaise: 400000,
    interestPaise: 16500,
    date: previewMonthDay(anchor, 0, anchor.day < 20 ? anchor.day : 20),
    isPaid: false,
  );
}
