using Microsoft.Data.SqlClient;

Console.WriteLine("Creating BajajDocumentProcessing Database...");
Console.WriteLine();

// Connection string to master database
var masterConnectionString = @"Server=localhost\SQLEXPRESS;Database=master;Trusted_Connection=True;TrustServerCertificate=true";

try
{
    using var connection = new SqlConnection(masterConnectionString);
    connection.Open();
    
    Console.WriteLine("✓ Connected to SQL Server");
    Console.WriteLine($"Server: {connection.DataSource}");
    Console.WriteLine($"Version: {connection.ServerVersion}");
    Console.WriteLine();

    // Check if database already exists
    using (var checkCmd = connection.CreateCommand())
    {
        checkCmd.CommandText = "SELECT COUNT(*) FROM sys.databases WHERE name = 'BajajDocumentProcessing'";
        var exists = (int)checkCmd.ExecuteScalar();
        
        if (exists > 0)
        {
            Console.WriteLine("✓ Database 'BajajDocumentProcessing' already exists");
            return;
        }
    }

    Console.WriteLine("Creating database 'BajajDocumentProcessing'...");
    
    // Create database
    using (var createCmd = connection.CreateCommand())
    {
        createCmd.CommandText = "CREATE DATABASE BajajDocumentProcessing";
        createCmd.ExecuteNonQuery();
    }

    Console.WriteLine("✓ Database created successfully!");
    Console.WriteLine();
    Console.WriteLine("Next steps:");
    Console.WriteLine("  1. Restart the application");
    Console.WriteLine("  2. The application will automatically create tables and seed users");
    Console.WriteLine("  3. Login with: agency@bajaj.com / Password123!");
}
catch (Exception ex)
{
    Console.WriteLine($"✗ Error: {ex.Message}");
    Console.WriteLine($"Type: {ex.GetType().Name}");
    
    if (ex.InnerException != null)
    {
        Console.WriteLine($"Inner: {ex.InnerException.Message}");
    }
    
    Console.WriteLine();
    Console.WriteLine("Troubleshooting:");
    Console.WriteLine("  1. Ensure SQL Server Express is running");
    Console.WriteLine("  2. Check Windows Authentication is enabled");
    Console.WriteLine("  3. Verify you have permissions to create databases");
}
