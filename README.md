# Yenma

An offline Flutter money tracker, rebuilt step by step from the Kotlin Money application.

## First increment

- Add, view, edit and delete expenses, income and transfers.
- Monthly spending, income, net cash flow and expense-category summaries.
- SQLite persistence and the original 13 category choices.
- Exact INR amounts stored in paise.
- Light, dark and system appearance with a saved preference.

Android app ID: `com.kiki.yenma`. This is a separate app with an empty ledger; existing Money data has not been imported.

## Debt management (0.2.0)

- Split a new expense with a friend or attach multiple shares to an existing payment.
- Track IOUs in both directions, grouped by person, with outstanding and settled history.
- Attach notes and a receipt/UPI screenshot; view, replace or remove the image.
- Record partial/full repayments and undo mistakes.
- Copy a reminder with a person's outstanding total for sharing yourself.
- Upgrade existing Yenma data without resetting transactions or preferences.

See [Debt management](docs/money-mobile-application/debt_management.md) for the ₹500 meal example and accounting rules. The dashboard shows gross spending; shares and repayments are tracked separately.

## Run

On a fresh launch, Yenma briefly shows a random welcome quote (two seconds, or skip with **Open my money**). It does not reappear while switching pages or resuming the app. Page headers are compact so payment information stays prominent; the Settings heading is unchanged. Screen-reader users continue manually so the quote does not disappear while being read.

Verified with Flutter 3.47.2 / Dart 3.13.2. Open this folder in Android Studio or VS Code with Flutter support, start an Android emulator or connect a device, then:

```powershell
flutter pub get
flutter run
```

## Verify and build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. The generated release configuration still uses debug signing; this is a development build, not a store release.

The local machine's Android toolchain has missing command-line tools/unknown license status according to Flutter doctor, but the APK builds with the currently installed SDK and Gradle components.

## Structure

- `lib/app/`: app composition, theme and presentation controller.
- `lib/domain/`: transaction/category models, exact money parsing and summaries.
- `lib/data/`: repository contract, SQLite schema and persistence.
- `lib/features/`: overview/history/settings and transaction screens.
- `test/`: domain, SQLite persistence, state-race and widget workflow tests.
- `tool/preview_test.dart`: optional screenshot generation with synthetic data.

Saved people appear as suggestions in **Add debt** and **Split with a friend**. Tap the name field to choose someone, type to filter, or enter a new name. Names from existing debts are included automatically and remain available after settlement or deletion. Matching ignores capitalization and extra spaces.

The database is `yenma.db`, schema version 3, in the app's private database directory. Versions 1 and 2 upgrade automatically to version 3. Every future schema change needs an explicit migration. INR is the supported currency.

## Documentation

- [Current Flutter features, use cases, and problems solved](docs/flutter-features.md) — source-reviewed inventory, platform limits, and questions about product intent.
- [Reference documentation](docs/money-mobile-application/README.md)
- [Implementation status and remaining work](docs/money-mobile-application/implementation_status.md)
- [Flutter implementation plan](docs/money-mobile-application/implementation.md)
- [Software architecture](docs/money-mobile-application/software_architecture.md)
- [Feature inventory](docs/money-mobile-application/features.md)
- [Debt management](docs/money-mobile-application/debt_management.md)

Upcoming: category management, journal, SMS import, and real data export/migration. See the status document for the full scope.

Persistence approach: [Flutter SQLite cookbook](https://docs.flutter.dev/cookbook/persistence/sqlite).
