using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using BajajDocumentProcessing.Infrastructure;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.API.Middleware;
using BajajDocumentProcessing.API.Filters;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token."
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
    
    // Enable file upload support in Swagger
    options.OperationFilter<FileUploadOperationFilter>();
    
    // Include XML comments for API documentation
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    options.IncludeXmlComments(xmlPath);
});

// Add Infrastructure layer
builder.Services.AddInfrastructure(builder.Configuration);

// Add HttpContextAccessor for CorrelationIdService
builder.Services.AddHttpContextAccessor();

// Configure JWT Authentication
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT Secret not configured");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "BajajDocumentProcessing";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "BajajDocumentProcessing";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.ASCII.GetBytes(jwtSecret)),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(5)
    };
});

// Configure Authorization Policies
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AgencyOnly", policy => policy.RequireRole("Agency"));
    options.AddPolicy("ASMOnly", policy => policy.RequireRole("ASM"));
    options.AddPolicy("RAOnly", policy => policy.RequireRole("HQ")); // HQ role name kept for DB compatibility
    options.AddPolicy("ASMOrRA", policy => policy.RequireRole("ASM", "HQ")); // HQ role name kept for DB compatibility
});

// Configure CORS for Flutter frontend
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Seed database
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    
    try
    {
        // Debug: Check configuration before getting DbContext
        var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
        var environment = app.Environment.EnvironmentName;
        
        logger.LogInformation("Environment: {Environment}", environment);
        logger.LogInformation("Connection string is null: {IsNull}", connectionString == null);
        logger.LogInformation("Connection string is empty: {IsEmpty}", string.IsNullOrEmpty(connectionString));
        
        if (!string.IsNullOrEmpty(connectionString))
        {
            logger.LogInformation("Connection string length: {Length} characters", connectionString.Length);
            logger.LogInformation("Connection string starts with: {Start}", connectionString.Substring(0, Math.Min(20, connectionString.Length)));
        }
        
        if (string.IsNullOrEmpty(connectionString))
        {
            logger.LogError("Connection string 'DefaultConnection' is null or empty. Check appsettings.json configuration.");
            logger.LogError("Current directory: {Directory}", Directory.GetCurrentDirectory());
            throw new InvalidOperationException("Database connection string is not configured.");
        }
        
        var context = services.GetRequiredService<ApplicationDbContext>();
        
        // Drop and recreate database to ensure schema matches current entity model
        logger.LogInformation("Dropping existing database if it exists...");
        await context.Database.EnsureDeletedAsync();
        
        logger.LogInformation("Creating database with current schema...");
        await context.Database.EnsureCreatedAsync();
        
        logger.LogInformation("Seeding database...");
        await ApplicationDbContextSeed.SeedAsync(context);
        
        logger.LogInformation("Database seeding completed successfully.");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while seeding the database.");
        throw; // Re-throw to prevent app from starting with invalid database
    }
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowFlutterApp");

// Correlation ID middleware - must be early in pipeline
app.UseMiddleware<CorrelationIdMiddleware>();

// Global exception handling - must be early in pipeline
app.UseMiddleware<GlobalExceptionMiddleware>();

app.UseAuthentication();
app.UseAuditLogging();
app.UseAuthorization();
app.MapControllers();

app.Run();
