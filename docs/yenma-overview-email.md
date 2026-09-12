Subject: Yenma — what the app does, why it helps, and the improvements we discussed

Hi,

Here is a reading copy of the current Yenma Flutter application: what is implemented, the everyday problems it addresses, and how it makes tracking money more convenient. The proposed debt changes are included separately at the end; they have only been documented, not implemented.

This reflects the Flutter source reviewed on 12 September 2026, including working changes. It is not a verification of the installed app. Kotlin was outside the review scope.

**The purpose of Yenma**

Yenma brings three everyday questions into one local application: Where did my money go? What money came in? Who still owes whom?

It reduces the need to remember payments, calculate monthly totals manually, search through screenshots, or reconstruct shared expenses from conversations. Its four main areas are Overview, Transactions, Debts, and Settings. No account registration is required by the Flutter flow, and records are stored locally in INR.

**Understanding a month at a glance**

Overview shows monthly spending, income, and net cash flow. Spending includes expense entries; net cash flow is income minus expenses. Transfers are excluded from both so moving money between your own accounts does not inflate spending or earnings. This is a summary of recorded activity, not a bank-account balance.

The top three expense categories show where the largest amounts went, with proportional bars. Five recent entries help you check new activity, and View all opens the complete selected-month history. Previous/next controls let you review older months, while tapping the month label returns to the current month.

The convenience is immediate visibility: you can notice a large food bill or a month with more expenses than income without adding up transactions yourself. Pull to refresh reloads stored records, and returning to the app reloads the ledger and debts.

**Recording and correcting money activity**

You can add expenses, income, and transfers with an amount, title, category, date, and optional note. This covers cash payments and anything missing from imported records. Backdated entry lets you record yesterday's purchase today. Future dates are accepted as ordinary dated records; they are not scheduled payments.

There are 13 preset categories: Food, Groceries, Transport, Shopping, Health, Entertainment, Bills, Subscriptions, Education, Salary, Investment, Transfer, and Other. The form offers categories appropriate to the transaction type.

Transactions appear newest first. Each detail page shows its amount, type, category, date, note, and origin. Imported entries include bank attribution. You can edit mistakes, delete with confirmation, or swipe-delete from the transaction list and use its temporary Undo action. Detail-page deletion has confirmation but no Undo.

Forms validate required information and positive amounts, keep your typed values when saving fails, and prevent conflicting actions during saving. Amounts are stored exactly in paise, avoiding floating-point rounding drift. These details make routine correction less frustrating and keep calculations consistent.

**Remembering shared expenses and IOUs**

When you pay for a shared expense, you can record a friend's share while saving the payment. An equal-split shortcut reduces calculation effort, and custom shares are supported. More friends can be added from the payment details. The screen shows the original payment, allocated shares, and your personal or unallocated remainder.

You can also create standalone debts in either direction: money owed to you or money you owe. These are useful for loans and obligations without a linked payment. Each debt records the person, reason, amount, date, and optional note.

The current Debts screen shows separate overall totals for money owed to you and money you owe across all dates. It groups records by person, supports searching people or payment titles, and separates Outstanding from Settled records. Saved-name suggestions avoid repeatedly typing the same friend; matching ignores capitalization and repeated spaces.

Linked debts and their original transactions can be opened from one another, so you can trace an amount back to the bill. Validation prevents all shares from exceeding the payment, repayments from exceeding the debt, and transaction changes that would invalidate existing shares. A payment with linked debts cannot be deleted until those debt records are removed.

**Repayments, evidence, and reminders**

You can record partial repayments or use the full remaining amount, with a date and optional note such as a payment reference. Repayment history explains how the outstanding balance was reached. Removing an incorrect repayment restores that amount to the debt. Fully repaid records currently remain available in Settled history.

Today, one receipt or UPI screenshot of up to 10 MB can be attached to each debt. You can preview it, zoom in, replace it, or remove it. Flutter also has a recovery flow for an interrupted Android photo selection, although native recovery was not verified. It can recover the image, not the unsaved form text. There is no OCR or automatic reading of the bill.

Copy reminder prepares a message for a person with their full outstanding owed-to-you total. You paste and send it yourself. Yenma does not automatically message people or schedule debt reminders.

Deleting a mistaken debt also deletes its repayment history and attachment while keeping the original transaction. It is a correction action, not a record that the debt was paid.

**An accounting example worth remembering**

Suppose you pay ₹500 for dinner and your friend owes ₹250. Yenma shows ₹500 in spending and ₹250 owed to you. If your friend repays ₹100, their outstanding amount becomes ₹150. Spending remains ₹500, and recording that repayment does not create income.

This keeps the payment log and debt log separate. However, it means the dashboard currently shows the full amount paid, not your eventual personal cost after reimbursement. A repayment imported separately from SMS can still become an income or expense entry; there is no automatic matching between SMS transactions and debt repayments.

**Reducing typing through SMS import**

The Flutter implementation includes a Sync bank messages action, first-use consent, progress feedback, and success or error messages. It parses recognized alerts into an amount, income or expense, date, bank, and recipient-derived title. Unrecognized messages are skipped; uncategorized imports use Other.

The first successful sync requests roughly three calendar months of messages. Later syncs request today's messages. Matching import identities help avoid importing the same message repeatedly. When an imported transaction with a recipient key is saved through the ordinary edit path, its category is remembered for later imports with that key. The split-save path currently bypasses this category-learning step.

The parser contains recognition strings for HDFC, Canara, Jupiter, ICICI, SBI, Axis, Kotak, IDFC FIRST, Bank of India, PNB, Central Bank of India, and Union Bank. This is not a guarantee of complete support for every message from those banks. Parsing uses text patterns, can misidentify details, and does not recognize transfers as a separate import type. There is no review queue before insertion or automatic matching with manually entered transactions.

Reading device messages and background scheduling require native functionality that was not inspected. Flutter requests daily scheduling and can trigger a startup sync after 10 p.m. when consent exists and today has not been marked synced. Actual background delivery is unverified. The consent wording says messages are read only when you sync, so the intended manual-versus-automatic behavior still needs clarification. Today-only repeat scans can also miss activity from days when no sync occurred.

**Comfort and reliability**

Settings offers Light, Dark, and Follow system appearance and remembers the choice. A short random welcome phrase appears once per launch, can be skipped immediately, and normally continues after two seconds. Accessible-navigation mode waits for manual continuation. Its likely benefit is tone and branding; a specific financial problem it solves has not been established.

Navigation adapts between a bottom bar and a wider-screen rail. Some summary layouts adapt for larger text. Empty states, loading indicators, retries, and protection against older loads replacing a newer month selection help keep the interface understandable.

The Flutter implementation uses screens and forms for interaction, a shared controller for state and actions, domain models for money and debt rules, and SQLite repositories for persistence. The current database schema is version 4, with upgrade paths for existing Yenma databases. Entries, debts, repayments, images, saved names, and preferences persist locally. This review did not run a build or tests on the working tree.

**The four improvements we have documented**

1. Hide fully repaid debts from the debt screen after two days. This removes completed obligations from everyday attention. Keeping the underlying history rather than deleting it is a recommendation; the exact timing and history-access rules remain open.

2. Show one collapsed row per person, with the amount at the side. Tapping the person expands individual splits. This makes the screen easier to scan. We still need to decide whether opposing obligations should display one net amount or two directional totals. A net display must not silently settle the underlying records.

3. Add reusable split groups for friends who regularly go out together. Choosing a group would populate the people so you only enter their shares and optional notes. This saves repeated selection and description entry. Equal versus manual defaults and support for another friend being the payer remain discussion points.

4. Move the bill attachment to the main transaction, with linked debts referring to it. This keeps one payment's evidence together and avoids duplicating the bill for every person. Attachment count, preserving existing images, and handling standalone debts without a parent transaction still need decisions.

These are proposals only. No application changes have been made for them.

**What the app does not currently provide**

There is no Flutter flow for custom category management, a journal, budgets or budget alerts, recurring or planned spending, savings goals, a today's-spending card, dedicated analytics, transaction text search, custom date-range filtering, bank-account balances, bank-selection toggles, currency conversion, configurable date/week/decimal preferences, a dynamic-color preference, export/backup/restore, migration from the old app, cloud sync, login, biometric/PIN locking, automatic repayment matching, or scheduled debt reminders.

Further product decisions include whether spending should represent full payments or personal cost, how reimbursements should affect income, whether manual entries should all be labeled Cash, whether name-only identity is sufficient for people, and what future-dated entries are meant to represent.

The main value already present is a local record that combines monthly money visibility with person-by-person obligations. The proposed changes focus on making that record quicker to use and easier to read, especially after a shared outing.

— Prepared from the Yenma Flutter feature review and debt-experience discussion, 12 September 2026
