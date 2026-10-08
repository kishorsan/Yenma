# Yenma Flutter: features, use cases, and problems solved

Reviewed 8 October 2026 against the current Flutter working tree, including uncommitted Dart changes. App version in pubspec.yaml: 0.2.2+4. This is a source-based inventory, not a device verification or a claim about an installed build. No Kotlin source or Kotlin Gradle scripts were inspected or changed.

Earlier debt and split proposals are tracked in [debt-experience-proposal.md](debt-experience-proposal.md). Reusable split groups and the conversational split flow are now implemented; other proposal items remain subject to their source evidence and open questions.

**Product purpose inferred from the implementation:** help an individual keep a local record of money coming in and going out, understand monthly spending, and remember money owed between people. The app has four destinations: Home, Cards, Categorize, and Settings. No account registration is required by the Flutter flow.

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
| F07 | Home has no month control. Cards has previous/next month controls and a current-month shortcut. Categorize has no month selector and uses one continuous recent feed from the previous calendar month's first day through today. | Review an older card ledger while keeping recent categorization work continuously visible without changing periods. | Keeps explicit month navigation in Cards and removes period switching from Home and Categorize. Cards and Home share the controller-selected month; Categorize uses an independent fixed date window. |
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

## Bulk categorization

Evidence: [categorization screen](../lib/features/bulk_categorization_screen.dart), [controller](../lib/app/money_controller.dart), [repository](../lib/data/money_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F65 | Categorize has no month selector. It requests one repository range from the previous calendar month's first day (inclusive) to tomorrow (exclusive), making today inclusive while excluding future-dated records. SQLite applies `date >= ? AND date < ?` and orders the feed by date descending, then ID descending; the screen preserves that deterministic newest-first order. | Classify all recent imports in one list even when the useful window crosses a month boundary. | Keeps the categorization queue continuous, recent, and independent of the month selected in Cards/Home. Older records and future-dated records are deliberately outside this feed. |
| F66 | Select any combination of transactions within one transaction kind. After the first selection, rows of other kinds are disabled; selected rows can be toggled individually or all cleared. | Select several unrelated expenses, while preventing an income-only category from being applied to them accidentally. | Supports deliberate bulk work without requiring matching merchant names and preserves category-kind validity. |
| F67 | A bottom action chip slides and fades into view with the selection count. It opens a draggable, dismissible category-grid sheet containing only categories valid for the selected transaction kind. Dragging or dismissing the sheet pauses the action and leaves the selection intact. | Inspect category options, dismiss the sheet to reconsider the selection, then reopen it without starting over. | Separates transaction selection from the commit decision and makes dismissal non-destructive. |
| F68 | Tapping a category immediately applies it atomically to the selected transactions, closes the sheet, clears selection after success, reloads the continuous recent feed, and shows completion feedback. A failed update retains the selection and exposes retryable error feedback. | Reclassify several recent expenses with one category tap and immediately see the refreshed list. | Reduces repetitive edits while keeping failure recoverable. Recipient-linked category learning continues through the existing bulk repository operation. |

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
| F24 | Use each normalized person as a parent debt record, with child debts summarized separately as Owes you and You owe. The same person can have active debts in both directions. | Review several obligations involving the same friend without netting away either direction. | Avoid calculating that person’s obligations across scattered records while keeping receivables and payables explicit. |
| F25 | Search by person or debt title. Repayments and person summaries are the default view; individual child debt rows are hidden until View all debts is selected, and then include both outstanding and settled records. | Check recent repayments first, then reveal the full debt history only when it is needed. | Keep the everyday screen focused while retaining access to every record. Filtered person totals reflect search results. |
| F26 | Saved-person suggestions in debt and split forms; type to filter, select an existing person, or enter someone new. | Reuse a friend’s name next time. | Reduce typing and duplicate spellings. Matching ignores case and repeated whitespace; saved names survive debt deletion and settlement. |
| F27 | Navigate from a payment’s share to debt details and from a linked debt to the original payment. | Check which expense explains an outstanding amount. | Preserve the relationship between the payment and the obligation. |
| F28 | Share/repayment integrity rules: shares cannot exceed the expense; linked payments cannot be deleted; edits cannot invalidate existing shares or repayments. | Avoid reducing a ₹500 bill below its already allocated ₹300 of shares. | Prevent contradictory financial records. Even settled linked debt records still protect the payment. |
| F29 | Delete a debt with confirmation, including its screenshot and repayment history; keep the original expense. | Remove an IOU entered by mistake. | Correct the debt log independently of the payment log. Deletion does not mean payment or debt forgiveness was recorded. |
| F48 | Create reusable named Split groups with one or more saved people and an optional group note. | Reuse the same travel or household group instead of selecting everyone again. | Reduces repeated setup for recurring shared expenses. The user is included implicitly as “Me.” |
| F49 | Open a group as a newest-first conversational history. User-paid entries appear as wide left-side bubbles; entries recorded for another payer appear on the right. | Scan the latest dinner, taxi, and hotel splits as a shared-expense conversation. | Keeps event context and direction visually legible without flattening all shares into an ordinary table. |
| F50 | Record a description and exact INR total, include or omit group participants, and assign equal or custom positive shares that must add up exactly. | Split ₹900 equally among three people or enter uneven shares. | Prevents partial saves and arithmetic inconsistencies. The equal split distributes any remainder paise deterministically. |
| F51 | Turn on “Record for someone else” and choose a group member as payer. | Capture a taxi that Asha paid for when she did not record it herself. | Preserves the expense context without falsely claiming the user paid. The full group allocation is retained, while only the user’s share becomes an “I owe” Debt record. |
| F52 | User-paid group entries create one “Owed to me” Debt record per included friend; impersonated entries create only the user’s “I owe” share. Split bubbles read settlement state from those Debt records. | Record a meal and later settle the generated balances through the existing Debt flow. | Keeps Debt as the authoritative obligation ledger and avoids inventing balances between two other people that the user neither owes nor is owed. Standalone Split entries do not create ledger transactions. |

## Repayments, receipts, and reminders

Evidence: [repayment form](../lib/features/debts/repayment_form.dart), [debt details](../lib/features/debts/debt_detail.dart), [debt screen](../lib/features/debts/debts_screen.dart), [receipt editor](../lib/features/debts/receipt_editor.dart), [image source](../lib/data/receipt_source.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F30 | Record partial repayments or use the full remaining amount; choose repayment date and optional note. Remaining balance updates; zero becomes Settled. | Record ₹100 received against a ₹250 debt, then the remaining ₹150 later. | Track gradual repayment without losing the original amount. Dates must fall between the debt date and today; overpayment is rejected. |
| F31 | View repayment history with amount, date, note, direction, and source debt directly under each person; open the debt for its full history and remove a repayment after confirmation to restore the outstanding balance. | Check what was received from or paid to a person, or correct a repayment recorded against the wrong debt. | Explain how the current balance was reached and reverse mistakes. There is no repayment edit form. |
| F32 | Attach, preview, replace, or remove one local receipt/UPI image per debt, up to 10 MB; open a zoomable viewer. | Keep proof of a meal payment alongside the IOU. | Avoid hunting through a photo gallery later. Images are selected from the gallery; no OCR or automatic amount extraction exists. |
| F33 | Recover an interrupted photo-picker result on supported Android plugin paths; use it on a new debt or discard it. | Return after the OS interrupted image selection. | Rescue the selected screenshot. Unsaved form text is not restored; actual native recovery was not verified here. |
| F34 | With View all debts selected, copy a reminder for a person who owes you; it uses the outstanding owed-to-you total currently represented by that person card. | Paste a reminder into a messaging app yourself. | Reduce the effort of drafting a repayment request. Yenma does not send it or schedule reminders. |

Accounting example: a ₹500 expense with a ₹250 friend’s share shows ₹500 spending and ₹250 owed to you. Recording a ₹100 repayment changes owed-to-you to ₹150; spending remains ₹500 and no income entry is created. A standalone debt and its repayment also leave transaction totals unchanged. If a repayment is separately imported from SMS, it is a separate transaction; there is no Flutter reconciliation flow linking that import to a repayment.

## SMS import: Flutter implementation with a native dependency

Evidence: [SMS parser and platform interface](../lib/data/sms_sync.dart), [controller](../lib/app/money_controller.dart), [repository](../lib/data/money_repository.dart), [consent and sync UI](../lib/features/home_screen.dart).

These workflows exist in Dart, including currently uncommitted changes. Reading device messages and scheduling background work depend on a platform implementation that was deliberately not inspected. Do not describe device/background success as verified.

| ID | Existing Flutter behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F35 | Home-only Sync bank messages action; first-use consent dialog; busy indicator and completion/permission/error messages. | Import payments without typing them individually. | Reduce manual entry while explaining message access without repeating the action across destinations. |
| F36 | First successful sync requests roughly three calendar months of messages; later syncs request today’s messages up to now. | Seed recent history, then collect today’s activity. | Reduce repeated scanning. This is not catch-up from the last successful sync; missed days can remain unimported. |
| F37 | Parse supported bank-like text into amount, income/expense/transfer, recipient-derived title, financial source, transaction date, SMS origin, account/card type, and masked four-digit instrument identity. The canonical bank-name map supplies the institution; recognized card wording derives a distinct source such as HDFC Credit Card or ICICI Credit Card, while account activity retains HDFC Bank or ICICI Bank. Card purchases and successful card AutoPay messages are expenses; card-bill receipts are transfers; future “will be debited” notices are skipped. | Keep an HDFC Credit Card purchase separate from an HDFC Bank account debit and avoid treating a card-bill payment as income. | Convert message text into structured records without mixing cards and accounts or counting a pending charge as completed. There is no review queue before insertion. |
| F38 | Store an import identity derived from sender, timestamp, and body; skip existing matching identities on import. | Tap sync again without reinserting the same recognized message. | Reduce repeated imports. This does not reconcile manual entries with SMS entries or remember deleted imports. |
| F39 | Ordinary save of a transaction with a recipient key stores its category for subsequent imports with that key. | Categorize an imported merchant once and reuse the choice later. | Reduce repeated categorization. No rule-management screen exists; saving through the split-expense path bypasses this category-learning write. |
| F40 | On initialization, request daily scheduling through the platform channel; with saved consent, at/after 22:00, perform a foreground sync if today is not marked synced. | Attempt to keep records current with less manual effort. | Intended benefit is freshness; the exact automatic-sync promise is unresolved. Native timing and delivery are unverified. |

The parser contains names for HDFC Bank, Canara Bank, Jupiter, ICICI Bank, SBI, Axis Bank, Kotak Mahindra Bank, IDFC FIRST Bank, Bank of India, Punjab National Bank, Central Bank of India, and Union Bank. This is a string-matching list, not verified comprehensive bank support. It takes the first INR/Rs/₹ amount and uses generic `card`/`credit card`/`CC` versus `A/C`/`account` markers; exact wording from an untested bank can still be missed. Card-bill transfers are classified but not automatically reconciled with their corresponding bank debit. No bank tracking controls or raw-message viewer exist in Flutter.

## Appearance, local storage, and usability

Evidence: [welcome screen](../lib/features/welcome_screen.dart), [app composition](../lib/app/yenma_app.dart), [home screen](../lib/features/home_screen.dart), [controller](../lib/app/money_controller.dart), [money model](../lib/domain/money.dart), [repository](../lib/data/money_repository.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F41 | Light, dark, and follow-system appearance; preference saved locally. | Keep the app comfortable in different lighting. | Support visual preference without reselecting it each launch. |
| F42 | Random welcome phrase once per launch, automatic continuation after two seconds, immediate Open my money action. Accessible-navigation mode requires manual continuation. | Enter the app through a short branded welcome. | Likely a tone/branding choice; a specific user problem is unconfirmed. Manual continuation prevents the text disappearing while being read. |
| F43 | Bottom navigation on narrow layouts, navigation rail on wider layouts, constrained content width, and stacking summary cards for larger text. | Use a wider screen or larger text setting. | Keep navigation and financial values readable across supported layouts. This does not establish platform support or certify full accessibility. |
| F44 | Local SQLite persistence for entries, debts, receipts, names, categories, plans, split groups, commitments, and preferences; current schema is version 16 with upgrade paths. Imported transactions retain account/card identity and import role. | Close and reopen the app without losing saved records. | Preserve history and preferences locally and support upgrading existing Yenma databases. No export, backup, or restore UI exists. |
| F45 | Exact integer-paise money handling and Indian rupee formatting. | Record ₹123.45 without floating-point rounding drift. | Keep stored amounts and aggregation exact to the paise. INR is fixed, not a currency selector. |
| F46 | Empty/loading/error states, retry actions, and protection against older asynchronous loads overwriting newer selections. | Switch months quickly or retry a failed read. | Explain absent data and avoid showing the wrong selection’s results. |
| F47 | Settings displays INR, local-storage/no-account information, and app version. | Check the app’s currency and basic storage model. | Set expectations about how records are handled. These labels are informational controls, not editable preferences. |

## Subscriptions

Evidence: [subscription screens](../lib/features/subscriptions/subscriptions_screen.dart), [commitment persistence](../lib/data/commitments_data.dart), [controller](../lib/app/money_controller.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F53 | Record and edit a named monthly or yearly subscription with an exact INR amount and billing date. Monthly records recur by day; yearly records retain month and day. | Add a ₹199 monthly streaming service or an annual storage plan. | Keep recurring commitments visible without treating them as completed ledger transactions. Billing days are limited to 1–28 so every monthly recurrence has a valid date. |
| F54 | Browse saved subscriptions as cards showing amount, active/paused state, and the next billing date; pull to refresh and open an individual detail view. | Scan which service bills next. | Bring recurring costs and timing into one local list. The list does not yet total or categorize subscription costs. |
| F55 | Subscription details show a countdown ring, renewal date, price, active/pause control, and edit action. An optional HTTP(S) account link can open in the platform browser. | Pause a cancelled service in Yenma or visit its account page. | Make each commitment actionable from its record. Opening the external browser depends on the platform URL-launcher integration and is not device-verified here. |
| F56 | Save a “Notify me” preference and display its status clearly. | Mark a subscription for a future reminder workflow. | Preserves reminder intent without falsely claiming a notification was scheduled. Flutter does not currently schedule subscription notifications. |

## EMIs

Evidence: [EMI screens](../lib/features/emi/emi_screen.dart), [commitment persistence](../lib/data/commitments_data.dart), [controller](../lib/app/money_controller.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F57 | Record an EMI as either “My EMI” or “Paid through me,” where someone pays the user and the user makes the EMI payment. Store the original principal, one-time processing fee, monthly due day, start/end dates, and a note. | Distinguish a personal phone EMI from a relative’s phone EMI routed through the user. | Keeps pass-through obligations visible without treating them as the user’s own financing. These EMI records do not create ledger transactions. |
| F58 | Show total principal remaining, active EMIs first, and completed EMIs afterward. An EMI completes when its paid monthly principal reaches the original principal. | See the outstanding financed amount and find current commitments before historical ones. | Avoids manually calculating principal remaining across installments. |
| F59 | Record each monthly EMI as principal plus interest, paid or due. GST is calculated automatically on interest using the configurable Settings rate and stored on the installment. | Record ₹1,000 principal and ₹100 interest with 18% GST as a ₹1,118 monthly EMI. | Makes the EMI’s components and tax explicit while preserving the historical GST amount if the configured rate changes later. |
| F60 | Restrict EMI billing days and EMI-related date selection to days 1–28. Reject negative component and processing-fee values, require a positive original principal, and prevent paid principal from exceeding the original amount. | Use a recurrence day that exists in every month and catch an accidental overpayment. | Prevents invalid monthly schedules and contradictory balances. Principal or interest may individually be zero, but a monthly EMI cannot have both at zero. |

## Loans

Evidence: [loan screens](../lib/features/loans/loan_screen.dart), [commitment persistence](../lib/data/commitments_data.dart), [controller](../lib/app/money_controller.dart).

| ID | Existing feature and behavior | Example use case | Problem it solves |
| --- | --- | --- | --- |
| F61 | Record and edit a loan with a lender/name, original amount, repayment type, start date, optional expected end date, and notes. Supported types are revolving credit, single repayment, and regular repayments. | Track a bank vehicle loan or an informal one-time loan. | Keeps the essential terms and identity of different borrowing arrangements in one local record. Loan records do not create ledger transactions. |
| F62 | Browse active and completed loan cards with total outstanding principal, per-loan remaining balance, and principal repayment progress. EMI records remain separate from this list. | Check the total principal still owed across active loans. | Provides a portfolio-level balance without double-counting the separate EMI feature. |
| F63 | Add or edit scheduled and paid repayment entries with principal, interest, optional fees/charges, and a payment or due date. Only paid principal reduces the balance and a loan completes when paid principal reaches the original amount. | Add next month's due amount now, then mark it paid later. | Combines a lightweight payment schedule with repayment history while keeping interest and charges out of principal progress. |
| F64 | Validate positive loan totals, chronological date ranges, non-negative payment components, payment dates within the loan range, and cumulative paid principal that does not exceed the original amount. | Catch an accidental payment that would overpay principal. | Prevents contradictory loan balances and invalid schedules. |

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
