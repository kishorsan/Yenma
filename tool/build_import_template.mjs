import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputPath = new URL(
  "../assets/templates/Yenma-Transaction-Import.xlsx",
  import.meta.url,
);
const previewDir = new URL("../build/import-template-preview/", import.meta.url);
const font = "Arial";
const navy = "#17324D";
const blue = "#2D6A9F";
const paleBlue = "#EAF3FA";
const paleYellow = "#FFF4CC";
const border = "#CFD8E3";

const workbook = Workbook.create();
const transactions = workbook.worksheets.add("Transactions");
const reference = workbook.worksheets.add("Reference");

transactions.showGridLines = false;
transactions.tabColor = navy;
transactions.getRange("A2").values = [["Yenma transaction import"]];
transactions.getRange("A2:L2").format.font = {
  name: font,
  size: 16,
  bold: true,
  color: navy,
};
transactions.getRange("A3").values = [[
  "Enter one transaction per row. Keep source_record_id unchanged when re-importing the same statement.",
]];
transactions.getRange("A3:L3").format.font = {
  name: font,
  size: 10,
  italic: true,
  color: "#4B5F73",
};
transactions.getRange("A4:L4").format.borders = {
  bottom: { style: "thin", color: blue },
};

const headers = [
  "source_record_id",
  "transaction_date",
  "description",
  "amount_inr",
  "transaction_type",
  "institution",
  "instrument_type",
  "instrument_last4",
  "currency",
  "category",
  "reference",
  "note",
];
transactions.getRange("A5:L5").values = [headers];
transactions.getRange("A5:L5").format = {
  fill: navy,
  font: { name: font, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: {
    insideVertical: { style: "thin", color: "#FFFFFF" },
    bottom: { style: "thin", color: navy },
  },
};
transactions.getRange("A6:L205").format = {
  font: { name: font, size: 10, color: "#1F2933" },
  verticalAlignment: "center",
  borders: {
    insideHorizontal: { style: "thin", color: border },
    bottom: { style: "thin", color: border },
  },
};
transactions.getRange("A6:G205").format.fill = paleYellow;
transactions.getRange("I6:I205").format.fill = paleYellow;
transactions.getRange("B6:B205").format.numberFormat = "dd-mmm-yyyy";
transactions.getRange("D6:D205").format.numberFormat = "₹#,##0.00";
transactions.getRange("H6:H205").format.numberFormat = "0000";
transactions.getRange("A6:A205").format.numberFormat = "@";
transactions.getRange("H6:H205").format.numberFormat = "@";
transactions.getRange("K6:K205").format.numberFormat = "@";
transactions.getRange("E6:E205").dataValidation = {
  rule: { type: "list", values: ["Expense", "Income", "Transfer"] },
};
transactions.getRange("G6:G205").dataValidation = {
  rule: { type: "list", values: ["Bank Account", "Credit Card"] },
};
transactions.getRange("I6:I205").dataValidation = {
  rule: { type: "list", values: ["INR"] },
};
transactions.getRange("J6:J205").dataValidation = {
  rule: {
    type: "list",
    values: [
      "Food",
      "Groceries",
      "Transport",
      "Shopping",
      "Health",
      "Entertainment",
      "Bills",
      "Subscriptions",
      "Education",
      "Salary",
      "Investment",
      "Transfer",
      "Other",
      "Rent",
      "Received",
      "Wallet",
      "Savings",
    ],
  },
};

for (const column of ["A", "B", "C", "D", "E", "F", "G", "I"]) {
  transactions
    .getRange(`${column}6:${column}205`)
    .conditionalFormats.addCustom(
      `=AND(COUNTA($A6:$L6)>0,${column}6="")`,
      { fill: "#FDE8E7", font: { color: "#B42318", bold: true } },
    );
}
transactions.getRange("A5:L205").format.rowHeight = 20;
transactions.getRange("A5:L5").format.rowHeight = 34;
const widths = [
  ["A:A", 21],
  ["B:B", 17],
  ["C:C", 30],
  ["D:D", 15],
  ["E:E", 17],
  ["F:F", 23],
  ["G:G", 18],
  ["H:H", 16],
  ["I:I", 11],
  ["J:J", 18],
  ["K:K", 23],
  ["L:L", 34],
];
for (const [range, width] of widths) {
  transactions.getRange(range).format.columnWidth = width;
}
transactions.freezePanes.freezeRows(5);
transactions.tables.add("A5:L205", true, "YenmaTransactions");

reference.showGridLines = false;
reference.tabColor = "#7A8DA1";
reference.getRange("A2").values = [["Template instructions"]];
reference.getRange("A2:H2").format.font = {
  name: font,
  size: 16,
  bold: true,
  color: navy,
};
reference.getRange("A4:B4").values = [["Step", "What to do"]];
reference.getRange("A5:B8").values = [
  [1, "Export or transform the bank statement into the Transactions sheet."],
  [2, "Keep the exact header names and enter one transaction per row."],
  [3, "Use a stable source_record_id so importing the same file again is safe."],
  [4, "Save as .xlsx and select the file in Yenma."],
];
reference.getRange("A10:D10").values = [[
  "Column",
  "Required",
  "Accepted value or format",
  "Meaning",
]];
reference.getRange("A11:D22").values = [
  ["source_record_id", "Yes", "Text; unique within the source", "Stable bank transaction/reference ID. Reuse it on re-export."],
  ["transaction_date", "Yes", "Excel date", "Posting date used in Yenma."],
  ["description", "Yes", "Text", "Merchant, payer, or statement narration."],
  ["amount_inr", "Yes", "Positive number", "Absolute amount in rupees, including paise."],
  ["transaction_type", "Yes", "Expense, Income, or Transfer", "How the transaction affects summaries."],
  ["institution", "Yes", "Text", "Bank or card issuer, for example HDFC Bank."],
  ["instrument_type", "Yes", "Bank Account or Credit Card", "Financial instrument used."],
  ["instrument_last4", "No", "Four digits as text", "Masked account/card identity when available."],
  ["currency", "Yes", "INR", "Phase 2 supports INR only."],
  ["category", "No", "Yenma category name", "Leave blank to import as Other or Transfer."],
  ["reference", "No", "Text", "Bank reference, UTR, cheque number, or transaction ID."],
  ["note", "No", "Text", "Additional context retained with the transaction."],
];
reference.getRange("A24:L24").values = [headers];
reference.getRange("A25:L27").values = [
  ["HDFC-20261015-000123", new Date(2026, 9, 15), "Corner Cafe", 125.5, "Expense", "HDFC Bank", "Bank Account", "1234", "INR", "Food", "000123", "Lunch"],
  ["HDFC-20261016-000124", new Date(2026, 9, 16), "Salary", 85000, "Income", "HDFC Bank", "Bank Account", "1234", "INR", "Salary", "000124", "October salary"],
  ["HDFC-20261017-000125", new Date(2026, 9, 17), "Credit card payment", 4856, "Transfer", "HDFC Bank", "Bank Account", "1234", "INR", "Transfer", "000125", "HDFC card ending 4321"],
];

for (const headerRange of ["A4:B4", "A10:D10", "A24:L24"]) {
  reference.getRange(headerRange).format = {
    fill: navy,
    font: { name: font, size: 10, bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { insideVertical: { style: "thin", color: "#FFFFFF" } },
  };
}
reference.getRange("A5:B8").format.font = { name: font, size: 10 };
reference.getRange("A11:D22").format.font = { name: font, size: 10 };
reference.getRange("A25:L27").format.font = { name: font, size: 10 };
reference.getRange("B5:B8").format.fill = paleBlue;
reference.getRange("B11:B22").format.horizontalAlignment = "center";
reference.getRange("B25:B27").format.numberFormat = "dd-mmm-yyyy";
reference.getRange("D25:D27").format.numberFormat = "₹#,##0.00";
reference.getRange("H25:H27").format.numberFormat = "@";
reference.getRange("A:A").format.columnWidth = 23;
reference.getRange("B:B").format.columnWidth = 50;
reference.getRange("C:C").format.columnWidth = 29;
reference.getRange("D:D").format.columnWidth = 48;
for (const column of ["E:E", "F:F", "G:G", "H:H", "I:I", "J:J", "K:K", "L:L"]) {
  reference.getRange(column).format.columnWidth = 19;
}
reference.getRange("A4:L27").format.verticalAlignment = "center";
reference.getRange("A11:D22").format.borders = {
  insideHorizontal: { style: "thin", color: border },
};
reference.getRange("A25:L27").format.borders = {
  insideHorizontal: { style: "thin", color: border },
  insideVertical: { style: "thin", color: border },
};

workbook.recalculate();
const dataCheck = await workbook.inspect({
  kind: "table",
  range: "Reference!A10:D22",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 6,
});
console.log(dataCheck.ndjson);
const errorCheck = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errorCheck.ndjson);

await fs.mkdir(new URL(".", outputPath), { recursive: true });
await fs.mkdir(previewDir, { recursive: true });
for (const [sheetName, range, fileName] of [
  ["Transactions", "A1:L16", "transactions.png"],
  ["Reference", "A1:L27", "reference.png"],
]) {
  const preview = await workbook.render({ sheetName, range, scale: 1.4, format: "png" });
  await fs.writeFile(new URL(fileName, previewDir), new Uint8Array(await preview.arrayBuffer()));
}
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath.pathname.replace(/^\/(.:)/, "$1"));
console.log(outputPath.pathname.replace(/^\/(.:)/, "$1"));
