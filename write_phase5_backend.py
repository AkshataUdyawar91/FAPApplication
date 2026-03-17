import re

path = r"FAPApplication/backend/src/BajajDocumentProcessing.API/Controllers/AssistantController.cs"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Replace the action routing switch to add invoice_validation actions
old_switch = '''                "invoice_uploaded" => await HandleInvoiceUploaded(request, agencyId.Value, ct),
                _ => BuildGreeting(),'''

new_switch = '''                "invoice_uploaded" => await HandleInvoiceValidation(request, agencyId.Value, ct),
                "continue_with_warnings" => await HandleContinueWithWarnings(request, agencyId.Value, ct),
                "reupload_invoice" => await HandleReuploadInvoice(request, agencyId.Value, ct),
                _ => BuildGreeting(),'''

content = content.replace(old_switch, new_switch)

# 2. Replace HandleInvoiceUploaded with HandleInvoiceValidation
old_method = '''    private async Task<AssistantResponse> HandleInvoiceUploaded(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        // Frontend sends documentId after uploading via /api/documents/upload
        string? documentId = request.Message?.Trim();
        if (string.IsNullOrEmpty(documentId) && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docProp))
                documentId = docProp.GetString();
        }

        if (string.IsNullOrWhiteSpace(documentId))
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice upload confirmation missing. Please try uploading again.",
            };
        }

        return new AssistantResponse
        {
            Type = "invoice_upload_success",
            Message = "Invoice uploaded successfully! Processing document...",
        };
    }'''

new_method = '''    private async Task<AssistantResponse> HandleInvoiceValidation(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        // Parse documentId and submissionId from payload
        string? documentId = null;
        string? submissionIdStr = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docProp)) documentId = docProp.GetString();
            if (payload.TryGetProperty("submissionId", out var sidProp)) submissionIdStr = sidProp.GetString();
        }
        if (string.IsNullOrEmpty(documentId)) documentId = request.Message?.Trim();

        if (string.IsNullOrWhiteSpace(documentId) || !Guid.TryParse(documentId, out var docId))
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice upload confirmation missing. Please try uploading again.",
            };
        }

        // Load invoice from DB
        var invoice = await _context.Invoices
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.Id == docId && !i.IsDeleted, ct);

        if (invoice == null)
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice record not found. Please try uploading again.",
            };
        }

        // Load package to get SelectedPOId and ActivityState
        var packageId = invoice.PackageId;
        var package = await _context.DocumentPackages
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId && !p.IsDeleted, ct);

        // Load PO for PO-based rules
        Domain.Entities.PO? po = null;
        if (package?.SelectedPOId != null)
        {
            po = await _context.POs
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == package.SelectedPOId && !p.IsDeleted, ct);
        }

        // Load GST rate for the activity state
        decimal expectedGstRate = 18m;
        if (!string.IsNullOrEmpty(package?.ActivityState))
        {
            var gstMaster = await _context.StateGstMasters
                .AsNoTracking()
                .FirstOrDefaultAsync(g => g.StateName == package.ActivityState && !g.IsDeleted, ct);
            if (gstMaster != null) expectedGstRate = gstMaster.GstPercentage;
        }

        // Parse extracted data from ExtractedDataJson if individual fields are missing
        InvoiceExtractedFields extracted = ParseExtractedFields(invoice);

        // Run 9 validation rules
        var rules = new List<ValidationRuleResult>();

        // Rule 1: Invoice Number Present
        var invNumPresent = !string.IsNullOrWhiteSpace(invoice.InvoiceNumber ?? extracted.InvoiceNumber);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_INVOICE_NUMBER_PRESENT",
            Type = "required",
            Passed = invNumPresent,
            IsWarning = false,
            Label = "Invoice Number",
            ExtractedValue = invoice.InvoiceNumber ?? extracted.InvoiceNumber,
            Message = invNumPresent ? null : "Invoice number not found in document.",
        });

        // Rule 2: Invoice Date Present
        var invDate = invoice.InvoiceDate ?? extracted.InvoiceDate;
        var invDatePresent = invDate.HasValue;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_DATE_PRESENT",
            Type = "required",
            Passed = invDatePresent,
            IsWarning = false,
            Label = "Invoice Date",
            ExtractedValue = invDate?.ToString("dd MMM yyyy"),
            Message = invDatePresent ? null : "Invoice date not found in document.",
        });

        // Rule 3: Amount Present
        var invAmount = invoice.TotalAmount ?? extracted.TotalAmount;
        var invAmountPresent = invAmount.HasValue && invAmount > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_AMOUNT_PRESENT",
            Type = "required",
            Passed = invAmountPresent,
            IsWarning = false,
            Label = "Invoice Amount",
            ExtractedValue = invAmount.HasValue ? $"₹{invAmount:N2}" : null,
            Message = invAmountPresent ? null : "Invoice amount not found or is zero.",
        });

        // Rule 4: GST Number Present (15-char alphanumeric)
        var gstNumber = invoice.GSTNumber ?? extracted.GSTNumber;
        var gstNumberValid = !string.IsNullOrWhiteSpace(gstNumber)
            && System.Text.RegularExpressions.Regex.IsMatch(gstNumber, @"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$");
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_GST_NUMBER_PRESENT",
            Type = "required",
            Passed = gstNumberValid,
            IsWarning = false,
            Label = "GST Number",
            ExtractedValue = gstNumber,
            Message = gstNumberValid ? null : string.IsNullOrWhiteSpace(gstNumber)
                ? "GST number not found in document."
                : "GST number format is invalid (expected 15-char GSTIN).",
        });

        // Rule 5: GST Percentage = expected rate
        var gstPct = extracted.GSTPercentage;
        var gstPctValid = gstPct.HasValue && Math.Abs(gstPct.Value - expectedGstRate) < 0.01m;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_GST_PERCENT_PRESENT",
            Type = "required",
            Passed = gstPctValid,
            IsWarning = false,
            Label = "GST Rate",
            ExtractedValue = gstPct.HasValue ? $"{gstPct.Value}%" : null,
            Message = gstPctValid ? null : gstPct.HasValue
                ? $"GST rate {gstPct.Value}% does not match expected {expectedGstRate}%."
                : "GST rate not found in document.",
        });

        // Rule 6: HSN/SAC Code Present
        var hsnCode = extracted.HSNSACCode;
        var hsnPresent = !string.IsNullOrWhiteSpace(hsnCode);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_HSN_SAC_PRESENT",
            Type = "required",
            Passed = hsnPresent,
            IsWarning = false,
            Label = "HSN/SAC Code",
            ExtractedValue = hsnCode,
            Message = hsnPresent ? null : "HSN/SAC code not found in document.",
        });

        // Rule 7: Vendor Code Present
        var vendorCode = extracted.VendorCode;
        var vendorCodePresent = !string.IsNullOrWhiteSpace(vendorCode);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_VENDOR_CODE_PRESENT",
            Type = "required",
            Passed = vendorCodePresent,
            IsWarning = false,
            Label = "Vendor Code",
            ExtractedValue = vendorCode,
            Message = vendorCodePresent ? null : "Vendor code not found in document.",
        });

        // Rule 8: PO Number Match
        var invPONumber = extracted.PONumber;
        bool poMatch;
        string? poMatchMsg;
        if (po == null)
        {
            poMatch = false;
            poMatchMsg = "No PO selected for this submission.";
        }
        else if (string.IsNullOrWhiteSpace(invPONumber))
        {
            poMatch = false;
            poMatchMsg = "PO number not found in invoice.";
        }
        else
        {
            poMatch = string.Equals(invPONumber.Trim(), po.PONumber?.Trim(), StringComparison.OrdinalIgnoreCase);
            poMatchMsg = poMatch ? null : $"Invoice PO# '{invPONumber}' does not match selected PO# '{po.PONumber}'.";
        }
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_PO_NUMBER_MATCH",
            Type = "check",
            Passed = poMatch,
            IsWarning = false,
            Label = "PO Number Match",
            ExtractedValue = invPONumber,
            Message = poMatchMsg,
        });

        // Rule 9: Amount vs PO Balance (warning only)
        bool amountOk;
        string? amountMsg;
        if (po == null || !invAmount.HasValue)
        {
            amountOk = true; // can't check, skip as warning
            amountMsg = po == null ? "No PO selected — balance check skipped." : "Invoice amount not available.";
        }
        else if (!po.RemainingBalance.HasValue)
        {
            amountOk = true;
            amountMsg = "PO remaining balance not available.";
        }
        else
        {
            amountOk = invAmount.Value <= po.RemainingBalance.Value;
            amountMsg = amountOk
                ? null
                : $"Invoice amount ₹{invAmount.Value:N2} exceeds PO remaining balance ₹{po.RemainingBalance.Value:N2}.";
        }
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_AMOUNT_VS_PO_BALANCE",
            Type = "warning",
            Passed = amountOk,
            IsWarning = true,
            Label = "Amount vs PO Balance",
            ExtractedValue = invAmount.HasValue ? $"₹{invAmount.Value:N2}" : null,
            Message = amountMsg,
        });

        var passed = rules.Count(r => r.Passed);
        var failed = rules.Count(r => !r.Passed && !r.IsWarning);
        var warnings = rules.Count(r => !r.Passed && r.IsWarning);

        _logger.LogInformation("Invoice validation: {Passed} passed, {Failed} failed, {Warnings} warnings for doc {DocId}",
            passed, failed, warnings, docId);

        return new AssistantResponse
        {
            Type = "invoice_validation",
            Message = "Invoice analysed. Here\'s what I found:",
            ValidationRules = rules,
            PassedCount = passed,
            FailedCount = failed,
            WarningCount = warnings,
        };
    }

    private static InvoiceExtractedFields ParseExtractedFields(Domain.Entities.Invoice invoice)
    {
        var fields = new InvoiceExtractedFields
        {
            InvoiceNumber = invoice.InvoiceNumber,
            InvoiceDate = invoice.InvoiceDate,
            TotalAmount = invoice.TotalAmount,
            GSTNumber = invoice.GSTNumber,
        };

        if (!string.IsNullOrEmpty(invoice.ExtractedDataJson))
        {
            try
            {
                var json = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(invoice.ExtractedDataJson);
                if (string.IsNullOrEmpty(fields.InvoiceNumber) && json.TryGetProperty("invoiceNumber", out var inv)) fields.InvoiceNumber = inv.GetString();
                if (!fields.InvoiceDate.HasValue && json.TryGetProperty("invoiceDate", out var dt) && DateTime.TryParse(dt.GetString(), out var parsedDt)) fields.InvoiceDate = parsedDt;
                if (!fields.TotalAmount.HasValue && json.TryGetProperty("totalAmount", out var amt) && amt.TryGetDecimal(out var parsedAmt)) fields.TotalAmount = parsedAmt;
                if (string.IsNullOrEmpty(fields.GSTNumber) && json.TryGetProperty("gstNumber", out var gst)) fields.GSTNumber = gst.GetString();
                if (json.TryGetProperty("gstPercentage", out var gstPct) && gstPct.TryGetDecimal(out var parsedGstPct)) fields.GSTPercentage = parsedGstPct;
                if (json.TryGetProperty("hsnSacCode", out var hsn)) fields.HSNSACCode = hsn.GetString();
                if (json.TryGetProperty("vendorCode", out var vc)) fields.VendorCode = vc.GetString();
                if (json.TryGetProperty("poNumber", out var po)) fields.PONumber = po.GetString();
            }
            catch { /* ignore parse errors */ }
        }

        return fields;
    }

    private async Task<AssistantResponse> HandleContinueWithWarnings(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        return new AssistantResponse
        {
            Type = "submission_confirmed",
            Message = "Understood. Proceeding with warnings noted. Your submission has been recorded.",
        };
    }

    private async Task<AssistantResponse> HandleReuploadInvoice(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        return new AssistantResponse
        {
            Type = "invoice_upload",
            Message = "Please upload a corrected invoice document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG" },
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_device", Title = "Upload from device", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_invoice" },
            },
        };
    }'''

content = content.replace(old_method, new_method)

# 3. Add InvoiceExtractedFields helper class before the closing of the file (before last })
helper_class = '''
public class InvoiceExtractedFields
{
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public decimal? TotalAmount { get; set; }
    public string? GSTNumber { get; set; }
    public decimal? GSTPercentage { get; set; }
    public string? HSNSACCode { get; set; }
    public string? VendorCode { get; set; }
    public string? PONumber { get; set; }
}
'''

# Insert before the last line (closing brace of file)
content = content.rstrip()
if not content.endswith(helper_class.strip()):
    content = content + "\n" + helper_class

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done writing AssistantController.cs")
