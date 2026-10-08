# Yenma Flutter implementation progress

Last reviewed: 3 October 2026 against the current Flutter working tree, including uncommitted Dart changes.

This is a living implementation record for the Flutter application. It deliberately does not use the separate Kotlin Money application or `docs/money-mobile-application` as evidence. Platform-channel behavior is described only through its Dart interface and remains unverified on a device unless a later entry explicitly records device verification.

## Status language

The following labels are used throughout this document:

- **Implemented**: supported by current Flutter source, including working-tree changes.
- **Inferred**: a likely product benefit or relationship derived from source or design context, but not directly confirmed by the product owner.
- **Unresolved**: a product or interaction decision that still needs confirmation.
- **Planned**: explicitly requested or accepted direction that is not yet fully implemented in Flutter.

## Confirmed product and navigation requirements

These requirements come from the current product conversation and supplied UI plan:

- **Planned:** The primary phone bottom navigation has four destinations, in this order: **Home**, **Card Specific Transactions**, **Categorize**, and **Settings**. Settings is the last icon.
- **Planned:** Home presents six priority-feature shortcuts in a 2-by-3 grid rather than adding six destinations to the bottom bar.
- **Planned:** The Home shortcut order is:
  1. Plan
  2. Split
  3. Subscriptions
  4. EMI
  5. Loan
  6. Debt
- **Planned:** Home has an SMS transaction sync action at the top-right. The action must expose busy, success, permission-denied, and failure states and must not start overlapping syncs.
- **Planned:** Home includes horizontally presented bank/card summaries above the six priority shortcuts, following the supplied wireframe.
- **Planned:** Implementation is design-first for every screen: establish the screen composition and its loading, empty, populated, selected, disabled, saving, and error states before completing its data wiring.
- **Planned:** The initial visual language is grey-themed.
- **Planned:** Colors are allocated dynamically through semantic theme tokens. Screens must not depend on arbitrary grey literals. Future light, dark, and other palettes must be able to replace the token values without rewriting feature widgets.
- **Planned:** Light and dark appearances are real palettes, not post-processing filters.
- **Planned:** Wide layouts continue to receive an appropriate navigation treatment rather than stretching the phone bottom bar.

## Current implemented baseline

### Application shell and appearance

- **Implemented:** [`HomeScreen`](../lib/features/home_screen.dart) now exposes the requested four destinations in order: Home, Cards, Categorize, and Settings. On narrow layouts it uses a `NavigationBar`; at 700 logical pixels or wider it uses a labeled `NavigationRail` in the same order.
- **Implemented:** Home shows the monthly summary, recognized-bank carousel, six-feature shortcut grid, monthly-plan progress when applicable, category breakdown, and recent transactions.
- **Implemented:** Home intentionally has no previous/next month control. Month navigation remains available in Card Specific Transactions. Both destinations share the controller's selected month, so changing month in Cards can change the month Home displays after returning; the requirement implemented here is removal of the Home control, not forced pinning of Home to today's month.
- **Implemented:** The six shortcuts appear in the confirmed order: Plan, Split, Subscriptions, EMI, Loan, and Debt.
- **Implemented:** Plan opens the working monthly-plan flow and Debt opens the existing debt area with its add-debt action.
- **Implemented:** Split opens its functional group and conversational-history flow. Subscriptions, EMI, and Loan still open reusable [`FeatureLandingScreen`](../lib/features/feature_landing_screen.dart) layouts only and must not be described as functionally implemented.
- **Implemented:** Settings currently persists the choice among system, light, and dark theme modes.
- **Implemented:** [`yenmaTheme`](../lib/app/theme.dart) now supplies grey-first light and dark `ColorScheme` values and a semantic `YenmaColors` `ThemeExtension` for income, expense, transfer, success, warning, and hero-surface roles. Updated financial widgets consume these roles through `BuildContext` rather than selecting light/dark values locally.
- **Implemented limitation:** Category identity colors remain stored data and are still constructed with `Color(category.color)` where shown. This is intentional data-driven identity, but contrast across future palettes still requires verification. Not every pre-existing widget has completed a semantic-color audit.

### SMS synchronization

- **Implemented:** SMS sync is now a Home-only top-right action. It provides a first-use consent dialog, busy indicator, and completion/error snackbar, and is disabled until initialization is ready.
- **Implemented:** [`MoneyController`](../lib/app/money_controller.dart) prevents concurrent synchronization and refreshes the selected month after an import.
- **Implemented:** Initial sync and later-sync date-window rules, parser behavior, duplicate identity handling, and saved category lookup exist in Dart.
- **Implemented:** Requesting daily SMS scheduling during controller initialization is now non-blocking and best-effort. Flutter initialization continues when the scheduling platform channel is unavailable or throws; scheduling failure is not treated as proof that ledger initialization failed.
- **Unresolved:** Consent copy says messages are read when the user syncs, while controller initialization can request an automatic sync after 22:00 when consent is saved. The intended manual/automatic promise still needs product confirmation.
- **Unverified native behavior:** Reading messages and requesting scheduled work cross a platform channel. The Dart call is resilient, but no claim is made here about the native implementation, registration of scheduled work, timing, or actual background execution.

### Transactions, categorization, and bank/card data

- **Implemented:** The transaction ledger supports month navigation, add/edit/details/delete, income/expense/transfer types, receipt storage, and transaction-category summaries.
- **Implemented:** [`BulkCategorizationScreen`](../lib/features/bulk_categorization_screen.dart) is embedded as the third primary destination and manages one continuous recent transaction feed independently of the shared Home/Cards month state. It has no month selector.
- **Implemented:** The repository exposes `transactionsBetween(startInclusive, endExclusive)`. Its SQLite implementation performs one explicit `date >= ? AND date < ?` query ordered by date descending and then ID descending.
- **Implemented:** Categorize calls that range API with the previous calendar month's first day and tomorrow, making today inclusive while excluding earlier and future-dated records. The screen retains deterministic newest-date/highest-ID ordering and discards stale asynchronous loads by generation.
- **Implemented:** Selection is arbitrary rather than merchant-name grouped. The first selected transaction fixes the active transaction kind; any other rows of that kind may be selected individually, while other kinds are visually disabled to keep category choices valid.
- **Implemented:** A count-bearing bottom action chip animates into view through slide and opacity transitions. It opens a draggable/dismissible modal grid on semantic `surfaceContainer`/`surfaceContainerHigh` theme surfaces and filters categories by the selected kind.
- **Implemented:** Dismissing or dragging down the category sheet is a pause action: it does not clear the selected transaction IDs or kind. Tapping a category closes the sheet and starts the bulk update immediately; success clears selection, reloads the Categorize month, and reports the changed count. Failure retains the selection and presents retryable error feedback.
- **Implemented:** Category identity colors remain data-driven inside the otherwise grey semantic surfaces. Learned recipient categories continue through the existing bulk repository write.
- **Not implemented:** A distinct uncategorized-first filter, explicit select-all control, and categorized-history mode are not present.
- **Implemented foundation:** The schema contains canonical bank records and transaction `bank_id` references, including tracking and credit-card flags. SMS imports also preserve bank attribution.
- **Implemented:** SMS imports use the canonical `SmsParser.bankNames` institution map, then derive a distinct credit-card source name when card wording is recognized (for example, HDFC Bank → HDFC Credit Card and ICICI Bank → ICICI Credit Card). Imports retain a masked four-digit instrument identity when present and classify purchases, account debits/credits, and card-bill payments. HDFC purchase, successful AutoPay, card-payment, account debit/credit, and pending-debit formats have regression coverage; generic instrument rules also have ICICI and SBI coverage. Exact formats from other banks remain unverified until representative messages are available.
- **Implemented:** [`CardTransactionsScreen`](../lib/features/card_transactions_screen.dart) is the second primary destination. It uses only credit-card transactions, groups choices by bank plus masked card identity, shows the filtered expense total and count, supports month navigation and refresh, and opens transaction details. Card-bill payments remain visible but are transfers and therefore do not inflate spending.
- **Implemented:** Home derives a horizontally scrollable bank-summary carousel from recognized `bankName` values. Each card shows monthly entry count and expense total; when no recognized bank is present, Home explains that SMS sync can populate the area. Tapping a summary opens the Cards destination, but does not yet carry that bank as the selected filter.
- **Implemented limitation:** Instrument identity is inferred from message wording and an optional masked suffix rather than managed through a user-facing account/card catalogue. Older imported HDFC rows cannot be safely reclassified because raw SMS bodies were not retained.
- **Unresolved:** A card-bill receipt and its corresponding bank debit are both transfers but are not automatically reconciled into one logical movement.

### Plan

- **Implemented:** [`MonthlyPlanScreen`](../lib/features/monthly_plan_screen.dart) provides a two-step future-month flow: expected salary followed by Investment, Savings, Loans, and Daily Spend allocations.
- **Implemented:** Plans can be loaded by month, revised, stored transactionally, and rejected when allocations exceed salary.
- **Implemented:** Home can show actual Daily Spend against the selected month's plan.
- **Implemented:** Repository and widget tests cover plan persistence, replacement, validation, and the two-step form.
- **Implemented:** Plan is now the first Home shortcut and opens the functional existing flow. Saving returns to Home and refreshes the viewed month's data.
- **Planned enhancement:** The flow still needs reconciliation with the Figma plan-card/list design and a full semantic-theme/visual-state review.
- **Unresolved:** Whether a plan may include income sources beyond salary and whether past/current-month plans should be editable are not established by the confirmed requirements.

### Split

- **Implemented:** Existing transaction forms can create a shared expense for one friend, and transaction details can add further friend shares. Linked debts, allocation limits, and navigation between a debt and its source transaction remain available.
- **Implemented:** The second Home shortcut opens reusable Split groups. Users can create a named group with saved people and an optional note, then open it as a newest-first conversational history.
- **Implemented:** Record Split supports participant inclusion, exact equal or custom INR shares, atomic validation, and an impersonation switch that selects another group member as payer. User-paid bubbles appear on the left and impersonated-payer bubbles on the right.
- **Implemented:** Group allocation persistence stores historical participant-name snapshots, payer direction, shares, and Debt links. User-paid entries create “Owed to me” debts for included friends; another-person-paid entries create only the user’s “I owe” share. Settlement display is derived from those Debt records, so obligations still have one authoritative balance.
- **Implemented boundary:** Group splits are standalone allocation records and do not create transaction-ledger expenses. Obligations involving two other group members are retained in the group history but do not become personal Debt records.
- **Not implemented:** Group/member editing, split editing/deletion, a direct settle action inside Split, and reconciliation with imported reimbursements remain outside this slice.

### Subscriptions

- **Implemented foundation:** [`commitments_data.dart`](../lib/data/commitments_data.dart) persists subscription name, positive amount, billing day 1–28, monthly/yearly period, active state, notification preference, and optional link.
- **Implemented — design shell only:** Subscriptions is the third Home shortcut and opens a themed landing structure for active subscriptions, upcoming billing dates, and subscription details. It has no list data, add/edit flow, activation behavior, provider-link action, or persistence wiring yet.
- **Unresolved:** Notification timing and delivery behavior are not defined. `notifyMe` storage alone does not establish working reminders.
- **Planned guardrail:** Tracking a subscription must not automatically create a ledger transaction unless a later, explicit reconciliation design prevents duplicate imported payments.

### EMI and Loan

- **Implemented foundation:** The commitments repository stores loans with principal, amount paid, dates, status, loan type, and EMI flag. Loan schedule entries store principal, interest, due date, and paid state.
- **Implemented foundation:** Saving a schedule entry recalculates cached paid principal transactionally and prevents paid principal from exceeding the loan total.
- **Implemented — design shells only:** EMI and Loan are the fourth and fifth Home shortcuts. Each opens a themed landing structure naming its intended sections. Neither shell has a feature controller, repository wiring, data entry, schedule actions, or functional detail views yet.
- **Inferred domain relationship:** Loan should own the overall borrowing, while EMI should present instalments across eligible loans. This relationship is consistent with the current schema but has not been separately confirmed as final product language.
- **Planned guardrail:** Marking an instalment paid should update the commitment schedule and should not silently add a ledger expense. Linking to an existing transaction is safer until reconciliation behavior is specified.

### Debt

- **Implemented:** Debt is already a complete Flutter area with both directions, grouped people, outstanding/settled views, search, partial/full repayments, repayment history, receipt images, reminders copied to the clipboard, and linked-transaction navigation.
- **Implemented:** Integrity rules protect transaction-linked shares, repayment totals, and linked transactions from contradictory edits/deletion.
- **Implemented:** Repayment eligibility compares normalized calendar dates rather than timestamps, so a debt dated today remains eligible regardless of its stored time of day.
- **Implemented:** Switching between Outstanding and Settled clears expanded-person state, preventing expansion from one filter from leaking into the other.
- **Implemented:** Debt has moved from the primary bottom navigation to the sixth Home shortcut. The shortcut opens the functional existing debt screen and preserves its add-debt entry point.
- **Planned enhancement:** Debt still needs a complete visual comparison against the supplied UI direction and semantic-token audit.
- **Inferred:** Debt should remain the canonical obligation/settlement record used by Split rather than being duplicated by a separate Split balance.

### Settings

- **Implemented:** Settings currently exposes theme selection and informational currency/local-storage/version content.
- **Implemented:** Settings is the fourth and final bottom-navigation destination in the redesigned shell.
- **Planned:** Future theme choices remain centrally controlled and locally persisted.
- **Unresolved:** Currency is currently fixed to INR; the presence of a currency information row does not establish editable multi-currency support.

## Implementation milestones

Milestones follow the user-visible priority while allowing shared foundations to be built before screens that depend on them.

| Milestone | Status | Planned outcome / remaining evidence |
| --- | --- | --- |
| M1: Theme foundation | **Implemented, verification remaining** | Grey-first light/dark `ColorScheme` and semantic `YenmaColors` roles are present. Complete the pre-existing-widget color audit and add representative theme/contrast tests. |
| M2: Shell and Home | **Implemented, verification remaining** | Four primary destinations, Home-only top-right SMS sync, bank carousel, ordered six-feature grid, and responsive rail are present. Add navigation/widget tests and visual checks for loading, empty, populated, busy, and error states. |
| M3: Card Specific Transactions | **Functional first slice** | Bank-name selection, selected-month total/list, month navigation, refresh, empty/error states, and transaction-detail reuse are present. Correct all-card scope/labeling, decide bank/account/card identity, preserve carousel selection when navigating, and add tests. |
| M4: Categorize | **Continuous-feed implementation verified** | One SQLite-backed inclusive-start/exclusive-end query covers the previous month's first day through today, excludes future dates, and returns date/ID descending order. Arbitrary same-kind multi-selection, animated action chip, dismissible category grid, selection preservation, immediate apply/reload, semantic surfaces, feedback, and retry state are present. The repository boundary and no-selector behavior pass focused and full-suite verification; uncategorized-first, select-all, and history remain absent. |
| M5: Plan | **Functional flow, redesign remaining** | Existing two-step plan flow and Home route work. Complete the plan-card/list design, selection/edit presentation, semantic visual review, and navigation tests. |
| M6: Split | **Functional first slice** | Group creation, newest-first chat history, equal/custom participant shares, payer impersonation, atomic persistence, Debt integration, and focused repository/widget tests are present. Group/split editing, direct settlement controls, and reimbursement reconciliation remain. |
| M7: Subscriptions | **Design shell; functional work planned** | Build active/inactive list, add/edit, billing period/day, provider link, upcoming ordering, and explicit tracking semantics with persistence and widget coverage. |
| M8: EMI and Loan | **Design shells; functional work planned** | Integrate the shared borrowing domain, EMI due list/status, and Loan overview/detail/schedule/history with arithmetic, integrity, and navigation tests. |
| M9: Debt integration | **Functional flow, visual integration remaining** | Debt is routed from Home priority six and correctness fixes are covered by the passing suite. Complete design/token alignment and shortcut/visual-state tests. |
| M10: Settings and regression | **Partially complete** | Settings is the final destination and the current slice passes analysis plus 47 tests. Responsive/accessibility polish, migration/end-to-end coverage, and any available device verification remain. |

## Verification for the current slice

- **Verified on 8 October 2026:** `flutter analyze` reports no issues with the final range-query Categorize implementation.
- **Verified on 8 October 2026:** The focused repository/categorization/navigation suite passes 14 of 14, including inclusive-start/exclusive-end repository boundaries and the absence of Categorize month controls.
- **Verified on 8 October 2026:** The full Flutter test suite passes 65 of 65.
- **Verified:** The two dedicated preview tests pass: 2 of 2.
- **Verified:** The targeted welcome tests pass: 3 of 3.
- **Verified:** [`home_navigation_test.dart`](../test/home_navigation_test.dart) asserts that Home has neither Previous month nor Next month tooltips and that the Cards destination retains both controls.
- **Verified:** Targeted analysis of `main-preview.dart`, `yenma_app.dart`, and `preview_entrypoint_test.dart` reports no issues.
- **Verified:** The focused interactive-preview entry-point tests pass: 2 of 2.
- **Not verified:** Native SMS reading and background scheduling behavior remain outside this Flutter-only verification pass.

## Runnable preview data and generated references

- **Implemented:** [`preview_test.dart`](../tool/preview_test.dart) provides a runnable golden-preview harness for both light and dark modes.
- **Implemented:** Its `TwoWeekPreviewRepository` seeds exactly eight SMS-style transactions attributed to one bank, HDFC Bank.
- **Implemented:** Fixture dates use offsets of 0, 2, 4, 6, 8, 10, 12, and 14 days before the day the preview is generated. This gives a deterministic every-other-day sample across the preceding two weeks through today while retaining a current-date anchor.
- **Implemented preview-only behavior:** The preview repository deliberately returns its complete fixture instead of applying production month filtering. All eight samples therefore remain visible on Home when the 14-day range crosses a calendar-month boundary. This behavior belongs only to the documentation preview and is not evidence that the production repository ignores month filters.
- **Generated:** Light and dark Home references are available at [`home-light.png`](previews/home-light.png) and [`home-dark.png`](previews/home-dark.png).
- **Generated:** The same preview run refreshed the light/dark welcome and debt references. Those screens use the shared fixture/run but the new one-bank, eight-transaction data is specifically intended to demonstrate Home.

### Interactive preview application

- **Implemented:** [`main-preview.dart`](../lib/main-preview.dart) is a separate runnable Flutter entry point for interactive design and behavior review. It opens directly on Home by setting `showWelcome: false`.
- **Implemented isolation:** The preview opens `yenma-preview.db`, not the normal application database. Preview records and edits therefore do not touch the user's normal Yenma data store.
- **Implemented SMS safety:** The entry point injects `PreviewSmsSyncService`. Its read method returns no messages and its daily-scheduling method is a no-op, so running the preview neither reads real SMS nor schedules real SMS work.
- **Implemented seed scope:** The isolated database is seeded with one canonical HDFC Bank record and eight HDFC Bank SMS-style transactions dated at offsets 0, 2, 4, 6, 8, 10, 12, and 14 days before today. Seven are expenses and one is income.
- **Implemented persistence:** The seed uses a stored version marker and stable import identities. Once seeded, reopening the preview does not overwrite or duplicate the fixtures, so manual edits made during preview testing persist.
- **Implemented reset:** Passing `RESET_PREVIEW=true` deletes only `yenma-preview.db` before initialization, recreating a clean preview database and reseeding it. It does not delete the normal app database.
- **Implemented production-like month behavior:** Unlike the golden-only `TwoWeekPreviewRepository`, the interactive preview uses `SqliteMoneyRepository` normally. All eight records exist in the isolated database, but Home/Cards month queries may show only the records in the selected calendar month when the two-week seed crosses a month boundary.
- **Test coverage present:** [`preview_entrypoint_test.dart`](../test/preview_entrypoint_test.dart) exercises the seed against an isolated temporary database, checks the one-bank/eight-transaction date range across month boundaries, and checks idempotency.

Run the interactive preview from the repository root:

```powershell
flutter run -t lib/main-preview.dart
```

Choose a specific device when needed:

```powershell
flutter run -t lib/main-preview.dart -d <device-id>
```

Reset only the preview database and run again:

```powershell
flutter run -t lib/main-preview.dart --dart-define=RESET_PREVIEW=true
```

## Design and dynamic-theme implementation rules

- Every reusable color is named for meaning, not appearance: background, surface, raised surface, border, primary/secondary text, selection, income, expense, transfer, success, warning, debt owed, and debt payable.
- Feature widgets read colors from `Theme.of(context).colorScheme` or a project `ThemeExtension`; they do not choose a specific grey because a screen happens to be in the initial palette.
- Category identity colors remain data-driven, but their containers/text must be contrast-safe under each palette.
- Grey is the initial design language, not an assumption that all semantic financial states are indistinguishable. Income, expense, warning, destructive, and success states require accessible semantic treatment.
- Loading, empty, error, disabled, pressed, selected, and saving states are designed alongside the default screen rather than added after repository wiring.
- Phone layouts follow the supplied Home composition. Wider layouts may use a rail or wider content arrangement while preserving destination order and feature priority.
- User-visible financial values remain integer-paise backed and formatted as INR unless the product owner explicitly expands currency support.

## Cross-feature implementation guardrails

- The transaction ledger remains the canonical record of money movement.
- Plans and future commitments are not ledger transactions by themselves.
- Subscription, EMI, loan, split, repayment, and SMS flows must avoid creating duplicate transaction records.
- Split obligations should integrate with Debt, with one authoritative outstanding balance.
- EMI schedule entries belong to a Loan record even when EMI receives a higher Home priority.
- Database changes require fresh-database and upgrade-path tests; new cross-feature writes require transactional tests.
- Existing working-tree changes are part of the reviewed baseline and must not be discarded while implementing the redesign.

## Open product decisions

These questions are tracked explicitly so planned behavior is not accidentally documented as implemented:

1. Does “Card Specific Transactions” include debit cards, bank accounts, and credit cards, or only credit cards?
2. How should users assign or correct an imported transaction's bank/card when SMS attribution is absent or wrong?
3. Is SMS synchronization intended to remain manual, become automatic after consent, or be user-configurable?
4. **Current implemented decision:** the dedicated group Split flow creates standalone allocation history and personal Debt records without creating a ledger transaction. The older transaction-form split remains linked to a ledger expense.
5. What settlement action should Split expose, and how should an imported reimbursement be reconciled without double counting?
6. What should subscription and EMI notifications promise, and which in-app controls govern them?
7. Should paying an EMI or subscription link to a matching transaction, offer to create one, or only update commitment state?
8. Are loans only amounts the user owes, or must the feature also cover money lent to others?
9. Are past/current-month plans editable, and can planned income include sources other than salary?
10. Which additional themes are intended beyond the initial grey design and the existing system/light/dark modes?

## Change log

### 8 October 2026 — bulk categorization interaction redesign

- Decoupled Categorize from the shared Home/Cards month state and removed its month selector. One feed spans from the previous calendar month's first day through today inclusive and excludes future-dated records.
- Added `transactionsBetween(startInclusive, endExclusive)` and backed the feed with one SQLite `date >= ? AND date < ?` query ordered by date and ID descending. Categorize passes the previous month's first day and tomorrow.
- Added arbitrary multi-select constrained to one transaction kind.
- Replaced the inline category field with an animated bottom action chip and a draggable/dismissible category grid sheet.
- Preserved selections when the sheet is dismissed, while category taps now apply immediately, close, clear after success, and reload the continuous recent feed.
- Adopted semantic grey theme surfaces around data-driven category identity colors.
- Added a repository boundary test and verified the final range-query/no-selector behavior with clean Flutter analysis, the focused repository/categorization/navigation suite at 14 of 14, and the full Flutter suite at 65 of 65.

### 3 October 2026 — baseline established

- Recorded confirmed navigation, Home, SMS sync, feature priority, design-first, and dynamic-color requirements.
- Audited current Flutter source and uncommitted Flutter changes.
- Distinguished mature existing functionality, persistence-only foundations, planned screens, inferred relationships, unresolved intent, and unverified native behavior.

### 3 October 2026 — first design/navigation slice implemented

- Added the grey-first `YenmaColors` semantic theme extension and updated transaction-kind styling to consume theme roles dynamically.
- Replaced the old primary shell with Home, Cards, Categorize, and Settings on both bottom navigation and wide-layout rail.
- Restricted the top-right SMS sync action to Home.
- Added Home's recognized-bank carousel and six shortcuts in the confirmed Plan, Split, Subscriptions, EMI, Loan, Debt order.
- Added a functional card-filtered transaction destination and embedded the functional bulk-categorization flow as a primary destination.
- Wired Plan and Debt shortcuts to their existing functional screens.
- Added themed design landing shells for Split, Subscriptions, EMI, and Loan. These four shells are visual navigation scaffolds only; their feature data and actions remain unimplemented.

### 3 October 2026 — correctness and verification pass

- Made daily SMS scheduling during initialization non-blocking and best-effort while retaining the native-behavior caveat.
- Corrected the transaction split summary to show the true unallocated personal share.
- Changed debt repayment eligibility to compare calendar dates and cleared expanded groups when changing Outstanding/Settled filters.
- Verified a clean `flutter analyze` run and a passing full Flutter suite of 47 tests.

### 3 October 2026 — Home navigation and runnable preview refinement

- Removed previous/next month navigation from Home only; retained month navigation in Card Specific Transactions and added a widget assertion for both sides of that boundary.
- Added a runnable light/dark Home preview backed by eight HDFC Bank SMS-style transactions at two-day offsets from today through 14 days ago.
- Kept the complete two-week fixture visible when it crosses a month boundary through a preview-only repository override.
- Generated `home-light.png` and `home-dark.png`, and refreshed the welcome/debt golden references during the same run.
- Verified preview tests 2 of 2, Flutter analysis clean, the regular suite 47 of 47, and targeted welcome tests 3 of 3.

### 3 October 2026 — isolated interactive preview entry point

- Added `lib/main-preview.dart` as a direct-to-Home interactive preview backed by the separate `yenma-preview.db` store.
- Injected a preview-only SMS service that neither reads device messages nor schedules daily work.
- Added a versioned, idempotent HDFC Bank fixture with eight SMS-style transactions from today through 14 days ago, preserving preview edits between runs.
- Added an explicit `RESET_PREVIEW` launch flag that deletes and reseeds only the preview database.
- Added temporary-database coverage for seed contents, cross-month dates, and idempotency, plus documented normal, device-specific, and reset commands.
- Verified targeted analysis of the preview entry point, app composition, and entry-point test with no issues; the focused preview tests pass 2 of 2.

### 3 October 2026 — functional Split groups and conversation

- Replaced Split’s design shell with a reusable-group list, group creation flow, member strip, newest-first chat-like history, and a record-split composer.
- Added equal/custom participant shares and a “Record for someone else” switch. User-paid entries render on the left; impersonated entries render on the right.
- Integrated group allocations with Debt atomically: user-paid friend shares become “Owed to me,” while only the user’s share becomes “I owe” when another member paid.
- Added schema version 13 and focused persistence, validation, direction, Debt-linkage, and widget-flow coverage.

