using Microsoft.Extensions.Configuration;
using Xunit;

namespace BajajDocumentProcessing.Tests.API;

/// <summary>
/// Tests for configuration loading
/// </summary>
public class ConfigurationTests
{
    [Fact]
    public void Configuration_ShouldLoadConnectionString()
    {
        // Arrange
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = "Server=test;Database=test;",
            })
            .Build();

        // Act
        var connectionString = configuration.GetConnectionString("DefaultConnection");

        // Assert
        Assert.NotNull(connectionString);
        Assert.Equal("Server=test;Database=test;", connectionString);
    }

    [Fact]
    public void Configuration_ShouldLoadAzureSettings()
    {
        // Arrange
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AzureServices:OpenAI:Endpoint"] = "https://test.openai.azure.com",
                ["AzureServices:OpenAI:ApiKey"] = "test-key",
                ["AzureServices:OpenAI:DeploymentName"] = "gpt-4",
            })
            .Build();

        // Act
        var endpoint = configuration["AzureServices:OpenAI:Endpoint"];
        var apiKey = configuration["AzureServices:OpenAI:ApiKey"];
        var deploymentName = configuration["AzureServices:OpenAI:DeploymentName"];

        // Assert
        Assert.Equal("https://test.openai.azure.com", endpoint);
        Assert.Equal("test-key", apiKey);
        Assert.Equal("gpt-4", deploymentName);
    }

    [Fact]
    public void Configuration_ShouldHandleMissingValues()
    {
        // Arrange
        var configuration = new ConfigurationBuilder().Build();

        // Act
        var missingValue = configuration["NonExistent:Key"];

        // Assert
        Assert.Null(missingValue);
    }
}
