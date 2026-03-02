namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IInputGuardrailService
{
    Task ValidateInputAsync(string query, Guid userId, CancellationToken cancellationToken = default);
}

public class InputValidationException : Exception
{
    public InputValidationException(string message) : base(message) { }
}
