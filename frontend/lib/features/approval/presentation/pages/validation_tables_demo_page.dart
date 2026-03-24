import 'package:flutter/material.dart';
import '../widgets/validation_tables_widget.dart';
import '../../../../core/theme/app_colors.dart';

/// Demo page showing how to use ValidationTablesWidget with API data
class ValidationTablesDemoPage extends StatelessWidget {
  const ValidationTablesDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data from your API response
    final invoiceValidations = [
      {
        "documentType": "Invoice",
        "documentId": "f7c6e852-cd1b-492c-9044-ecb72e4ee9ac",
        "fileName": "Invoice.pdf",
        "allPassed": false,
        "failureReason": "Vendor Code; PO Number",
        "fieldPresence": null,
        "crossDocument": null,
        "validatedAt": "2026-03-19T17:30:49.4682042",
        "validationDetailsJson":
            "{\"fieldPresence\":{\"allFieldsPresent\":false,\"missingFields\":[\"Vendor Code\",\"PO Number\"]}}"
      }
    ];

    final costSummaryValidation = {
      "allValidationsPassed": false,
      "failureReason": "Number of Activations",
      "sapVerificationPassed": false,
      "amountConsistencyPassed": false,
      "lineItemMatchingPassed": false,
      "completenessCheckPassed": false,
      "dateValidationPassed": false,
      "vendorMatchingPassed": false,
      "ruleResultsJson": null,
      "validationDetailsJson":
          "{\"fieldPresence\":{\"allFieldsPresent\":false,\"missingFields\":[\"Number of Activations\"]},\"crossDocument\":{\"allChecksPass\":true,\"totalCostValid\":true,\"elementCostsValid\":true,\"fixedCostsValid\":true,\"variableCostsValid\":true,\"issues\":[]}}"
    };

    final activityValidation = {
      "allValidationsPassed": false,
      "failureReason":
          "Number of days mismatch: Activity Summary has 49 days, Cost Summary has 90 days",
      "sapVerificationPassed": false,
      "amountConsistencyPassed": false,
      "lineItemMatchingPassed": false,
      "completenessCheckPassed": false,
      "dateValidationPassed": false,
      "vendorMatchingPassed": false,
      "ruleResultsJson": null,
      "validationDetailsJson":
          "{\"fieldPresence\":{\"allFieldsPresent\":true,\"missingFields\":[]},\"crossDocument\":{\"allChecksPass\":false,\"numberOfDaysMatches\":false,\"issues\":[\"Number of days mismatch: Activity Summary has 49 days, Cost Summary has 90 days\"]}}"
    };

    final enquiryValidation = {
      "allValidationsPassed": false,
      "failureReason":
          "Dealer Code (present in 0/1 records); Pincode (present in 0/1 records)",
      "sapVerificationPassed": false,
      "amountConsistencyPassed": false,
      "lineItemMatchingPassed": false,
      "completenessCheckPassed": false,
      "dateValidationPassed": false,
      "vendorMatchingPassed": false,
      "ruleResultsJson": null,
      "validationDetailsJson":
          "{\"fieldPresence\":{\"allFieldsPresent\":false,\"totalRecords\":1,\"recordsWithState\":1,\"recordsWithDate\":1,\"recordsWithDealerCode\":0,\"recordsWithDealerName\":1,\"recordsWithDistrict\":1,\"recordsWithPincode\":0,\"recordsWithCustomerName\":1,\"recordsWithCustomerNumber\":1,\"recordsWithTestRide\":1,\"missingFields\":[\"Dealer Code (present in 0/1 records)\",\"Pincode (present in 0/1 records)\"]}}"
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation Tables'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ValidationTablesWidget(
          invoiceValidations: invoiceValidations,
          costSummaryValidation: costSummaryValidation,
          activityValidation: activityValidation,
          enquiryValidation: enquiryValidation,
        ),
      ),
    );
  }
}
