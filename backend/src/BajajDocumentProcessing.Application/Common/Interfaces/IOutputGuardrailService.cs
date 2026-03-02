namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IOutputGuardrailService
{
    Task<string> ValidateAndSanitizeOutputAsync(
        string response, 
        List<VectorSearchResult> sourceData, 
        CancellationToken cancellationToken = default);
}

public class OutputValidationException : Exception
{
    public OutputValidationException(string message) : base(message) { }
}
