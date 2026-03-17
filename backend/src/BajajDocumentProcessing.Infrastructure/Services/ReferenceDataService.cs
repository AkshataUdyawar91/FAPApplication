using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Reference data service backed by database tables with in-memory caching
/// </summary>
public class ReferenceDataService : IReferenceDataService
{
    private readonly IApplicationDbContext _dbContext;
    private readonly IMemoryCache _cache;
    private readonly ILogger<ReferenceDataService> _logger;

    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(1);
    private const string GstCacheKey = "RefData_GstMappings";
    private const string HsnCacheKey = "RefData_HsnCodes";
    private const string StateRatesCacheKey = "RefData_StateRates";

    public ReferenceDataService(
        IApplicationDbContext dbContext,
        IMemoryCache cache,
        ILogger<ReferenceDataService> logger)
    {
        _dbContext = dbContext;
        _cache = cache;
        _logger = logger;
    }

    /// <inheritdoc />
    public bool ValidateGSTStateMapping(string gstNumber, string stateCode)
    {
        // GstRate is a rate value (e.g. 18%), not a state prefix — state mapping validation skipped
        return true;
    }

    /// <inheritdoc />
    public string? GetStateCodeFromGST(string gstNumber)
    {
        if (string.IsNullOrWhiteSpace(gstNumber) || gstNumber.Length < 2)
            return null;

        // First 2 chars of GSTIN are the state code prefix — match against StateCode
        var prefix = gstNumber.Substring(0, 2).ToUpperInvariant();
        var gstMappings = GetGstMappings();
        return gstMappings.ContainsKey(prefix) ? prefix : null;
    }

    /// <inheritdoc />
    public bool ValidateHSNSACCode(string hsnSacCode)
    {
        if (string.IsNullOrWhiteSpace(hsnSacCode))
        {
            _logger.LogWarning("HSN/SAC code is empty");
            return false;
        }

        var cleanCode = hsnSacCode.Trim().Replace(" ", "").Replace("-", "");
        var validCodes = GetHsnCodes();
        var isValid = validCodes.Contains(cleanCode);

        if (!isValid)
        {
            _logger.LogWarning("Invalid or unknown HSN/SAC code: {HSNSACCode}", hsnSacCode);
        }

        return isValid;
    }

    /// <inheritdoc />
    public decimal GetDefaultGSTPercentage(string stateCode)
    {
        return 18.0m;
    }

    /// <inheritdoc />
    public bool ValidateElementCostAgainstStateRate(string elementName, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(stateCode))
            return true;

        var rate = GetStateRateValue(elementName, stateCode);
        if (rate == null)
        {
            _logger.LogWarning("No rate defined for element '{ElementName}' in state {StateCode}", elementName, stateCode);
            return true;
        }

        // Allow 10% tolerance
        var tolerance = rate.Value * 0.10m;
        var isValid = Math.Abs(cost - rate.Value) <= tolerance;

        if (!isValid)
        {
            _logger.LogWarning(
                "Element cost mismatch. Element: {ElementName}, Expected: {ExpectedRate}, Actual: {ActualCost}, State: {StateCode}",
                elementName, rate.Value, cost, stateCode);
        }

        return isValid;
    }

    /// <inheritdoc />
    public bool ValidateFixedCostLimit(string category, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(category) || string.IsNullOrWhiteSpace(stateCode))
            return true;

        var rate = GetStateRateValue(category, stateCode);
        if (rate == null)
        {
            _logger.LogWarning("No fixed cost limit for category '{Category}' in state {StateCode}", category, stateCode);
            return true;
        }

        var isValid = cost <= rate.Value;
        if (!isValid)
        {
            _logger.LogWarning(
                "Fixed cost exceeds limit. Category: {Category}, Limit: {Limit}, Actual: {ActualCost}, State: {StateCode}",
                category, rate.Value, cost, stateCode);
        }

        return isValid;
    }

    /// <inheritdoc />
    public bool ValidateVariableCostLimit(string category, decimal cost, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(category) || string.IsNullOrWhiteSpace(stateCode))
            return true;

        var rate = GetStateRateValue(category, stateCode);
        if (rate == null)
        {
            _logger.LogWarning("No variable cost limit for category '{Category}' in state {StateCode}", category, stateCode);
            return true;
        }

        var isValid = cost <= rate.Value;
        if (!isValid)
        {
            _logger.LogWarning(
                "Variable cost exceeds limit. Category: {Category}, Limit: {Limit}, Actual: {ActualCost}, State: {StateCode}",
                category, rate.Value, cost, stateCode);
        }

        return isValid;
    }

    /// <inheritdoc />
    public decimal? GetStateRate(string elementName, string stateCode)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(stateCode))
            return null;

        return GetStateRateValue(elementName, stateCode);
    }

    // --- Private cache helpers ---

    private Dictionary<string, decimal> GetGstMappings()
    {
        return _cache.GetOrCreate<Dictionary<string, decimal>>(GstCacheKey, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = CacheTtl;
            try
            {
                return _dbContext.StateGstMasters
                    .AsNoTracking()
                    .Where(g => g.IsActive)
                    .ToDictionary(g => g.StateCode, g => g.GstPercentage);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load GST mappings from database, using empty dictionary");
                return new Dictionary<string, decimal>();
            }
        })!;
    }

    private HashSet<string> GetHsnCodes()
    {
        return _cache.GetOrCreate(HsnCacheKey, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = CacheTtl;
            try
            {
                return _dbContext.HsnMasters
                    .AsNoTracking()
                    .Where(h => h.IsActive)
                    .Select(h => h.Code)
                    .ToHashSet();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load HSN codes from database, using empty set");
                return new HashSet<string>();
            }
        })!;
    }

    private Dictionary<string, Dictionary<string, decimal>> GetStateRates()
    {
        return _cache.GetOrCreate(StateRatesCacheKey, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = CacheTtl;
            try
            {
                var rates = _dbContext.CostMasterStateRates
                    .AsNoTracking()
                    .Where(r => r.IsActive)
                    .ToList();

                return rates
                    .GroupBy(r => r.StateCode)
                    .ToDictionary(
                        g => g.Key,
                        g => g.ToDictionary(r => r.ElementName, r => r.RateValue));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load state rates from database, using empty dictionary");
                return new Dictionary<string, Dictionary<string, decimal>>();
            }
        })!;
    }

    private decimal? GetStateRateValue(string elementName, string stateCode)
    {
        var stateRates = GetStateRates();
        if (!stateRates.TryGetValue(stateCode, out var rateDict))
            return null;

        return rateDict.TryGetValue(elementName, out var rate) ? rate : null;
    }
}
