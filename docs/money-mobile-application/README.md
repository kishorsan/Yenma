# Money Mobile Application — documentation

Reviewed: 11 September 2026.

Reference project: `C:\Users\kisho\AndroidStudioProjects\Money`.
Reference package: `com.kiki.money`; product also calls itself Kiki Money.
Git HEAD: `33d633f9092c39c364f8aa7690719a392e9c5b25`.

This review uses the current working tree, including uncommitted changes to Transaction.kt, TransactionEditScreen.kt, KnownBankAccounts.kt and SmsReader.kt. HEAD alone does not reproduce the reviewed snapshot. Existing OverallArchitecture/PROJECT_CONTEXT.md was consulted, but executable source takes precedence over its broader feature claims.

## Documents

- [Debt management](debt_management.md): implemented splits, IOUs, attachments, notes and repayments in Yenma 0.2.0.
- [Current Yenma implementation status](implementation_status.md): delivered Flutter increment, validation and next steps.
- [Implementation](implementation.md): current implementation, known gaps, phased Flutter delivery and verification.
- [Software architecture](software_architecture.md): current components, schema, data flows and proposed Flutter architecture.
- [Features](features.md): source-backed feature inventory, behavior and acceptance criteria.

## Scope and evidence

This is a static source review, not a successful build or device test. “Implemented” means a source workflow exists; it does not certify that the current checkout compiles or works on a device. No Kotlin changes or Flutter application implementation were made for this documentation task.

Reviewed areas include Gradle configuration, manifest, navigation, entities, DAOs, repositories, ViewModels, screen logic, SMS parsing, seeds, preferences and existing tests. Build outputs and the bundled SMS backup were not used as behavioral evidence; personal SMS contents are not reproduced here.

In the documents, paths beginning with `data/`, `presentation/`, or `sms/` are relative to `app/src/main/java/com/kiki/money/` in the reference project. Proposed architecture and acceptance criteria describe future work, not existing capabilities.
