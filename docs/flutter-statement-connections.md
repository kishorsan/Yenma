# Flutter statement connections — Phase 2

Status: canonical CSV/XLSX adapters, configurable mappings, saved profiles, and
the default Excel template were started on 16 October 2026. File-selection UI,
PDF ingestion, and a hosted transformation service remain planned. Native file
picker behavior has not been implemented or verified.

## Architecture decision

Yenma should not contain a growing collection of fragile bank-specific parsers.
The Flutter app owns one canonical statement contract. A separate transformation
service can recognize Canara Bank, HDFC Bank, and other source layouts and emit
that contract as XLSX or CSV.

The boundary is:

`Bank statement → transformation service → Yenma workbook → import inbox → ledger`

This lets the service evolve bank-specific parsing independently while Yenma
keeps local validation, account matching, duplicate protection, provenance,
diagnostics, and user review.

## Default workbook contract

The bundled template is
`assets/templates/Yenma-Transaction-Import.xlsx`. It contains a blank,
validated `Transactions` table and a `Reference` sheet with instructions,
definitions, and examples.

| Column | Required | Rule |
| --- | --- | --- |
| `source_record_id` | Yes | Stable and unique within one source/profile. It must remain unchanged when the same statement is transformed again. |
| `transaction_date` | Yes | Excel date or a supported date string. |
| `description` | Yes | Merchant, payer, or statement narration. |
| `amount_inr` | Yes | Positive rupee amount. Direction comes from `transaction_type`. |
| `transaction_type` | Yes | `Expense`, `Income`, or `Transfer`. |
| `institution` | Yes | Bank or card issuer. |
| `instrument_type` | Yes | `Bank Account` or `Credit Card`. |
| `instrument_last4` | No | Last four digits, stored as text. |
| `currency` | Yes | `INR` in the current phase. |
| `category` | No | Existing Yenma category name. Invalid or blank values safely fall back to `Other`; transfers use `Transfer`. |
| `reference` | No | UTR, cheque number, bank reference, or transaction ID. |
| `note` | No | Additional context. |

The workbook uses typed dates and amounts, validations for controlled values,
required-input coloring, frozen headers, and 200 prepared rows. The example data
is isolated on `Reference`, so importing the blank template cannot create sample
transactions.

## CSV and XLSX adapters

The Dart decoder reads CSV or XLSX into a neutral row matrix. The mapping layer
then converts rows into the Phase 1 `ImportRecord` model.

The canonical profile expects the exact template headers. A configurable
profile can instead map arbitrary headers such as `Txn Id`, `Posted`,
`Narration`, `Debit`, and `Credit`. Profiles may provide constants for values
that are not columns, such as institution, account type, last four digits, and
currency.

Mappings support either:

- one positive amount column plus a transaction-type column; or
- separate debit and credit columns, from which transaction type is inferred.

Invalid rows are not silently discarded. They become rejected import-inbox
records with a row number and reason such as invalid date, invalid amount,
missing institution, or unsupported currency.

## Re-import without duplicates

The external transaction identity is:

`statement:<profile source key>:<source_record_id>`

The profile source key identifies a particular account/feed and does not change
when the profile is renamed. The transformed `source_record_id` identifies the
bank event. Re-importing an overlapping or identical statement therefore reaches
the existing Phase 1 external-ID and inbox deduplication checks.

The transformation service must never generate a new random ID for an existing
bank event. Prefer the bank's transaction/reference ID. If none exists, the
service should generate a deterministic fingerprint from stable source fields
and document that rule.

## Saved import profiles

SQLite schema version 18 stores profile name, stable source key, file format,
worksheet, zero-based header row, column mappings, and default field values.
This is the persistence foundation for a future mapping UI and repeat imports.

## Separate transformation service contract

The service should:

1. accept the original statement through an explicit user upload;
2. detect the bank/layout and extract transaction rows;
3. preserve a stable source record ID and bank reference;
4. normalize dates, positive INR amounts, direction, institution, instrument,
   and optional last four digits;
5. output the exact Yenma template columns without macros, formulas, hidden
   transaction rows, or sample records;
6. validate required fields before returning the workbook;
7. avoid retaining the original statement or generated workbook beyond a clear,
   user-approved retention period.

The service should not decide Yenma ledger deduplication or silently merge
transactions. Yenma remains authoritative for import outcomes and provenance.

## Planned work

1. Add Flutter file selection, preview, row-error review, and import confirmation.
2. Add the configurable mapping screen and profile picker using the implemented
   profile repository.
3. Define transformation-service authentication, encryption, retention, audit,
   size limits, and failure responses before uploading financial statements.
4. Add initial HDFC and Canara transformers and fixture-based contract tests.
5. Add user-selected PDF statements only after the canonical CSV/XLSX workflow
   is reliable. PDF extraction belongs in the transformation layer unless a
   document is already structured enough for safe local parsing.
