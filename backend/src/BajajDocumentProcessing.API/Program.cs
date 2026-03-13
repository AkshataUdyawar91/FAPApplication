using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using BajajDocumentProcessing.Infrastructure;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.API.Middleware;
using BajajDocumentProcessing.API.Filters;
using BajajDocumentProcessing.API.Hubs;
using BajajDocumentProcessing.API.Services;
using BajajDocumentProcessing.Application.Common.Interfaces;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddSignalR();
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

// Override the no-op notification service with the real SignalR implementation
builder.Services.AddScoped<ISubmissionNotificationService, SignalRSubmissionNotificationService>();

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
        ClockSkew = TimeSpan.FromMinutes(5),
        RoleClaimType = System.Security.Claims.ClaimTypes.Role,
        NameClaimType = System.Security.Claims.ClaimTypes.NameIdentifier
    };

    // SignalR sends JWT via query string for WebSocket connections
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
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

// Configure CORS for Flutter frontend and SignalR
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Seed database
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<ApplicationDbContext>();
        // Drop and recreate to pick up all schema changes (dev only)
        await context.Database.EnsureDeletedAsync();
        await context.Database.EnsureCreatedAsync();
        await ApplicationDbContextSeed.SeedAsync(context);
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while seeding the database.");
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
app.MapHub<SubmissionNotificationHub>("/hubs/submission");

app.Run();
