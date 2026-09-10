# Yenma implementation status

Initial increment: 11 September 2026. Project: `C:\Personal\projects\Yenma`.

## Saved people — 0.2.2+4

Debt and transaction split forms now suggest locally saved people. Empty fields show saved names, typing filters them, and selecting a suggestion fills the field. New names remain supported. Matching normalizes capitalization and whitespace. Schema 3 adds a persistent people registry, populated from existing debts on upgrade; names remain available after debt settlement or deletion. Failed saves do not add names. Validation: 26 unit/widget/repository tests passed; static analysis clean.

## Debt increment — 0.2.0+2

UI update **0.2.1+3**: random launch-only welcome quote with immediate skip and automatic two-second dismissal; compact page headings and toolbars; existing Settings heading preserved. Amount typography and financial behavior are unchanged. Screen-reader navigation keeps the welcome screen until the user continues. Validation: 21 unit/widget/repository tests passed, including welcome lifecycle checks.

Debt management is implemented: linked expense shares, standalone IOUs in either direction, person totals, notes, persistent image attachments, partial/full repayment history, corrections and copied reminders. SQLite now uses schema 2 with a non-destructive 1→2 migration. See [Debt management](debt_management.md) for behavior, source files and tests. The initial increment below records the foundation for this feature.

## Initial increment delivered

- Flutter Android app, display name Yenma, package `com.kiki.yenma`, version 0.1.0+1.
- Central light/dark/system themes, with the selected mode persisted locally.
- SQLite schema version 1: categories, transactions and settings; foreign-key enforcement, date index and 13 seeded categories from Money.
- Typed expense/income/transfer model; INR amounts parsed and stored in integer paise; explicit category eligibility metadata.
- Transaction creation, month list, details, editing and confirmed deletion. Forms validate amounts, required title/category and preserve content on failed writes.
- Monthly expense/income/net-cash-flow summaries, top three expense categories, five recent entries and full month history. Stable date/ID ordering. Transfers do not affect expense/income/net calculations.
- Month selection, current-month shortcut (tap month label), refresh, empty/loading/retry states and protection against out-of-order month query responses.

## Architecture delivered

`lib/domain/money.dart` owns money/date rules and models. `lib/data/money_repository.dart` defines the persistence interface and SQLite implementation. `lib/app/money_controller.dart` coordinates presentation state. `lib/features/` contains the overview/list/settings shell and transaction form/detail screens.

Constructor injection and ChangeNotifier/ListenableBuilder are used for this first increment. SQLite uses sqflite; formatting uses intl. Installed versions are recorded in pubspec.lock. Schema version 1 is a fresh Yenma schema, not a Room version-8 migration.

## Scope still pending

Category management beyond the seeded pickers, journal, SMS import and sender tracking, data migration from Money, export/backup/restore, general preferences beyond theme, today's spending, dynamic Android colors, plans and dedicated analytics remain future increments. No placeholder buttons claim to perform them. Receiver and SMS provenance will need explicit schema/model decisions when those workflows are introduced.

Yenma is installed separately from Money and starts with an empty ledger. It does not access or migrate the old application's private database. All current transaction values are INR. No exchange conversion or account-balance ledger is implied by the net cash-flow summary.

## Validation

- Flutter 3.47.2 / Dart 3.13.2 on the existing local toolchain.
- Unit checks for exact decimal parsing, formatting, expense-only aggregation and date handling.
- SQLite integration checks for creation/seeding, restart persistence, update/delete, preferences, leap-day/month boundaries, stable ordering and invalid-write rejection.
- Widget checks for create/edit/delete, canceled deletion, validation and failed-save content retention.
- Controller check for stale month-query responses.
- Light/dark screenshots generated with synthetic records under `docs/previews/`; these are not the user's financial data. Preview script is `tool/preview_test.dart` and is run separately from normal tests.
- Android debug APK built and launched on the existing Pixel 7 / API 35 emulator; initial screen inspected and AndroidRuntime log checked for launch crashes. This is a launch smoke test, not a full device-level CRUD test.

The local doctor reports missing Android command-line tools and unknown license status, although the installed Gradle/SDK components successfully built this APK. Release signing is still the generated debug configuration and must be configured before distribution.

## Next increment

Implement category create/edit/hide, including user-category eligibility and preservation of categories referenced by historical transactions. Then add journal workflows before the Android SMS adapter and parser work. Define the data migration route before replacing an installed Money app.

