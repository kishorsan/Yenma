# Debt management — Yenma 0.2.0

## A ₹500 meal split

1. Add an Expense for ₹500 with its title, category and date.
2. Enable **Split with a friend**, enter their name and the amount they owe.
3. **Split equally** assigns ₹250 to the friend and leaves ₹250 for you. For an odd paise, the extra paise stays with you. If the friend owes the entire ₹500, enter ₹500 instead.
4. Add a note such as “Pay whenever you can” and optionally attach a receipt/UPI screenshot.
5. Save once. The payment and its linked debt are saved atomically.

Payment details show what you paid, your share/unallocated amount, and each friend's original share and remaining debt. Use **Add a friend’s share** to split an existing expense or add more people. Original shares together cannot exceed the payment, including shares already repaid.

## Debt log and reminders

The **Debts** tab shows money owed to you and money you owe across all dates. Entries are grouped by person, with Outstanding/Settled tabs and search by person or description. Grouping ignores capitalization and repeated spaces; use distinct names for different people with the same first name. This version has no contact IDs or phone-book integration.

**Add debt** supports standalone “Owed to me” and “I owe” records. A standalone debt does not create a transaction, so an existing IOU can be recorded without duplicating the original payment. Linked debts are only supported for expenses you paid and mean “Owed to me.”

**Copy reminder** copies a polite message with the person's complete outstanding total owed to you across all dates, even when search filters the displayed records. You choose where and when to share it. Yenma sends no messages and initiates no UPI transfers.

## Screenshots and notes

Each debt supports a note and one image from the photo picker. Debt details show a preview; tap to zoom. Edit debt lets you replace/remove the image and update the note.

- Images must be decodable and no larger than 10 MB. Common JPG, PNG and WebP screenshots work. PDFs and multiple attachments are not included.
- Screenshot bytes are saved in SQLite, not left in picker cache files. Rows use 256 KiB chunks to avoid Android CursorWindow limits; list queries do not load image bytes.
- Replacing/removing a screenshot is atomic with the debt edit. Canceling the picker preserves the existing selection; canceling the form does not save a new attachment. A failed save retains form values and the selected image for retry.
- If Android destroys the activity while the picker is open, startup attempts image recovery. A banner in Debts lets you use the recovered screenshot in a new debt after re-entering details, or discard it. It is not assigned automatically to an unrelated record.
- Attachments remain local. Backup/export is not implemented yet.

The gallery integration uses [Flutter's image_picker](https://pub.dev/packages/image_picker). No broad storage, contacts, camera or SMS permissions were added.

## Repayments and accounting

**Record repayment** stores the amount received (or paid for “I owe”), its date and an optional reference/note. Use a partial amount or **Use full remaining amount**. Remaining balance equals the original share minus all recorded repayments; zero means settled. Repayments cannot exceed the remaining debt, precede the debt date or be dated in the future.

History remains available after settlement. Remove an incorrect repayment with confirmation to restore the balance. Editing the debt cannot reduce its original amount below recorded repayments or move its date after its first repayment. Direction and payment linkage are fixed after creation.

The dashboard shows **gross payments**, including the full ₹500 meal. Your portion is shown separately in the payment split; expense totals are not silently recalculated. Recording repayment changes the debt log only and does not insert duplicate income/expenses. Bank balances, automatic UPI reconciliation and SMS import are not part of this increment.

Deleting a payment is blocked while linked debt records exist, even if settled. A linked payment cannot be changed away from expense or reduced below its shares. Deleting a debt requires confirmation and removes its attachment and repayment history while keeping the original transaction. Deletion is not settlement.

## Implementation and checks

SQLite schema **2** adds `debts`, `repayments` and `debt_receipt_chunks` through a non-destructive **1→2** migration. Existing transactions, categories and preferences are retained.

- `lib/domain/debt.dart`: debt/repayment models and repository contract.
- `lib/data/debt_repository.dart`: atomic writes, share constraints and repayment accounting.
- `lib/data/receipt_source.dart`: injectable picker, image validation and recovery.
- `lib/features/debts/`: log, debt/detail/repayment forms and attachment UI.
- Existing transaction forms/details and navigation integrate the feature.

Automated tests cover migration, atomic split rollback, over-allocation, protected payments, partial/full repayment and undo, concurrent overpayment prevention, invalid dates, cascade deletion, screenshot chunking/reopen/replace/remove and standalone IOUs. Widget tests cover a ₹500/₹250 split with screenshot/note, repayment flow, canceled selection and failed-save retention.

The Android test uses a separate `yenma-debt-device-test.db`, never the user's `yenma.db`. It exercises native SQLite with a 3 MB attachment, reopening, replacement and the repayment screen. The system gallery picker itself still needs manual selection testing; widget tests inject the image source.

Validation on 11 September 2026: 18 unit/widget/repository tests passed, the native Android integration test passed on Pixel 7 / API 35, and light/dark previews were rendered and inspected. The delivered APK is rebuilt from the normal app entry point after running the integration test.

```powershell
flutter analyze
flutter test
flutter test integration_test/debt_flow_test.dart -d <android-device-id>
flutter build apk --debug
```

Light/dark screenshots under `docs/previews/debts-*.png` contain synthetic examples.
