using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Text.Json;

namespace BajajDocumentProcessing.API.Filters;

/// <summary>
/// Custom model validation filter that provides user-friendly error messages
/// for model binding and validation errors, especially for enum validation failures.
/// </summary>
public class ModelValidationFilter : IActionFilter
{
    private readonly ILogger<ModelValidationFilter> _logger;

    public ModelValidationFilter(ILogger<ModelValidationFilter> logger)
    {
        _logger = logger;
    }

    public void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.ModelState.IsValid)
        {
            var errors = new Dictionary<string, string[]>();
            var correlationId = context.HttpContext.Items.TryGetValue("CorrelationId", out var id) 
                ? id?.ToString() ?? Guid.NewGuid().ToString()
                : Guid.NewGuid().ToString();

            foreach (var modelState in context.ModelState.Values)
            {
                foreach (var error in modelState.Errors)
                {
                    var fieldName = GetFieldName(context.ModelState, error);
                    var userFriendlyMessage = GetUserFriendlyMessage(error.ErrorMessage);

                    if (!errors.ContainsKey(fieldName))
                    {
                        errors[fieldName] = new[] { userFriendlyMessage };
                    }
                    else
                    {
                        var existingErrors = errors[fieldName].ToList();
                        existingErrors.Add(userFriendlyMessage);
                        errors[fieldName] = existingErrors.ToArray();
                    }
                }
            }

            _logger.LogWarning(
                "Model validation failed. CorrelationId: {CorrelationId}, Errors: {@Errors}",
                correlationId,
                errors);

            var response = new
            {
                type = "https://tools.ietf.org/html/rfc9110#section-15.5.1",
                title = "One or more validation errors occurred.",
                status = 400,
                errors = errors,
                traceId = correlationId
            };

            context.Result = new BadRequestObjectResult(response);
        }
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        // No action needed after execution
    }

    /// <summary>
    /// Gets the field name from the model state entry
    /// </summary>
    private static string GetFieldName(ModelStateDictionary modelState, ModelError error)
    {
        var entry = modelState.FirstOrDefault(x => x.Value.Errors.Contains(error));
        return entry.Key ?? "unknown";
    }

    /// <summary>
    /// Converts technical error messages to user-friendly messages
    /// </summary>
    private static string GetUserFriendlyMessage(string errorMessage)
    {
        // Handle enum validation errors
        if (errorMessage.Contains("is not valid") && errorMessage.Contains("'"))
        {
            // Extract the invalid value
            var match = System.Text.RegularExpressions.Regex.Match(errorMessage, @"'([^']*)'");
            if (match.Success)
            {
                var invalidValue = match.Groups[1].Value;
                return $"'{invalidValue}' is not a valid document type. Supported types are: PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhoto, AdditionalDocument.";
            }
            return "Invalid document type provided. Please check the supported document types.";
        }

        // Handle required field errors
        if (errorMessage.Contains("required", StringComparison.OrdinalIgnoreCase))
        {
            return "This field is required.";
        }

        // Handle format errors
        if (errorMessage.Contains("format", StringComparison.OrdinalIgnoreCase))
        {
            return "The value provided is in an invalid format.";
        }

        // Return original message if no specific mapping found
        return errorMessage;
    }
}
