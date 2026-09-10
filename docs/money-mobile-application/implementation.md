# Money Mobile Application — implementation

## Objective and baseline

Rewrite the existing Kotlin app in Flutter one feature at a time, preserving useful behavior and data while correcting confirmed source defects. This document covers implementation planning only. See [features](features.md) for requirements and [architecture](software_architecture.md) for component/data contracts.

The reviewed working tree contains active transaction, journal, category, sender-tracking and settings code, an on-demand SMS importer, and incomplete debt/planning/analytics/data-tool features. No Android build or device test was run for this documentation task. The two existing test files only check arithmetic and the application package name; they do not establish feature correctness.

## Findings to account for before porting

| ID | Evidence | Implication and Flutter action |
| --- | --- | --- |
| R01 | Transaction.kt requires receiver; AddTransactionScreen.kt and SmsViewModel.kt omit it | Source-level constructor mismatch. Define receiver semantics/defaults and cover both creation paths. |
| R02 | DatabaseModule.kt contains empty Migration subclasses, no 7→8 migration and destructive fallback; MoneyDatabase is version 8 | Placeholder subclasses omit the required migration implementation, indicating a build blocker; historical upgrade safety is unproven. Create explicit migration fixtures and never copy destructive fallback into the rewrite. |
| R03 | SmsReader.kt suppresses equal amount/date candidates | Legitimate transactions can be lost. Replace with stable message identity and storage uniqueness. |
| R04 | SMS parser uses first currency amount, broad keyword matching and literal `transfered` | Misclassification/incorrect amount possible. Introduce test cases, explicit confidence/rejection rules and reviewable results. |
| R05 | SMS limit checks equality with 2026-01-01 | Older messages can still be scanned/imported. Use a real bounded timestamp query and checkpoint. |
| R06 | MainActivity permission callback only displays a toast; navigation proceeds immediately | Import can begin before permission resolves. Await permission outcome before retrieval. |
| R07 | SmsViewModel uses categoryId 2 | Imported transactions become Groceries. Use a deliberate import/uncategorized mapping. |
| R08 | HomeScreen totals today's all types, top category all types; home rows have ineffective callback | Expense totals and navigation can mislead. Centralize typed calculations and implement ID navigation. |
| R09 | Entry/edit category grids filter seeded IDs | Custom categories are unavailable to entry workflows. Store eligibility explicitly. |
| R10 | TransactionEditScreen copies fields without isEdited | SMS edit provenance is incomplete. Preserve raw source and set edited metadata. |
| R11 | TransactionDao date-range arguments are Long, stored dates String; all-transactions query is unordered | Normalize date contract and sort explicitly. |
| R12 | Repository.exists performs insertion; duplicate TransactionUiState definitions exist | Remove misleading/duplicate contracts rather than translating them mechanically. |
| R13 | Entity references have no declared foreign keys; custom categories can be deleted | Validate historical references and prevent new orphan records. |
| R14 | SettingsViewModel export/backup/clear methods contain TODOs but emit success messages | Implement real operations and failure states; never retain false-success behavior. |
| R15 | Some settings are persisted without global consumers | Connect each supported setting to observable behavior or defer its control. |
| R16 | DebtScreen, DebtRepository and DebtViewModel are empty; planned/analytics routes unregistered | Track these as new feature work after core parity. |

R01/R02 are static findings, not compiler output. Other build issues may remain. The reference working tree has uncommitted changes, so retain its provenance when selecting a reproducible baseline.

## Delivery sequence

Each phase produces a reviewable increment and passes its exit checks before dependent work begins. Phase numbering expresses dependencies, not calendar estimates.

| Phase | Work | Dependencies | Exit checks |
| --- | --- | --- | --- |
| 0 — Baseline | Capture reproducible source snapshot, collect screen references on a working build if available, agree corrected behaviors, choose Android identity/data-transfer strategy | Documentation review | Feature/status inventory accepted for implementation; fixtures contain no personal SMS; existing data preservation route recorded |
| 1 — Foundation | Scaffold Flutter, select/pin toolchain and packages, compose dependencies, theme tokens, routes, loading/error/empty states | 0 | App launches on Android; navigation/back works; light/dark/system behavior verified; analyze and foundational tests pass |
| 2 — Storage and categories | Versioned schema, typed money/date/kind models, repositories, seeds, category management and preference storage | 1 | Persistence/restart, migrations and seed idempotency pass; category references remain valid; custom categories are selectable |
| 3 — Manual transactions | Add/list/detail/edit/delete, month selection, validation and deterministic sorting | 2 | Full CRUD passes after restart; invalid amounts/dates rejected; missing IDs and write errors handled; canceled deletion preserves data |
| 4 — Dashboard | Shared monthly/today totals, category summary, feed and working detail navigation | 3 | Hand-calculated income/expense/transfer fixture matches all totals; empty month and date rollover verified |
| 5 — Journal | List/new/view/edit/delete with explicit state and failure handling | 2, foundation routes | Complete lifecycle persists; edit preserves intended timestamp; confirmation and unsaved content behavior verified |
| 6 — Preferences | Apply formatting, visibility and supported appearance settings; database-derived statistics | 3–5 | Every exposed preference has a visible effect and survives restart; currency semantics avoid relabeling financial value |
| 7 — Sender tracking and SMS | Sender seeds/toggles, Android gateway, permission sequence, Dart parser, stable dedupe, batched import/checkpoint, retry/results | 2–4 | Device permission matrix passes; repeat import adds zero duplicates; same-amount/day messages survive; failures/retries do not lose or overwrite entries |
| 8 — Data transfer and tools | Actual archive export/import, CSV export, validated restore, real clear-data and preference reset | 2–7 | Archive round-trip preserves entities/references/preferences; invalid archives leave data intact; file-write errors never report success |
| 9 — Additional features | Debt workflows, planned spending and dedicated analytics as separate increments | Core parity and defined business rules | Each gets explicit requirements, schema migration and feature tests; no empty destinations ship |
| 10 — Release validation | Rehearse chosen upgrade/import, performance, accessibility and release packaging; review distribution requirements | All selected release phases | Device workflows pass; migrated counts/totals reconcile; release installation works; no data-destroying fallback |

Phases 5 and parts of 6 can be implemented after their own dependencies without waiting for SMS. Phase 8 is a release prerequisite whenever existing user data must move into the new application. Phase 9 is optional expansion rather than a prerequisite for a core-parity release. Auto-backup scheduling is a separate phase-8 increment requiring working restore first.

## First implementation slice

After agreeing the baseline, the first code delivery should be the Flutter shell, central theme, local schema and seeded categories, followed by one complete vertical workflow: create a manual expense and observe it in a persisted transaction list. This proves the app's structure and data flow before importing the more error-prone SMS behavior.

Deliverables for that slice: app source, pinned dependency lockfile, developer run instructions, schema migration version, synthetic fixture, relevant tests and a concise result report. Preserve the Kotlin reference for comparison.

## Verification strategy

| Area | Required scenarios |
| --- | --- |
| Money and dates | 0.10 + 0.20 exactly in minor units; invalid/zero/negative entry; rounding legacy values; month/year boundaries; leap day; timezone change for date-only values |
| Aggregation | Expense 100 + income 500 + transfer 200 gives expense 100, income 500 and net cash-flow summary 400 when defined as income minus expense; transfer excluded from expense/category totals |
| Repository integrity | Reopen after writes; hide referenced category; reject/resolve orphan import; missing record; failed write preserves UI content |
| SMS parser | Income, expense, ambiguous credit-card wording, multiple amounts, malformed amount, unsupported sender, missing suffix, T/S suffix, transfer spelling variants and non-transaction SMS |
| SMS import | Same amount/day different messages; duplicate within/across batches; import interrupted before/after commit; retry; permission denied/revoked; zero tracked groups; bounded historical scan |
| Migration | Fixture for every actually supported source schema; all IDs/references preserved or mapped; normalized kind/currency/date; counts and per-kind totals reconciled; rollback on invalid source |
| UI | CRUD, confirmation, missing detail, empty month, large font, light/dark contrast, keyboard/form layout, back behavior and screen reader labels |
| Files | CSV commas/quotes/newlines; spreadsheet-formula-safe text handling; valid versioned archive; malformed/unsupported archive; canceled file action; insufficient storage |

Use unit tests for pure rules, database integration tests for persistence/migrations, widget tests for state and forms, and device integration tests for permission/platform behavior. Run Flutter formatting, static analysis and the relevant test suite for each increment. A later release pass should measure a representative large transaction/SMS fixture without logging message bodies.

## Existing-data transfer procedure

1. Identify the installed database version and whether this is an in-place upgrade or a separate app. Do not assume the repository's version-8 declaration matches an installed device.
2. Create and validate a backup/export using a real implemented path. Avoid treating the current success snackbar as a backup.
3. Load into staging; validate required fields, record counts, references, supported enums and currencies. Record recoverable discrepancies for review.
4. Convert Double amounts with a documented rounding rule, normalize legacy kinds and preserve date-only values. Preserve original SMS provenance and edit information where available.
5. Compare original and transformed counts and per-type/per-month totals. Investigate differences rather than silently discarding rows.
6. Commit atomically, record migration version and verify reopening. Keep source/backup available for recovery; do not delete it as a side effect of importing.

## Decisions required at the relevant phase

- Before app creation: final Flutter app name/location, Android-first scope and whether package/signing continuity is needed.
- Before schema finalization: receiver meaning, historical currency, category type eligibility and whether “accounts” remain sender groups.
- Before SMS implementation: intended import date range, uncertain-message review policy, raw-body retention and actual distribution channel.
- Before additional features: debt settlement accounting, planned-to-paid conversion, analytic measures and budget semantics.

These are implementation decision points, not a request to resolve every item before reviewing this documentation. No feature migration has started yet.
