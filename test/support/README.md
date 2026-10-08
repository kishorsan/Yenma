# Synthetic transaction dataset

`transaction_dataset.dart` generates 75 transactions: lunch, bus commute, groceries, freelance income and savings transfer for each of seven days before an anchor date, the anchor date, and seven days after it. Pass `DateTime.now()` for a rolling window. The regression suite uses 1 September 2026 to also exercise a month boundary.

These fixtures are imported only by tests, are not app assets, and are never seeded into the user's database or included in the release app. Tests create a separate temporary SQLite database and remove their own database afterward.

Run `flutter test test/recorded_transaction_debt_test.dart` for persistence, existing-payment debt creation through details/edit, and atomic rollback checks. Run `flutter test` for the full suite. No APK build is required.
