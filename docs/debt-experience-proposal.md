# Debt experience: discussion and proposed requirements

Started: 12 September 2026. Status: discussion draft; not implemented.

Scope: Flutter application only. Kotlin remains outside scope. This document records the user's requested direction separately from recommendations and unanswered questions. The [current feature inventory](flutter-features.md) continues to describe existing behavior.

## Purpose

Make the debt screen answer “Who do I need to settle with, and how much?” with minimal scanning. Show individual payment details only when requested. Reduce repeated entry for friends who regularly spend together, and keep the bill with the transaction it describes.

## 1. Hide repaid debts after two days

**User request:** keep a fully repaid debt visible for two days, then stop showing it on the debt screen.

**Problem:** completed obligations create clutter after they stop requiring attention.

**Proposed behavior:**

- Outstanding debts remain visible, including partially repaid debts.
- Fully repaid debts remain available on the debt screen during the two-day window, clearly marked as settled.
- After that window, hide the settled record from the debt screen and its expanded person rows. If a person has no remaining visible records, their row disappears.
- Hiding is a display rule. Preserve the debt, repayments, and transaction relationship in storage; do not delete financial history automatically.
- If a repayment is reversed and a balance becomes outstanding again, show the debt immediately.

**Recommendation, pending agreement:** use 48 hours from the moment the app records full settlement. A backdated repayment should still get a review window after entry. If a debt is reopened and fully settled again, restart the window. The current model calculates settlement from the remaining amount and does not store a settlement timestamp, so this requires persisted settlement timing.

**Open:** does “two days” mean 48 hours or two calendar days? Should older settled records be reachable through a separate history action, only through their linked transaction, or another route? Standalone debts also need a way to recover old records if corrections are required. Existing settled debts need a migration policy because their actual settlement-recording time is unknown.

## 2. Collapse debts into one row per person

**User request:** show the person's name and full amount at the side. Tapping the name expands all their individual split amounts.

**Problem:** showing every obligation at once makes it difficult to find the amount that matters for a person.

**Proposed behavior:**

- Each person starts collapsed, with their name, amount, direction, and an expansion indicator.
- Tapping the person row expands their individual debts with payment description, remaining amount, direction, and optional note. Recently settled entries follow the two-day rule above.
- Individual records still open their details for repayment and corrections.
- Totals use outstanding amounts, not original shares, and clearly identify whether the person owes the user or the user owes them.

**Key decision:** what does the single “full amount” mean when money is owed in both directions?

Example: Arun owes the user ₹800; the user owes Arun ₹300.

| Option | Collapsed row | Meaning |
| --- | --- | --- |
| Recommended: net amount | Arun — owes you ₹500 | One amount describes the net position. Expansion still shows ₹800 receivable and ₹300 payable with their individual records. |
| Separate directional totals | Arun — owes you ₹800 / you owe ₹300 | Keeps both obligations explicit, but displays two amounts. |

A net display must not silently mark either debt repaid. If equal opposing outstanding amounts produce net zero, the person still has unresolved records and remains visible, with a label such as “Net ₹0 · open debts.” The two-day hiding rule applies to actual settlement, not netting.

**Open:** confirm the amount convention. If net amounts are chosen, copied reminders and overall totals must use clearly consistent wording; the current reminder asks for gross owed-to-you amounts. Whether paying one net amount should settle multiple records is a separate future decision, not implied by collapsing the display.

## 3. Reusable groups for splitting transactions

**User request:** create a reusable group for people who often go out together; select it for a split, enter names and amounts, and make each person's note optional.

**Problem:** repeatedly selecting the same friends and repeating payment descriptions slows down recording a shared bill.

**Proposed flow:**

1. Create a named group, such as “Dinner friends,” containing the user and two friends.
2. Add or open the main expense transaction and choose the group for its split.
3. Show the group members together. Enter each friend's share; allow an optional note per person. Use the transaction description as the shared context rather than requiring another description for every friend.
4. Show the user's share or unallocated remainder and validate that allocated amounts do not exceed the bill.
5. Save the split together so a failure does not leave only some members recorded.

**Recommendations, pending agreement:** groups save membership rather than fixed amounts; allow a member to be omitted for a particular outing without changing the saved group. Changes to group membership apply to future splits and do not rewrite past obligations. The user's own share must not become a debt owed to themselves.

Example: a ₹900 dinner with ₹300 for each of three people creates a ₹900 expense and two ₹300 friend debts when the user paid. The user's ₹300 is their personal remainder. Notes can be blank. The reusable group avoids selecting the two friends again on the next outing.

**Open:** should selecting a group automatically split equally, or leave shares empty for manual entry? Should the first version support only “I paid,” matching the current linked-expense model, or also choosing a friend as payer? Group payment by another person needs explicit rules for the user's transaction and debts; it should not create an expense claiming the user paid the full bill.

## 4. Attach the bill to the main transaction

**User request:** move the bill attachment from debts to the main transaction.

**Problem:** a bill describes one payment shared by several people; attaching it separately to debts duplicates evidence and puts it in the wrong place.

**Proposed behavior:**

- Attach, view, replace, or remove the bill from transaction creation/editing and transaction details, including transactions without splits.
- Linked debts reference their parent transaction's bill instead of owning separate copies. A View bill action can open that shared attachment.
- Deleting a linked debt leaves the transaction and its bill intact.
- Replacing the transaction's bill updates what all linked debts show.
- Keep attachment notes separate from optional person-specific notes.

**Migration recommendation:** preserve all existing images. Move a linked debt's existing bill to its transaction. If several linked debts contain different images, retain them all until a clear consolidation policy is agreed; do not arbitrarily choose one and discard the rest. The current one-image-per-debt model means a transaction attachment model and migration are required.

**Open:** should a transaction support one bill image or multiple images/pages? What should happen to attachments on standalone debts that have no parent transaction? Existing standalone images must remain available until a migration decision is made. Do repayment proofs need their own attachment location, or are attachments only for the original bill?

## Discussion order

First settle what the person-row amount means. Next confirm the two-day timing/history rule, group split defaults and payer scope, then transaction attachment count and standalone-debt handling. These decisions can be answered incrementally and recorded here without implementing application changes yet.

## Acceptance outline after decisions are agreed

- A person with many debts occupies one collapsed row; expansion reveals accurate individual balances.
- Partial repayment updates person totals. Opposing debts follow the chosen amount convention without silently becoming settled.
- Fully settled entries disappear after the agreed window, survive restart in storage, and reappear if reopened.
- Selecting a saved group populates the intended people; notes are optional; historical splits survive membership changes.
- A shared bill is managed from the main transaction and accessible from linked debt records; migration loses no images.
- Only Flutter code and its data migration are in implementation scope unless the user explicitly changes the Kotlin restriction.
