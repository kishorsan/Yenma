# Money Mobile Application — features

See [review scope](README.md) for the source snapshot and verification limits. This inventory is the baseline for the [implementation plan](implementation.md).

## Feature inventory

| ID | Feature | Current source status | Primary evidence |
| --- | --- | --- | --- |
| F01 | Home dashboard | Implemented with calculation/navigation gaps | presentation/ui/home/HomeScreen.kt |
| F02 | Manual transactions | Create, list, detail, edit and delete code exists; creation has a constructor mismatch | presentation/ui/transactions/*.kt |
| F03 | Categories | Management and persistence exist; custom-category selection is restricted by hardcoded IDs | data/repository/CategoryRepository.kt; SettingsScreen.kt; AddTransactionScreen.kt |
| F04 | Financial journal | List, new, view, edit and delete flows exist | presentation/ui/journal/JournalScreen.kt |
| F05 | SMS import | On-demand import, progress, result and retry code exists; correctness gaps remain | sms/SmsReader.kt; data/local/viewModel/SmsViewModel.kt |
| F06 | Bank tracking | Seeded sender groups and tracking toggles exist | sms/KnownBankAccounts.kt; presentation/ui/settings/BankAccountSettingsScreen.kt |
| F07 | Appearance | Theme and dynamic-color preferences reach the app theme; other switches persist | MainActivity.kt; SettingsViewModel.kt |
| F08 | General preferences | Currency, date, week, decimal and budget values persist; global behavior is incomplete | presentation/ui/settings/SettingsState.kt; SettingsViewModel.kt |
| F09 | Data tools | Export, backup and clear-data are placeholders; reset clears preferences | data/local/viewModel/SettingsViewModel.kt |
| F10 | Debts | Entity and DAO exist; repository, ViewModel and screen are empty | data/local/entity/Debt.kt; presentation/ui/debts/DebtScreen.kt |
| F11 | Planned spending | Entity and route declaration only; absent from database and navigation graph | data/local/entity/PlannedSpend.kt; presentation/navigation/Screen.kt |
| F12 | Dedicated analytics | Route declaration only; dashboard summaries are separate | presentation/navigation/Screen.kt; AppNavGraph.kt |

## F01 — Dashboard

The home screen selects a month/year, calculates monthly expense, shows today's amount, transaction count and top category, and takes up to 20 month transactions for its feed. Navigation callbacks cover entry, journal, list, SMS and settings. A debt callback is supplied by navigation, but the debt destination is empty.

Current monthly spending includes only type `"2"`. Today's spending sums all transaction types, and top category also groups all types. The all-transactions DAO has no explicit ordering, so the first 20 are not guaranteed to be the latest. The home transaction callback merely evaluates an ID and does not navigate to details.

Flutter acceptance: expense metrics use expenses only; income and transfers cannot inflate them; feed order is date descending with a stable tie-breaker; tapping a row opens details; empty months show zero and an empty state. Refresh the meaning of “today” when the app resumes or the date changes.

## F02 — Transactions

Manual entry collects amount, title, type, category, note and date. Amount must be positive, title nonblank and category selected. Dates are stored as ISO calendar dates. Types are stored as `1` income, `2` expense and `3` transfer. Some list display code also accepts textual INCOME/EXPENSE values.

The list filters by month, shows income/expense summaries and opens detail by ID. Edit changes title, amount, type, category, note and date; deletion has a confirmation dialog. Editing preserves SMS origin, but does not set the available `isEdited` flag. The newly required `receiver` entity field has no default and is omitted by manual/SMS creation code.

Flutter acceptance: CRUD survives restart and updates both dashboard and list; canceled deletion does nothing; missing IDs have a visible state; invalid input cannot save; save failures retain form content. SMS edits retain original body/source and set edit metadata. Define whether receiver is optional before coding it. Treat transfer as a single recorded activity for baseline parity; do not imply two-account balance accounting, which is absent from this model.

## F03 — Categories

Defaults are: Food (1), Groceries (2), Transport (3), Shopping (4), Health (5), Entertainment (6), Bills (7), Subscriptions (8), Education (9), Salary (10), Investment (11), Transfer (12), Other (13). Each stores a name, material-icon key, ARGB color, default flag and active flag.

Repository operations support creation, update, hiding, custom-category deletion and restoring defaults. Default restoration can overwrite edits to seeded rows. Entry pickers allow income IDs 10/11/13, expense IDs 1–9/13 and transfer ID 12, excluding newly created categories.

Flutter acceptance: user categories can be selected for allowed transaction types; hidden categories remain readable on historical entries; deleting a referenced category cannot orphan transactions. Prefer hiding referenced categories. Preserve seeded IDs during migration, while replacing ID-based eligibility with explicit metadata.

## F04 — Journal

The journal implements list/new/edit/view states inside one route. Entries contain title, text and a timestamp; listing is newest timestamp first. Edits preserve the existing date; delete is available from the list with confirmation.

Flutter acceptance: create, read, update and delete persist; back navigation returns through the appropriate journal state; empty content has defined validation; storage errors keep unsaved text. No financial transaction link is currently modeled.

## F05 — SMS synchronization

Opening SMS requests READ_SMS through the activity and navigates immediately. The SMS screen starts sync on entry, reports loading/error/imported/skipped states and supports retry. The ViewModel prevents another run while loading or after completion until reset.

Source pipeline:

1. Load tracked sender groups and query device SMS address/body/timestamp, newest first.
2. Accept sender pattern `AA-HEADER-SUFFIX` with suffix T or S. Although the regex suffix is optional, code rejects a missing suffix. Match known keys as substrings within the validated header.
3. Extract the first amount marked Rs/INR/rupee symbol. Determine income/debit from keyword sets; ambiguous credit/debit prefers income. Transfer recognizes the literal misspelling `transfered` after the credit/debit branches.
4. Derive description from merchant-like words, UPI reference or “Bank transaction”; convert timestamp to a local calendar date.
5. Drop candidates with the same amount and date as a previous candidate, regardless of bank or body.
6. Skip bodies already stored as SMS transactions, then insert with category ID 2 (currently Groceries), bank ID and raw body. Update that sender's last-sync timestamp after insertion.

The date limit stops only when an accepted parsed message equals 2026-01-01. It is not a reliable lower-bound filter. Stored-body duplicate checking and within-scan amount/date suppression use different rules. Permission granting is not awaited before screen-driven reading. No registered incoming-SMS receiver or implemented background worker was found; RECEIVE_SMS and WorkManager declarations alone do not provide automatic import.

Flutter acceptance: permission denial/revocation produces a recoverable state; retry is safe; two legitimate same-amount/day messages survive; repeat import adds zero duplicates; edits are not overwritten; date range is explicit and enforced. Persist a stable import identity and report malformed, unsupported and duplicate counts separately. Use an explicit import/uncategorized category instead of Groceries. Test with synthetic messages covering ambiguous keywords, multiple amounts and sender variants.

## F06 — Bank tracking

The seed includes 12 bank sender groups (HDFC, ICICI, SBI, Axis, Kotak, IDFC, Bank of India, Punjab National Bank, Canara, Central Bank, Union Bank and Jupiter) and four initially disabled UPI groups (Paytm, Google Pay, PhonePe, Amazon Pay). Entity account types allow BANK/UPI/CARD, but the seed contains no card group.

These records represent SMS sender groups, not verified bank connections or individually numbered accounts. Settings observe records and persist tracking toggles; import honors enabled senders.

Flutter acceptance: toggles survive restart; disabling affects future scanning without deleting history; labels accurately describe sender tracking. No live bank balances or banking API integration is included in baseline scope.

## F07–F09 — Settings and data

Stored choices include light/dark/system, dynamic color, compact mode, home balance visibility, animations, INR/USD/EUR/GBP/JPY, three date formats, Monday/Sunday week start, decimals, monthly budget and automatic backup. Theme and dynamic color are explicitly wired at the application root. Other preference persistence should not be mistaken for completed screen behavior; transaction screens still contain rupee formatting.

CSV export and backup show success messages without writing files. Clear-data updates display state without clearing Room. Reset clears SharedPreferences but not the database. Statistics default to zero in SettingsState; no database-derived statistics loading is implemented in SettingsViewModel.

Flutter acceptance: supported preferences visibly apply across screens after restart. Currency selection is formatting unless a separately specified conversion feature is added; never reinterpret imported INR values as another currency. Export/backup report success only after an actual file is written. Restore validates schema and handles failure without corrupting current data. Clear-data and preference reset have distinct wording and real effects. Auto-backup must remain unavailable until scheduling and restore are implemented.

## F10–F12 — Future features

Debts need full forms, lists, settlement behavior and rules for their required transaction link. The schema captures direction (OWED_TO_ME/I_OWE), amount, description, optional due date, settlement flag and creation time. Do not automatically create income/expense on settlement without defining double-counting rules.

Planned spending needs storage registration, queries, screens and rules for converting a plan to a transaction. Its draft model includes title, amount, category, target month/year, paid flag and note.

Dedicated analytics needs specified questions and charts. A proposed first increment is expense by category and monthly income/expense trends using the same calculations as the dashboard. These are new development, not completed Kotlin features to port.

## Baseline boundaries

Start with Android, offline storage and manual workflows. Cloud accounts, authentication, multi-device sync, exchange-rate conversion, bank APIs, budgets with alerts, recurring transactions and notifications have no completed implementation evidenced here. Additional-platform scope and SMS alternatives require separate product decisions.
