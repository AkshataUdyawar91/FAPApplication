# Requirements Document

## Introduction

This feature adds Purchase Order (PO) balance calculation and display to the Bajaj Document Processing System. When an ASM reviews a submission, the system retrieves PO data from a static JSON data source that mimics the SAP response format, calculates the remaining balance (total PO value minus invoiced GRN amounts), and displays it in the UI. This gives reviewers immediate visibility into how much PO budget remains before approving further invoices.

## Glossary

- **PO (Purchase Order)**: A financial commitment document in SAP identified by a `po_num`.
- **PO_Line_Item**: A single line within a PO, each carrying a `price_without_tax` value and a list of GRN records.
- **GRN (Goods Receipt Note)**: A record of goods received against a PO line item, identified by `gr_mat_doc_num` and carrying an `invoice_value`.
- **PO Balance**: The remaining uncommitted value on a PO, calculated as the sum of all `price_without_tax` values across all line items minus the sum of all non-empty `invoice_value` values across all GRN records.
- **PO_Data_Provider**: The backend service responsible for returning structured PO data from the static JSON data source. The JSON structure mirrors the SAP response format (`response.status`, `response.data.po_header`, `response.data.po_line_item[]`, `gr_data[]`).

**Static JSON Data Source (with dummy invoice values):**
```json
{
  "response": {
    "status": "S",
    "remarks": "Success",
    "data": {
      "po_header": {
        "po_num": "5110014001",
        "company_code": "BAL",
        "po_category": "F",
        "supplier_code": "0000118720",
        "payment_term": "ZP06",
        "po_rel_stat": "X",
        "purchasing_org": "BA01",
        "purchasing_group": "DE4"
      },
      "po_line_item": [
        {
          "po_num": "5110014001",
          "po_line_item": "00010",
          "price_without_tax": "537870.00",
          "currency": "INR",
          "po_line_item_text": "BATTERY",
          "gr_data": [
            { "gr_mat_doc_num": "5074135139", "invoice_num": "2385100596", "iv_flag": "Y", "invoice_value": "150000.00" },
            { "gr_mat_doc_num": "5074095019", "invoice_num": "2385100572", "iv_flag": "Y", "invoice_value": "120000.00" }
          ]
        },
        {
          "po_num": "5110014001",
          "po_line_item": "00020",
          "price_without_tax": "537870.00",
          "currency": "INR",
          "po_line_item_text": "BATTERY",
          "gr_data": [
            { "gr_mat_doc_num": "5074135098", "invoice_num": "2385100595", "iv_flag": "Y", "invoice_value": "200000.00" }
          ]
        }
      ]
    }
  }
}
```
**Expected balance:** 537,870.00 + 537,870.00 − 150,000.00 − 120,000.00 − 200,000.00 = **INR 605,740.00**
- **PO_Balance_Service**: The backend service responsible for orchestrating PO data retrieval from the static data source and computing the PO balance.
- **PO_Balance_Controller**: The ASP.NET Core API controller that exposes the PO balance endpoint.
- **PO_Balance_Widget**: The Flutter UI widget that displays the calculated PO balance.
- **Submission_Detail_Screen**: The Flutter screen where ASMs review submission details before approving or rejecting.

---

## Requirements

### Requirement 1: Fetch PO Data from Static JSON Source

**User Story:** As an ASM, I want the system to retrieve PO data using the PO number on a submission, so that the balance calculation reflects the PO structure and values.

#### Acceptance Criteria

1. WHEN a valid `po_num` is provided, THE PO_Data_Provider SHALL return the full PO response from the static JSON data source, including `po_header` and all `po_line_item` entries with their nested `gr_data` arrays.
2. IF the static JSON response contains a `status` field not equal to `"S"`, THEN THE PO_Data_Provider SHALL return a descriptive error indicating the failure reason from the `remarks` field.
3. WHEN the static JSON response contains an empty `po_line_item` array, THE PO_Data_Provider SHALL return a valid response with zero line items rather than an error.
4. THE PO_Data_Provider SHALL return data whose structure conforms to the SAP response format: a top-level `response` object containing `status`, `remarks`, and `data` fields, where `data` contains `po_header` and `po_line_item` arrays.

---

### Requirement 2: Calculate PO Balance

**User Story:** As an ASM, I want the system to calculate the real-time PO balance from SAP data, so that I can see exactly how much budget remains on the PO before approving an invoice.

#### Acceptance Criteria

1. THE PO_Balance_Service SHALL calculate PO Balance as: sum of `price_without_tax` across all `po_line_item` entries, minus the sum of `invoice_value` across all `gr_data` entries in all line items.
2. WHEN a `gr_data` entry has an empty string or null `invoice_value`, THE PO_Balance_Service SHALL treat that entry's invoice value as zero in the calculation.
3. WHEN a `po_line_item` has an empty or null `price_without_tax`, THE PO_Balance_Service SHALL treat that line item's price as zero in the calculation.
4. THE PO_Balance_Service SHALL return the balance as a decimal value with the currency code from the first `po_line_item` entry that contains a non-empty `currency` field.
5. WHEN all `po_line_item` entries have empty `currency` fields, THE PO_Balance_Service SHALL return the balance with a currency code of `"UNKNOWN"`.
6. THE PO_Balance_Service SHALL preserve two decimal places in the calculated balance.

---

### Requirement 3: Expose PO Balance via API Endpoint

**User Story:** As a frontend developer, I want a dedicated API endpoint to retrieve the PO balance for a given PO number, so that the Flutter UI can display it without coupling to SAP directly.

#### Acceptance Criteria

1. THE PO_Balance_Controller SHALL expose a GET endpoint at `/api/po-balance/{poNum}` that accepts a PO number as a route parameter.
2. WHEN a valid `poNum` is provided and the SAP call succeeds, THE PO_Balance_Controller SHALL return HTTP 200 with a JSON response containing `poNum`, `balance`, `currency`, and `calculatedAt` fields.
3. IF `poNum` is null, empty, or contains only whitespace, THEN THE PO_Balance_Controller SHALL return HTTP 400 with a descriptive validation error.
4. IF the PO_Data_Provider returns an error, THEN THE PO_Balance_Controller SHALL return HTTP 502 with a descriptive error message and a correlation ID.
5. THE PO_Balance_Controller SHALL require a valid JWT token with at least the ASM or HQ role to access the endpoint.

---

### Requirement 4: Display PO Balance in the Flutter UI

**User Story:** As an ASM, I want to see the real-time PO balance displayed on the submission detail screen, so that I can make an informed approval decision.

#### Acceptance Criteria

1. WHEN the Submission_Detail_Screen loads and a `po_num` is available on the submission, THE PO_Balance_Widget SHALL fetch and display the PO balance from the `/api/po-balance/{poNum}` endpoint.
2. WHILE the PO balance is being fetched, THE PO_Balance_Widget SHALL display a loading indicator in place of the balance value.
3. IF the API call to retrieve the PO balance fails, THEN THE PO_Balance_Widget SHALL display a user-friendly error message and a retry button.
4. WHEN the PO balance is successfully retrieved, THE PO_Balance_Widget SHALL display the balance formatted as a currency value with the currency code (e.g., `INR 1,075,740.00`).
5. WHEN the calculated PO balance is negative, THE PO_Balance_Widget SHALL display the balance in a visually distinct style (e.g., red color) to indicate an over-committed PO.
6. WHEN a submission does not have a `po_num`, THE PO_Balance_Widget SHALL not be rendered on the Submission_Detail_Screen.

---

### Requirement 5: Balance Calculation Correctness

**User Story:** As a finance stakeholder, I want the PO balance calculation to be verifiable and consistent, so that I can trust the displayed values match what SAP holds.

#### Acceptance Criteria

1. THE PO_Balance_Service SHALL produce a balance of zero when the sum of all `invoice_value` entries equals the sum of all `price_without_tax` entries.
2. THE PO_Balance_Service SHALL produce a positive balance when the sum of all `invoice_value` entries is less than the sum of all `price_without_tax` entries.
3. THE PO_Balance_Service SHALL produce a negative balance when the sum of all `invoice_value` entries exceeds the sum of all `price_without_tax` entries.
4. FOR ALL valid SAP PO responses, THE PO_Balance_Service SHALL produce the same balance regardless of the order in which `po_line_item` entries or `gr_data` entries appear in the response (order-independence property).
5. THE PO_Balance_Service SHALL produce a balance equal to the total `price_without_tax` sum when all `gr_data` arrays are empty or all `invoice_value` fields are empty strings.
6. FOR the static JSON data source, THE PO_Balance_Service SHALL produce a balance of `605740.00 INR` (537870.00 + 537870.00 − 150000.00 − 120000.00 − 200000.00).
