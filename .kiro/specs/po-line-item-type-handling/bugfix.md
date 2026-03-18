# Bugfix Requirements Document

## Introduction

The SAP PO Balance API returns the `po_line_item` field inconsistently: as a JSON array when multiple line items exist, and as a JSON object when only one line item exists. The Infrastructure layer currently deserializes this field expecting it to always be an array, causing a deserialization/parsing error for any PO with a single line item. This fix normalizes `po_line_item` to always be treated as a list regardless of the API response shape.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the SAP PO Balance API returns `po_line_item` as a JSON object (single line item) THEN the system fails with a deserialization error and cannot process the PO balance response

1.2 WHEN the SAP PO Balance API returns `po_line_item` as a JSON object THEN the system returns an error to the caller instead of the parsed PO data

### Expected Behavior (Correct)

2.1 WHEN the SAP PO Balance API returns `po_line_item` as a JSON object (single line item) THEN the system SHALL normalize it into a single-element list and continue processing without error

2.2 WHEN the SAP PO Balance API returns `po_line_item` as a JSON object THEN the system SHALL return the parsed PO data to the caller with the line item correctly included in the list

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the SAP PO Balance API returns `po_line_item` as a JSON array (multiple line items) THEN the system SHALL CONTINUE TO deserialize all line items correctly into the list

3.2 WHEN the SAP PO Balance API returns `po_line_item` as a JSON array with a single element THEN the system SHALL CONTINUE TO deserialize it correctly as a one-element list

3.3 WHEN the SAP PO Balance API returns a successful response with any valid `po_line_item` shape THEN the system SHALL CONTINUE TO map all line item fields (po_num, po_line_item, type_ind, tax_code, gr_data, etc.) correctly

3.4 WHEN the SAP PO Balance API returns `po_header` data THEN the system SHALL CONTINUE TO deserialize and return the header fields unchanged
