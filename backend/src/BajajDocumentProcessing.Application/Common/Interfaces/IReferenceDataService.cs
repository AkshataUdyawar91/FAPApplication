namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for accessing reference data (GST state mappings, HSN/SAC codes, state rates, etc.)
/// </summary>
public interface IReferenceDataService
{
    /// <summary>
    /// Validates if a GST number matches the expected state code
    /// </summary>
    /// <param name="gstNumber">GST number to validate (first 2 digits represent state code)</param>
    /// <param name="stateCode">State code to match against</param>
    /// <returns>True if GST number matches the state</returns>
    bool ValidateGSTStateMapping(string gstNumber, string stateCode);

    /// <summary>
    /// Gets the state code from a GST number
    /// </summary>
    /// <param name="gstNumber">GST number (first 2 digits represent state code)</param>
    /// <returns>State code or null if invalid</returns>
    string? GetStateCodeFromGST(string gstNumber);

    /// <summary>
    /// Validates if an HSN/SAC code exists in the reference data
    /// </summary>
    /// <param name="hsnSacCode">HSN or SAC code to validate</param>
    /// <returns>True if the code is valid</returns>
    bool ValidateHSNSACCode(string hsnSacCode);

    /// <summary>
    /// Gets the default GST percentage for a state
    /// </summary>
    /// <param name="stateCode">State code</param>
    /// <returns>Default GST percentage (typically 18%)</returns>
    decimal GetDefaultGSTPercentage(string stateCode);

    /// <summary>
    /// Validates if an element cost matches the state-specific rate
    /// </summary>
    /// <param name="elementName">Name of the cost element</param>
    /// <param name="cost">Cost amount</param>
    /// <param name="stateCode">State code</param>
    /// <returns>True if cost matches state rate</returns>
    bool ValidateElementCostAgainstStateRate(string elementName, decimal cost, string stateCode);

    /// <summary>
    /// Validates if a fixed cost is within state limits
    /// </summary>
    /// <param name="category">Cost category</param>
    /// <param name="cost">Cost amount</param>
    /// <param name="stateCode">State code</param>
    /// <returns>True if within limits</returns>
    bool ValidateFixedCostLimit(string category, decimal cost, string stateCode);

    /// <summary>
    /// Validates if a variable cost is within state limits
    /// </summary>
    /// <param name="category">Cost category</param>
    /// <param name="cost">Cost amount</param>
    /// <param name="stateCode">State code</param>
    /// <returns>True if within limits</returns>
    bool ValidateVariableCostLimit(string category, decimal cost, string stateCode);

    /// <summary>
    /// Gets the expected rate for an element in a specific state
    /// </summary>
    /// <param name="elementName">Name of the cost element</param>
    /// <param name="stateCode">State code</param>
    /// <returns>Expected rate or null if not found</returns>
    decimal? GetStateRate(string elementName, string stateCode);

    /// <summary>
    /// Gets the numeric state code from a state name (e.g., "Bihar" → "10")
    /// </summary>
    /// <param name="stateName">State name</param>
    /// <returns>2-digit state code or null if not found</returns>
    string? GetStateCodeByName(string stateName);
}
