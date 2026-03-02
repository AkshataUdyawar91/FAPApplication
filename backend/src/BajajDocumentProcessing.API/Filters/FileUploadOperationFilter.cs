using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace BajajDocumentProcessing.API.Filters;

/// <summary>
/// Swagger operation filter to properly display file upload parameters
/// </summary>
public class FileUploadOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var fileParameters = context.MethodInfo.GetParameters()
            .Where(p => p.ParameterType == typeof(IFormFile))
            .ToList();

        if (!fileParameters.Any())
            return;

        operation.RequestBody = new OpenApiRequestBody
        {
            Content = new Dictionary<string, OpenApiMediaType>
            {
                ["multipart/form-data"] = new OpenApiMediaType
                {
                    Schema = new OpenApiSchema
                    {
                        Type = "object",
                        Properties = context.MethodInfo.GetParameters()
                            .ToDictionary(
                                p => p.Name!,
                                p => p.ParameterType == typeof(IFormFile)
                                    ? new OpenApiSchema { Type = "string", Format = "binary" }
                                    : new OpenApiSchema { Type = GetSchemaType(p.ParameterType) }
                            ),
                        Required = context.MethodInfo.GetParameters()
                            .Where(p => !IsNullable(p.ParameterType))
                            .Select(p => p.Name!)
                            .ToHashSet()
                    }
                }
            }
        };
    }

    private static string GetSchemaType(Type type)
    {
        if (type == typeof(string)) return "string";
        if (type == typeof(int) || type == typeof(int?)) return "integer";
        if (type == typeof(long) || type == typeof(long?)) return "integer";
        if (type == typeof(bool) || type == typeof(bool?)) return "boolean";
        if (type == typeof(Guid) || type == typeof(Guid?)) return "string";
        if (type.IsEnum) return "string";
        return "string";
    }

    private static bool IsNullable(Type type)
    {
        return Nullable.GetUnderlyingType(type) != null || 
               !type.IsValueType ||
               type == typeof(string);
    }
}
