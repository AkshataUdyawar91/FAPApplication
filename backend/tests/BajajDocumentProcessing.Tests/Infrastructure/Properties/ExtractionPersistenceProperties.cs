using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using FsCheck;
using FsCheck.Xunit;
using System.Text.Json;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 9: Extraction Persistence Round-Trip
/// Validates: Requirements 2.7
/// 
/// Property: For any extracted document data, persisting it to the database and then 
/// retrieving it should produce equivalent data.
/// </summary>
public class ExtractionPersistenceProperties
{
    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false
    };

    /// <summary>
    /// Property: POData serialization and deserialization produces equivalent data
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(PODataGenerators) })]
    public void POData_SerializationRoundTrip_ProducesEquivalentData(POData originalData)
    {
        // Property: For any POData, serializing to JSON and deserializing should produce equivalent data
        
        // Act: Serialize to JSON (simulating database storage)
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        
        // Act: Deserialize from JSON (simulating database retrieval)
        var retrievedData = JsonSerializer.Deserialize<POData>(json, _jsonOptions);
        
        // Assert: Retrieved data is not null
        Assert.NotNull(retrievedData);
        
        // Assert: All fields match
        Assert.Equal(originalData.PONumber, retrievedData.PONumber);
        Assert.Equal(originalData.VendorName, retrievedData.VendorName);
        Assert.Equal(originalData.PODate, retrievedData.PODate);
        Assert.Equal(originalData.TotalAmount, retrievedData.TotalAmount);
        Assert.Equal(originalData.IsFlaggedForReview, retrievedData.IsFlaggedForReview);
        
        // Assert: Line items count matches
        Assert.Equal(originalData.LineItems.Count, retrievedData.LineItems.Count);
        
        // Assert: Each line item matches
        for (int i = 0; i < originalData.LineItems.Count; i++)
        {
            Assert.Equal(originalData.LineItems[i].ItemCode, retrievedData.LineItems[i].ItemCode);
            Assert.Equal(originalData.LineItems[i].Description, retrievedData.LineItems[i].Description);
            Assert.Equal(originalData.LineItems[i].Quantity, retrievedData.LineItems[i].Quantity);
            Assert.Equal(originalData.LineItems[i].UnitPrice, retrievedData.LineItems[i].UnitPrice);
            Assert.Equal(originalData.LineItems[i].LineTotal, retrievedData.LineItems[i].LineTotal);
        }
        
        // Assert: Field confidences match
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
        foreach (var kvp in originalData.FieldConfidences)
        {
            Assert.True(retrievedData.FieldConfidences.ContainsKey(kvp.Key));
            Assert.Equal(kvp.Value, retrievedData.FieldConfidences[kvp.Key]);
        }
    }

    /// <summary>
    /// Property: InvoiceData serialization and deserialization produces equivalent data
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(InvoiceDataGenerators) })]
    public void InvoiceData_SerializationRoundTrip_ProducesEquivalentData(InvoiceData originalData)
    {
        // Property: For any InvoiceData, serializing to JSON and deserializing should produce equivalent data
        
        // Act: Serialize to JSON (simulating database storage)
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        
        // Act: Deserialize from JSON (simulating database retrieval)
        var retrievedData = JsonSerializer.Deserialize<InvoiceData>(json, _jsonOptions);
        
        // Assert: Retrieved data is not null
        Assert.NotNull(retrievedData);
        
        // Assert: All fields match
        Assert.Equal(originalData.InvoiceNumber, retrievedData.InvoiceNumber);
        Assert.Equal(originalData.VendorName, retrievedData.VendorName);
        Assert.Equal(originalData.InvoiceDate, retrievedData.InvoiceDate);
        Assert.Equal(originalData.SubTotal, retrievedData.SubTotal);
        Assert.Equal(originalData.TaxAmount, retrievedData.TaxAmount);
        Assert.Equal(originalData.TotalAmount, retrievedData.TotalAmount);
        Assert.Equal(originalData.IsFlaggedForReview, retrievedData.IsFlaggedForReview);
        
        // Assert: Line items count matches
        Assert.Equal(originalData.LineItems.Count, retrievedData.LineItems.Count);
        
        // Assert: Each line item matches
        for (int i = 0; i < originalData.LineItems.Count; i++)
        {
            Assert.Equal(originalData.LineItems[i].ItemCode, retrievedData.LineItems[i].ItemCode);
            Assert.Equal(originalData.LineItems[i].Description, retrievedData.LineItems[i].Description);
            Assert.Equal(originalData.LineItems[i].Quantity, retrievedData.LineItems[i].Quantity);
            Assert.Equal(originalData.LineItems[i].UnitPrice, retrievedData.LineItems[i].UnitPrice);
            Assert.Equal(originalData.LineItems[i].LineTotal, retrievedData.LineItems[i].LineTotal);
        }
        
        // Assert: Field confidences match
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
        foreach (var kvp in originalData.FieldConfidences)
        {
            Assert.True(retrievedData.FieldConfidences.ContainsKey(kvp.Key));
            Assert.Equal(kvp.Value, retrievedData.FieldConfidences[kvp.Key]);
        }
    }

    /// <summary>
    /// Property: CostSummaryData serialization and deserialization produces equivalent data
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(CostSummaryDataGenerators) })]
    public void CostSummaryData_SerializationRoundTrip_ProducesEquivalentData(CostSummaryData originalData)
    {
        // Property: For any CostSummaryData, serializing to JSON and deserializing should produce equivalent data
        
        // Act: Serialize to JSON (simulating database storage)
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        
        // Act: Deserialize from JSON (simulating database retrieval)
        var retrievedData = JsonSerializer.Deserialize<CostSummaryData>(json, _jsonOptions);
        
        // Assert: Retrieved data is not null
        Assert.NotNull(retrievedData);
        
        // Assert: All fields match
        Assert.Equal(originalData.CampaignName, retrievedData.CampaignName);
        Assert.Equal(originalData.State, retrievedData.State);
        Assert.Equal(originalData.CampaignStartDate, retrievedData.CampaignStartDate);
        Assert.Equal(originalData.CampaignEndDate, retrievedData.CampaignEndDate);
        Assert.Equal(originalData.TotalCost, retrievedData.TotalCost);
        Assert.Equal(originalData.IsFlaggedForReview, retrievedData.IsFlaggedForReview);
        
        // Assert: Cost breakdowns count matches
        Assert.Equal(originalData.CostBreakdowns.Count, retrievedData.CostBreakdowns.Count);
        
        // Assert: Each cost breakdown matches
        for (int i = 0; i < originalData.CostBreakdowns.Count; i++)
        {
            Assert.Equal(originalData.CostBreakdowns[i].Category, retrievedData.CostBreakdowns[i].Category);
            Assert.Equal(originalData.CostBreakdowns[i].Amount, retrievedData.CostBreakdowns[i].Amount);
        }
        
        // Assert: Field confidences match
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
        foreach (var kvp in originalData.FieldConfidences)
        {
            Assert.True(retrievedData.FieldConfidences.ContainsKey(kvp.Key));
            Assert.Equal(kvp.Value, retrievedData.FieldConfidences[kvp.Key]);
        }
    }

    /// <summary>
    /// Property: PhotoMetadata serialization and deserialization produces equivalent data
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(PhotoMetadataGenerators) })]
    public void PhotoMetadata_SerializationRoundTrip_ProducesEquivalentData(PhotoMetadata originalData)
    {
        // Property: For any PhotoMetadata, serializing to JSON and deserializing should produce equivalent data
        
        // Act: Serialize to JSON (simulating database storage)
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        
        // Act: Deserialize from JSON (simulating database retrieval)
        var retrievedData = JsonSerializer.Deserialize<PhotoMetadata>(json, _jsonOptions);
        
        // Assert: Retrieved data is not null
        Assert.NotNull(retrievedData);
        
        // Assert: All fields match
        Assert.Equal(originalData.Timestamp, retrievedData.Timestamp);
        Assert.Equal(originalData.Latitude, retrievedData.Latitude);
        Assert.Equal(originalData.Longitude, retrievedData.Longitude);
        Assert.Equal(originalData.DeviceModel, retrievedData.DeviceModel);
        Assert.Equal(originalData.IsFlaggedForReview, retrievedData.IsFlaggedForReview);
        
        // Assert: Field confidences match
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
        foreach (var kvp in originalData.FieldConfidences)
        {
            Assert.True(retrievedData.FieldConfidences.ContainsKey(kvp.Key));
            Assert.Equal(kvp.Value, retrievedData.FieldConfidences[kvp.Key]);
        }
    }

    /// <summary>
    /// Unit test: Verify POData with complex nested data survives round-trip
    /// </summary>
    [Fact]
    public void POData_WithComplexNestedData_SurvivesRoundTrip()
    {
        // Arrange
        var originalData = new POData
        {
            PONumber = "PO-12345",
            VendorName = "Test Vendor Inc.",
            PODate = new DateTime(2024, 1, 15, 10, 30, 0, DateTimeKind.Utc),
            LineItems = new List<POLineItem>
            {
                new POLineItem
                {
                    ItemCode = "ITEM-001",
                    Description = "Test Item 1",
                    Quantity = 10,
                    UnitPrice = 100.50m,
                    LineTotal = 1005.00m
                },
                new POLineItem
                {
                    ItemCode = "ITEM-002",
                    Description = "Test Item 2",
                    Quantity = 5,
                    UnitPrice = 200.75m,
                    LineTotal = 1003.75m
                }
            },
            TotalAmount = 2008.75m,
            FieldConfidences = new Dictionary<string, double>
            {
                { "PONumber", 0.95 },
                { "VendorName", 0.90 },
                { "PODate", 0.88 },
                { "TotalAmount", 0.92 }
            },
            IsFlaggedForReview = false
        };

        // Act: Serialize and deserialize
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        var retrievedData = JsonSerializer.Deserialize<POData>(json, _jsonOptions);

        // Assert: All data matches
        Assert.NotNull(retrievedData);
        Assert.Equal(originalData.PONumber, retrievedData.PONumber);
        Assert.Equal(originalData.VendorName, retrievedData.VendorName);
        Assert.Equal(originalData.PODate, retrievedData.PODate);
        Assert.Equal(originalData.TotalAmount, retrievedData.TotalAmount);
        Assert.Equal(originalData.LineItems.Count, retrievedData.LineItems.Count);
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
    }

    /// <summary>
    /// Unit test: Verify InvoiceData with special characters survives round-trip
    /// </summary>
    [Fact]
    public void InvoiceData_WithSpecialCharacters_SurvivesRoundTrip()
    {
        // Arrange
        var originalData = new InvoiceData
        {
            InvoiceNumber = "INV-2024/001",
            VendorName = "Test & Co. (Pvt.) Ltd.",
            InvoiceDate = new DateTime(2024, 2, 20, 14, 45, 30, DateTimeKind.Utc),
            LineItems = new List<InvoiceLineItem>
            {
                new InvoiceLineItem
                {
                    ItemCode = "ITEM-001",
                    Description = "Item with \"quotes\" and special chars: @#$%",
                    Quantity = 3,
                    UnitPrice = 150.00m,
                    LineTotal = 450.00m
                }
            },
            SubTotal = 450.00m,
            TaxAmount = 81.00m,
            TotalAmount = 531.00m,
            FieldConfidences = new Dictionary<string, double>
            {
                { "InvoiceNumber", 0.96 },
                { "VendorName", 0.89 }
            },
            IsFlaggedForReview = false
        };

        // Act: Serialize and deserialize
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        var retrievedData = JsonSerializer.Deserialize<InvoiceData>(json, _jsonOptions);

        // Assert: All data matches including special characters
        Assert.NotNull(retrievedData);
        Assert.Equal(originalData.InvoiceNumber, retrievedData.InvoiceNumber);
        Assert.Equal(originalData.VendorName, retrievedData.VendorName);
        Assert.Equal(originalData.LineItems[0].Description, retrievedData.LineItems[0].Description);
    }

    /// <summary>
    /// Unit test: Verify CostSummaryData with empty collections survives round-trip
    /// </summary>
    [Fact]
    public void CostSummaryData_WithEmptyCollections_SurvivesRoundTrip()
    {
        // Arrange
        var originalData = new CostSummaryData
        {
            CampaignName = "Test Campaign",
            State = "Maharashtra",
            CampaignStartDate = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            CampaignEndDate = new DateTime(2024, 12, 31, 23, 59, 59, DateTimeKind.Utc),
            CostBreakdowns = new List<CostBreakdown>(),
            TotalCost = 0m,
            FieldConfidences = new Dictionary<string, double>(),
            IsFlaggedForReview = true
        };

        // Act: Serialize and deserialize
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        var retrievedData = JsonSerializer.Deserialize<CostSummaryData>(json, _jsonOptions);

        // Assert: All data matches including empty collections
        Assert.NotNull(retrievedData);
        Assert.Equal(originalData.CampaignName, retrievedData.CampaignName);
        Assert.Equal(originalData.State, retrievedData.State);
        Assert.Empty(retrievedData.CostBreakdowns);
        Assert.Empty(retrievedData.FieldConfidences);
        Assert.True(retrievedData.IsFlaggedForReview);
    }

    /// <summary>
    /// Unit test: Verify PhotoMetadata with null optional fields survives round-trip
    /// </summary>
    [Fact]
    public void PhotoMetadata_WithNullOptionalFields_SurvivesRoundTrip()
    {
        // Arrange
        var originalData = new PhotoMetadata
        {
            Timestamp = new DateTime(2024, 3, 10, 8, 15, 0, DateTimeKind.Utc),
            Latitude = null,
            Longitude = null,
            DeviceModel = null,
            FieldConfidences = new Dictionary<string, double>
            {
                { "Timestamp", 0.99 }
            },
            IsFlaggedForReview = false
        };

        // Act: Serialize and deserialize
        var json = JsonSerializer.Serialize(originalData, _jsonOptions);
        var retrievedData = JsonSerializer.Deserialize<PhotoMetadata>(json, _jsonOptions);

        // Assert: All data matches including null values
        Assert.NotNull(retrievedData);
        Assert.Equal(originalData.Timestamp, retrievedData.Timestamp);
        Assert.Null(retrievedData.Latitude);
        Assert.Null(retrievedData.Longitude);
        Assert.Null(retrievedData.DeviceModel);
        Assert.Equal(originalData.FieldConfidences.Count, retrievedData.FieldConfidences.Count);
    }
}

/// <summary>
/// Custom generators for PhotoMetadata
/// </summary>
public static class PhotoMetadataGenerators
{
    public static Arbitrary<PhotoMetadata> PhotoMetadataGenerator()
    {
        return (from timestamp in Arb.Generate<DateTime>().Where(d => d > DateTime.MinValue && d < DateTime.MaxValue)
                from latitude in Arb.Generate<double?>().Where(lat => !lat.HasValue || (lat.Value >= -90 && lat.Value <= 90))
                from longitude in Arb.Generate<double?>().Where(lon => !lon.HasValue || (lon.Value >= -180 && lon.Value <= 180))
                from deviceModel in Arb.Generate<string?>()
                from fieldConfidences in Gen.Constant(new Dictionary<string, double>
                {
                    { "Timestamp", 0.95 }
                })
                from isFlagged in Arb.Generate<bool>()
                select new PhotoMetadata
                {
                    Timestamp = timestamp,
                    Latitude = latitude,
                    Longitude = longitude,
                    DeviceModel = deviceModel,
                    FieldConfidences = fieldConfidences,
                    IsFlaggedForReview = isFlagged
                }).ToArbitrary();
    }
}
