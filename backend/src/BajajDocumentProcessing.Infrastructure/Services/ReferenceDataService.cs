using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Reference data service implementation with GST state mappings and HSN/SAC codes
/// </summary>
public class ReferenceDataService : IReferenceDataService
{
    private readonly ILogger<ReferenceDataService> _logger;

    // GST State Code Mapping (first 2 digits of GST number represent state code)
    private static readonly Dictionary<string, string> StateCodeToGSTCode = new()
    {
        { "01", "JK" },  // Jammu and Kashmir
        { "02", "HP" },  // Himachal Pradesh
        { "03", "PB" },  // Punjab
        { "04", "CH" },  // Chandigarh
        { "05", "UK" },  // Uttarakhand
        { "06", "HR" },  // Haryana
        { "07", "DL" },  // Delhi
        { "08", "RJ" },  // Rajasthan
        { "09", "UP" },  // Uttar Pradesh
        { "10", "BR" },  // Bihar
        { "11", "SK" },  // Sikkim
        { "12", "AR" },  // Arunachal Pradesh
        { "13", "NL" },  // Nagaland
        { "14", "MN" },  // Manipur
        { "15", "MZ" },  // Mizoram
        { "16", "TR" },  // Tripura
        { "17", "ML" },  // Meghalaya
        { "18", "AS" },  // Assam
        { "19", "WB" },  // West Bengal
        { "20", "JH" },  // Jharkhand
        { "21", "OR" },  // Odisha
        { "22", "CG" },  // Chhattisgarh
        { "23", "MP" },  // Madhya Pradesh
        { "24", "GJ" },  // Gujarat
        { "26", "DD" },  // Dadra and Nagar Haveli and Daman and Diu
        { "27", "MH" },  // Maharashtra
        { "29", "KA" },  // Karnataka
        { "30", "GA" },  // Goa
        { "31", "LD" },  // Lakshadweep
        { "32", "KL" },  // Kerala
        { "33", "TN" },  // Tamil Nadu
        { "34", "PY" },  // Puducherry
        { "35", "AN" },  // Andaman and Nicobar Islands
        { "36", "TS" },  // Telangana
        { "37", "AP" },  // Andhra Pradesh
        { "38", "LA" }   // Ladakh
    };

    // Sample HSN/SAC codes (in production, this would be loaded from database or external service)
    // HSN codes are for goods, SAC codes are for services
    private static readonly HashSet<string> ValidHSNSACCodes = new()
    {
        // Common HSN codes for automotive industry
        "8703", "8704", "8711", "8708", "8714", "8716",
        // Common SAC codes for services
        "995411", "995412", "995413", "995414", "995415",
        "996511", "996512", "996513", "996514", "996515",
        "998511", "998512", "998513", "998514", "998515"
    };

    public ReferenceDataService(ILogger<ReferenceDataService> logger)
    {
        _logger = logger;
    }

    public bool ValidateGSTStateMapping(string gstNumber, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(gstNumber) || gstNumber.Length < 2)
        {
            _logger.LogWarning("Invalid GST number format: {GSTNumber}", gstNumber);
            return false;
        }

        if (string.IsNullOrWhiteSpace(stateCode))
        {
            _logger.LogWarning("State code is empty");
            return false;
        }

        var gstStateCode = gstNumber.Substring(0, 2);
        
        if (!StateCodeToGSTCode.TryGetValue(gstStateCode, out var expectedStateCode))
        {
            _logger.LogWarning("Unknown GST state code: {GSTStateCode}", gstStateCode);
            return false;
        }

        var isValid = expectedStateCode.Equals(stateCode, StringComparison.OrdinalIgnoreCase);
        
        if (!isValid)
        {
            _logger.LogWarning(
                "GST state mismatch. GST number {GSTNumber} indicates state {ExpectedState}, but document has {ActualState}",
                gstNumber,
                expectedStateCode,
                stateCode);
        }

        return isValid;
    }

    public string? GetStateCodeFromGST(string gstNumber)
    {
        if (string.IsNullOrWhiteSpace(gstNumber) || gstNumber.Length < 2)
        {
            return null;
        }

        var gstStateCode = gstNumber.Substring(0, 2);
        return StateCodeToGSTCode.TryGetValue(gstStateCode, out var stateCode) ? stateCode : null;
    }

    public bool ValidateHSNSACCode(string hsnSacCode)
    {
        if (string.IsNullOrWhiteSpace(hsnSacCode))
        {
            _logger.LogWarning("HSN/SAC code is empty");
            return false;
        }

        // Remove any spaces or special characters
        var cleanCode = hsnSacCode.Trim().Replace(" ", "").Replace("-", "");

        // Check if code exists in reference data
        var isValid = ValidHSNSACCodes.Contains(cleanCode);

        if (!isValid)
        {
            _logger.LogWarning("Invalid or unknown HSN/SAC code: {HSNSACCode}", hsnSacCode);
        }

        return isValid;
    }

    public decimal GetDefaultGSTPercentage(string stateCode)
    {
        // Default GST rate is 18% for most goods and services in India
        // In production, this could vary based on product category
        return 18.0m;
    }

    // State-specific rates for cost elements (sample data - in production, load from database)
    private static readonly Dictionary<string, Dictionary<string, decimal>> StateRates = new()
    {
        {
            "27", new Dictionary<string, decimal> // Maharashtra
            {
                { "Venue Rental", 5000m },
                { "Staff Cost", 500m },
                { "Marketing Material", 200m },
                { "Transportation", 1000m },
                { "Equipment Rental", 3000m }
            }
        },
        {
            "29", new Dictionary<string, decimal> // Karnataka
            {
                { "Venue Rental", 4500m },
                { "Staff Cost", 450m },
                { "Marketing Material", 180m },
                { "Transportation", 900m },
                { "Equipment Rental", 2800m }
            }
        },
        {
            "07", new Dictionary<string, decimal> // Delhi
            {
                { "Venue Rental", 6000m },
                { "Staff Cost", 600m },
                { "Marketing Material", 250m },
                { "Transportation", 1200m },
                { "Equipment Rental", 3500m }
            }
        }
    };

    // Fixed cost limits by state (sample data)
    private static readonly Dictionary<string, Dictionary<string, decimal>> FixedCostLimits = new()
    {
        {
            "27", new Dictionary<string, decimal> // Maharashtra
            {
                { "Setup Cost", 10000m },
                { "License Fee", 5000m },
                { "Insurance", 3000m }
            }
        },
        {
            "29", new Dictionary<string, decimal> // Karnataka
            {
                { "Setup Cost", 9000m },
                { "License Fee", 4500m },
                { "Insurance", 2800m }
            }
        }
    };

    // Variable cost limits by state (sample data)
    private static readonly Dictionary<string, Dictionary<string, decimal>> VariableCostLimits = new()
    {
        {
            "27", new Dictionary<string, decimal> // Maharashtra
            {
                { "Per Day Cost", 2000m },
                { "Per Person Cost", 500m },
                { "Per Unit Cost", 100m }
            }
        },
        {
            "29", new Dictionary<string, decimal> // Karnataka
            {
                { "Per Day Cost", 1800m },
                { "Per Person Cost", 450m },
                { "Per Unit Cost", 90m }
            }
        }
    };

    public bool ValidateElementCostAgainstStateRate(string elementName, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(stateCode))
        {
            return true; // Skip validation if data is missing
        }

        if (!StateRates.TryGetValue(stateCode, out var stateRateDict))
        {
            _logger.LogWarning("No state rates defined for state code: {StateCode}", stateCode);
            return true; // Pass validation if no rates defined for this state
        }

        if (!stateRateDict.TryGetValue(elementName, out var expectedRate))
        {
            _logger.LogWarning("No rate defined for element '{ElementName}' in state {StateCode}", elementName, stateCode);
            return true; // Pass validation if no rate defined for this element
        }

        // Allow 10% tolerance
        var tolerance = expectedRate * 0.10m;
        var isValid = Math.Abs(cost - expectedRate) <= tolerance;

        if (!isValid)
        {
            _logger.LogWarning(
                "Element cost mismatch. Element: {ElementName}, Expected: {ExpectedRate}, Actual: {ActualCost}, State: {StateCode}",
                elementName,
                expectedRate,
                cost,
                stateCode);
        }

        return isValid;
    }

    public bool ValidateFixedCostLimit(string category, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(category) || string.IsNullOrWhiteSpace(stateCode))
        {
            return true; // Skip validation if data is missing
        }

        if (!FixedCostLimits.TryGetValue(stateCode, out var limitDict))
        {
            _logger.LogWarning("No fixed cost limits defined for state code: {StateCode}", stateCode);
            return true; // Pass validation if no limits defined for this state
        }

        if (!limitDict.TryGetValue(category, out var limit))
        {
            _logger.LogWarning("No fixed cost limit defined for category '{Category}' in state {StateCode}", category, stateCode);
            return true; // Pass validation if no limit defined for this category
        }

        var isValid = cost <= limit;

        if (!isValid)
        {
            _logger.LogWarning(
                "Fixed cost exceeds limit. Category: {Category}, Limit: {Limit}, Actual: {ActualCost}, State: {StateCode}",
                category,
                limit,
                cost,
                stateCode);
        }

        return isValid;
    }

    public bool ValidateVariableCostLimit(string category, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(category) || string.IsNullOrWhiteSpace(stateCode))
        {
            return true; // Skip validation if data is missing
        }

        if (!VariableCostLimits.TryGetValue(stateCode, out var limitDict))
        {
            _logger.LogWarning("No variable cost limits defined for state code: {StateCode}", stateCode);
            return true; // Pass validation if no limits defined for this state
        }

        if (!limitDict.TryGetValue(category, out var limit))
        {
            _logger.LogWarning("No variable cost limit defined for category '{Category}' in state {StateCode}", category, stateCode);
            return true; // Pass validation if no limit defined for this category
        }

        var isValid = cost <= limit;

        if (!isValid)
        {
            _logger.LogWarning(
                "Variable cost exceeds limit. Category: {Category}, Limit: {Limit}, Actual: {ActualCost}, State: {StateCode}",
                category,
                limit,
                cost,
                stateCode);
        }

        return isValid;
    }

    public decimal? GetStateRate(string elementName, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(stateCode))
        {
            return null;
        }

        if (!StateRates.TryGetValue(stateCode, out var stateRateDict))
        {
            return null;
        }

        return stateRateDict.TryGetValue(elementName, out var rate) ? rate : null;
    }
}
