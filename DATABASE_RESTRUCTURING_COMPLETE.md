# Database Restructuring Complete

## New Hierarchical Structure

```
FAP (DocumentPackage)
  └── 1 PO (Document where Type=PO)
        └── Multiple Invoices
              └── Multiple Campaigns (per Invoice)
                    └── Multiple Photos (per Campaign)
```

## New Entities Created

### 1. Invoice Entity
- **Location**: `backend/src/BajajDocumentProcessing.Domain/Entities/Invoice.cs`
- **Purpose**: Represents an invoice document linked to a PO
- **Key Fields**: InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount
- **Relationships**: 
  - Belongs to DocumentPackage (FAP)
  - Linked to PO Document
  - Has many Campaigns

### 2. Campaign Entity
- **Location**: `backend/src/BajajDocumentProcessing.Domain/Entities/Campaign.cs`
- **Purpose**: Represents a campaign/activity linked to an invoice
- **Key Fields**: CampaignName, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, GPSLocation, State, TotalCost, TeamsJson
- **Relationships**:
  - Belongs to Invoice
  - Belongs to DocumentPackage (for easier querying)
  - Has many CampaignPhotos

### 3. CampaignPhoto Entity
- **Location**: `backend/src/BajajDocumentProcessing.Domain/Entities/CampaignPhoto.cs`
- **Purpose**: Represents a photo linked to a campaign
- **Key Fields**: FileName, BlobUrl, Caption, PhotoTimestamp, Latitude, Longitude, DeviceModel, ExtractedMetadataJson
- **Relationships**:
  - Belongs to Campaign
  - Belongs to DocumentPackage (for easier querying)

## EF Core Configurations Created

- `InvoiceConfiguration.cs`
- `CampaignConfiguration.cs`
- `CampaignPhotoConfiguration.cs`

## Updated Files

1. **DocumentPackage.cs** - Added navigation properties for Invoices, Campaigns, CampaignPhotos
2. **Document.cs** - Added LinkedInvoices navigation property for PO documents
3. **ApplicationDbContext.cs** - Added DbSets for Invoice, Campaign, CampaignPhoto

## Migration Files

1. **SQL Script**: `ADD_HIERARCHICAL_STRUCTURE.sql` - Run with `add-hierarchical-structure.bat`
2. **EF Core Migration**: `20260309100000_AddHierarchicalStructure.cs`

## How to Apply Migration

### Option 1: Using SQL Script (Recommended)
```batch
add-hierarchical-structure.bat
```

### Option 2: Using EF Core
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet ef database update
```

## Specs Updated

1. **requirements.md** - Added Requirement 22: Hierarchical Document Structure
2. **design.md** - Updated Data Models section with new entities and Database Schema

## Next Steps

1. Run the migration to create the new tables
2. Update the frontend upload wizard to support:
   - Multiple invoices per PO
   - Multiple campaigns per invoice
   - Multiple photos per campaign
3. Update API endpoints to handle hierarchical data
4. Update validation logic to validate across the hierarchy
