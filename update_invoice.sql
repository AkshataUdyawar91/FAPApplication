-- Update invoice E1000004 with data from the uploaded invoice image
UPDATE Invoices
SET InvoiceNumber = 'SE-01/2025-26',
    InvoiceDate = '2025-04-22',
    VendorName = 'M/S SWIFT EVENTS',
    GSTNumber = '10DEFPK2659R2Z3',
    SubTotal = 376035.00,
    TaxAmount = 67686.00,
    TotalAmount = 443721.00,
    FileName = 'INV-SE-01-2025-26.pdf',
    ContentType = 'application/pdf',
    ExtractionConfidence = 95.0,
    ExtractedDataJson = N'{"InvoiceNumber":"SE-01/2025-26","InvoiceDate":"2025-04-22","VendorName":"M/S SWIFT EVENTS","GSTNumber":"10DEFPK2659R2Z3","RecipientGSTIN":"10AADCB2923M1Z0","RecipientName":"Bajaj Auto Ltd. Patna","SupplyTypeCode":"B2B","PlaceOfSupply":"BIHAR","DocumentType":"Tax Invoice","HSNSACCode":"998596","GSTPercentage":18,"TaxableAmount":376035.00,"CGSTAmount":33843.15,"SGSTAmount":33843.15,"IGSTAmount":0.00,"TotalAmount":443721.00,"IRN":"191530e699e9e86d9a8cd7b5802011cab48f3249f37ea07cf7544848cb3c7ec7","AckNo":"182518902146014","VendorCode":null,"PONumber":null}',
    UpdatedAt = GETUTCDATE()
WHERE Id = 'E1000004-0000-0000-0000-000000000001';

PRINT 'Invoice E1000004 updated with extracted data';
