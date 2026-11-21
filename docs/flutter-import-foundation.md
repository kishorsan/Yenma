# Flutter import foundation — Phase 1

Status: foundation implementation started 16 October 2026. This document uses
the current Flutter working tree as evidence. Native message reading and
background scheduling were not inspected and remain unverified.

## What Phase 1 means

Phase 1 creates a trustworthy boundary between an external source (currently
bank SMS) and Yenma's transaction ledger. Importing must be repeatable,
explainable, and safe before more sources or automation are added.

### Accounts and cards model

**Need:** a bank account and its credit card must not be represented only by a
free-form transaction label. Yenma needs a stable instrument record containing
the institution, account/card type, masked last four digits when available, and
a display name.

**Implemented foundation:** `financial_accounts` is populated from parsed
imports and deduplicated by institution, instrument type, and last four digits.
Transactions continue to retain their current instrument fields, so existing
screens do not require an immediate migration.

**User benefit (inferred):** future balances, account filters, and transfer
matching can refer to the same instrument instead of guessing from text.

**Unresolved product intent:** manual account creation, renaming, merging two
partially identified accounts, opening balances, and whether one card can move
between replacement numbers.

### Import inbox

**Need:** external records should land in a durable staging/audit area rather
than disappear when they cannot be parsed or when they are duplicates.

**Implemented foundation:** every newly observed SMS is stored in
`import_inbox` with source identity, raw payload, delivery time, outcome, reason,
linked financial account, and linked ledger transaction when imported.
Supported records are still promoted automatically to preserve today's UX.

**User benefit (inferred):** a future diagnostics or review screen can explain
why a message did or did not become a transaction.

**Unresolved product intent:** whether ambiguous records should wait for manual
approval, how long raw payloads should be retained, and what redaction/export
controls are required for sensitive message content.

### Deduplication and provenance

**Need:** repeated scans, overlapping date windows, and resent notifications
must not create duplicate ledger entries. Every imported transaction must also
be traceable to the source item that created it.

**Implemented foundation:** exact source IDs, identical source payloads, and
existing external transaction IDs are checked. Outcomes are recorded as
`duplicate` with a machine-readable reason. Imported rows receive an immutable
`transaction_provenance` link to their inbox item.

**Important limit:** fuzzy matching by amount/merchant/date is deliberately not
used for automatic deletion because two legitimate purchases can look alike.

### Transfer and card-payment reconciliation

**Need:** paying a credit-card bill can generate an account debit and a card
payment notification for the same movement. Treating one side as spending can
double count it.

**Implemented foundation:** account-debit and card-payment records with the same
amount within three calendar days produce a `suggested` reconciliation link.
The implementation does not silently reclassify or delete either transaction.

**Unresolved product intent:** the confirmation UI, whether confirmation should
convert both rows to a single transfer, retain two linked legs, or hide one leg,
and how partial/combined card payments should work.

### Last-covered-date cursors

**Need:** “last run time” is not proof that all data before that time was read.
A failed run must not advance coverage and create a permanent gap.

**Implemented foundation:** `import_cursors` stores the exclusive end of the
last successfully read interval per source. SMS sync now starts at that cursor,
or approximately three months back on first use, and advances it only after the
read and database import complete.

**Important limit:** correctness still depends on the platform implementation
honoring the Dart half-open `[from, until)` request; that native behavior is
unverified.

### Import diagnostics

**Need:** support and users need to distinguish “nothing new” from “everything
was duplicate,” “messages were unsupported,” and “the source failed.”

**Implemented foundation:** `import_runs` records the requested range, start and
completion times, manual/automatic trigger, scanned/parsed/imported/duplicate/
rejected counts, and reconciliation suggestion count. The older SMS run log is
kept for compatibility.

**Still planned:** persist failed runs with sanitized error codes, surface run
history and inbox outcomes in Flutter UI, add retention controls, and expose
reconciliation confirmation/dismissal actions.

## Current data flow

1. Dart requests SMS records for `[last covered through, now)`.
2. Every returned message receives a stable source identity and parser outcome.
3. The repository writes an inbox outcome and performs exact deduplication.
4. Supported unique records create/reuse an account/card, create a ledger row,
   and receive a provenance link in one database transaction.
5. Safe card-payment candidates are stored as suggestions only.
6. A successful run records diagnostics and advances the source cursor.

## Next implementation slices

1. Add repository operations to confirm/dismiss reconciliation suggestions and
   define their ledger effect after product approval.
2. Add an Import activity screen showing run summaries and inbox reasons,
   without exposing full message bodies by default.
3. Record failed runs with sanitized platform/parser/database error codes.
4. Add account management for rename, merge, missing last-four resolution, and
   explicit ownership of transfer endpoints.
5. Add retention/privacy rules for raw source payloads.
