# Yenma Flutter: features, use cases, and problems solved

Reviewed 12 September 2026 against the current Flutter working tree, including uncommitted Dart changes. App version in pubspec.yaml: 0.2.2+4. This is a source-based inventory, not a device verification or a claim about an installed build. No Kotlin source or Kotlin Gradle scripts were inspected or changed.

Proposed changes under discussion: [simpler debt screen, reusable split groups, and transaction bills](debt-experience-proposal.md). These are not yet implemented.

**Product purpose inferred from the implementation:** help an individual keep a local record of money coming in and going out, understand monthly spending, and remember money owed between people. The app has four destinations: Overview, Transactions, Debts, and Settings. No account registration is required by the Flutter flow.

The tables describe existing Flutter behavior. The use cases and problems are interpretations of that behavior, not confirmed product research. Open questions below identify where those interpretations are insufficient to establish intent.

## Overview and transaction history

Evidence: [home screen](../lib/features/home_screen.dart), [money calculations](../lib/domain/money.dart), [repository](../lib/data/money_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F01 | Monthly spending: total of expense entries in the selected month. | See how much was paid out in August. | Avoid manually adding up many payments. |
| F02 | Monthly income: total of income entries. | Check recorded salary and other incoming money. | Make incoming money visible alongside spending. |
| F03 | Net cash flow: income minus expenses; transfers excluded. | See whether recorded income exceeded expenses this month. | Understand the month's recorded surplus or shortfall. This is not an account balance. |
| F04 | Top three expense categories, sorted by amount, with proportional bars. | Notice that Food dominates the month's spending. | Identify the largest spending areas quickly. There is no full category analytics screen. |
| F05 | Five most recent entries in the selected month and a View all shortcut. | Check whether a recently entered payment appears. | Review recent activity without opening the full list. |
| F06 | Full selected-month transaction list, newest date first, then newest ID for ties; shows title, category, date, type, and amount. | Review every recorded payment in a month. | Provide a consistent, readable history. No transaction text search or extra filters are exposed. |
| F07 | Previous/next month controls; tapping the month label returns to the current month. | Review an older month, then return to today’s month. | Navigate historical records without changing the data. |
| F08 | Pull to refresh for ledger and debts; reload month and debts on app resume. | Return to the app and see freshly loaded records. | Reduce stale displayed information. Ledger refresh reloads the database; it does not trigger SMS import. |

## Recording and correcting transactions

Evidence: [transaction form](../lib/features/transaction_form.dart), [details](../lib/features/transaction_detail.dart), [home screen](../lib/features/home_screen.dart), [repository](../lib/data/money_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F09 | Add an expense with a positive INR amount, title, eligible category, date, and optional note. | Record a cash lunch that has no bank message. | Capture spending that would otherwise be forgotten. |
| F10 | Add income using the same fields. | Record salary or another receipt of money. | Keep a record of incoming money for monthly comparisons. |
| F11 | Add a transfer, excluded from income, spending, and net cash flow. | Record movement between your own accounts. | Avoid treating internal movement as spending or earnings. No source/destination account balances are modeled. |
| F12 | Choose among 13 preset categories, filtered by transaction type. | Classify groceries separately from entertainment. | Make consistent spending summaries possible. No category create/edit/hide/delete UI exists. |
| F13 | Choose a transaction date, including past or future dates within 1900–2100, and add an optional note. | Backfill yesterday’s expense and its context. | Separate recording time from the event date and preserve details. Future entries are ordinary dated entries, not scheduled transactions. |
| F14 | Transaction details show title, amount, type, category, date, source, and any note. SMS entries show bank attribution. | Check where an entry came from before correcting it. | Make an individual entry understandable and traceable at a basic level. |
| F15 | Edit transaction fields; retain stored SMS source/bank/import identity. | Correct the amount, date, or category of an existing entry. | Repair mistakes without recreating the entry. |
| F16 | Confirmed deletion in details; swipe deletion with a temporary Undo action in Transactions. | Remove an accidental entry or undo an accidental swipe. | Correct the ledger with recovery for swipe mistakes. Detail deletion has confirmation but no Undo. |
| F17 | Validate amount/title/category; retain form values after failed saves; disable conflicting actions while saving. | Fix invalid input or retry after a storage error. | Prevent incomplete entries and avoid having to retype a failed submission. |

Preset categories: expenses use Food, Groceries, Transport, Shopping, Health, Entertainment, Bills, Subscriptions, Education, or Other; income uses Salary, Investment, or Other; transfers use Transfer.

## Shared expenses and debts

Evidence: [transaction form](../lib/features/transaction_form.dart), [transaction details](../lib/features/transaction_detail.dart), [debt form](../lib/features/debts/debt_form.dart), [debt screen](../lib/features/debts/debts_screen.dart), [debt persistence](../lib/data/debt_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F18 | Split an expense with one friend during transaction creation or editing; save the expense and new share together. | Pay ₹500 for dinner and record that a friend owes ₹250. | Connect a recoverable amount to the payment that created it. |
| F19 | Equal-split shortcut, or half of the amount still unallocated; custom amounts supported. | Divide a two-person bill without mental arithmetic. | Reduce calculation effort and entry errors. Half rounds down to whole paise; any extra paise stays unallocated. |
| F20 | Add more friends’ shares from an expense’s details. Show full payment, unallocated/personal remainder, each share, and its settlement state. | Allocate a group meal among several friends. | Keep multiple obligations tied to one payment. This is sequential share entry, not a group equal-split wizard. |
| F21 | Create standalone debts in either direction: Owed to me or I owe. | Record a cash loan or money owed for a meal someone else paid for. | Track obligations even when there is no linked transaction in your ledger. This does not create income or expense. |
| F22 | Debt description, person, original amount, date, optional note; edit after creation. | Clarify what an IOU was for or correct its amount. | Preserve context and correct errors. Direction and linked payment cannot be changed after creation. |
| F23 | Separate all-date totals for Owed to you and You owe. | Check the total still recoverable and the total still payable. | Keep both obligations visible without silently offsetting them. These totals are independent of the selected transaction month and search. |
| F24 | Group debt records by normalized person name, with separate per-person balances in each direction. | Review several payments involving the same friend. | Avoid calculating that person’s obligations across scattered records. |
| F25 | Search debts by person or payment title; switch between Outstanding and Settled. | Find a particular meal or confirm that an IOU was paid. | Locate records and separate active obligations from history. Filtered group totals reflect search results. |
| F26 | Saved-person suggestions in debt and split forms; type to filter, select an existing person, or enter someone new. | Reuse a friend’s name next time. | Reduce typing and duplicate spellings. Matching ignores case and repeated whitespace; saved names survive debt deletion and settlement. |
| F27 | Navigate from a payment’s share to debt details and from a linked debt to the original payment. | Check which expense explains an outstanding amount. | Preserve the relationship between the payment and the obligation. |
| F28 | Share/repayment integrity rules: shares cannot exceed the expense; linked payments cannot be deleted; edits cannot invalidate existing shares or repayments. | Avoid reducing a ₹500 bill below its already allocated ₹300 of shares. | Prevent contradictory financial records. Even settled linked debt records still protect the payment. |
| F29 | Delete a debt with confirmation, including its screenshot and repayment history; keep the original expense. | Remove an IOU entered by mistake. | Correct the debt log independently of the payment log. Deletion does not mean payment or debt forgiveness was recorded. |

## Repayments, receipts, and reminders

Evidence: [repayment form](../lib/features/debts/repayment_form.dart), [debt details](../lib/features/debts/debt_detail.dart), [debt screen](../lib/features/debts/debts_screen.dart), [receipt editor](../lib/features/debts/receipt_editor.dart), [image source](../lib/data/receipt_source.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F30 | Record partial repayments or use the full remaining amount; choose repayment date and optional note. Remaining balance updates; zero becomes Settled. | Record ₹100 received against a ₹250 debt, then the remaining ₹150 later. | Track gradual repayment without losing the original amount. Dates must fall between the debt date and today; overpayment is rejected. |
| F31 | View repayment history with amount, date, and note; remove a repayment after confirmation to restore the outstanding balance. | Correct a repayment recorded against the wrong debt. | Explain how the current balance was reached and reverse mistakes. There is no repayment edit form. |
| F32 | Attach, preview, replace, or remove one local receipt/UPI image per debt, up to 10 MB; open a zoomable viewer. | Keep proof of a meal payment alongside the IOU. | Avoid hunting through a photo gallery later. Images are selected from the gallery; no OCR or automatic amount extraction exists. |
| F33 | Recover an interrupted photo-picker result on supported Android plugin paths; use it on a new debt or discard it. | Return after the OS interrupted image selection. | Rescue the selected screenshot. Unsaved form text is not restored; actual native recovery was not verified here. |
| F34 | Copy a reminder for a person who owes you; uses their entire outstanding owed-to-you total, even when search filters the visible records. | Paste a reminder into a messaging app yourself. | Reduce the effort of drafting a repayment request. Yenma does not send it or schedule reminders. |

Accounting example: a ₹500 expense with a ₹250 friend’s share shows ₹500 spending and ₹250 owed to you. Recording a ₹100 repayment changes owed-to-you to ₹150; spending remains ₹500 and no income entry is created. A standalone debt and its repayment also leave transaction totals unchanged. If a repayment is separately imported from SMS, it is a separate transaction; there is no Flutter reconciliation flow linking that import to a repayment.

## SMS import: Flutter implementation with a native dependency

Evidence: [SMS parser and platform interface](../lib/data/sms_sync.dart), [controller](../lib/app/money_controller.dart), [repository](../lib/data/money_repository.dart), [consent and sync UI](../lib/features/home_screen.dart).

These workflows exist in Dart, including currently uncommitted changes. Reading device messages and scheduling background work depend on a platform implementation that was deliberately not inspected. Do not describe device/background success as verified.

| ID | Existing Flutter behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F35 | Sync bank messages action on Overview, Transactions, and Debts; first-use consent dialog; busy indicator and completion/permission/error messages. | Import payments without typing them individually. | Reduce manual entry while explaining message access. |
| F36 | First successful sync requests roughly three calendar months of messages; later syncs request today’s messages up to now. | Seed recent history, then collect today’s activity. | Reduce repeated scanning. This is not catch-up from the last successful sync; missed days can remain unimported. |
| F37 | Parse supported bank-like text into amount, income/expense, recipient-derived title, bank, date, and SMS origin. Unrecognized messages are skipped; default category is Other. | Turn a recognized debit alert into a draftless ledger entry. | Convert message text into structured records. There is no review queue before insertion. |
| F38 | Store an import identity derived from sender, timestamp, and body; skip existing matching identities on import. | Tap sync again without reinserting the same recognized message. | Reduce repeated imports. This does not reconcile manual entries with SMS entries or remember deleted imports. |
| F39 | Ordinary save of a transaction with a recipient key stores its category for subsequent imports with that key. | Categorize an imported merchant once and reuse the choice later. | Reduce repeated categorization. No rule-management screen exists; saving through the split-expense path bypasses this category-learning write. |
| F40 | On initialization, request daily scheduling through the platform channel; with saved consent, at/after 22:00, perform a foreground sync if today is not marked synced. | Attempt to keep records current with less manual effort. | Intended benefit is freshness; the exact automatic-sync promise is unresolved. Native timing and delivery are unverified. |

The parser contains names for HDFC Bank, Canara Bank, Jupiter, ICICI Bank, SBI, Axis Bank, Kotak Mahindra Bank, IDFC FIRST Bank, Bank of India, Punjab National Bank, Central Bank of India, and Union Bank. This is a string-matching list, not verified comprehensive bank support. It takes the first INR/Rs/₹ amount, treats mixed credit/debit keywords as an expense, and does not infer transfers. Overlapping bank keys and free-form recipient extraction can misidentify records. No bank tracking controls or raw-message viewer exist in Flutter.

## Appearance, local storage, and usability

Evidence: [welcome screen](../lib/features/welcome_screen.dart), [app composition](../lib/app/yenma_app.dart), [home screen](../lib/features/home_screen.dart), [controller](../lib/app/money_controller.dart), [money model](../lib/domain/money.dart), [repository](../lib/data/money_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F41 | Light, dark, and follow-system appearance; preference saved locally. | Keep the app comfortable in different lighting. | Support visual preference without reselecting it each launch. |
| F42 | Random welcome phrase once per launch, automatic continuation after two seconds, immediate Open my money action. Accessible-navigation mode requires manual continuation. | Enter the app through a short branded welcome. | Likely a tone/branding choice; a specific user problem is unconfirmed. Manual continuation prevents the text disappearing while being read. |
| F43 | Bottom navigation on narrow layouts, navigation rail on wider layouts, constrained content width, and stacking summary cards for larger text. | Use a wider screen or larger text setting. | Keep navigation and financial values readable across supported layouts. This does not establish platform support or certify full accessibility. |
| F44 | Local SQLite persistence for entries, debts, receipts, names, categories, and preferences; current schema is version 4 with upgrade paths. | Close and reopen the app without losing saved records. | Preserve history and preferences locally and support upgrading existing Yenma databases. No export, backup, or restore UI exists. |
| F45 | Exact integer-paise money handling and Indian rupee formatting. | Record ₹123.45 without floating-point rounding drift. | Keep stored amounts and aggregation exact to the paise. INR is fixed, not a currency selector. |
| F46 | Empty/loading/error states, retry actions, and protection against older asynchronous loads overwriting newer selections. | Switch months quickly or retry a failed read. | Explain absent data and avoid showing the wrong selection’s results. |
| F47 | Settings displays INR, local-storage/no-account information, and app version. | Check the app’s currency and basic storage model. | Set expectations about how records are handled. These labels are informational controls, not editable preferences. |

## Product intent that needs confirmation

The core use cases are understandable. The following choices cannot be settled from code alone. They are questions for documentation, not authorization to change behavior.

| ID | What is unclear | Current behavior | Question for the product owner |
| --- | --- | --- | --- |
| Q1 | What should “spending” represent? | Full outgoing expense, including recoverable friend shares; repayments do not change spending. | Should users understand this as gross payments, or is the intended problem understanding their own final cost after splits? |
| Q2 | Manual versus automatic SMS access | Consent says messages are read “only when you sync,” but initialization requests scheduling and can sync after 22:00. No in-app opt-out control exists. | Is SMS sync intended to be manual, automatic after consent, or user-selectable? |
| Q3 | Missing-day import coverage | After initial import, Flutter reads only today. | Is today-only intentional, or should returning users catch up from their last successful import? |
| Q4 | Repayments arriving via SMS | A repayment record does not affect income/expense; an SMS import can independently do so. | How should the user avoid counting a reimbursement as income or a repayment as new spending? Should the documentation prescribe a workflow or is reconciliation intended? |
| Q5 | The meaning of a manual payment’s source | All manual details say Cash, with no payment-method field. | Does manual mean cash only, or should it include manually entered UPI, card, and bank payments? |
| Q6 | Name as person identity | Names differing only in case/spaces are grouped; saved names persist after deletion. | Is name-only identity and permanent suggestion retention intentional, including two friends with the same name? |
| Q7 | Future-dated entries | Ordinary transactions/debts can be dated in the future and contribute when that month is viewed; future debts already enter all-date outstanding totals. | Are these intended to represent real obligations, planned activity, or simply unrestricted date entry? |
| Q8 | Welcome screen purpose | A random phrase precedes the ledger on each launch. | Is its goal branding, reassurance, habit-building, or something else? I cannot identify a specific financial problem it solves from the implementation. |

## Features not present in the reviewed Flutter app

No Flutter flow was found for custom category management, journal entries, budgets or budget alerts, recurring/planned spending, savings goals, today's-spending card, dedicated analytics, transaction text search, custom date-range filtering, bank/account balance management, bank-selection toggles, currency conversion, general date/week/decimal preferences, dynamic-color preference, export/backup/restore, old-app data migration, cloud sync, account login, biometric/PIN lock, automatic repayment matching, or scheduled debt reminders. These are boundaries of this inventory, not a proposed roadmap.

The older [reference feature inventory](money-mobile-application/features.md) describes the separate reference application. It must not be used to claim Flutter feature availability. The root README and older implementation status still call SMS import upcoming and refer to schema 3; the reviewed Flutter source now contains SMS workflows and schema 4. Those documents are historical where they disagree with this snapshot.

## Review limits and maintenance

This pass traced all screens under lib/features plus Dart composition, state, models, storage, and platform interfaces. No application code was changed; no build or test suite was run for this documentation-only task. Existing test names and previous validation claims are not evidence that this working tree passes today.

When updating this inventory, verify the actual Flutter entry point, persistence effect, and accounting effect for each feature. Keep platform-dependent promises qualified until independently verified within the user-authorized scope. Record answers to Q1–Q8 before describing those product choices as settled intent.
