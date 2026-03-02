using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using BajajDocumentProcessing.Infrastructure;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Tests for dependency injection configuration
/// </summary>
public class DependencyInjectionTests
{
    [Fact]
    public void AddInfrastructure_ShouldRegisterServices()
    {
        // Arrange
        var services = new ServiceCollection();
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = "Server=test;Database=test;",
            })
            .Build();

        // Act
        services.AddInfrastructure(configuration);
        var serviceProvider = services.BuildServiceProvider();

        // Assert
        Assert.NotNull(serviceProvider);
        // Additional service registrations will be tested as they are added
    }

    [Fact]
    public void AddInfrastructure_WithNullConfiguration_ShouldNotThrow()
    {
        // Arrange
        var services = new ServiceCollection();
        var configuration = new ConfigurationBuilder().Build();

        // Act & Assert
        var exception = Record.Exception(() => services.AddInfrastructure(configuration));
        Assert.Null(exception);
    }
}
